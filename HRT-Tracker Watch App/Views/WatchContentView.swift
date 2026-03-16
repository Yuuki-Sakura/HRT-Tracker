import SwiftUI
import HRTModels

struct WatchContentView: View {
    @ObservedObject var vm: WatchTimelineViewModel

    @State private var showAddDose = false

    var body: some View {
        TabView {
            // Tab 1: Concentration + Chart
            concentrationTab

            // Tab 2: Recent events
            eventsTab
        }
        .tabViewStyle(.verticalPage)
        .sheet(isPresented: $showAddDose) {
            WatchAddDoseView { event in
                vm.save(event)
            }
        }
    }

    private var concentrationTab: some View {
        VStack(spacing: 4) {
            // 右上角标题
            HStack {
                Spacer()
                Text(String(localized: "watch.title.estimated"))
                    .font(.caption2)
                    .foregroundStyle(.pink)
            }
            .padding(.horizontal)

            // Chart on top
            if let sim = vm.result {
                WatchMiniChartView(
                    sim: sim,
                    currentE2: vm.currentConcentration,
                    currentCPA: vm.currentCPA
                )
                .frame(height: 90)
                .padding(.horizontal, 4)
            }

            Spacer(minLength: 0)

            // Big numbers below — Heart Rate style
            VStack(alignment: .leading, spacing: 2) {
                if let conc = vm.currentConcentration {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(Ester.E2.localizedName)
                            .font(.caption)
                            .foregroundStyle(.pink.opacity(0.7))
                        Text(String(format: "%.0f", conc))
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundStyle(.pink)
                        Text("pg/mL")
                            .font(.caption2)
                            .foregroundStyle(.pink.opacity(0.7))
                    }
                }
                if let cpa = vm.currentCPA {
                    HStack(alignment: .firstTextBaseline, spacing: 4) {
                        Text(Ester.CPA.localizedName)
                            .font(.caption)
                            .foregroundStyle(.indigo.opacity(0.7))
                        Text(String(format: "%.1f", cpa))
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundStyle(.indigo)
                        Text("ng/mL")
                            .font(.caption2)
                            .foregroundStyle(.indigo.opacity(0.7))
                    }
                }
            }
            .padding(.horizontal)
        }
        .padding(.bottom, 8)
    }

    private var eventsTab: some View {
        ScrollView {
            VStack(spacing: 8) {
                Button {
                    showAddDose = true
                } label: {
                    Label(String(localized: "input.title.add"), systemImage: "plus")
                }
                .padding(.horizontal)

                ForEach(vm.events.suffix(10).reversed()) { event in
                    HStack {
                        VStack(alignment: .leading) {
                            Text(event.ester.localizedName)
                                .font(.caption.bold())
                            Text(event.date, style: .date)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing) {
                            if event.doseMG > 0 {
                                Text(String(format: "%.1f mg", event.doseMG))
                                    .font(.caption)
                            }
                            Text(event.date, style: .time)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .padding(.top, 8)
        }
    }
}

#Preview {
    WatchContentView(vm: WatchTimelineViewModel.preview)
}
