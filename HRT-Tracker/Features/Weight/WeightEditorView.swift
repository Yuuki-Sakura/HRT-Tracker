import SwiftUI

struct WeightEditorView: View {
    @State private var tempWeight: Double
    @State private var weightText: String
    @FocusState private var fieldFocused: Bool

    private let originalWeight: Double
    let onSave: (Double) -> Void
    let onCancel: () -> Void

    init(initialWeight: Double, onSave: @escaping (Double) -> Void, onCancel: @escaping () -> Void) {
        _tempWeight = State(initialValue: initialWeight)
        _weightText = State(initialValue: String(format: "%.1f", initialWeight))
        self.originalWeight = (initialWeight * 10).rounded() / 10
        self.onSave = onSave
        self.onCancel = onCancel
    }

    private var roundedTemp: Double { (tempWeight * 10).rounded() / 10 }
    private var isDirty: Bool { roundedTemp != originalWeight }

    var body: some View {
        VStack(spacing: 16) {
            Spacer(minLength: 20)

            HStack(alignment: .center, spacing: 20) {
                Button { withAnimation { tempWeight = max(30.0, tempWeight - 0.1) } } label: {
                    Image(systemName: "minus.circle.fill")
                        .resizable().scaledToFit().frame(width: 56, height: 56)
                        .foregroundColor(.pink)
                }

                VStack(spacing: 6) {
                    ZStack {
                        Text(String(format: "%.1f", roundedTemp))
                            .font(.system(size: 56, weight: .bold))
                            .minimumScaleFactor(0.5)
                            .onTapGesture { fieldFocused = true }

                        TextField("", text: $weightText)
                            #if os(iOS) || os(watchOS)
                            .keyboardType(.decimalPad)
                            #endif
                            .focused($fieldFocused)
                            .onChange(of: weightText) { _, newValue in
                                let sanitized = newValue.replacingOccurrences(of: ",", with: ".")
                                if sanitized.isEmpty { tempWeight = 0 } else if let v = Double(sanitized) { tempWeight = v }
                            }
                            .opacity(0.01).frame(width: 140, height: 44)
                            .accessibilityHidden(true)
                    }
                    .frame(height: 56)

                    Text("weight.unit.kg")
                        .font(.title3).foregroundColor(.secondary)
                }
                .frame(minWidth: 120)

                Button { withAnimation { tempWeight = min(200.0, tempWeight + 0.1) } } label: {
                    Image(systemName: "plus.circle.fill")
                        .resizable().scaledToFit().frame(width: 56, height: 56)
                        .foregroundColor(.pink)
                }
            }
            .padding(.horizontal)

            Spacer()
        }
        .padding()
        .navigationTitle("weight.title")
        .toolbar {
            ToolbarItem(placement: .cancellationAction) {
                Button(String(localized: "common.cancel")) { onCancel() }
            }
            ToolbarItem(placement: .confirmationAction) {
                Button(String(localized: "common.save")) {
                    onSave(min(max(roundedTemp, 30.0), 200.0))
                }
                .disabled(!isDirty)
                .buttonStyle(.borderedProminent).tint(.pink)
            }
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button(String(localized: "common.done")) { fieldFocused = false }
            }
        }
        .onChange(of: tempWeight) { _, _ in
            if !fieldFocused { weightText = String(format: "%.1f", roundedTemp) }
        }
        .onChange(of: fieldFocused) { _, focused in
            if !focused {
                let clamped = min(max(tempWeight, 30.0), 200.0)
                tempWeight = clamped
                weightText = String(format: "%.1f", (clamped * 10).rounded() / 10)
            }
        }
    }
}

#Preview {
    NavigationStack {
        WeightEditorView(initialWeight: 65.0, onSave: { _ in }, onCancel: {})
    }
}
