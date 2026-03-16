import SwiftUI

struct EstimateInfoSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Label {
                        Text("modal.estimate.title")
                            .font(.title2.bold())
                    } icon: {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                    }

                    Text("modal.estimate.p2")
                        .font(.body)

                    Text("modal.estimate.p3")
                        .font(.body)
                        .fontWeight(.medium)
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
    EstimateInfoSheet()
}
