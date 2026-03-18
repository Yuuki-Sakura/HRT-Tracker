import SwiftUI
import HRTModels
import HRTPKEngine

struct LabTab: View {
    @ObservedObject var vm: TimelineViewModel

    @State private var showAddLab = false
    @State private var showClearConfirm = false
    @State private var editingLab: LabResult?

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack {
                        Text("lab.tip_scale")
                            .foregroundStyle(.secondary)
                        Spacer()
                        if let scale = vm.labCalibrationScale {
                            Text("×\(String(format: "%.2f", scale))")
                                .font(.title3.bold())
                        } else {
                            Text("×1.00")
                                .font(.title3.bold())
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                if vm.labResults.isEmpty {
                    ContentUnavailableView {
                        Label(String(localized: "lab.title"), systemImage: "flask")
                    } description: {
                        Text("lab.empty")
                    }
                    .frame(maxWidth: .infinity, minHeight: 200)
                    .listRowBackground(Color.clear)
                } else {
                    ForEach(vm.labResults.sorted(by: { $0.timestamp > $1.timestamp })) { lab in
                        HStack {
                            VStack(alignment: .leading) {
                                Text(lab.date, style: .date)
                                    .font(.subheadline)
                                Text(lab.date, style: .time)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            HStack(alignment: .firstTextBaseline, spacing: 0) {
                                Text(String(format: "%.1f", lab.concValue))
                                    .font(.title3.bold())
                                    .foregroundStyle(.pink)
                                Text(" \(lab.unit == .pgPerML ? "pg/mL" : "pmol/L")")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture { editingLab = lab }
                    }
                    .onDelete { indexSet in
                        let sorted = vm.labResults.sorted(by: { $0.timestamp > $1.timestamp })
                        for i in indexSet {
                            vm.removeLabResult(sorted[i])
                        }
                    }
                }
            }
            .listStyle(.automatic)
            .navigationTitle(String(localized: "lab.title"))
            .toolbarTitleDisplayMode(.inlineLarge)
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showAddLab = true
                    } label: {
                        Image(systemName: "plus")
                    }
                    .contextMenu {
                        Button(role: .destructive) {
                            showClearConfirm = true
                        } label: {
                            Label(String(localized: "lab.clear_all"), systemImage: "trash")
                        }
                        .disabled(vm.labResults.isEmpty)
                    }
                }
            }
            .sheet(isPresented: $showAddLab) {
                NavigationStack {
                    LabInputView { result in
                        vm.addLabResult(result)
                    }
                }
            }
            .sheet(item: $editingLab) { lab in
                NavigationStack {
                    LabInputView(editing: lab) { result in
                        vm.updateLabResult(result)
                    }
                }
            }
            .alert(String(localized: "lab.clear_confirm"), isPresented: $showClearConfirm) {
                Button(String(localized: "btn.cancel"), role: .cancel) {}
                Button(String(localized: "lab.clear_all"), role: .destructive) {
                    vm.clearAllLabResults()
                }
            }
        }
    }
}

#Preview {
    LabTab(vm: .preview)
}
