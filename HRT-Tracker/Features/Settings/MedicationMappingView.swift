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
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(String(localized: "common.cancel")) { dismiss() }
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
    @FocusState private var focusedField: FocusedDoseField?

    init(vm: TimelineViewModel, medication: MedicationInfo) {
        self.vm = vm
        self.medication = medication

        let existingMapping = vm.medicationMappings.first(where: { $0.id == medication.id })
        let parsedMG = MedicationRecognizer.parseStrengthMG(medication.displayName)

        if let mapping = existingMapping {
            _draft = State(initialValue: DraftDoseEvent.from(mapping))
        } else if let recognized = MedicationRecognizer.recognize(medication.displayName) {
            let route = recognized.ester == .CPA ? .oral : (medication.route ?? .injection)
            var d = DraftDoseEvent(route: route, ester: recognized.ester)
            if let mg = parsedMG {
                if recognized.ester == .CPA {
                    d.rawEsterDoseText = Self.formatMG(mg)
                } else {
                    d.e2EquivalentDoseText = Self.formatMG(mg)
                }
            }
            _draft = State(initialValue: d)
        } else {
            let route = medication.route ?? .injection
            var d = DraftDoseEvent(route: route, ester: route.availableEsters.first ?? .EV)
            if let mg = parsedMG {
                d.e2EquivalentDoseText = Self.formatMG(mg)
            }
            _draft = State(initialValue: d)
        }
    }

    private static func formatMG(_ mg: Double) -> String {
        if mg == mg.rounded() { return "\(Int(mg))" }
        return "\(mg)"
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

            DoseConfigurationFields(draft: $draft, focusedField: $focusedField)
        }
        #if os(iOS)
        .scrollDismissesKeyboard(.interactively)
        #endif
        .navigationTitle(medication.displayName)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            #if os(iOS) || os(watchOS)
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button(String(localized: "common.done")) { focusedField = nil }
            }
            #endif
            ToolbarItem(placement: .confirmationAction) {
                Button(String(localized: "common.save")) {
                    let doseMG: Double
                    if draft.ester == .CPA {
                        doseMG = draft.parsedDouble(draft.rawEsterDoseText) ?? 0
                    } else {
                        doseMG = draft.parsedDouble(draft.e2EquivalentDoseText) ?? 0
                    }
                    let extras = draft.buildExtras()
                    let mapping = MedicationMapping(
                        id: medication.id,
                        displayName: medication.displayName,
                        route: draft.route,
                        ester: draft.ester,
                        doseMG: doseMG,
                        extras: extras
                    )
                    vm.saveMedicationMapping(mapping)
                    dismiss()
                    Task {
                        await vm.importDoseEventsFromHealthKit()
                    }
                }
                .disabled(!draft.isValid)
            }
        }
    }
}
