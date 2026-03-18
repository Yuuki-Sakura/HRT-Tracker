import SwiftUI
import HRTModels

struct LabInputView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var date: Date
    @State private var valueText: String
    @State private var unit: ConcentrationUnit

    private let editingResult: LabResult?
    var onSave: (LabResult) -> Void

    init(editing result: LabResult? = nil, onSave: @escaping (LabResult) -> Void) {
        self.editingResult = result
        self.onSave = onSave
        _date = State(initialValue: result?.date ?? Date())
        _valueText = State(initialValue: result.map { String(format: "%.1f", $0.concValue) } ?? "")
        _unit = State(initialValue: result?.unit ?? .pgPerML)
    }

    var body: some View {
        Form {
            DatePicker(String(localized: "lab.date"), selection: $date, displayedComponents: [.date, .hourAndMinute])

            DecimalField(label: String(localized: "lab.value"), text: $valueText)

            Picker(String(localized: "lab.unit"), selection: $unit) {
                ForEach(ConcentrationUnit.allCases) { u in
                    Text(u.rawValue).tag(u)
                }
            }
        }
        #if os(iOS)
        .scrollDismissesKeyboard(.interactively)
        #endif
        .navigationTitle("lab.title")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(String(localized: "common.cancel")) { dismiss() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(String(localized: "common.save")) {
                    let sanitized = valueText.replacingOccurrences(of: ",", with: ".")
                    guard let value = Double(sanitized), value > 0 else { return }
                    let result = LabResult(
                        id: editingResult?.id ?? UUID(),
                        timestamp: Int64(date.timeIntervalSince1970),
                        concValue: value,
                        unit: unit
                    )
                    onSave(result)
                    dismiss()
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        LabInputView { result in
            print("Saved: \(result)")
        }
    }
}
