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

    var slTierIndex: Int = 2
    var useCustomTheta: Bool = false
    var customThetaText: String = ""

    var applicationSite: ApplicationSite?

    var availableEsters: [Ester] {
        switch route {
        case .injection: return [.EB, .EV, .EC, .EN]
        case .patchApply, .patchRemove, .gel: return [.E2]
        case .oral: return [.E2, .EV, .CPA]
        case .sublingual: return [.E2, .EV]
        }
    }

    func parsedDouble(_ text: String) -> Double? {
        let sanitized = text.replacingOccurrences(of: ",", with: ".")
        return Double(sanitized)
    }

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

    func toDoseEvent() -> DoseEvent {
        var dose: Double
        if ester == .CPA {
            dose = parsedDouble(rawEsterDoseText) ?? 0
        } else {
            dose = parsedDouble(e2EquivalentDoseText) ?? 0
        }
        var extras: [ExtraKey: Double] = [:]

        if route == .patchApply && patchMode == .releaseRate {
            dose = 0
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
            } else {
                extras[.sublingualTier] = Double(min(max(slTierIndex, 0), 3))
            }
        }

        if let site = applicationSite {
            extras[.applicationSite] = Double(site.rawValue)
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

        if template.route == .patchApply {
            if let rate = template.extras[.releaseRateUGPerDay] {
                draft.patchMode = .releaseRate
                draft.releaseRateText = String(format: "%.0f", rate)
                let days = template.extras[.patchWearDays] ?? 3
                draft.e2EquivalentDoseText = String(format: "%.2f", rate * days / 1000.0)
            }
            if let days = template.extras[.patchWearDays] {
                draft.patchWearDays = Int(days)
            }
        }

        if template.route == .sublingual {
            if let theta = template.extras[.sublingualTheta] {
                draft.useCustomTheta = true
                draft.customThetaText = String(format: "%.2f", theta)
            }
            if let tierCode = template.extras[.sublingualTier] {
                draft.slTierIndex = min(max(Int(tierCode.rounded()), 0), 3)
            }
        }

        if let siteCode = template.extras[.applicationSite] {
            draft.applicationSite = ApplicationSite(rawValue: Int(siteCode))
        }

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

        if event.route == .patchApply {
            if let rate = event.extras[.releaseRateUGPerDay] {
                draft.patchMode = .releaseRate
                draft.releaseRateText = String(format: "%.0f", rate)
                let days = event.extras[.patchWearDays] ?? 3
                draft.e2EquivalentDoseText = String(format: "%.2f", rate * days / 1000.0)
            }
            if let days = event.extras[.patchWearDays] {
                draft.patchWearDays = Int(days)
            }
        }

        if event.route == .sublingual {
            if let theta = event.extras[.sublingualTheta] {
                draft.useCustomTheta = true
                draft.customThetaText = String(format: "%.2f", theta)
            }
            if let tierCode = event.extras[.sublingualTier] {
                draft.slTierIndex = min(max(Int(tierCode.rounded()), 0), 3)
            }
        }

        if let siteCode = event.extras[.applicationSite] {
            draft.applicationSite = ApplicationSite(rawValue: Int(siteCode))
        }

        return draft
    }
}
