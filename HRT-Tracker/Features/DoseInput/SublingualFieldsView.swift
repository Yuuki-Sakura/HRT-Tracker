import SwiftUI
import HRTModels
import HRTPKEngine

struct SublingualFieldsView: View {
    @Binding var draft: DraftDoseEvent
    var focusedField: FocusState<FocusedDoseField?>.Binding

    private var currentTier: SublingualTier {
        let tiers: [SublingualTier] = [.quick, .casual, .standard, .strict]
        return tiers[min(max(draft.slTierIndex, 0), 3)]
    }

    var body: some View {
        Section(String(localized: "input.sublingual")) {
            Picker(String(localized: "input.sublingual.hold"), selection: $draft.slTierIndex) {
                Text("input.sublingual.quick").tag(0)
                Text("input.sublingual.casual").tag(1)
                Text("input.sublingual.standard").tag(2)
                Text("input.sublingual.strict").tag(3)
            }
            .pickerStyle(.segmented)

            let hold = SublingualTheta.holdMinutes[currentTier] ?? 0
            let theta = SublingualTheta.recommended[currentTier] ?? 0.11
            Text("input.sublingual.suggestion \(hold, specifier: "%.0f") \(theta, specifier: "%.2f")")
                .font(.footnote)
                .foregroundStyle(.secondary)

            Text("input.sublingual.instructions")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.leading)

            Toggle(String(localized: "input.sublingual.customTheta"), isOn: $draft.useCustomTheta)
            if draft.useCustomTheta {
                TextField(String(localized: "input.sublingual.customThetaPlaceholder"), text: $draft.customThetaText)
                    #if os(iOS) || os(watchOS)
                    .keyboardType(.decimalPad)
                    #endif
                    .focused(focusedField, equals: .customTheta)
            }
        }
    }
}

#Preview {
    @Previewable @State var draft = DraftDoseEvent(route: .sublingual, ester: .E2)
    @Previewable @FocusState var focus: FocusedDoseField?
    Form {
        SublingualFieldsView(draft: $draft, focusedField: $focus)
    }
}
