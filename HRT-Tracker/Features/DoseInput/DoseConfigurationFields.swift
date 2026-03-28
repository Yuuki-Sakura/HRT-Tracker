import SwiftUI
import HRTModels

/// Shared form sections for dose configuration: route, ester, dose fields,
/// route-specific fields, dose guide, and all onChange logic.
struct DoseConfigurationFields: View {
    @Binding var draft: DraftDoseEvent
    var focusedField: FocusState<FocusedDoseField?>.Binding

    var body: some View {
        Group {
            routeSection
            esterSection
            doseSection
            routeSpecificFields
            doseGuideSection
        }
        // Patch: releaseRate → e2
        .onChange(of: draft.releaseRateText) { _, _ in
            guard draft.route == .patchApply, draft.patchMode == .releaseRate,
                  focusedField.wrappedValue == .patchRelease else { return }
            draft.convertRateToE2()
        }
        // Patch: e2 (patchTotal) → releaseRate
        .onChange(of: draft.e2EquivalentDoseText) { _, _ in
            let focused = focusedField.wrappedValue
            if draft.route == .patchApply, draft.patchMode == .totalDose, focused == .patchTotal {
                draft.convertE2ToRate()
            } else if focused == .e2 {
                if draft.route == .patchApply && draft.patchMode == .releaseRate {
                    draft.convertE2ToRate()
                } else {
                    draft.convertToRawEster()
                }
            }
        }
        // Raw ester → e2
        .onChange(of: draft.rawEsterDoseText) { _, _ in
            guard focusedField.wrappedValue == .raw else { return }
            draft.convertToE2Equivalent()
        }
        // Ester change → sync dose texts
        .onChange(of: draft.ester) { _, _ in
            draft.syncDoseTextsAfterEsterChange()
        }
        // Patch wear days → recalculate
        .onChange(of: draft.patchWearDays) { _, _ in
            guard draft.route == .patchApply else { return }
            if draft.patchMode == .releaseRate {
                draft.convertRateToE2()
            } else {
                draft.convertE2ToRate()
            }
        }
        // Patch mode switch → sync
        .onChange(of: draft.patchMode) { _, newMode in
            guard draft.route == .patchApply else { return }
            if newMode == .releaseRate, !draft.e2EquivalentDoseText.isEmpty {
                draft.convertE2ToRate()
            } else if newMode == .totalDose, !draft.releaseRateText.isEmpty {
                draft.convertRateToE2()
            }
        }
    }

    // MARK: - Sections

    private var routeSection: some View {
        Section {
            Picker(String(localized: "input.route"), selection: $draft.route) {
                Text("input.route.injection").tag(Route.injection)
                Text("input.route.patchApply").tag(Route.patchApply)
                Text("input.route.gel").tag(Route.gel)
                Text("input.route.oral").tag(Route.oral)
                Text("input.route.sublingual").tag(Route.sublingual)
            }
            .onChange(of: draft.route) { _, _ in
                draft.resetForRouteChange()
            }
        }
    }

    private var esterSection: some View {
        Section(String(localized: "input.drugEster")) {
            if draft.availableEsters.count > 1 {
                Picker(String(localized: "input.drugEster"), selection: $draft.ester) {
                    ForEach(draft.availableEsters) { e in
                        Text(e.localizedName).tag(e)
                    }
                }
            } else {
                HStack {
                    Text(String(localized: "input.drugEster"))
                    Spacer()
                    Text(draft.ester.localizedName)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    @ViewBuilder
    private var doseSection: some View {
        Section(String(localized: "input.drugDetails")) {
            if draft.ester == .CPA {
                DecimalField(label: String(localized: "input.dose.cpa"), text: $draft.rawEsterDoseText, suffix: "mg")
                    .focused(focusedField, equals: .raw)
            } else {
                if draft.ester != .E2 {
                    DecimalField(label: String(localized: "input.dose.raw \(draft.ester.rawValue)"), text: $draft.rawEsterDoseText, suffix: "mg")
                        .focused(focusedField, equals: .raw)
                }

                DecimalField(label: String(localized: "input.dose.e2"), text: $draft.e2EquivalentDoseText, suffix: "mg")
                    .focused(focusedField, equals: .e2)
            }
        }
    }

    @ViewBuilder
    private var routeSpecificFields: some View {
        if draft.route == .patchApply {
            PatchFieldsView(draft: $draft, focusedField: focusedField)
        }
        if draft.route == .gel {
            GelFieldsView(draft: $draft)
        }
        if draft.route == .injection {
            InjectionFieldsView(draft: $draft, focusedField: focusedField)
        }
        if draft.route == .sublingual {
            SublingualFieldsView(draft: $draft, focusedField: focusedField)
        }
    }

    private var doseGuideSection: some View {
        Section {
            if draft.route == .injection {
                InjectionGuideView()
            }
            DoseGuideView(
                route: draft.route,
                ester: draft.ester,
                doseText: draft.ester == .CPA ? draft.rawEsterDoseText : draft.e2EquivalentDoseText
            )
        }
        .listRowBackground(Color.clear)
        .listRowInsets(EdgeInsets())
    }
}

#Preview {
    @Previewable @State var draft = DraftDoseEvent(route: .patchApply, ester: .E2)
    @Previewable @FocusState var focus: FocusedDoseField?
    NavigationStack {
        Form {
            DoseConfigurationFields(draft: $draft, focusedField: $focus)
        }
    }
}
