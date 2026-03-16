import SwiftUI

struct GAHTInfoSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    private let sourceURL = URL(string: "https://doi.org/10.1080/26895269.2022.2100644")!

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Label {
                        Text("modal.gaht.title")
                            .font(.title2.bold())
                    } icon: {
                        Image(systemName: "heart.text.clipboard")
                            .foregroundStyle(.purple)
                    }

                    Text("modal.gaht.body")
                        .font(.body)

                    Button {
                        openURL(sourceURL)
                    } label: {
                        HStack {
                            Image(systemName: "link")
                            Text("modal.gaht.source")
                                .multilineTextAlignment(.leading)
                        }
                        .font(.subheadline)
                    }
                }
                .padding()
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "btn.ok")) { dismiss() }
                }
            }
        }
        .presentationDetents([.medium])
    }
}

#Preview {
    GAHTInfoSheet()
}
