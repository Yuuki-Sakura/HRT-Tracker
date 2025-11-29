//
//  TimelineScreen.swift
//  HRTRecorder
//
//  Created by mihari-zhong on 2025/8/1.
//

import Foundation
import SwiftUI

extension DoseEvent {
    var date: Date { Date(timeIntervalSince1970: timeH * 3600.0) }
}

private enum TimelineSheet: Identifiable {
    case add(UUID)
    case edit(DoseEvent)
    case weight

    var id: UUID {
        switch self {
        case .add(let token): return token
        case .edit(let event): return event.id
        case .weight: return UUID(uuidString: "00000000-0000-0000-0000-000000000001")!
        }
    }
}

struct TimelineScreen: View {
    @StateObject var vm: DoseTimelineVM

    init(vm: DoseTimelineVM) {
        _vm = StateObject(wrappedValue: vm)
    }

    // **NEW**: State to manage which event is being edited.
    @State private var activeSheet: TimelineSheet?
    @FocusState private var weightFieldFocused: Bool

    var body: some View {
        NavigationStack {
            VStack {
                // ... (ProgressView remains the same)
                
                List {
                    ForEach(groupEventsByDay(vm.events), id: \.day) { dayGroup in
                        Section(header: Text(dayGroup.day)) {
                            ForEach(dayGroup.events) { event in
                                // **NEW**: Each row is now a button that triggers the edit sheet.
                                Button(action: {
                                    activeSheet = .edit(event)
                                }) {
                                    TimelineRowView(event: event)
                                }
                                .buttonStyle(PlainButtonStyle()) // Use plain style to avoid default button appearance
                            }
                            .onDelete { indexSet in
                                let originalIndices = findOriginalIndices(for: indexSet, in: dayGroup, from: vm.events)
                                vm.remove(at: originalIndices)
                            }
                        }
                    }
                }
                .listStyle(InsetGroupedListStyle())

                // ... (ResultChartView and placeholder text remain the same)
                if let sim = vm.result, !sim.timeH.isEmpty {
                    ResultChartView(sim: sim)
                        .frame(height: 280)
                        .padding([.horizontal, .bottom])
                } else if !vm.isSimulating {
                    Spacer()
                    Text("timeline.empty")
                        .font(.headline).foregroundColor(.secondary)
                        .multilineTextAlignment(.center).padding()
                    Spacer()
                }
            }
            .navigationTitle("timeline.title")
            .toolbar {
                // Left: explicit leading item for weight editor
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        activeSheet = .weight
                    } label: {
                        Image(systemName: "ellipsis.circle.fill")
                            .font(.title2)
                            .accessibilityLabel(Text("timeline.toolbar.weightEdit"))
                    }
                }

                // Right: explicit trailing item for adding events
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        activeSheet = .add(UUID())
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            .accessibilityLabel(Text("timeline.toolbar.add"))
                    }
                }
            }
            .sheet(item: $activeSheet) { mode in
                switch mode {
                case .add(_):
                    // Dosing info sheet: only the event input view
                    NavigationStack {
                        InputEventView(eventToEdit: nil) { event in
                            vm.save(event)
                        }
                        .padding()
                        .navigationTitle("timeline.add.title")
                    }

                case .weight:
                    // Present a dedicated WeightEditorView which keeps a temporary value until saved.
                    NavigationStack {
                        WeightEditorView(initialWeight: vm.bodyWeightKG) { newWeight in
                            vm.bodyWeightKG = newWeight
                            activeSheet = nil
                        } onCancel: {
                            activeSheet = nil
                        }
                    }

                case .edit(let event):
                    // Edit event sheet: same as before
                    NavigationStack {
                        InputEventView(eventToEdit: event) { updated in
                            vm.save(updated)
                        }
                        .padding()
                    }
                }
            }
        }
    }

    // ... (findOriginalIndices helper remains the same)
    private func findOriginalIndices(for localIndexSet: IndexSet, in dayGroup: DayGroup, from allEvents: [DoseEvent]) -> IndexSet {
        let idsToDelete = localIndexSet.map { dayGroup.events[$0].id }
        let originalIndices = allEvents.enumerated()
            .filter { idsToDelete.contains($0.element.id) }
            .map { $0.offset }
        return IndexSet(originalIndices)
    }

}

// MARK: - Timeline Row View
struct TimelineRowView: View {
    let event: DoseEvent
    
    // ... (icon, title, doseText computed properties remain the same)
    private var icon: (name: String, color: Color) {
        switch event.route {
        case .injection: return ("syringe.fill", .red)
        case .patchApply: return ("app.badge.fill", .orange)
        case .patchRemove: return ("app.badge", .gray)
        case .gel: return ("drop.fill", .cyan)
        case .oral: return ("pills.fill", .purple)
        case .sublingual: return ("pills.fill", .teal)
        }
    }
    
    private var title: String {
        switch event.route {
        case .injection:
            return String(format: NSLocalizedString("timeline.row.injection", comment: "Timeline row title for injection"), locale: Locale.current, event.ester.abbreviation)
        case .patchApply:
            return NSLocalizedString("timeline.row.patchApply", comment: "Timeline row title for patch apply")
        case .patchRemove:
            return NSLocalizedString("timeline.row.patchRemove", comment: "Timeline row title for patch removal")
        case .gel:
            return NSLocalizedString("timeline.row.gel", comment: "Timeline row title for gel dosing")
        case .oral:
            return String(format: NSLocalizedString("timeline.row.oral", comment: "Timeline row title for oral"), locale: Locale.current, event.ester.abbreviation)
        case .sublingual:
            return String(format: NSLocalizedString("timeline.row.sublingual", comment: "Timeline row title for sublingual"), locale: Locale.current, event.ester.abbreviation)
        }
    }
    
    /// Returns dose string:
    /// • if patch apply with zero‑order extras → “XX µg/d”
    /// • otherwise for non‑zero doseMG → “YY mg”
    private var doseText: String? {
        // hide for patch removal or zero dose injection
        if event.route == .patchRemove { return nil }
        
        // zero‑order patch: show release rate
        if let rateUG = event.extras[.releaseRateUGPerDay] {
            let rounded = String(format: "%.0f", locale: Locale.current, rateUG)
            return String(format: NSLocalizedString("timeline.row.dose.releaseRate", comment: "Release rate label"), locale: Locale.current, rounded)
        }

        // other routes: show mg
        guard event.doseMG > 0 else { return nil }
        return String(format: NSLocalizedString("timeline.row.dose.mg", comment: "Dose label in mg"), locale: Locale.current, String(format: "%.2f", locale: Locale.current, event.doseMG))
    }
    
    var body: some View {
        HStack(spacing: 15) {
            Image(systemName: icon.name)
                .font(.title2).foregroundColor(.white)
                .frame(width: 40, height: 40).background(icon.color)
                .clipShape(Circle())
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.headline)
                // **FIXED**: Now displays both date and time correctly.
                Text(event.date, style: .time).font(.subheadline).foregroundColor(.secondary)
            }
            
            Spacer()
            
            if let doseText = doseText {
                Text(doseText)
                    .font(.headline.weight(.semibold))
                    .padding(.horizontal, 10).padding(.vertical, 5)
                    .background(Color(uiColor: .systemGray6))
                    .clipShape(Capsule())
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Grouping Logic
struct DayGroup: Identifiable {
    var id: String { day }
    let day: String
    let events: [DoseEvent]
}

private func groupEventsByDay(_ events: [DoseEvent]) -> [DayGroup] {
    let sortedEvents = events.sorted { $0.timeH < $1.timeH }
    
    let formatter = DateFormatter()
    formatter.locale = Locale.current
    formatter.setLocalizedDateFormatFromTemplate("yMMMMdEEEE")
    
    let groupedDictionary = Dictionary(grouping: sortedEvents) { formatter.string(from: $0.date) }
    
    return groupedDictionary.map { DayGroup(day: $0.key, events: $0.value) }
        .sorted { $0.events.first!.timeH > $1.events.first!.timeH }
}

// New: dedicated weight editor view used by the sheet above
struct WeightEditorView: View {
    @State private var tempWeight: Double
    @State private var weightText: String
    @FocusState private var fieldFocused: Bool

    // keep original for change detection
    private let originalWeight: Double

    let onSave: (Double) -> Void
    let onCancel: () -> Void

    init(initialWeight: Double, onSave: @escaping (Double) -> Void, onCancel: @escaping () -> Void) {
        _tempWeight = State(initialValue: initialWeight)
        _weightText = State(initialValue: String(format: "%.1f", locale: Locale.current, initialWeight))
        self.originalWeight = (initialWeight * 10).rounded() / 10
        self.onSave = onSave
        self.onCancel = onCancel
    }

    private var roundedTemp: Double { (tempWeight * 10).rounded() / 10 }
    private var isDirty: Bool { roundedTemp != originalWeight }

    var body: some View {
        VStack(spacing: 16) {
            Spacer(minLength: 20)

            // Center band: minus - big number - plus
            HStack(alignment: .center, spacing: 20) {
                // Decrease
                Button(action: {
                    withAnimation { tempWeight = max(30.0, (tempWeight - 0.1)) }
                }) {
                    Image(systemName: "minus.circle.fill")
                        .resizable().scaledToFit()
                        .frame(width: 56, height: 56)
                        .foregroundColor(.pink)
                        .accessibilityLabel(Text("common.decrease"))
                }

                // Number + unit
                VStack(spacing: 6) {
                    ZStack {
                        Text(String(format: "%.1f", roundedTemp))
                            .font(.system(size: 56, weight: .bold, design: .default))
                            .minimumScaleFactor(0.5)
                            .accessibilityLabel(Text("timeline.bodyWeight.accessibility.value"))
                            .onTapGesture { fieldFocused = true }
                            .offset(y: 2)

                        // Invisible TextField to receive input
                        TextField("", text: $weightText)
                            .keyboardType(.decimalPad)
                            .submitLabel(.done)
                            .focused($fieldFocused)
                            .onSubmit { fieldFocused = false }
                            .onChange(of: weightText) { _old, newValue in
                                let sanitized = newValue.replacingOccurrences(of: ",", with: ".")
                                if sanitized.isEmpty {
                                    tempWeight = 0.0
                                } else if let value = Double(sanitized) {
                                    tempWeight = value
                                }
                            }
                            .opacity(0.01)
                            .frame(width: 140, height: 44)
                            .accessibilityHidden(true)
                    }
                    .frame(height: 56)

                    // Unit placed under the number (previous helper area)
                    Text("timeline.bodyWeight.unit")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }
                .frame(minWidth: 120)

                // Increase
                Button(action: {
                    withAnimation { tempWeight = min(200.0, (tempWeight + 0.1)) }
                }) {
                    Image(systemName: "plus.circle.fill")
                        .resizable().scaledToFit()
                        .frame(width: 56, height: 56)
                        .foregroundColor(.pink)
                        .accessibilityLabel(Text("common.increase"))
                }
            }
            .padding(.horizontal)

            Spacer()
        }
        .padding()
        .navigationTitle("timeline.bodyWeight.title")
        .toolbar {
            // Cancel in navigation bar leading
            ToolbarItem(placement: .navigationBarLeading) {
                Button("common.cancel") { onCancel() }
            }

            // Save in navigation bar trailing
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: {
                    let clamped = min(max(roundedTemp, 30.0), 200.0)
                    onSave(clamped)
                }) {
                    Text("common.save")
                }
                .disabled(!isDirty)
                .buttonStyle(.borderedProminent)
                .tint(.pink)
            }

            // Keep keyboard Done button
            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                Button("common.done") { fieldFocused = false }
            }
        }
        // Helper text moved to bottom safe area
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 8) {
                Divider()
                Text("timeline.bodyWeight.help")
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                    .padding(.bottom, 6)
            }
            .background(Color(UIColor.systemBackground))
        }
        // Sync textual representation when not editing
        .onChange(of: tempWeight) { _old, _new in
            if !fieldFocused {
                weightText = String(format: "%.1f", locale: Locale.current, roundedTemp)
            }
        }
        // When editing finishes, clamp and format
        .onChange(of: fieldFocused) { _old, focused in
            if !focused {
                let clamped = min(max(tempWeight, 30.0), 200.0)
                tempWeight = clamped
                let rounded = (clamped * 10).rounded() / 10
                weightText = String(format: "%.1f", locale: Locale.current, rounded)
            }
        }
    }
}
