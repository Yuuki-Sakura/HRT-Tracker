import Foundation
import HRTModels
import HRTPKEngine

enum PatchInputMode: String, CaseIterable, Identifiable {
    case totalDose
    case releaseRate
    var id: Self { self }
}

nonisolated enum FocusedDoseField: Hashable, Sendable {
    case raw
    case e2
    case doseMG
    case patchTotal
    case patchRelease
    case customTheta
}

struct DraftDoseEvent {
    var id: UUID?
    var date = Date()
    var route: Route = .injection
    var ester: Ester = .EV

    var rawEsterDoseText: String = ""
    var e2EquivalentDoseText: String = ""

    var patchMode: PatchInputMode = .totalDose
    var releaseRateText: String = ""
    var patchWearDays: Int = 3

    var useCustomTheta: Bool = false
    var customThetaText: String = ""

    var applicationSite: ApplicationSite?

    var availableEsters: [Ester] {
        route.availableEsters
    }

    func parsedDouble(_ text: String) -> Double? {
        DecimalField.parse(text)
    }

    // MARK: - Conversions

    /// 释放速率 + 佩戴天数 → e2EquivalentDoseText
    mutating func convertRateToE2() {
        guard let rate = parsedDouble(releaseRateText) else { return }
        let mg = rate * Double(patchWearDays) / 1000.0
        e2EquivalentDoseText = String(format: "%.2f", mg)
    }

    /// e2EquivalentDoseText + 佩戴天数 → releaseRateText
    mutating func convertE2ToRate() {
        guard let mg = parsedDouble(e2EquivalentDoseText), patchWearDays > 0 else { return }
        let rate = mg * 1000.0 / Double(patchWearDays)
        releaseRateText = String(format: "%.0f", rate)
    }

    /// rawEsterDoseText → e2EquivalentDoseText (via toE2Factor)
    mutating func convertToE2Equivalent() {
        guard let rawDose = parsedDouble(rawEsterDoseText) else { return }
        e2EquivalentDoseText = String(format: "%.2f", rawDose * EsterInfo.by(ester: ester).toE2Factor)
    }

    /// e2EquivalentDoseText → rawEsterDoseText (via toE2Factor)
    mutating func convertToRawEster() {
        guard ester != .E2, let e2Dose = parsedDouble(e2EquivalentDoseText) else { return }
        rawEsterDoseText = String(format: "%.2f", e2Dose / EsterInfo.by(ester: ester).toE2Factor)
    }

    /// 酯类切换后同步两个剂量文本
    mutating func syncDoseTextsAfterEsterChange() {
        if ester == .CPA { e2EquivalentDoseText = ""; return }
        if ester == .E2 { rawEsterDoseText = ""; return }
        if !e2EquivalentDoseText.isEmpty, parsedDouble(e2EquivalentDoseText) != nil {
            convertToRawEster()
        } else if !rawEsterDoseText.isEmpty, parsedDouble(rawEsterDoseText) != nil {
            convertToE2Equivalent()
        }
    }

    // MARK: - Extras

    func buildExtras() -> [ExtraKey: Double] {
        var extras: [ExtraKey: Double] = [:]

        if route == .patchApply && patchMode == .releaseRate {
            if let rateUG = parsedDouble(releaseRateText) {
                extras[.releaseRateUGPerDay] = rateUG
            }
        }

        if route == .patchApply {
            extras[.patchWearDays] = Double(patchWearDays)
        }

        if route == .sublingual {
            if useCustomTheta, let th = parsedDouble(customThetaText) {
                extras[.sublingualTheta] = max(0.0, min(1.0, th))
            }
        }

        if let site = applicationSite {
            extras[.applicationSite] = Double(site.rawValue)
        }

        return extras
    }

    /// route 变更后重置所有路由相关字段
    mutating func resetForRouteChange() {
        if let first = availableEsters.first { ester = first }
        rawEsterDoseText = ""
        e2EquivalentDoseText = ""
        patchMode = .totalDose
        releaseRateText = ""
        useCustomTheta = false
        customThetaText = ""
        applicationSite = nil
    }

    // MARK: - Validation

    var isValid: Bool {
        if route == .patchApply && patchMode == .releaseRate {
            guard let rate = parsedDouble(releaseRateText), rate > 0 else { return false }
            return true
        }
        if ester == .CPA {
            guard let dose = parsedDouble(rawEsterDoseText), dose > 0 else { return false }
            return true
        }
        guard let dose = parsedDouble(e2EquivalentDoseText), dose > 0 else { return false }
        return true
    }

    // MARK: - Build DoseEvent

    func toDoseEvent() -> DoseEvent {
        var dose: Double
        if ester == .CPA {
            dose = parsedDouble(rawEsterDoseText) ?? 0
        } else {
            dose = parsedDouble(e2EquivalentDoseText) ?? 0
        }

        var extras = buildExtras()

        if route == .patchApply && patchMode == .releaseRate {
            dose = 0
        }

        return DoseEvent(
            id: id ?? UUID(),
            route: route,
            timestamp: Int64(date.timeIntervalSince1970),
            doseMG: dose,
            ester: ester,
            extras: extras
        )
    }

    // MARK: - Factory Methods

    static func from(_ template: DoseTemplate) -> DraftDoseEvent {
        let isCPA = template.ester == .CPA
        var draft = DraftDoseEvent(
            id: nil,
            date: Date(),
            route: template.route,
            ester: template.ester,
            rawEsterDoseText: isCPA
                ? String(format: "%.2f", template.doseMG)
                : (template.ester == .E2 ? "" : String(format: "%.2f", template.doseMG / EsterInfo.by(ester: template.ester).toE2Factor)),
            e2EquivalentDoseText: isCPA ? "" : String(format: "%.2f", template.doseMG)
        )
        draft.restoreExtras(route: template.route, extras: template.extras)
        return draft
    }

    static func from(_ event: DoseEvent) -> DraftDoseEvent {
        let isCPA = event.ester == .CPA
        var draft = DraftDoseEvent(
            id: event.id,
            date: event.date,
            route: event.route,
            ester: event.ester,
            rawEsterDoseText: isCPA
                ? String(format: "%.2f", event.doseMG)
                : (event.ester == .E2 ? "" : String(format: "%.2f", event.doseMG / EsterInfo.by(ester: event.ester).toE2Factor)),
            e2EquivalentDoseText: isCPA ? "" : String(format: "%.2f", event.doseMG)
        )
        draft.restoreExtras(route: event.route, extras: event.extras)
        return draft
    }

    static func from(_ mapping: MedicationMapping) -> DraftDoseEvent {
        let isCPA = mapping.ester == .CPA
        var draft = DraftDoseEvent(
            route: mapping.route,
            ester: mapping.ester,
            rawEsterDoseText: isCPA
                ? Self.formatDose(mapping.doseMG)
                : (mapping.ester == .E2 ? "" : Self.formatDose(mapping.doseMG / EsterInfo.by(ester: mapping.ester).toE2Factor)),
            e2EquivalentDoseText: isCPA ? "" : Self.formatDose(mapping.doseMG)
        )
        draft.restoreExtras(route: mapping.route, extras: mapping.extras)
        return draft
    }

    private static func formatDose(_ mg: Double) -> String {
        if mg == 0 { return "" }
        if mg == mg.rounded() { return "\(Int(mg))" }
        return String(format: "%.2f", mg)
    }

    // MARK: - Private

    private mutating func restoreExtras(route: Route, extras: [ExtraKey: Double]) {
        if route == .patchApply {
            if let rate = extras[.releaseRateUGPerDay] {
                patchMode = .releaseRate
                releaseRateText = String(format: "%.0f", rate)
                let days = extras[.patchWearDays] ?? 3
                e2EquivalentDoseText = String(format: "%.2f", rate * days / 1000.0)
            }
            if let days = extras[.patchWearDays] {
                patchWearDays = Int(days)
            }
        }

        if route == .sublingual, let theta = extras[.sublingualTheta] {
            useCustomTheta = true
            customThetaText = String(format: "%.2f", theta)
        }

        if let siteCode = extras[.applicationSite] {
            applicationSite = ApplicationSite(rawValue: Int(siteCode))
        }
    }
}
