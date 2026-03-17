import SwiftUI
import HRTModels

struct InlineLabInputView: View {
    @State private var date: Date
    @State private var valueText: String
    @State private var unit: ConcentrationUnit
    @FocusState private var isFieldFocused: Bool

    let editingResult: LabResult?
    var onSave: (LabResult) -> Void
    var onDelete: (() -> Void)?
    var onCancel: () -> Void

    init(editing result: LabResult? = nil,
         onSave: @escaping (LabResult) -> Void,
         onDelete: (() -> Void)? = nil,
         onCancel: @escaping () -> Void) {
        self.editingResult = result
        self.onSave = onSave
        self.onDelete = onDelete
        self.onCancel = onCancel
        _date = State(initialValue: result?.date ?? Date())
        _valueText = State(initialValue: result.map { String(format: "%.1f", $0.concValue) } ?? "")
        _unit = State(initialValue: result?.unit ?? .pgPerML)
    }

    var body: some View {
        VStack(spacing: 12) {
            DatePicker(String(localized: "lab.date"), selection: $date, displayedComponents: [.date, .hourAndMinute])
                .datePickerStyle(.compact)

            HStack {
                Text(String(localized: "lab.value"))
                    .foregroundStyle(.secondary)
                Spacer()
                DecimalField(label: String(localized: "lab.value"), text: $valueText)
                    .focused($isFieldFocused)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 120)
            }

            Picker(String(localized: "lab.unit"), selection: $unit) {
                ForEach(ConcentrationUnit.allCases) { u in
                    Text(u.rawValue).tag(u)
                }
            }

            HStack(spacing: 12) {
                if let onDelete {
                    Button(role: .destructive) {
                        onDelete()
                    } label: {
                        Label(String(localized: "common.delete"), systemImage: "trash")
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                }

                Spacer()

                Button {
                    onCancel()
                } label: {
                    Text("common.cancel")
                }
                .buttonStyle(.bordered)

                Button {
                    let sanitized = valueText.replacingOccurrences(of: ",", with: ".")
                    guard let value = Double(sanitized), value > 0 else { return }
                    let result = LabResult(
                        id: editingResult?.id ?? UUID(),
                        timestamp: Int64(date.timeIntervalSince1970),
                        concValue: value,
                        unit: unit
                    )
                    onSave(result)
                } label: {
                    Text("common.save")
                }
                .buttonStyle(.borderedProminent)
                .tint(.teal)
            }
            .padding(.top, 4)
        }
        .padding()
        .contentShape(Rectangle())
        .onTapGesture { isFieldFocused = false }
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(.background)
                .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .strokeBorder(.separator, lineWidth: 0.5)
        )
    }
}
