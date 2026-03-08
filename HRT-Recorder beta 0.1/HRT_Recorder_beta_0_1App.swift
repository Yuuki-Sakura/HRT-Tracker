//
//  HRT_Recorder_beta_0_1App.swift
//  HRT-Recorder beta 0.1
//
//  Created by wzzzz Shao on 2025/9/28.
//

import SwiftUI

@main
struct HRTRecorderBetaApp: App {
    @Environment(\.scenePhase) private var phase
    @AppStorage("healthkit.weight.authorization.requested") private var didRequestHealthKitWeightAuthorization = false
    @StateObject private var store: PersistedStore<[DoseEvent]>
    @StateObject private var timelineVM: DoseTimelineVM
    
    init() {
        let persistedStore = PersistedStore<[DoseEvent]>(
            filename: "dose_events.json",
            defaultValue: []
        )
        _store = StateObject(wrappedValue: persistedStore)
        _timelineVM = StateObject(wrappedValue: DoseTimelineVM(initialEvents: persistedStore.value) { updated in
            persistedStore.value = updated
        })
    }
    
    var body: some Scene {
        WindowGroup {
            TimelineScreen(vm: timelineVM)
        }
        .onChange(of: phase) { _, newPhase in
            if newPhase == .active {
                Task {
                    if !didRequestHealthKitWeightAuthorization {
                        try? await timelineVM.requestHealthKitAuthorization()
                        didRequestHealthKitWeightAuthorization = true
                    }
                    await timelineVM.refreshLatestBodyWeightSilently()
                }
            } else if newPhase == .inactive || newPhase == .background {
                store.saveSync()
            }
        }
    }
}
