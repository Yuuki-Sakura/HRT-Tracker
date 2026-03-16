import SwiftUI
import HRTModels

struct PatchFieldsView: View {
    @Binding var draft: DraftDoseEvent
    var focusedField: FocusState<FocusedDoseField?>.Binding

    var body: some View {
        Section(String(localized: "input.patchMode")) {
            Picker(String(localized: "input.patchMode.label"), selection: $draft.patchMode) {
                Text("input.patchMode.totalDose").tag(PatchInputMode.totalDose)
                Text("input.patchMode.releaseRate").tag(PatchInputMode.releaseRate)
            }
            .pickerStyle(.segmented)

            if draft.patchMode == .totalDose {
                TextField(String(localized: "input.patchMode.totalDose.placeholder"), text: $draft.e2EquivalentDoseText)
                    #if os(iOS) || os(watchOS)
                    .keyboardType(.decimalPad)
                    #endif
                    .focused(focusedField, equals: .patchTotal)
            } else {
                TextField(String(localized: "input.patchMode.releaseRate.placeholder"), text: $draft.releaseRateText)
                    #if os(iOS) || os(watchOS)
                    .keyboardType(.decimalPad)
                    #endif
                    .focused(focusedField, equals: .patchRelease)
            }

            Stepper(
                String(localized: "input.patchWearDays \(draft.patchWearDays)"),
                value: $draft.patchWearDays,
                in: 1...14
            )
        }

        Section(String(localized: "input.patch.site")) {
            Picker(String(localized: "input.patch.site.label"), selection: $draft.applicationSite) {
                Text("input.patch.site.none").tag(ApplicationSite?.none)
                ForEach(ApplicationSite.patchSites) { site in
                    Text(site.localizedName).tag(ApplicationSite?.some(site))
                }
            }

            if draft.applicationSite?.isScrotal == true {
                Text("input.patch.site.scrotalNote")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

#Preview {
    @Previewable @State var draft = DraftDoseEvent(route: .patchApply, ester: .E2)
    @Previewable @FocusState var focus: FocusedDoseField?
    Form {
        PatchFieldsView(draft: $draft, focusedField: $focus)
    }
}
