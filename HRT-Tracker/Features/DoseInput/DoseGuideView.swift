import SwiftUI
import HRTModels

struct DoseGuideView: View {
    let route: Route
    let ester: Ester
    let doseText: String

    private var parsedDose: Double? {
        Double(doseText.replacingOccurrences(of: ",", with: "."))
    }

    var body: some View {
        if let config = thresholds {
            doseGuide(config: config)
        } else if route == .injection {
            // Injection uses InjectionGuideView separately
            EmptyView()
        }
    }

    // MARK: - Dose Guide

    private func doseGuide(config: DoseThresholds) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Label(String(localized: "dose.guide.title"), systemImage: "info.circle")
                    .font(.subheadline.bold())
                Spacer()
                if let dose = parsedDose, dose > 0 {
                    Text(levelLabel(dose: dose, config: config))
                        .font(.caption.bold())
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(levelColor(dose: dose, config: config).opacity(0.15), in: Capsule())
                        .foregroundStyle(levelColor(dose: dose, config: config))
                }
            }

            if let dose = parsedDose, dose > 0 {
                Text(String(localized: "dose.guide.current") + ": \(String(format: "%.1f", dose)) \(config.unit)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("dose.guide.current_blank")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text(String(localized: "dose.guide.reference") + ": " + config.referenceText)
                .font(.caption)
                .foregroundStyle(.secondary)

            if ester == .CPA {
                Text(String(localized: "dose.guide.cpa_hint.rec"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(String(localized: "dose.guide.cpa_hint.combo"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(String(localized: "dose.guide.cpa_hint.ultralow"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 12))
    }

    // MARK: - Thresholds

    private struct DoseThresholds {
        let thresholds: [Double] // [low, medium, high, veryHigh]
        let unit: String
        var referenceText: String {
            thresholds.map { String(format: "%.1f", $0) }.joined(separator: " / ") + " \(unit)"
        }
    }

    private var thresholds: DoseThresholds? {
        if ester == .CPA {
            return DoseThresholds(thresholds: [5, 12.5, 25, 50], unit: "mg")
        }
        switch route {
        case .oral:
            return DoseThresholds(thresholds: [2, 4, 8, 12], unit: "mg")
        case .sublingual:
            return DoseThresholds(thresholds: [1, 2, 4, 6], unit: "mg")
        case .patchApply:
            return DoseThresholds(thresholds: [100, 200, 400, 600], unit: String(localized: "unit.ug_per_day"))
        case .gel:
            return DoseThresholds(thresholds: [1.5, 3, 6, 9], unit: "mg")
        default:
            return nil
        }
    }

    private func levelLabel(dose: Double, config: DoseThresholds) -> String {
        let t = config.thresholds
        if dose <= t[0] { return String(localized: "dose.guide.level.low") }
        if dose <= t[1] { return String(localized: "dose.guide.level.medium") }
        if dose <= t[2] { return String(localized: "dose.guide.level.high") }
        if dose <= t[3] { return String(localized: "dose.guide.level.very_high") }
        return String(localized: "dose.guide.level.above")
    }

    private func levelColor(dose: Double, config: DoseThresholds) -> Color {
        let t = config.thresholds
        if dose <= t[0] { return .green }
        if dose <= t[1] { return .blue }
        if dose <= t[2] { return .orange }
        if dose <= t[3] { return .red }
        return .red.opacity(0.8)
    }
}

#Preview {
    VStack(spacing: 16) {
        DoseGuideView(route: .oral, ester: .E2, doseText: "3")
        DoseGuideView(route: .oral, ester: .CPA, doseText: "12.5")
    }
    .padding()
}
