import SwiftUI

/// Unified decimal input field with decimalPad keyboard, input sanitization, optional suffix, and Done button.
struct DecimalField: View {
    let label: String
    @Binding var text: String
    var suffix: String?

    @FocusState private var isFocused: Bool

    var body: some View {
        HStack {
            TextField(label, text: $text)
                #if os(iOS) || os(watchOS)
                .keyboardType(.decimalPad)
                #endif
                .focused($isFocused)
                .onChange(of: text) { _, _ in
                    sanitize()
                }
                #if os(iOS) || os(watchOS)
                .toolbar {
                    ToolbarItemGroup(placement: .keyboard) {
                        Spacer()
                        Button(String(localized: "common.done")) {
                            isFocused = false
                        }
                    }
                }
                #endif
            if let suffix {
                Text(suffix)
                    .foregroundStyle(.secondary)
            }
        }
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
