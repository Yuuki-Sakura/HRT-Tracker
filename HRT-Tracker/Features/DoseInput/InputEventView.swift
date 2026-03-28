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
            }

            DoseConfigurationFields(draft: $draft, focusedField: $focusedField)
        }
        .formStyle(.grouped)
        .buttonStyle(.borderless)
        #if os(iOS)
        .scrollDismissesKeyboard(.interactively)
        #endif
        .navigationTitle(draft.id == nil ? String(localized: "input.title.add") : String(localized: "input.title.edit"))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(String(localized: "common.cancel")) { dismiss() }
            }
            #if os(iOS) || os(watchOS)
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button(String(localized: "common.done")) { focusedField = nil }
            }
            #endif
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
