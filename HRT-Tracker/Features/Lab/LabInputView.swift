import SwiftUI
import HRTModels

struct LabInputView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var date = Date()
    @State private var valueText = ""
    @State private var unit: ConcentrationUnit = .pgPerML

    var onSave: (LabResult) -> Void

    var body: some View {
        Form {
            DatePicker(String(localized: "lab.date"), selection: $date, displayedComponents: [.date, .hourAndMinute])

            TextField(String(localized: "lab.value"), text: $valueText)
                #if os(iOS) || os(watchOS)
                .keyboardType(.decimalPad)
                #endif

            Picker(String(localized: "lab.unit"), selection: $unit) {
                ForEach(ConcentrationUnit.allCases) { u in
                    Text(u.rawValue).tag(u)
                }
            }
        }
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
