//
//  ResultChartView.swift
//  HRTRecorder
//
//    Created by mihari-zhong on 2025/8/1.
//

import Foundation
import SwiftUI
import Charts
import Combine

struct ResultChartView: View {
    let sim: SimulationResult

    @State private var visibleDomainLength: Double = 48
    @Environment(\.horizontalSizeClass) var sizeClass
    @State private var now: Date = Date()
    @State private var scrollPosition: Date = Date()
    private let timer = Timer.publish(every: 60, tolerance: 5, on: .main, in: .common).autoconnect()

    private var currentConcentrationText: String {
        let currentHour = now.timeIntervalSince1970 / 3600.0
        if let value = sim.concentration(at: currentHour) {
            let formatted = value.formatted(.number.precision(.fractionLength(1)))
            return String.localizedStringWithFormat(NSLocalizedString("chart.currentConc.value", comment: "Current concentration label"), formatted)
        } else {
            return NSLocalizedString("chart.currentConc.missing", comment: "Current concentration unavailable")
        }
    }


    /// (Date, conc) tuples to simplify the Chart body and help the compiler type‑check faster
    private var datedPoints: [(date: Date, conc: Double)] {
        // Break the work into 2 simpler steps so the compiler can type‑check faster
        let paired: [(Double, Double)] = Array(zip(sim.timeH, sim.concPGmL))
        return paired.map { (hour: Double, conc: Double) -> (date: Date, conc: Double) in
            let date = Date(timeIntervalSince1970: hour * 3600)
            return (date, conc)
        }
    }
    
    private var yAxisDomain: ClosedRange<Double> {
        let maxConcentration = sim.concPGmL.max() ?? 0
        let topBoundary = max(maxConcentration, 50) * 1.1
        return 0.0...topBoundary    // use Double literal to avoid type‑inference cost
    }

    // Precomputed axis label strings to avoid long inline expressions
    private var xAxisLabel: String { NSLocalizedString("chart.axis.time", comment: "X-axis label") }
    private var yAxisLabel: String { NSLocalizedString("chart.axis.conc", comment: "Y-axis label") }

    // Current concentration + date used by helper subviews
    private var currentPoint: (conc: Double, date: Date)? {
        let currentHour = now.timeIntervalSince1970 / 3600.0
        if let c = sim.concentration(at: currentHour) {
            return (c, Date(timeIntervalSince1970: currentHour * 3600))
        }
        return nil
    }

    // A separate sub‑view for the chart itself to keep `body` small and compiler‑friendly
    private var concentrationChart: some View {
        Chart {
            areaMarksView
            lineMarksView
            currentMarksView
        }
        .chartXAxis {
            // Show a tick per day and allow labels to wrap up to two lines so month names don't get clipped
            AxisMarks(values: .stride(by: .day)) { value in
                AxisGridLine()
                AxisTick()
                AxisValueLabel {
                    if let date = value.as(Date.self) {
                        Text(date, format: dayLabelFormat)
                            .font(.caption)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                            .minimumScaleFactor(0.7)
                    } else {
                        EmptyView()
                    }
                }
            }
        }
        // --- Y-Axis Configuration ---
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 6)) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let conc = value.as(Double.self) {
                        Text((conc >= 10 ? String(format: "%.0f", conc) : String(format: "%.1f", conc)) + " pg/mL")
                    } else {
                        EmptyView()
                    }
                }
             }
         }
        .chartXVisibleDomain(length: visibleDomainLength * 3600)   // hours -> seconds
        .chartScrollableAxes(.horizontal)
        .chartScrollPosition(x: $scrollPosition)
        .chartYScale(domain: yAxisDomain)
        .frame(minHeight: 220)
    }

    // MARK: - Chart subviews (small, focused helpers to reduce type-checker work)
    @ChartContentBuilder
    private var areaMarksView: some ChartContent {
        ForEach(Array(datedPoints.enumerated()), id: \.offset) { pair in
            let pt = pair.element
            AreaMark(
                x: .value(xAxisLabel, pt.date),
                y: .value(yAxisLabel, pt.conc)
            )
            .foregroundStyle(
                LinearGradient(colors: [Color.pink.opacity(0.28), Color.pink.opacity(0.06)], startPoint: .top, endPoint: .bottom)
            )
            .interpolationMethod(.catmullRom)
        }
    }

    @ChartContentBuilder
    private var lineMarksView: some ChartContent {
        ForEach(Array(datedPoints.enumerated()), id: \.offset) { pair in
            let pt = pair.element
            LineMark(
                x: .value(xAxisLabel, pt.date),
                y: .value(yAxisLabel, pt.conc)
            )
            .interpolationMethod(.catmullRom)
            .foregroundStyle(LinearGradient(colors: [Color.pink, Color.purple], startPoint: .leading, endPoint: .trailing))
            .lineStyle(StrokeStyle(lineWidth: 2))
        }
    }

    @ChartContentBuilder
    private var currentMarksView: some ChartContent {
        if let cp = currentPoint {
            RuleMark(x: .value(xAxisLabel, cp.date))
                .lineStyle(StrokeStyle(lineWidth: 1, dash: [4,4]))
                .foregroundStyle(Color.primary.opacity(0.7))

            PointMark(
                x: .value(xAxisLabel, cp.date),
                y: .value(yAxisLabel, cp.conc)
            )
            .symbolSize(80)
            .symbol {
                ZStack {
                    Circle().fill(Color.pink).frame(width: 12, height: 12)
                    Circle().fill(Color.white).frame(width: 6, height: 6)
                }
            }
            .annotation(position: .top) {
                VStack(spacing: 2) {
                    Text(String(format: "%.1f pg/mL", cp.conc))
                        .font(.caption2).bold()
                        .padding(6)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Color(.systemBackground)).shadow(radius: 1))
                }
                .fixedSize()
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(LocalizedStringKey("chart.title"))
                    .font(.headline)
                Spacer()
                Text(currentConcentrationText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel(currentConcentrationText)
            }
            .padding(.horizontal)

            concentrationChart
                .accessibilityElement(children: .combine)
                .accessibilityLabel(Text(LocalizedStringKey("chart.accessibility")))
        }
        .animation(.easeInOut, value: sim.concPGmL)
        .onAppear {
            self.visibleDomainLength = (sizeClass == .compact) ? 24 : 48
            scrollPosition = now
        }
        .onReceive(timer) { date in
            now = date
        }
        .onChange(of: sim.timeH.first) {
            scrollPosition = Date()
        }
    }
    
    // MARK: - Date Formatters
    private var dayLabelFormat: Date.FormatStyle {
        if sizeClass == .compact {
            return .dateTime.month(.defaultDigits).day()
        } else {
            return .dateTime.month(.abbreviated).day()
        }
    }
}
