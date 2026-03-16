import SwiftUI
import HRTModels
import HRTPKEngine

struct SublingualFieldsView: View {
    @Binding var draft: DraftDoseEvent
    var focusedField: FocusState<FocusedDoseField?>.Binding

    var body: some View {
        Section(String(localized: "input.sublingual")) {
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
                Text("input.sublingual.thetaReference")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
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
