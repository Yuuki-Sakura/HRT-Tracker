import SwiftUI

struct AboutView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            MarkdownWebView()
                .navigationTitle(String(localized: "settings.model_title"))
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(String(localized: "common.ok")) {
                            dismiss()
                        }
                    }
                }
        }
    }
}

#Preview {
    AboutView()
}
