import SwiftUI
import HRTModels

struct TimelineRowView: View {
    let event: DoseEvent

    private var icon: (name: String, fgColor: Color, bgColor: Color) {
        if event.ester == .CPA {
            return ("pills.fill", .indigo, Color.indigo.opacity(0.12))
        }
        switch event.route {
        case .injection: return ("syringe.fill", .pink, Color.pink.opacity(0.12))
        case .patchApply, .patchRemove: return ("bandage.fill", .orange, Color.orange.opacity(0.12))
        case .gel: return ("drop.fill", .cyan, Color.cyan.opacity(0.12))
        case .oral: return ("pills.fill", .purple, Color.purple.opacity(0.12))
        case .sublingual: return ("pills.fill", .teal, Color.teal.opacity(0.12))
        }
    }

    /// Drug name: "醋酸环丙孕酮 (CPA)"
    private var drugName: String {
        "\(event.ester.localizedName) (\(event.ester.rawValue))"
    }

    /// Route display: "肌肉注射 (Injection)"
    private var routeDisplay: String {
        let base: String
        switch event.route {
        case .injection:  base = String(localized: "route.injection")
        case .oral:       base = String(localized: "route.oral")
        case .sublingual: base = String(localized: "route.sublingual")
        case .gel:        base = String(localized: "route.gel")
        case .patchApply, .patchRemove: base = String(localized: "route.patchApply")
        }
        if let code = event.extras[.applicationSite],
           let site = ApplicationSite(rawValue: Int(code)) {
            return "\(base) · \(site.localizedName)"
        }
        return base
    }

    /// Dose text: "6.00 mg" or "100 µg/天"
    private var doseText: String? {
        if let rateUG = event.extras[.releaseRateUGPerDay] {
            let rateStr = String(format: "%.0f", rateUG)
            let base = String(localized: "timeline.row.patch_rate \(rateStr)")
            if let days = event.extras[.patchWearDays] {
                let dayStr = String(localized: "timeline.row.patch_days \(Int(days))")
                return "\(base) · \(dayStr)"
            }
            return base
        }
        guard event.doseMG > 0 else { return nil }
        let base = String(format: "%.2f mg", event.doseMG)
        if event.route == .patchApply, let days = event.extras[.patchWearDays] {
            let dayStr = String(localized: "timeline.row.patch_days \(Int(days))")
            return "\(base) · \(dayStr)"
        }
        return base
    }

    /// Estradiol equivalent for ester injections: "(雌二醇 eq: 4.58 mg)"
    private var e2EquivalentText: String? {
        guard event.ester.isEstrogen, event.ester != .E2, event.doseMG > 0 else { return nil }
        let factor = EsterInfo.by(ester: event.ester).toE2Factor
        let e2mg = event.doseMG * factor
        return String(localized: "timeline.row.e2eq \(String(format: "%.2f", e2mg))")
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon.name)
                .font(.title3)
                .foregroundStyle(icon.fgColor)
                .frame(width: 44, height: 44)
                .background(icon.bgColor, in: Circle())

            VStack(alignment: .leading, spacing: 3) {
                Text(drugName)
                    .font(.headline)
                Text(routeDisplay)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                if let doseText {
                    HStack(spacing: 6) {
                        Text(doseText)
                            .font(.subheadline.weight(.semibold))
                        if let eq = e2EquivalentText {
                            Text(eq)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Spacer()

            Text(event.date, style: .time)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 6)
        .contentShape(Rectangle())
    }
}

#Preview {
    List {
        TimelineRowView(event: DoseEvent(route: .injection, timestamp: Int64(Date().timeIntervalSince1970), doseMG: 6.0, ester: .EV))
        TimelineRowView(event: DoseEvent(route: .oral, timestamp: Int64(Date().timeIntervalSince1970), doseMG: 12.5, ester: .CPA))
        TimelineRowView(event: DoseEvent(route: .oral, timestamp: Int64(Date().timeIntervalSince1970), doseMG: 2.0, ester: .E2))
        TimelineRowView(event: DoseEvent(route: .sublingual, timestamp: Int64(Date().timeIntervalSince1970), doseMG: 1.0, ester: .EV))
        TimelineRowView(event: DoseEvent(route: .patchApply, timestamp: Int64(Date().timeIntervalSince1970), doseMG: 0, ester: .E2, extras: [.releaseRateUGPerDay: 100]))
        TimelineRowView(event: DoseEvent(route: .gel, timestamp: Int64(Date().timeIntervalSince1970), doseMG: 1.5, ester: .E2))
    }
}
