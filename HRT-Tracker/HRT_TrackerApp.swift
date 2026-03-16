import SwiftUI
import SwiftData
import HRTModels
import HRTPKEngine
import HRTServices

@main
struct HRT_TrackerApp: App {
    @StateObject private var vm = TimelineViewModel()
    @Environment(\.scenePhase) private var scenePhase

    var sharedModelContainer: ModelContainer = {
        do {
            return try HRTModelContainer.create(deleteStoreOnFailure: true)
        } catch {
            // Last resort: in-memory only so the app doesn't crash
            print("CRITICAL: ModelContainer creation failed: \(error)")
            return try! HRTModelContainer.create(inMemory: true) // swiftlint:disable:this force_try
        }
    }()

    var body: some Scene {
        WindowGroup {
            MainTabView(vm: vm)
                .onAppear {
                    let context = sharedModelContainer.mainContext
                    MigrationService.migrateLegacyDataIfNeeded(context: context)
                    vm.configure(modelContext: context)
                    #if canImport(WatchConnectivity)
                    WatchConnectivityService.shared.start()
                    #endif

                    #if !OPENSOURCE && !os(macOS)
                    // Auto-sync HealthKit weight
                    if vm.isHealthKitAuthorized {
                        Task { await vm.refreshWeightSilently() }
                        vm.startObservingHealthKit()
                    }
                    // Auto-sync medication dose events
                    if vm.isMedicationSyncEnabled {
                        Task {
                            await vm.fetchMedicationsFromHealthKit()
                            await vm.importDoseEventsFromHealthKit()
                        }
                    }
                    #endif
                    // Schedule dose reminders for all templates
                    vm.scheduleAllReminders()

                    // Wire up notification tap handler
                    NotificationService.shared.onDoseReminderTapped = { [weak vm] templateID in
                        guard let vm = vm else { return }
                        if let template = vm.templates.first(where: { $0.id == templateID }) {
                            vm.pendingTemplateFromNotification = template
                        }
                    }
                }
                .onChange(of: scenePhase) { _, newPhase in
                    #if !OPENSOURCE && !os(macOS)
                    if newPhase == .active && vm.isHealthKitAuthorized {
                        Task {
                            await vm.refreshWeightSilently()
                            if vm.isMedicationSyncEnabled {
                                await vm.importDoseEventsFromHealthKit()
                            }
                        }
                    }
                    #endif
                }
        }
        .modelContainer(sharedModelContainer)
        #if os(macOS)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button(String(localized: "menu.newEvent")) {
                    // Keyboard shortcut handled
                }
                .keyboardShortcut("n")
            }
        }
        #endif
    }
}
