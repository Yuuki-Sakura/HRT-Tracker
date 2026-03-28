import SwiftUI

/// Decimal input field: label on the left, right-aligned number input, optional unit suffix.
struct DecimalField: View {
    let label: String
    @Binding var text: String
    var suffix: String?

    @FocusState private var isFocused: Bool

    var body: some View {
        HStack {
            Text(label)
            Spacer()
            TextField("0", text: $text)
                #if os(iOS) || os(watchOS)
                .keyboardType(.decimalPad)
                #endif
                .multilineTextAlignment(.trailing)
                .fixedSize()
                .focused($isFocused)
                .onChange(of: text) { _, _ in
                    sanitize()
                }
            if let suffix {
                Text(suffix)
                    .foregroundStyle(.secondary)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture { isFocused = true }
    }

    private func sanitize() {
        var s = text.replacingOccurrences(of: ",", with: ".")
        s = s.filter { $0.isNumber || $0 == "." }
        var hasDot = false
        s = String(s.compactMap { c -> Character? in
            if c == "." {
                if hasDot { return nil }
                hasDot = true
            }
            return c
        })
        if s != text { text = s }
    }

    static func parse(_ text: String) -> Double? {
        let s = text.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: ".")
        return Double(s)
    }
}
