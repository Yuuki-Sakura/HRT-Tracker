import SwiftUI
import SwiftData
import HRTModels
import HRTServices

@main
struct HRTTrackerWatchApp: App {
    @StateObject private var vm = WatchTimelineViewModel()

    var sharedModelContainer: ModelContainer = {
        do {
            return try HRTModelContainer.create()
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            WatchContentView(vm: vm)
                .onAppear {
                    vm.configure(modelContext: sharedModelContainer.mainContext)
                    WatchConnectivityService.shared.start()
                }
        }
        .modelContainer(sharedModelContainer)
    }
}
