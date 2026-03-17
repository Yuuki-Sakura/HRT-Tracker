import SwiftUI
import SwiftData
import HRTModels
import HRTPKEngine
import HRTServices

@main
struct HRT_TrackerApp: App {
    @StateObject private var vm: TimelineViewModel
    @Environment(\.scenePhase) private var scenePhase

    let sharedModelContainer: ModelContainer

    init() {
        let container: ModelContainer
        do {
            container = try HRTModelContainer.create(deleteStoreOnFailure: true)
        } catch {
            print("CRITICAL: ModelContainer creation failed: \(error)")
            container = try! HRTModelContainer.create(inMemory: true) // swiftlint:disable:this force_try
        }
        self.sharedModelContainer = container
        _vm = StateObject(wrappedValue: TimelineViewModel(modelContext: container.mainContext))
    }

    var body: some Scene {
        WindowGroup {
            MainTabView(vm: vm)
                .onAppear {
                    MigrationService.migrateLegacyDataIfNeeded(context: sharedModelContainer.mainContext)
                    #if canImport(WatchConnectivity)
                    WatchConnectivityService.shared.start()
                    #endif

                    #if !OPENSOURCE && !os(macOS)
                    // Auto-sync HealthKit weight + medications
                    if vm.isHealthKitAuthorized {
                        Task { await vm.refreshWeightSilently() }
                        vm.startObservingHealthKit()
                        Task {
                            await vm.fetchMedicationsFromHealthKit()
                            await vm.importDoseEventsFromHealthKit()
                        }
                    }
                    #endif
                }
                .onChange(of: scenePhase) { _, newPhase in
                    #if !OPENSOURCE && !os(macOS)
                    if newPhase == .active && vm.isHealthKitAuthorized {
                        Task {
                            await vm.refreshWeightSilently()
                            await vm.fetchMedicationsFromHealthKit()
                            await vm.importDoseEventsFromHealthKit()
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
