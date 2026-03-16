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
    @State private var notificationPermissionDenied = false
    #if !OPENSOURCE && !os(macOS)
    @State private var showHealthKitError = false
    #endif
    @State private var showWeightEditor = false

    // Reminder interval options in hours
    private let intervalOptions: [(String, Double)] = [
        (String(localized: "settings.reminder.interval.daily"), 24),
        (String(localized: "settings.reminder.interval.2d"), 48),
        (String(localized: "settings.reminder.interval.3d"), 72),
        (String(localized: "settings.reminder.interval.5d"), 120),
        (String(localized: "settings.reminder.interval.7d"), 168),
        (String(localized: "settings.reminder.interval.14d"), 336),
    ]

    /// Default 9:00 AM date for new reminder time-of-day.
    private var defaultReminderTime: Date {
        var c = Calendar.current.dateComponents([.year, .month, .day], from: Date())
        c.hour = 9; c.minute = 0
        return Calendar.current.date(from: c) ?? Date()
    }

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
                // Authorization / Import weight
                if vm.isHealthKitAuthorized {
                    Button {
                        Task { await vm.importWeightFromHealthKit() }
                    } label: {
                        Label(String(localized: "settings.healthkit.import_weight"), systemImage: "arrow.down.heart")
                    }
                } else {
                    Button {
                        Task { await vm.requestHealthKitAuthorization() }
                    } label: {
                        Label(String(localized: "settings.healthkit.enable"), systemImage: "heart.fill")
                    }
                }

                // Sync status
                if let lastSync = vm.lastHealthKitSync {
                    Text(String(localized: "settings.healthkit.last_sync") + " " + lastSync.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                // Medication sync toggle
                Toggle(isOn: Binding(
                    get: { vm.isMedicationSyncEnabled },
                    set: { newValue in
                        vm.isMedicationSyncEnabled = newValue
                        if newValue {
                            Task {
                                await vm.requestMedicationAuthorization()
                                await vm.fetchMedicationsFromHealthKit()
                            }
                        }
                    }
                )) {
                    Label(String(localized: "settings.healthkit.medication_sync"), systemImage: "pills")
                }

                // Medication list
                if vm.isMedicationSyncEnabled && !vm.medications.isEmpty {
                    ForEach(vm.medications) { med in
                        HStack {
                            Image(systemName: "pill")
                                .foregroundStyle(.secondary)
                            Text(med.displayName)
                        }
                    }
                }
            }
            #endif

            // MARK: - Dose Reminder
            Section(String(localized: "settings.group.reminder")) {
                if vm.templates.isEmpty {
                    Text(String(localized: "settings.reminder.empty"))
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(vm.templates) { template in
                        templateReminderRow(template)
                    }
                    .onDelete { offsets in
                        for index in offsets {
                            vm.removeTemplate(vm.templates[index])
                        }
                    }
                }

                if notificationPermissionDenied {
                    Text(String(localized: "settings.reminder.notification_hint"))
                        .font(.caption)
                        .foregroundStyle(.orange)
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

    // MARK: - Template Reminder Row

    @ViewBuilder
    private func templateReminderRow(_ template: DoseTemplate) -> some View {
        let isEnabled = template.reminderIntervalHours != nil
        Toggle(isOn: Binding(
            get: { isEnabled },
            set: { newValue in
                var updated = template
                if newValue {
                    updated.reminderIntervalHours = 24.0
                    updated.reminderTimeOfDay = defaultReminderTime
                    vm.saveTemplate(updated)
                    vm.scheduleAllReminders()
                    Task {
                        let granted = await NotificationService.shared.requestPermission()
                        if !granted {
                            notificationPermissionDenied = true
                        } else {
                            notificationPermissionDenied = false
                        }
                    }
                } else {
                    updated.reminderIntervalHours = nil
                    updated.reminderTimeOfDay = nil
                    vm.saveTemplate(updated)
                }
            }
        )) {
            Label(template.name, systemImage: isEnabled ? "bell.fill" : "bell.slash")
        }
        .deleteDisabled(isEnabled)

        if isEnabled {
            // Interval picker
            Picker(String(localized: "settings.reminder.interval"), selection: Binding(
                get: { template.reminderIntervalHours ?? 24.0 },
                set: { newValue in
                    var updated = template
                    updated.reminderIntervalHours = newValue
                    vm.saveTemplate(updated)
                }
            )) {
                ForEach(intervalOptions, id: \.1) { option in
                    Text(option.0).tag(option.1)
                }
            }
            .deleteDisabled(true)

            // Time of day picker
            DatePicker(
                String(localized: "settings.reminder.time"),
                selection: Binding(
                    get: { template.reminderTimeOfDay ?? defaultReminderTime },
                    set: { newValue in
                        var updated = template
                        updated.reminderTimeOfDay = newValue
                        vm.saveTemplate(updated)
                    }
                ),
                displayedComponents: .hourAndMinute
            )
            .deleteDisabled(true)

            // Next reminder display
            if let nextDate = vm.nextReminderDate(for: template) {
                HStack {
                    Text(String(localized: "settings.reminder.next"))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(nextDate.formatted(date: .abbreviated, time: .shortened))
                        .foregroundStyle(.secondary)
                }
                .deleteDisabled(true)
            }
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
