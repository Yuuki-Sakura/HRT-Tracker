import SwiftUI
import HRTModels
import HRTPKEngine

struct HomeTab: View {
    @ObservedObject var vm: TimelineViewModel

    @State private var activeSheet: HomeSheet?
    @State private var showGAHTInfo = false
    @State private var showDisclaimer = false
    @AppStorage("hasSeenEstimateDisclaimer") private var hasSeenDisclaimer = false

    var body: some View {
        NavigationStack {
            List {
                // MARK: - Dashboard
                Section {
                    VStack(spacing: 16) {
                        concentrationCard
                        chartCard
                    }
                }
                .listRowInsets(EdgeInsets())
                .listRowBackground(Color.clear)
                .listRowSeparator(.hidden)
                .padding(.bottom, 12)

                // MARK: - Event List
                if vm.events.isEmpty && !vm.isSimulating {
                    Section {
                        ContentUnavailableView {
                            Label(String(localized: "timeline.title"), systemImage: "list.clipboard")
                        } description: {
                            Text("timeline.empty")
                        }
                        .frame(maxWidth: .infinity, minHeight: 200)
                    }
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(vm.dayGroups) { group in
                        DayGroupSection(dayGroup: group) { event in
                            activeSheet = .edit(event)
                        } onDelete: { events in
                            for event in events {
                                vm.remove(event)
                            }
                        }
                    }
                }
            }
            .listStyle(.automatic)
            .navigationTitle(String(localized: "tab.home"))
            .toolbarTitleDisplayMode(.inlineLarge)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        activeSheet = .add(UUID())
                    } label: {
                        Image(systemName: "plus")
                    }
                    .contextMenu {
                        if !vm.templates.isEmpty {
                            ForEach(vm.templates) { template in
                                Button {
                                    activeSheet = .addFromTemplate(template)
                                } label: {
                                    Label(template.name, systemImage: "doc.on.clipboard")
                                }
                            }
                        }
                    }
                }
            }
            .sheet(item: $activeSheet) { sheet in
                NavigationStack {
                    switch sheet {
                    case .add:
                        InputEventView { event in
                            vm.save(event)
                        } onSaveAsTemplate: { template in
                            vm.saveTemplate(template)
                        }
                        .existingTemplateNames(vm.templates.map(\.name))
                    case .edit(let event):
                        InputEventView(eventToEdit: event) { event in
                            vm.save(event)
                        } onSaveAsTemplate: { template in
                            vm.saveTemplate(template)
                        }
                        .existingTemplateNames(vm.templates.map(\.name))
                    case .addFromTemplate(let template):
                        InputEventView(template: template) { event in
                            vm.save(event)
                        } onSaveAsTemplate: { template in
                            vm.saveTemplate(template)
                        }
                        .existingTemplateNames(vm.templates.map(\.name))
                    }
                }
            }
            .sheet(isPresented: $showGAHTInfo) {
                GAHTInfoSheet()
            }
            .sheet(isPresented: $showDisclaimer) {
                EstimateInfoSheet()
                    .onDisappear {
                        hasSeenDisclaimer = true
                    }
            }
            .onAppear {
                if !hasSeenDisclaimer {
                    showDisclaimer = true
                }
            }
        }
    }

    // MARK: - Concentration Card

    private var concentrationCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("status.estimate")
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                Spacer()
                if let e2 = vm.currentE2 {
                    Text(Self.e2PhaseLabel(e2))
                        .font(.caption)
                        .foregroundStyle(.blue)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .background(Color.blue.opacity(0.1), in: Capsule())
                    if (100...200).contains(e2) {
                        Button {
                            showGAHTInfo = true
                        } label: {
                            HStack(spacing: 4) {
                                Text("GAHT")
                                Image(systemName: "info.circle")
                            }
                            .font(.caption)
                            .foregroundStyle(.purple)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                            .background(Color.purple.opacity(0.1), in: Capsule())
                        }
                        .buttonStyle(.borderless)
                    }
                }
            }

            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Circle().fill(Color.pink).frame(width: 8, height: 8)
                        Text("label.e2")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if let e2 = vm.currentE2 {
                        HStack(alignment: .firstTextBaseline, spacing: 0) {
                            Text(String(format: "%.0f", e2))
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundStyle(.primary)
                            Text(" pg/mL")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Text("0")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Circle().fill(Color.indigo).frame(width: 8, height: 8)
                        Text("label.cpa")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    if let cpa = vm.currentCPA {
                        HStack(alignment: .firstTextBaseline, spacing: 0) {
                            Text(String(format: "%.1f", cpa))
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundStyle(.primary)
                            Text(" ng/mL")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } else {
                        Text("--")
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding()
        .background(.background, in: RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
    }

    // MARK: - Chart Card

    private static func e2PhaseLabel(_ e2: Double) -> LocalizedStringResource {
        switch e2 {
        case ..<30:    return "phase.low"
        case 30..<160: return "phase.follicular"
        case 160..<350: return "phase.luteal"
        case 350..<500: return "phase.ovulatory"
        default:       return "phase.supra"
        }
    }

    private var chartCard: some View {
        Group {
            if let sim = vm.result {
                ConcentrationChartView(sim: sim, events: vm.events, labResults: vm.labResults)
                    .frame(minHeight: 280)
                    .padding()
                    .background(.background, in: RoundedRectangle(cornerRadius: 16))
                    .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "waveform.path.ecg")
                        .font(.system(size: 40))
                        .foregroundStyle(.secondary.opacity(0.5))
                    Text("timeline.empty")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, minHeight: 200)
                .background(.background, in: RoundedRectangle(cornerRadius: 16))
                .shadow(color: .black.opacity(0.05), radius: 8, y: 2)
            }
        }
    }
}

// MARK: - Sheet Enum

enum HomeSheet: Identifiable {
    case add(UUID)
    case edit(DoseEvent)
    case addFromTemplate(DoseTemplate)

    var id: UUID {
        switch self {
        case .add(let token): return token
        case .edit(let event): return event.id
        case .addFromTemplate(let template): return template.id
        }
    }
}

#Preview {
    HomeTab(vm: .preview)
}
