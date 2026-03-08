import SwiftUI
import Charts
import Combine

struct ContentView: View {
    @StateObject private var store: WatchDoseStore
    @StateObject private var syncService: WatchDoseSyncService
    @StateObject private var timelineVM: WatchDoseTimelineVM
    @State private var showAddSheet = false
    private let timer = Timer.publish(every: 60, on: .main, in: .common).autoconnect()

    init() {
        let store = WatchDoseStore()
        let syncService = WatchDoseSyncService()
        _store = StateObject(wrappedValue: store)
        _syncService = StateObject(wrappedValue: syncService)
        _timelineVM = StateObject(wrappedValue: WatchDoseTimelineVM(store: store))
    }

    var body: some View {
        NavigationStack {
            List {
                concentrationSection
                eventSection
            }
            .navigationTitle("HRT 记录")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAddSheet = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showAddSheet) {
                WatchAddDoseView { event in
                    store.add(event)
                    syncService.send(event: event)
                }
            }
            .task {
                syncService.attach(store: store) { syncedWeight in
                    timelineVM.bodyWeightKG = syncedWeight
                }
            }
            .onReceive(timer) { _ in
                timelineVM.runSimulation()
            }
        }
    }

    private var chartPointsForDisplay: [WatchChartPoint] {
        let sourcePoints = syncService.chartPoints.isEmpty ? timelineVM.localChartPoints : syncService.chartPoints
        return sourcePoints.sorted { $0.timeH < $1.timeH }
    }

    private var chartDomain: ClosedRange<Date> {
        guard let firstDate = chartPointsForDisplay.first?.date,
              let lastDate = chartPointsForDisplay.last?.date else {
            let now = Date()
            return now...now
        }
        return firstDate...lastDate
    }

    private var concentrationForDisplay: Double? {
        syncService.currentConcentration ?? timelineVM.currentConcentration
    }

    private var concentrationSection: some View {
        Section("当前浓度") {
            TimelineView(.periodic(from: .now, by: 60)) { _ in
                if let value = concentrationForDisplay {
                    Text(String(format: "%.1f pg/mL", value))
                        .font(.headline)
                } else {
                    Text("暂无数据")
                        .foregroundStyle(.secondary)
                }
            }

            if !chartPointsForDisplay.isEmpty {
                Chart(chartPointsForDisplay) { point in
                    LineMark(
                        x: .value("时间", point.date),
                        y: .value("浓度", point.concentration)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(.pink)
                }
                .chartXScale(domain: chartDomain)
                .frame(height: 90)
            }
        }
    }

    private var eventSection: some View {
        Section("用药记录") {
            if store.events.isEmpty {
                Text("还没有记录")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(store.events) { event in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(event.route.displayName)
                            .font(.headline)
                        Text(eventDoseLabel(for: event))
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        Text(event.date, style: .time)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .onDelete { offsets in
                    store.delete(at: offsets)
                    syncService.replaceAll(events: store.events)
                }
            }
        }
    }

    private func eventDoseLabel(for event: WatchDoseEvent) -> String {
        if let rate = event.extras[.releaseRateUGPerDay] {
            return String(format: "%@ · %.0f μg/day", event.ester.rawValue, rate)
        }
        if let tier = event.extras[.sublingualTier] {
            return String(format: "%@ · %.2f mg · tier %d", event.ester.rawValue, event.doseMG, Int(tier))
        }
        if let theta = event.extras[.sublingualTheta] {
            return String(format: "%@ · %.2f mg · θ %.2f", event.ester.rawValue, event.doseMG, theta)
        }
        return String(format: "%@ · %.2f mg", event.ester.rawValue, event.doseMG)
    }
}

#Preview {
    ContentView()
}
