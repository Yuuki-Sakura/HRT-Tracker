import SwiftUI

private enum WatchPatchInputMode: String, CaseIterable, Identifiable {
    case totalDose
    case releaseRate

    var id: Self { self }

    var title: String {
        switch self {
        case .totalDose: return "总剂量"
        case .releaseRate: return "释放率"
        }
    }
}

struct WatchAddDoseView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var route: WatchDoseEvent.Route = .injection
    @State private var ester: WatchDoseEvent.Ester = .EV
    @State private var doseText = ""

    @State private var patchMode: WatchPatchInputMode = .totalDose
    @State private var patchReleaseRateText = ""

    @State private var sublingualTierIndex = 2
    @State private var useCustomTheta = false
    @State private var customThetaText = ""

    let onSave: (WatchDoseEvent) -> Void

    private var availableEsters: [WatchDoseEvent.Ester] {
        switch route {
        case .injection:
            return [.EB, .EV, .EC, .EN]
        case .oral, .sublingual:
            return [.E2, .EV]
        case .gel, .patchApply, .patchRemove:
            return [.E2]
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Picker("方式", selection: $route) {
                    ForEach(WatchDoseEvent.Route.allCases, id: \.self) { value in
                        Text(value.displayName).tag(value)
                    }
                }
                .onChange(of: route) { _, _ in
                    ester = availableEsters.first ?? .E2
                    if route == .patchRemove {
                        doseText = "0"
                    }
                    if route != .patchApply {
                        patchMode = .totalDose
                        patchReleaseRateText = ""
                    }
                    if route != .sublingual {
                        sublingualTierIndex = 2
                        useCustomTheta = false
                        customThetaText = ""
                    }
                }

                Picker("药物", selection: $ester) {
                    ForEach(availableEsters, id: \.self) { value in
                        Text(value.rawValue).tag(value)
                    }
                }

                if route == .patchApply {
                    Picker("贴片输入", selection: $patchMode) {
                        ForEach(WatchPatchInputMode.allCases) { mode in
                            Text(mode.title).tag(mode)
                        }
                    }

                    if patchMode == .totalDose {
                        TextField("总剂量 mg", text: $doseText)
                    } else {
                        TextField("释放率 μg/day", text: $patchReleaseRateText)
                    }
                } else if route != .patchRemove {
                    TextField("剂量 mg", text: $doseText)
                }

                if route == .sublingual {
                    Picker("含服档位", selection: $sublingualTierIndex) {
                        Text("Quick").tag(0)
                        Text("Casual").tag(1)
                        Text("Standard").tag(2)
                        Text("Strict").tag(3)
                    }

                    Toggle("自定义 theta", isOn: $useCustomTheta)
                    if useCustomTheta {
                        TextField("theta (0-1)", text: $customThetaText)
                    }
                }
            }
            .navigationTitle("新增记录")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
                        save()
                    }
                    .disabled(!canSave)
                }
            }
        }
    }

    private var canSave: Bool {
        switch route {
        case .patchRemove:
            return true
        case .patchApply:
            if patchMode == .totalDose {
                return parsedDouble(doseText) != nil
            }
            return parsedDouble(patchReleaseRateText) != nil
        case .sublingual:
            if parsedDouble(doseText) == nil { return false }
            if useCustomTheta {
                guard let theta = parsedDouble(customThetaText) else { return false }
                return theta >= 0 && theta <= 1
            }
            return true
        default:
            return parsedDouble(doseText) != nil
        }
    }

    private func parsedDouble(_ text: String) -> Double? {
        Double(text.replacingOccurrences(of: ",", with: "."))
    }

    private func save() {
        var dose = 0.0
        var extras: [WatchDoseEvent.ExtraKey: Double] = [:]

        switch route {
        case .patchRemove:
            dose = 0
        case .patchApply:
            if patchMode == .releaseRate {
                dose = 0
                if let rate = parsedDouble(patchReleaseRateText) {
                    extras[.releaseRateUGPerDay] = rate
                }
            } else {
                dose = parsedDouble(doseText) ?? 0
            }
        case .sublingual:
            dose = parsedDouble(doseText) ?? 0
            if useCustomTheta, let theta = parsedDouble(customThetaText) {
                extras[.sublingualTheta] = max(0, min(1, theta))
            } else {
                extras[.sublingualTier] = Double(min(max(sublingualTierIndex, 0), 3))
            }
        default:
            dose = parsedDouble(doseText) ?? 0
        }

        let event = WatchDoseEvent(
            id: UUID(),
            route: route,
            date: Date(),
            doseMG: dose,
            ester: ester,
            extras: extras
        )
        onSave(event)
        dismiss()
    }
}
