import Foundation
import Combine
import SwiftUI
import SwiftData
import HRTModels
import HRTPKEngine
import HRTServices

@MainActor
final class WatchTimelineViewModel: ObservableObject {
    @Published var events: [DoseEvent] = []
    @Published var result: SimulationResult?
    @Published var bodyWeightKG: Double = 70.0

    private let modelContext: ModelContext
    private var simulationTask: Task<Void, Never>?

    var currentConcentration: Double? {
        let ts = Int64(Date().timeIntervalSince1970)
        return result?.concentration(at: ts)
    }

    var currentCPA: Double? {
        let ts = Int64(Date().timeIntervalSince1970)
        guard let conc = result?.concentrationCPA(at: ts), conc > 0 else { return nil }
        return conc
    }

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
        loadFromStore()
        runSimulation()
    }

    static var preview: WatchTimelineViewModel {
        let container = try! HRTModelContainer.create()
        let vm = WatchTimelineViewModel(modelContext: container.mainContext)
        let now = Int64(Date().timeIntervalSince1970)
        let start = now - 14 * 24 * 3600
        var events = [DoseEvent]()
        for day in 0..<14 {
            events.append(DoseEvent(route: .gel, timestamp: start + Int64(day) * 24 * 3600, doseMG: 2.0, ester: .E2))
        }
        for i in stride(from: 0, to: 14, by: 3) {
            events.append(DoseEvent(route: .oral, timestamp: start + Int64(i) * 24 * 3600, doseMG: 12.5, ester: .CPA))
        }
        vm.events = events
        vm.runSimulation()
        return vm
    }

    func save(_ event: DoseEvent) {
        if let index = events.firstIndex(where: { $0.id == event.id }) {
            events[index] = event
        } else {
            events.append(event)
            events.sort { $0.timestamp < $1.timestamp }
        }
        saveToStore(event)
        WatchConnectivityService.shared.sendEventToPhone(event)
        runSimulation()
    }

    func runSimulation() {
        simulationTask?.cancel()
        guard !events.isEmpty else {
            result = nil
            return
        }

        let sortedEvents = events
        let weight = bodyWeightKG

        simulationTask = Task {
            let startTime = (sortedEvents.first?.timestamp ?? 0) - 24 * 3600
            let endTime = (sortedEvents.last?.timestamp ?? startTime) + 24 * 7 * 3600
            let engine = SimulationEngine(
                events: sortedEvents,
                bodyWeightKG: weight,
                startTimestamp: startTime,
                endTimestamp: endTime,
                numberOfSteps: 500
            )
            let simResult = engine.run()
            if !Task.isCancelled {
                self.result = simResult
            }
        }
    }

    private func loadFromStore() {
        do {
            let records = try modelContext.fetch(FetchDescriptor<DoseEventRecord>())
            events = records.compactMap { $0.toDoseEvent() }.sorted { $0.timestamp < $1.timestamp }
        } catch {
            print("Watch: Failed to load events: \(error)")
        }
    }

    private func saveToStore(_ event: DoseEvent) {
        modelContext.insert(DoseEventRecord.from(event))
        try? modelContext.save()
    }
}
