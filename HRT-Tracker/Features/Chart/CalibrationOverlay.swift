import SwiftUI
import Charts
import HRTModels

struct CalibrationOverlay: ChartContent {
    let labResults: [LabResult]

    var body: some ChartContent {
        ForEach(labResults) { lab in
            let date = Date(timeIntervalSince1970: TimeInterval(lab.timestamp))
            let conc = lab.concInPgPerML
            PointMark(
                x: .value("Time", date),
                y: .value("Conc", conc)
            )
            .symbol(.diamond)
            .symbolSize(100)
            .foregroundStyle(.green)
        }
    }
}

#Preview {
    Text("CalibrationOverlay is used within ConcentrationChartView")
}
