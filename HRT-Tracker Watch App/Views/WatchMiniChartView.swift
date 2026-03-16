import SwiftUI
import Charts
import HRTModels

struct WatchMiniChartView: View {
    let sim: SimulationResult
    var currentE2: Double?
    var currentCPA: Double?

    private var recentE2Points: [(date: Date, conc: Double)] {
        let now = Int64(Date().timeIntervalSince1970)
        let cutoff = now - 72 * 3600
        return zip(sim.timestamps, sim.concPGmL)
            .filter { $0.0 >= cutoff }
            .map { (Date(timeIntervalSince1970: TimeInterval($0.0)), $0.1) }
    }

    private var recentCPAPoints: [(date: Date, conc: Double)] {
        guard sim.hasCPA else { return [] }
        let now = Int64(Date().timeIntervalSince1970)
        let cutoff = now - 72 * 3600
        let maxE2 = max(sim.concPGmL.max() ?? 0, 50)
        let maxCPA = max(sim.concNGmL_CPA.max() ?? 0, 10)
        let scale = maxE2 / maxCPA
        return zip(sim.timestamps, sim.concNGmL_CPA)
            .filter { $0.0 >= cutoff }
            .map { (Date(timeIntervalSince1970: TimeInterval($0.0)), $0.1 * scale) }
    }

    private var e2Range: (min: Double, max: Double) {
        let concs = recentE2Points.map(\.conc)
        return (min: concs.min() ?? 0, max: concs.max() ?? 0)
    }

    private var cpaRange: (min: Double, max: Double) {
        guard sim.hasCPA else { return (0, 0) }
        let now = Int64(Date().timeIntervalSince1970)
        let cutoff = now - 72 * 3600
        let concs = zip(sim.timestamps, sim.concNGmL_CPA)
            .filter { $0.0 >= cutoff }
            .map(\.1)
        return (min: concs.min() ?? 0, max: concs.max() ?? 0)
    }

    /// CPA values scaled to E2 Y-axis for right-side labels
    private var cpaRangeScaled: (min: Double, max: Double) {
        guard sim.hasCPA else { return (0, 0) }
        let maxE2 = max(sim.concPGmL.max() ?? 0, 50)
        let maxCPA = max(sim.concNGmL_CPA.max() ?? 0, 10)
        let scale = maxE2 / maxCPA
        return (min: cpaRange.min * scale, max: cpaRange.max * scale)
    }

    private var cpaScale: Double {
        let maxE2 = max(sim.concPGmL.max() ?? 0, 50)
        let maxCPA = max(sim.concNGmL_CPA.max() ?? 0, 10)
        return maxE2 / maxCPA
    }

    private var cpaAxisValues: [Double] {
        guard sim.hasCPA else { return [] }
        return [cpaRangeScaled.min, cpaRangeScaled.max]
    }

    var body: some View {
        Chart {
            ForEach(Array(recentE2Points.enumerated()), id: \.offset) { pair in
                LineMark(
                    x: .value("Time", pair.element.date),
                    y: .value("Conc", pair.element.conc),
                    series: .value("Series", "E2")
                )
                .interpolationMethod(.monotone)
                .foregroundStyle(Color.pink)
                .lineStyle(StrokeStyle(lineWidth: 2))
            }

            ForEach(Array(recentCPAPoints.enumerated()), id: \.offset) { pair in
                LineMark(
                    x: .value("Time", pair.element.date),
                    y: .value("Conc", pair.element.conc),
                    series: .value("Series", "CPA")
                )
                .interpolationMethod(.monotone)
                .foregroundStyle(Color.indigo)
                .lineStyle(StrokeStyle(lineWidth: 2))
            }

            // Current E2 point
            if let e2 = currentE2 {
                PointMark(
                    x: .value("Time", Date()),
                    y: .value("Conc", e2)
                )
                .foregroundStyle(Color.pink)
                .symbolSize(30)
                .annotation(position: .top, spacing: 2) {
                    Text(String(format: "%.0f", e2))
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.pink)
                }
            }

            // Current CPA point
            if let cpa = currentCPA, cpa > 0 {
                PointMark(
                    x: .value("Time", Date()),
                    y: .value("Conc", cpa * cpaScale)
                )
                .foregroundStyle(Color.indigo)
                .symbolSize(30)
                .annotation(position: .bottom, spacing: 2) {
                    Text(String(format: "%.1f", cpa))
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.indigo)
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .day, count: 2)) { value in
                AxisValueLabel {
                    if let d = value.as(Date.self) {
                        Text("\(Calendar.current.component(.month, from: d))/\(Calendar.current.component(.day, from: d))")
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                    }
                }
                AxisGridLine()
                    .foregroundStyle(.secondary.opacity(0.3))
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: [e2Range.min, e2Range.max]) { value in
                AxisValueLabel {
                    if let v = value.as(Double.self) {
                        Text(String(format: "%.0f", v))
                            .font(.system(size: 9))
                            .foregroundStyle(.pink.opacity(0.7))
                    }
                }
            }
            AxisMarks(position: .trailing, values: cpaAxisValues) { value in
                AxisValueLabel {
                    if let v = value.as(Double.self) {
                        Text(String(format: "%.0f", v / cpaScale))
                            .font(.system(size: 9))
                            .foregroundStyle(.indigo.opacity(0.7))
                    }
                }
            }
        }
    }
}

#Preview {
    let timestamps = (0..<50).map { Int64($0) * 5400 + 490000 * 3600 }
    let conc = timestamps.map { 80.0 * exp(-0.02 * Double($0 - 490000 * 3600) / 3600.0) }
    WatchMiniChartView(sim: SimulationResult(timestamps: timestamps, concPGmL: conc, auc: 500), currentE2: 60, currentCPA: nil)
        .frame(height: 80)
}
