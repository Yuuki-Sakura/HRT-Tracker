import SwiftUI
import HRTModels

struct DoseTemplatesView: View {
    @Binding var templates: [DoseTemplate]
    let onApply: (DoseTemplate) -> Void

    var body: some View {
        List {
            ForEach(templates) { template in
                Button {
                    onApply(template)
                } label: {
                    HStack {
                        VStack(alignment: .leading) {
                            Text(template.name).font(.headline)
                            Text("\(template.ester.rawValue) - \(template.route.rawValue)")
                                .font(.subheadline).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Text(String(format: "%.2f mg", template.doseMG))
                            .font(.headline).foregroundStyle(.pink)
                    }
                }
                .buttonStyle(.plain)
            }
            .onDelete { indexSet in
                templates.remove(atOffsets: indexSet)
            }
        }
        .navigationTitle("templates.title")
        .overlay {
            if templates.isEmpty {
                ContentUnavailableView(
                    String(localized: "templates.empty"),
                    systemImage: "doc.text",
                    description: Text("templates.empty.description")
                )
            }
        }
    }
}

#Preview {
    @Previewable @State var templates = [
        DoseTemplate(name: "Daily EV", route: .injection, ester: .EV, doseMG: 5.0),
        DoseTemplate(name: "Patch 100", route: .patchApply, ester: .E2, doseMG: 0, extras: [.releaseRateUGPerDay: 100]),
    ]
    NavigationStack {
        DoseTemplatesView(templates: $templates, onApply: { _ in })
    }
}
