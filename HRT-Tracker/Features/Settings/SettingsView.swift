import SwiftUI
import UniformTypeIdentifiers
import HRTModels
import HRTServices

struct SettingsView: View {
    @ObservedObject var vm: TimelineViewModel

    @State private var showClearConfirm = false
    @State private var showExportOptions = false
    @State private var showingImporter = false
    @State private var exportMessage: String?
    @State private var exportDocument: ExportDocument?
    @State private var showFileExporter = false
    @State private var exportFilename = ""
    @State private var exportContentType: UTType = .json
    @State private var showPasswordPrompt = false
    @State private var encryptionPassword = ""
    @State private var showAbout = false
    #if !OPENSOURCE && !os(macOS)
    @State private var showHealthKitError = false
    @State private var showMedicationMapping = false
    @State private var medicationToConfig: MedicationInfo?
    #endif
    @State private var showWeightEditor = false

    var body: some View {
        Form {
            // MARK: - Body Weight
            Section(String(localized: "settings.group.weight")) {
                Button {
                    showWeightEditor = true
                } label: {
                    HStack {
                        Label(String(localized: "settings.weight.current"), systemImage: "scalemass")
                        Spacer()
                        Text(String(format: "%.1f kg", vm.bodyWeightKG))
                            .foregroundStyle(.secondary)
                    }
                }
                .tint(.primary)
            }

            #if !OPENSOURCE && !os(macOS)
            // MARK: - HealthKit
            Section(String(localized: "settings.group.healthkit")) {
                Toggle(isOn: Binding(
                    get: { vm.isHealthKitAuthorized },
                    set: { newValue in
                        if newValue {
                            Task {
                                await vm.requestHealthKitAuthorization()
                                if vm.isHealthKitAuthorized {
                                    await vm.requestMedicationAuthorization()
                                    await vm.fetchMedicationsFromHealthKit()
                                    await vm.importDoseEventsFromHealthKit()
                                    vm.startObservingHealthKit()
                                    if let first = vm.unmappedMedications.first {
                                        medicationToConfig = first
                                    }
                                }
                            }
                        } else {
                            vm.isHealthKitAuthorized = false
                        }
                    }
                )) {
                    Label(String(localized: "settings.healthkit.enable"), systemImage: "heart.fill")
                }

                if vm.isHealthKitAuthorized {
                    if let lastSync = vm.lastHealthKitSync {
                        Text(String(localized: "settings.healthkit.last_sync") + " " + lastSync.formatted(date: .abbreviated, time: .shortened))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Button {
                        showMedicationMapping = true
                    } label: {
                        HStack {
                            Label(String(localized: "settings.healthkit.mapping.title"), systemImage: "pills")
                            Spacer()
                            if !vm.unmappedMedications.isEmpty {
                                Text("\(vm.unmappedMedications.count)")
                                    .font(.caption2).bold()
                                    .padding(.horizontal, 6).padding(.vertical, 2)
                                    .background(.orange).clipShape(Capsule())
                                    .foregroundStyle(.white)
                            }
                            Image(systemName: "chevron.right")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .tint(.primary)
                }
            }
            #endif

            // MARK: - Dose Templates
            Section(String(localized: "settings.group.template")) {
                if vm.templates.isEmpty {
                    Text(String(localized: "settings.template.empty"))
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(vm.templates) { template in
                        Label(template.name, systemImage: "syringe")
                    }
                    .onDelete { offsets in
                        for index in offsets {
                            vm.removeTemplate(vm.templates[index])
                        }
                    }
                }
            }

            // MARK: - Data
            Section(String(localized: "settings.group.data")) {
                Button {
                    showExportOptions = true
                } label: {
                    Label(String(localized: "export.title"), systemImage: "square.and.arrow.up")
                }
                .tint(.primary)

                Button {
                    showingImporter = true
                } label: {
                    Label(String(localized: "import.title"), systemImage: "square.and.arrow.down")
                }
                .tint(.primary)

                Button(role: .destructive) {
                    showClearConfirm = true
                } label: {
                    Label(String(localized: "settings.clear_all"), systemImage: "trash")
                }
            }

            // MARK: - About
            Section {
                Button {
                    showAbout = true
                } label: {
                    Label(String(localized: "about.model"), systemImage: "info.circle")
                }
                .tint(.primary)
            } header: {
                Text(String(localized: "settings.group.about"))
            } footer: {
                VStack(spacing: 16) {
                    disclaimerBanner
                    VStack(spacing: 6) {
                        Text(appVersion)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Link(destination: URL(string: "https://github.com/Yuuki-Sakura/HRT-Tracker")!) {
                            HStack(spacing: 6) {
                                GitHubIcon()
                                    .frame(width: 14, height: 14)
                                Text("Yuuki-Sakura/HRT-Tracker")
                                    .font(.caption)
                            }
                            .foregroundStyle(.secondary)
                        }
                    }
                }
                .padding(.horizontal, -10)
                .padding(.top, 16)
            }
        }
        .formStyle(.grouped)
        .buttonStyle(.borderless)
        .navigationTitle("settings.title")
        .toolbarTitleDisplayMode(.inlineLarge)
        .sheet(isPresented: $showAbout) {
            AboutView()
        }
        .sheet(isPresented: $showWeightEditor) {
            NavigationStack {
                WeightEditorView(initialWeight: vm.bodyWeightKG) { newWeight in
                    vm.bodyWeightKG = newWeight
                    showWeightEditor = false
                } onCancel: {
                    showWeightEditor = false
                }
            }
        }
        .alert(String(localized: "settings.clear_confirm"), isPresented: $showClearConfirm) {
            Button(String(localized: "btn.cancel"), role: .cancel) {}
            Button(String(localized: "settings.clear_all"), role: .destructive) {
                vm.clearAllEvents()
            }
        }
        .confirmationDialog(String(localized: "export.title"), isPresented: $showExportOptions) {
            Button(String(localized: "export.json")) {
                do {
                    let data = try ExportService().exportJSON(events: vm.events, labResults: vm.labResults)
                    let dateStr = ISO8601DateFormatter().string(from: Date()).prefix(10)
                    exportFilename = "HRT-Export-\(dateStr).json"
                    exportContentType = .json
                    exportDocument = ExportDocument(data: data)
                    showFileExporter = true
                } catch {
                    exportMessage = String(localized: "export.error")
                }
            }
            Button(String(localized: "export.csv")) {
                let csv = ExportService().exportCSV(events: vm.events)
                let data = Data(csv.utf8)
                let dateStr = ISO8601DateFormatter().string(from: Date()).prefix(10)
                exportFilename = "HRT-Export-\(dateStr).csv"
                exportContentType = .commaSeparatedText
                exportDocument = ExportDocument(data: data)
                showFileExporter = true
            }
            Button(String(localized: "export.encrypted")) {
                encryptionPassword = ""
                showPasswordPrompt = true
            }
            Button(String(localized: "btn.cancel"), role: .cancel) {}
        }
        .alert(String(localized: "export.title"), isPresented: Binding(
            get: { exportMessage != nil },
            set: { if !$0 { exportMessage = nil } }
        )) {
            Button(String(localized: "common.ok")) { exportMessage = nil }
        } message: {
            Text(exportMessage ?? "")
        }
        #if !OPENSOURCE && !os(macOS)
        .alert("HealthKit", isPresented: Binding(
            get: { vm.healthKitError != nil },
            set: { if !$0 { vm.healthKitError = nil } }
        )) {
            Button(String(localized: "common.ok")) { vm.healthKitError = nil }
        } message: {
            Text(vm.healthKitError ?? "")
        }
        .sheet(isPresented: $showMedicationMapping) {
            NavigationStack {
                MedicationMappingListView(vm: vm)
            }
        }
        .sheet(item: $medicationToConfig) { med in
            NavigationStack {
                MedicationMappingDetailView(vm: vm, medication: med)
                    .id(med.id)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button(String(localized: "btn.cancel")) {
                            medicationToConfig = nil
                        }
                    }
                }
            }
        }
        .onChange(of: medicationToConfig) { oldValue, newValue in
            // After a sheet dismisses (newValue == nil) and there was a previous item,
            // check if there are more unmapped medications to configure
            if newValue == nil, oldValue != nil {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    medicationToConfig = vm.unmappedMedications.first
                }
            }
        }
        #endif
        .fileImporter(isPresented: $showingImporter, allowedContentTypes: [.json]) { result in
            switch result {
            case .success(let url):
                print("Selected file: \(url)")
            case .failure(let error):
                print("Import error: \(error)")
            }
        }
        .fileExporter(
            isPresented: $showFileExporter,
            document: exportDocument,
            contentType: exportContentType,
            defaultFilename: exportFilename
        ) { result in
            switch result {
            case .success:
                exportMessage = String(localized: "export.success")
            case .failure:
                exportMessage = String(localized: "export.error")
            }
            exportDocument = nil
        }
        .alert(String(localized: "export.encrypted"), isPresented: $showPasswordPrompt) {
            SecureField(String(localized: "export.password.placeholder"), text: $encryptionPassword)
            Button(String(localized: "btn.cancel"), role: .cancel) {
                encryptionPassword = ""
            }
            Button(String(localized: "export.title")) {
                let password = encryptionPassword
                encryptionPassword = ""
                guard !password.isEmpty else { return }
                do {
                    let data = try ExportService().exportEncryptedJSON(
                        events: vm.events, labResults: vm.labResults, password: password
                    )
                    let dateStr = ISO8601DateFormatter().string(from: Date()).prefix(10)
                    exportFilename = "HRT-Export-\(dateStr)-encrypted.json"
                    exportContentType = .json
                    exportDocument = ExportDocument(data: data)
                    showFileExporter = true
                } catch {
                    exportMessage = String(localized: "export.error")
                }
            }
        } message: {
            Text(String(localized: "export.password.message"))
        }
    }

    // MARK: - App Version

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "v\(version)+\(build)"
    }

    // MARK: - Disclaimer Banner

    private var disclaimerBanner: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label {
                Text("disclaimer.header")
                    .font(.headline.bold())
            } icon: {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
            }

            Text("disclaimer.body.1")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.primary)

            Text("disclaimer.body.2")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.primary)

            Text("disclaimer.body.3")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.orange)
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(Color.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
    }
}

#Preview {
    NavigationStack {
        SettingsView(vm: .preview)
    }
}
