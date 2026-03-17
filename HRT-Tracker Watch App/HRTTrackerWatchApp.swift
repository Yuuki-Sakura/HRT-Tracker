import SwiftUI
import SwiftData
import HRTModels
import HRTServices

@main
struct HRTTrackerWatchApp: App {
    @StateObject private var vm: WatchTimelineViewModel

    let sharedModelContainer: ModelContainer

    init() {
        let container = try! HRTModelContainer.create()
        self.sharedModelContainer = container
        _vm = StateObject(wrappedValue: WatchTimelineViewModel(modelContext: container.mainContext))
    }

    var body: some Scene {
        WindowGroup {
            WatchContentView(vm: vm)
                .onAppear {
                    WatchConnectivityService.shared.start()
                }
        }
        .modelContainer(sharedModelContainer)
    }
}
