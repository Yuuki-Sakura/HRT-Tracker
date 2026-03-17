import SwiftUI
import HRTModels
import HRTServices

// MARK: - List View

struct MedicationMappingListView: View {
    @ObservedObject var vm: TimelineViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            if vm.medications.isEmpty {
                ContentUnavailableView(
                    String(localized: "settings.healthkit.mapping.empty"),
                    systemImage: "pills",
                    description: Text(String(localized: "settings.healthkit.mapping.empty.description"))
                )
            } else {
                ForEach(vm.medications) { med in
                    NavigationLink {
                        MedicationMappingDetailView(vm: vm, medication: med)
                            .id(med.id)
                    } label: {
                        medicationRow(med)
                    }
                }
            }
        }
        .id(vm.medicationMappings.count)
        .navigationTitle(String(localized: "settings.healthkit.mapping.title"))
        #if !os(macOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(String(localized: "btn.cancel")) { dismiss() }
            }
        }
        .task {
            await vm.requestMedicationAuthorization()
            await vm.fetchMedicationsFromHealthKit()
        }
    }

    @ViewBuilder
    private func medicationRow(_ med: MedicationInfo) -> some View {
        let mapping = vm.medicationMappings.first(where: { $0.id == med.id })
        HStack {
            Image(systemName: "pill")
                .foregroundStyle(mapping != nil ? Color.accentColor : Color.secondary)
            VStack(alignment: .leading) {
                Text(med.displayName)
                if mapping == nil {
                    Text(String(localized: "settings.healthkit.notConfigured"))
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }
        }
    }
}

// MARK: - Detail View

struct MedicationMappingDetailView: View {
    @ObservedObject var vm: TimelineViewModel
    let medication: MedicationInfo
    @Environment(\.dismiss) private var dismiss

    @State private var draft: DraftDoseEvent
    @State private var doseMGText: String
    @FocusState private var focusedField: FocusedDoseField?

    private static let mappableRoutes: [Route] = [.injection, .patchApply, .gel, .oral, .sublingual]

    init(vm: TimelineViewModel, medication: MedicationInfo) {
        self.vm = vm
        self.medication = medication

        let existingMapping = vm.medicationMappings.first(where: { $0.id == medication.id })
        let parsedMG = MedicationRecognizer.parseStrengthMG(medication.displayName)

        if let mapping = existingMapping {
            var d = DraftDoseEvent()
            d.route = mapping.route
            d.ester = mapping.ester
            // Restore extras from mapping
            if mapping.route == .patchApply {
                if let rate = mapping.extras[.releaseRateUGPerDay] {
                    d.patchMode = .releaseRate
                    d.releaseRateText = String(format: "%.0f", rate)
                }
                if let days = mapping.extras[.patchWearDays] {
                    d.patchWearDays = Int(days)
                }
            }
            if mapping.route == .sublingual {
                if let theta = mapping.extras[.sublingualTheta] {
                    d.useCustomTheta = true
                    d.customThetaText = String(format: "%.2f", theta)
                }
            }
            if let siteCode = mapping.extras[.applicationSite] {
                d.applicationSite = ApplicationSite(rawValue: Int(siteCode))
            }
            _draft = State(initialValue: d)
            _doseMGText = State(initialValue: Self.formatMG(mapping.doseMG))
        } else if let recognized = MedicationRecognizer.recognize(medication.displayName) {
            let route = recognized.ester == .CPA ? .oral : (medication.route ?? .injection)
            var d = DraftDoseEvent()
            d.route = route
            d.ester = recognized.ester
            _draft = State(initialValue: d)
            _doseMGText = State(initialValue: parsedMG.map { Self.formatMG($0) } ?? "")
        } else {
            var d = DraftDoseEvent()
            d.route = medication.route ?? .injection
            d.ester = (medication.route ?? .injection).availableEsters.first ?? .EV
            _draft = State(initialValue: d)
            _doseMGText = State(initialValue: parsedMG.map { Self.formatMG($0) } ?? "")
        }
    }

    private static func formatMG(_ mg: Double) -> String {
        if mg == mg.rounded() { return "\(Int(mg))" }
        return "\(mg)"
    }

    private var parsedDoseMG: Double? {
        DecimalField.parse(doseMGText)
    }

    var body: some View {
        Form {
            Section {
                HStack {
                    Image(systemName: "pill.fill")
                        .foregroundStyle(.tint)
                    Text(medication.displayName)
                        .fontWeight(.medium)
                }
            }

            Section(String(localized: "settings.healthkit.mapping.route")) {
                Picker(String(localized: "settings.healthkit.mapping.route"), selection: $draft.route) {
                    ForEach(Self.mappableRoutes) { route in
                        Text(route.localizedName).tag(route)
                    }
                }
                .pickerStyle(.menu)
                .onChange(of: draft.route) { _, _ in
                    // Reset ester to first available for new route
                    if let first = draft.availableEsters.first {
                        draft.ester = first
                    }
                    // Reset route-specific fields
                    draft.patchMode = .totalDose
                    draft.releaseRateText = ""
                    draft.useCustomTheta = false
                    draft.customThetaText = ""
                    draft.applicationSite = nil
                }
            }

            Section(String(localized: "settings.healthkit.mapping.ester")) {
                if draft.availableEsters.count > 1 {
                    Picker(String(localized: "settings.healthkit.mapping.ester"), selection: $draft.ester) {
                        ForEach(draft.availableEsters) { ester in
                            Text(ester.localizedName).tag(ester)
                        }
                    }
                    .pickerStyle(.menu)
                } else {
                    HStack {
                        Text(String(localized: "settings.healthkit.mapping.ester"))
                        Spacer()
                        Text(draft.ester.localizedName)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section(String(localized: "settings.healthkit.mapping.dose")) {
                    DecimalField(label: "mg", text: $doseMGText, suffix: "mg")
            }

            // Route-specific fields
            if draft.route == .patchApply {
                PatchFieldsView(draft: $draft, focusedField: $focusedField)
            }

            if draft.route == .gel {
                GelFieldsView(draft: $draft)
            }

            if draft.route == .sublingual {
                SublingualFieldsView(draft: $draft, focusedField: $focusedField)
            }
        }
        #if os(iOS)
        .scrollDismissesKeyboard(.interactively)
        #endif
        .navigationTitle(medication.displayName)
        #if !os(macOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button(String(localized: "common.save")) {
                    guard let mg = parsedDoseMG, mg > 0 else { return }
                    let extras = buildExtras()
                    let mapping = MedicationMapping(
                        id: medication.id,
                        displayName: medication.displayName,
                        route: draft.route,
                        ester: draft.ester,
                        doseMG: mg,
                        extras: extras
                    )
                    vm.saveMedicationMapping(mapping)
                    dismiss()
                    Task {
                        await vm.importDoseEventsFromHealthKit()
                    }
                }
                .disabled(parsedDoseMG == nil || (parsedDoseMG ?? 0) <= 0)
            }
        }
    }

    /// Build extras dict from draft state, matching DraftDoseEvent.toDoseEvent() logic.
    private func buildExtras() -> [ExtraKey: Double] {
        var extras: [ExtraKey: Double] = [:]

        if draft.route == .patchApply {
            extras[.patchWearDays] = Double(draft.patchWearDays)
            if draft.patchMode == .releaseRate,
               let rate = draft.parsedDouble(draft.releaseRateText) {
                extras[.releaseRateUGPerDay] = rate
            }
        }

        if draft.route == .sublingual {
            if draft.useCustomTheta, let th = draft.parsedDouble(draft.customThetaText) {
                extras[.sublingualTheta] = max(0.0, min(1.0, th))
            }
        }

        if let site = draft.applicationSite {
            extras[.applicationSite] = Double(site.rawValue)
        }

        return extras
    }
}
