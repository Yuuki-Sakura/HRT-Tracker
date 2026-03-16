import SwiftUI
import HRTModels

struct ExportImportView: View {
    @State private var exportMessage: String?
    @State private var showingImporter = false

    var body: some View {
        Form {
            Section(String(localized: "export.section")) {
                Button(String(localized: "export.json")) {
                    exportMessage = String(localized: "export.success")
                }
                Button(String(localized: "export.csv")) {
                    exportMessage = String(localized: "export.success")
                }
                Button(String(localized: "export.encrypted")) {
                    exportMessage = String(localized: "export.success")
                }
            }

            Section(String(localized: "import.section")) {
                Button(String(localized: "import.json")) {
                    showingImporter = true
                }
            }
        }
        .navigationTitle("exportImport.title")
        .alert(String(localized: "export.title"), isPresented: Binding(
            get: { exportMessage != nil },
            set: { if !$0 { exportMessage = nil } }
        )) {
            Button(String(localized: "common.ok")) { exportMessage = nil }
        } message: {
            Text(exportMessage ?? "")
        }
    }
}

#Preview {
    NavigationStack {
        ExportImportView()
    }
}
