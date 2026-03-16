import SwiftUI
import HRTModels

struct LabResultsListView: View {
    let results: [LabResult]
    let onDelete: (LabResult) -> Void

    var body: some View {
        List {
            ForEach(results.sorted(by: { $0.timestamp > $1.timestamp })) { result in
                HStack {
                    VStack(alignment: .leading) {
                        Text(result.date, style: .date)
                            .font(.headline)
                        Text(result.date, style: .time)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text(String(format: "%.1f %@", result.concValue, result.unit.rawValue))
                        .font(.headline)
                        .foregroundStyle(.pink)
                }
            }
            .onDelete { indexSet in
                let sorted = results.sorted(by: { $0.timestamp > $1.timestamp })
                for index in indexSet {
                    onDelete(sorted[index])
                }
            }
        }
        .navigationTitle("lab.results.title")
    }
}

#Preview {
    NavigationStack {
        LabResultsListView(results: [
            LabResult(timestamp: Int64(Date().timeIntervalSince1970), concValue: 85.3, unit: .pgPerML),
            LabResult(timestamp: Int64(Date().timeIntervalSince1970) - 48 * 3600, concValue: 312, unit: .pmolPerL),
        ], onDelete: { _ in })
    }
}
