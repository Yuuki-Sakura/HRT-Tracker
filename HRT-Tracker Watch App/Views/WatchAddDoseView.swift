import SwiftUI
import HRTModels

struct WatchAddDoseView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var route: Route = .injection
    @State private var ester: Ester = .EV
    @State private var doseText: String = ""
    @State private var date = Date()
    @State private var patchWearDays: Int = 3

    var onSave: (DoseEvent) -> Void

    private var availableEsters: [Ester] {
        switch route {
        case .injection: return [.EB, .EV, .EC, .EN]
        case .patchApply, .patchRemove, .gel: return [.E2]
        case .oral: return [.E2, .EV, .CPA]
        case .sublingual: return [.E2, .EV]
        }
    }

    private var isCPA: Bool { ester == .CPA }

    private var dosePlaceholder: String {
        isCPA ? String(localized: "input.dose.cpa") : String(localized: "input.dose.e2")
    }

    var body: some View {
        NavigationStack {
            Form {
                Picker(String(localized: "input.route"), selection: $route) {
                    Text("input.route.injection").tag(Route.injection)
                    Text("input.route.patchApply").tag(Route.patchApply)
                    Text("input.route.gel").tag(Route.gel)
                    Text("input.route.oral").tag(Route.oral)
                    Text("input.route.sublingual").tag(Route.sublingual)
                }
                .onChange(of: route) { _, _ in
                    if let first = availableEsters.first { ester = first }
                }

                if availableEsters.count > 1 {
                    Picker(String(localized: "input.drugEster"), selection: $ester) {
                        ForEach(availableEsters) { e in
                            Text(e.localizedName).tag(e)
                        }
                    }
                }

                TextField(dosePlaceholder, text: $doseText)

                if route == .patchApply {
                    Stepper(value: $patchWearDays, in: 1...14) {
                        Text("watch.patchDays \(patchWearDays)")
                    }
                }

                DatePicker(String(localized: "input.time"), selection: $date, displayedComponents: .hourAndMinute)
                DatePicker(selection: $date, displayedComponents: .date) {
                    EmptyView()
                }
            }
            .navigationTitle(String(localized: "input.title.add"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(String(localized: "common.cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(String(localized: "common.save")) {
                        let dose = Double(doseText.replacingOccurrences(of: ",", with: ".")) ?? 0
                        var extras: [ExtraKey: Double] = [:]
                        if route == .patchApply {
                            extras[.patchWearDays] = Double(patchWearDays)
                        }
                        let event = DoseEvent(
                            route: route,
                            timestamp: Int64(date.timeIntervalSince1970),
                            doseMG: dose,
                            ester: isCPA ? .CPA : ester,
                            extras: extras
                        )
                        onSave(event)
                        dismiss()
                    }
                }
            }
        }
    }
}

#Preview {
    WatchAddDoseView { _ in }
}
