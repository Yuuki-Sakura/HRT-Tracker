import SwiftUI
import HRTModels
import HRTPKEngine

struct InputEventView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var draft: DraftDoseEvent
    @State private var showTemplateName = false
    @State private var templateName = ""
    @FocusState private var focusedField: FocusedDoseField?

    var onSave: (DoseEvent) -> Void
    var onSaveAsTemplate: ((DoseTemplate) -> Void)?
    var existingTemplateNames: [String] = []

    init(eventToEdit: DoseEvent? = nil, onSave: @escaping (DoseEvent) -> Void, onSaveAsTemplate: ((DoseTemplate) -> Void)? = nil) {
        self.onSave = onSave
        self.onSaveAsTemplate = onSaveAsTemplate
        if let event = eventToEdit {
            _draft = State(initialValue: DraftDoseEvent.from(event))
        } else {
            _draft = State(initialValue: DraftDoseEvent())
        }
    }

    init(template: DoseTemplate, onSave: @escaping (DoseEvent) -> Void, onSaveAsTemplate: ((DoseTemplate) -> Void)? = nil) {
        self.onSave = onSave
        self.onSaveAsTemplate = onSaveAsTemplate
        _draft = State(initialValue: DraftDoseEvent.from(template))
    }

    var body: some View {
        Form {
            Section {
                DatePicker(String(localized: "input.time"), selection: $draft.date, displayedComponents: [.date, .hourAndMinute])
                Picker(String(localized: "input.route"), selection: $draft.route) {
                    Text("input.route.injection").tag(Route.injection)
                    Text("input.route.patchApply").tag(Route.patchApply)
                    Text("input.route.gel").tag(Route.gel)
                    Text("input.route.oral").tag(Route.oral)
                    Text("input.route.sublingual").tag(Route.sublingual)
                }
                .onChange(of: draft.route) { _, _ in
                    if let first = draft.availableEsters.first {
                        draft.ester = first
                    }
                    draft.rawEsterDoseText = ""
                    draft.e2EquivalentDoseText = ""
                    draft.patchMode = .totalDose
                    draft.releaseRateText = ""
                    draft.useCustomTheta = false
                    draft.customThetaText = ""
                    draft.applicationSite = nil
                }
            }

            Section(String(localized: "input.drugDetails")) {
                if draft.availableEsters.count > 1 {
                    Picker(String(localized: "input.drugEster"), selection: $draft.ester) {
                        ForEach(draft.availableEsters) { e in
                            Text(e.localizedName).tag(e)
                        }
                    }
                    .onChange(of: draft.ester) { _, _ in
                        syncDoseTextsAfterEsterChange()
                    }
                }

                if draft.ester == .CPA {
                    TextField(
                        String(localized: "input.dose.cpa"),
                        text: $draft.rawEsterDoseText
                    )
                    #if os(iOS) || os(watchOS)
                    .keyboardType(.decimalPad)
                    #endif
                    .focused($focusedField, equals: .raw)
                    .onChange(of: draft.rawEsterDoseText) { _, _ in
                        filterNumericInput(&draft.rawEsterDoseText)
                    }
                } else {
                    if draft.ester != .E2 {
                        TextField(
                            String(localized: "input.dose.raw \(draft.ester.rawValue)"),
                            text: $draft.rawEsterDoseText
                        )
                        #if os(iOS) || os(watchOS)
                        .keyboardType(.decimalPad)
                        #endif
                        .focused($focusedField, equals: .raw)
                        .onChange(of: draft.rawEsterDoseText) { _, _ in
                            filterNumericInput(&draft.rawEsterDoseText)
                            guard focusedField == .raw else { return }
                            convertToE2Equivalent()
                        }
                    }

                    TextField(String(localized: "input.dose.e2"), text: $draft.e2EquivalentDoseText)
                        #if os(iOS) || os(watchOS)
                        .keyboardType(.decimalPad)
                        #endif
                        .focused($focusedField, equals: .e2)
                        .onChange(of: draft.e2EquivalentDoseText) { _, _ in
                            filterNumericInput(&draft.e2EquivalentDoseText)
                            guard focusedField == .e2 else { return }
                            if draft.route == .patchApply && draft.patchMode == .releaseRate {
                                convertE2ToRate()
                            } else {
                                convertToRawEster()
                            }
                        }
                }
            }

            if draft.route == .patchApply {
                PatchFieldsView(draft: $draft, focusedField: $focusedField)
            }

            if draft.route == .gel {
                GelFieldsView(draft: $draft)
            }

            if draft.route == .injection {
                InjectionFieldsView(draft: $draft, focusedField: $focusedField)
            }

            if draft.route == .sublingual {
                SublingualFieldsView(draft: $draft, focusedField: $focusedField)
            }

            // Dose guide
            Section {
                if draft.route == .injection {
                    InjectionGuideView()
                }
                DoseGuideView(route: draft.route, ester: draft.ester, doseText: draft.ester == .CPA ? draft.rawEsterDoseText : draft.e2EquivalentDoseText)
            }
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())
        }
        .formStyle(.grouped)
        .buttonStyle(.borderless)
        .onChange(of: draft.releaseRateText) { _, _ in
            guard draft.route == .patchApply, draft.patchMode == .releaseRate,
                  focusedField == .patchRelease else { return }
            convertRateToE2()
        }
        .onChange(of: draft.patchWearDays) { _, _ in
            guard draft.route == .patchApply, draft.patchMode == .releaseRate else { return }
            convertRateToE2()
        }
        .navigationTitle(draft.id == nil ? String(localized: "input.title.add") : String(localized: "input.title.edit"))
        #if !os(macOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(String(localized: "common.cancel")) { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(String(localized: "common.save")) {
                    onSave(draft.toDoseEvent())
                    dismiss()
                }
                .disabled(!draft.isValid)
                .contextMenu {
                    if onSaveAsTemplate != nil && draft.isValid {
                        Button {
                            showTemplateName = true
                        } label: {
                            Label(String(localized: "input.saveAndCreateTemplate"), systemImage: "square.and.arrow.down")
                        }
                    }
                }
            }
            #if os(iOS) || os(watchOS)
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button(String(localized: "common.done")) { focusedField = nil }
            }
            #endif
        }
        .alert(String(localized: "input.saveAsTemplate"), isPresented: $showTemplateName) {
            TextField(String(localized: "input.templateName"), text: $templateName)
            Button(String(localized: "common.save")) {
                let doseMG = draft.parsedDouble(draft.ester == .CPA ? draft.rawEsterDoseText : draft.e2EquivalentDoseText) ?? 0
                let template = DoseTemplate(
                    name: templateName,
                    route: draft.route,
                    ester: draft.ester,
                    doseMG: doseMG,
                    extras: draft.toDoseEvent().extras
                )
                onSaveAsTemplate?(template)
                onSave(draft.toDoseEvent())
                templateName = ""
                dismiss()
            }
            .disabled(templateName.trimmingCharacters(in: .whitespaces).isEmpty || existingTemplateNames.contains(templateName.trimmingCharacters(in: .whitespaces)))
            Button(String(localized: "common.cancel"), role: .cancel) {
                templateName = ""
            }
        } message: {
            if existingTemplateNames.contains(templateName.trimmingCharacters(in: .whitespaces)) {
                Text("input.templateName.duplicate")
            }
        }
    }

    private func convertToE2Equivalent() {
        guard let rawDose = draft.parsedDouble(draft.rawEsterDoseText) else { return }
        let factor = EsterInfo.by(ester: draft.ester).toE2Factor
        draft.e2EquivalentDoseText = String(format: "%.2f", rawDose * factor)
    }

    private func convertToRawEster() {
        guard draft.ester != .E2, let e2Dose = draft.parsedDouble(draft.e2EquivalentDoseText) else { return }
        let factor = EsterInfo.by(ester: draft.ester).toE2Factor
        draft.rawEsterDoseText = String(format: "%.2f", e2Dose / factor)
    }

    private func convertRateToE2() {
        guard let rate = draft.parsedDouble(draft.releaseRateText) else { return }
        let mg = rate * Double(draft.patchWearDays) / 1000.0
        draft.e2EquivalentDoseText = String(format: "%.2f", mg)
    }

    private func convertE2ToRate() {
        guard let mg = draft.parsedDouble(draft.e2EquivalentDoseText), draft.patchWearDays > 0 else { return }
        let rate = mg * 1000.0 / Double(draft.patchWearDays)
        draft.releaseRateText = String(format: "%.0f", rate)
    }

    private func filterNumericInput(_ text: inout String) {
        let filtered = text.filter { $0.isNumber || $0 == "." || $0 == "," }
        if filtered != text { text = filtered }
        // Keep only the first decimal separator
        var hasDot = false
        text = String(text.compactMap { c -> Character? in
            if c == "." || c == "," {
                if hasDot { return nil }
                hasDot = true
                return c
            }
            return c
        })
    }

    private func syncDoseTextsAfterEsterChange() {
        if draft.ester == .CPA {
            draft.e2EquivalentDoseText = ""
            return
        }
        if draft.ester == .E2 {
            draft.rawEsterDoseText = ""
            return
        }
        if !draft.e2EquivalentDoseText.isEmpty, draft.parsedDouble(draft.e2EquivalentDoseText) != nil {
            convertToRawEster()
        } else if !draft.rawEsterDoseText.isEmpty, draft.parsedDouble(draft.rawEsterDoseText) != nil {
            convertToE2Equivalent()
        }
    }

    func existingTemplateNames(_ names: [String]) -> Self {
        var copy = self
        copy.existingTemplateNames = names
        return copy
    }
}

#Preview {
    NavigationStack {
        InputEventView { event in
            print("Saved: \(event)")
        }
    }
}
