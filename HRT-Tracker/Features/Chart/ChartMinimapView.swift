import SwiftUI
import Charts

// MARK: - Minimap (Equatable static chart + dynamic thumb overlay)

struct MinimapChartContent: View, Equatable {
    let points: [IndexedPoint]
    let cpaPoints: [IndexedPoint]
    let hasE2: Bool
    let hasCPA: Bool
    let yAxisDomain: ClosedRange<Double>
    let xAxisDomain: ClosedRange<Date>

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.points == rhs.points &&
        lhs.cpaPoints == rhs.cpaPoints &&
        lhs.hasE2 == rhs.hasE2 &&
        lhs.hasCPA == rhs.hasCPA &&
        lhs.yAxisDomain == rhs.yAxisDomain &&
        lhs.xAxisDomain == rhs.xAxisDomain
    }

    var body: some View {
        Chart {
            if hasE2 {
                ForEach(points.filter { $0.conc > 0 }) { pt in
                    LineMark(
                        x: .value("Time", pt.date),
                        y: .value("Conc", pt.conc),
                        series: .value("Series", "E2")
                    )
                    .foregroundStyle(Color.pink.opacity(0.4))
                    .lineStyle(StrokeStyle(lineWidth: 1))
                    .interpolationMethod(.monotone)
                }
            }
            if hasCPA {
                ForEach(cpaPoints.filter { $0.conc > 0 }) { pt in
                    LineMark(
                        x: .value("Time", pt.date),
                        y: .value("Conc", pt.conc),
                        series: .value("Series", "CPA")
                    )
                    .foregroundStyle(Color.indigo.opacity(0.4))
                    .lineStyle(StrokeStyle(lineWidth: 1))
                    .interpolationMethod(.monotone)
                }
            }
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartXScale(domain: xAxisDomain)
        .chartYScale(domain: yAxisDomain)
        .frame(height: 40)
        .drawingGroup()
    }
}

struct ChartMinimapView: View {
    let indexedPoints: [IndexedPoint]
    let indexedCPAPoints: [IndexedPoint]
    let hasE2: Bool
    let hasCPA: Bool
    let yAxisDomain: ClosedRange<Double>
    let totalTimeRange: (start: TimeInterval, end: TimeInterval)
    let visibleDomainLength: Double
    @Binding var scrollPosition: Date

    @State private var dragStartScrollTime: TimeInterval?

    var body: some View {
        let xDomain = Date(timeIntervalSince1970: totalTimeRange.start)...Date(timeIntervalSince1970: totalTimeRange.end)
        MinimapChartContent(
            points: indexedPoints,
            cpaPoints: indexedCPAPoints,
            hasE2: hasE2,
            hasCPA: hasCPA,
            yAxisDomain: yAxisDomain,
            xAxisDomain: xDomain
        )
        .equatable()
        .overlay { thumbOverlay }
        .padding(6)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(.fill)
        )
    }

    private var thumbOverlay: some View {
        GeometryReader { geo in
            let total = totalTimeRange
            let totalDuration = total.end - total.start
            let visibleStart = scrollPosition.timeIntervalSince1970
            let visibleEnd = visibleStart + visibleDomainLength * 3600

            let startFrac = totalDuration > 0
                ? max(0, (visibleStart - total.start) / totalDuration)
                : 0
            let endFrac = totalDuration > 0
                ? min(1, (visibleEnd - total.start) / totalDuration)
                : 1
            let thumbWidth = max(20, geo.size.width * (endFrac - startFrac))
            let thumbOffset = geo.size.width * startFrac

            RoundedRectangle(cornerRadius: 3)
                .fill(Color.accentColor.opacity(0.15))
                .overlay(
                    RoundedRectangle(cornerRadius: 3)
                        .strokeBorder(Color.accentColor.opacity(0.4), lineWidth: 1)
                )
                .frame(width: thumbWidth, height: geo.size.height)
                .offset(x: thumbOffset)
                .gesture(
                    DragGesture(minimumDistance: 1)
                        .onChanged { value in
                            if dragStartScrollTime == nil {
                                dragStartScrollTime = scrollPosition.timeIntervalSince1970
                            }
                            guard let startTime = dragStartScrollTime, totalDuration > 0 else { return }
                            let deltaFrac = value.translation.width / geo.size.width
                            let deltaTime = deltaFrac * totalDuration
                            let visibleDuration = visibleDomainLength * 3600
                            let newTime = max(
                                total.start,
                                min(total.end - visibleDuration, startTime + deltaTime)
                            )
                            scrollPosition = Date(timeIntervalSince1970: newTime)
                        }
                        .onEnded { _ in
                            dragStartScrollTime = nil
                        }
                )
        }
    }
}
