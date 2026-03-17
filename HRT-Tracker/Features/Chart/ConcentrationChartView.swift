import SwiftUI
import Combine
import Charts
import HRTModels
import HRTPKEngine

private struct IndexedPoint: Identifiable, Equatable {
    let id: Int
    let date: Date
    let conc: Double
}

struct ConcentrationChartView: View {
    let sim: SimulationResult
    var events: [DoseEvent] = []
    var labResults: [LabResult] = []

    // Pre-computed data points (depend only on immutable `sim`, no need to recompute per frame)
    private let datedPoints: [(date: Date, conc: Double)]
    private let maxE2: Double
    private let hasE2: Bool
    private let maxCPA: Double
    private let scaledCPAPoints: [(date: Date, conc: Double)]
    // Pre-indexed arrays for minimap (avoids Array(enumerated()) allocation per frame)
    private let rawIndexedPoints: [IndexedPoint]
    private let rawIndexedCPAPoints: [IndexedPoint]

    @State private var visibleDomainLength: Double = 48
    @Environment(\.horizontalSizeClass) var sizeClass
    @State private var now = Date()
    @State private var scrollPosition: Date = Date()
    @State private var selectedDate: Date?
    @State private var tooltipSize: CGSize = .zero
    @State private var tooltipPosition: CGPoint = .zero
    @State private var touchY: CGFloat = 0
    @State private var tooltipAnimated = false
    @State private var chartWidth: CGFloat = 0
    private let timer = Timer.publish(every: 60, tolerance: 5, on: .main, in: .common).autoconnect()

    /// Y-axis title font based on available chart width
    private var yAxisFont: Font {
        chartWidth > 500 ? .callout : .caption2
    }

    /// Y-axis value label rotation and width based on available chart width
    private var yAxisValueRotation: Double {
        chartWidth > 500 ? 0 : -90
    }

    private var yAxisValueWidth: CGFloat {
        chartWidth > 500 ? 28 : 16
    }

    init(sim: SimulationResult, events: [DoseEvent] = [], labResults: [LabResult] = []) {
        self.sim = sim
        self.events = events
        self.labResults = labResults

        // Use calibrated concentrations if lab data is available
        let e2Conc: [Double]
        if !labResults.isEmpty {
            e2Conc = LabCalibration.calibratedConcentration(sim: sim, labResults: labResults)
        } else {
            e2Conc = sim.concPGmL
        }

        let rawE2 = zip(sim.timestamps, e2Conc).map {
            (Date(timeIntervalSince1970: TimeInterval($0.0)), $0.1)
        }
        self.rawIndexedPoints = rawE2.enumerated().map { IndexedPoint(id: $0.offset, date: $0.element.0, conc: $0.element.1) }
        self.datedPoints = Self.trimLeadingZeros(rawE2)

        let mE2 = max(sim.concPGmL.max() ?? 0, 50)
        self.maxE2 = mE2
        self.hasE2 = (sim.concPGmL.max() ?? 0) > 0

        let mCPA = max(sim.concNGmL_CPA.max() ?? 0, 10)
        self.maxCPA = mCPA

        if sim.hasCPA {
            let scale = mE2 / mCPA
            let rawCPA = zip(sim.timestamps, sim.concNGmL_CPA).map {
                (Date(timeIntervalSince1970: TimeInterval($0.0)), $0.1 * scale)
            }
            self.rawIndexedCPAPoints = rawCPA.enumerated().map { IndexedPoint(id: $0.offset, date: $0.element.0, conc: $0.element.1) }
            self.scaledCPAPoints = Self.trimLeadingZeros(rawCPA)
        } else {
            self.rawIndexedCPAPoints = []
            self.scaledCPAPoints = []
        }
    }

    /// Trim leading consecutive zero-concentration points, keeping one zero point before the first nonzero as a transition.
    private static func trimLeadingZeros(_ points: [(date: Date, conc: Double)]) -> [(date: Date, conc: Double)] {
        guard let firstNonZero = points.firstIndex(where: { $0.conc > 0 }) else { return points }
        if firstNonZero == 0 { return points }
        // Keep one zero point before the first nonzero as transition
        let keepFrom = max(0, firstNonZero - 1)
        return Array(points[keepFrom...])
    }

    /// Data points filtered to the visible time window (+ 1-point margin) to reduce Chart mark count
    private var visibleDatedPoints: [IndexedPoint] {
        Self.filterToVisibleRange(datedPoints, start: scrollPosition, hours: visibleDomainLength)
    }

    private var visibleScaledCPAPoints: [IndexedPoint] {
        Self.filterToVisibleRange(scaledCPAPoints, start: scrollPosition, hours: visibleDomainLength)
    }

    /// Binary-search filter: keeps only points within [start - margin, end + margin]
    private static func filterToVisibleRange(
        _ points: [(date: Date, conc: Double)],
        start: Date,
        hours: Double
    ) -> [IndexedPoint] {
        guard points.count > 2 else {
            return points.enumerated().map { IndexedPoint(id: $0.offset, date: $0.element.date, conc: $0.element.conc) }
        }
        let margin: TimeInterval = hours * 3600 * 0.1 // 10% margin on each side
        let lo = start.addingTimeInterval(-margin)
        let hi = start.addingTimeInterval(hours * 3600 + margin)

        // Binary search for first index >= lo
        var low = 0, high = points.count
        while low < high {
            let mid = (low + high) / 2
            if points[mid].date < lo { low = mid + 1 } else { high = mid }
        }
        let startIdx = max(0, low - 1) // keep 1 extra for line continuity

        // Binary search for first index > hi
        low = startIdx; high = points.count
        while low < high {
            let mid = (low + high) / 2
            if points[mid].date <= hi { low = mid + 1 } else { high = mid }
        }
        let endIdx = min(points.count - 1, low) // keep 1 extra

        if startIdx == 0 && endIdx == points.count - 1 {
            return points.enumerated().map { IndexedPoint(id: $0.offset, date: $0.element.date, conc: $0.element.conc) }
        }
        return points[startIdx...endIdx].enumerated().map { IndexedPoint(id: $0.offset, date: $0.element.date, conc: $0.element.conc) }
    }

    private var yAxisDomain: ClosedRange<Double> {
        0.0...(maxE2 * 1.1)
    }

    /// Calibrated E2 concentration at a given timestamp
    private func calibratedE2(at ts: Int64) -> Double? {
        guard let raw = sim.concentration(at: ts) else { return nil }
        guard !labResults.isEmpty else { return raw }
        let points = LabCalibration.buildCalibrationPoints(sim: sim, labResults: labResults)
        guard !points.isEmpty else { return raw }
        return raw * LabCalibration.calibrationRatio(at: ts, points: points)
    }

    private var currentPoint: (conc: Double, date: Date)? {
        let ts = Int64(now.timeIntervalSince1970)
        if let c = calibratedE2(at: ts) { return (c, Date(timeIntervalSince1970: TimeInterval(ts))) }
        return nil
    }

    private var currentCPAPoint: (conc: Double, date: Date)? {
        let ts = Int64(now.timeIntervalSince1970)
        if let c = sim.concentrationCPA(at: ts) { return (c, Date(timeIntervalSince1970: TimeInterval(ts))) }
        return nil
    }

    private var selectedPoint: (conc: Double, date: Date)? {
        guard let date = selectedDate else { return nil }
        let ts = Int64(date.timeIntervalSince1970)
        if let c = calibratedE2(at: ts) { return (c, date) }
        return nil
    }

    private var selectedCPAPoint: (conc: Double, date: Date)? {
        guard let date = selectedDate, sim.hasCPA else { return nil }
        let ts = Int64(date.timeIntervalSince1970)
        if let c = sim.concentrationCPA(at: ts) { return (c, date) }
        return nil
    }

    private var tooltipData: (date: Date, e2: Double, cpa: Double?)? {
        guard let sp = selectedPoint else { return nil }
        return (sp.date, sp.conc, selectedCPAPoint?.conc)
    }

    /// Total time range of the data, capped to at most 30 days ago
    private var totalTimeRange: (start: TimeInterval, end: TimeInterval) {
        guard let first = sim.timestamps.first, let last = sim.timestamps.last else {
            return (0, 1)
        }
        let thirtyDaysAgo = Date().timeIntervalSince1970 - 30 * 24 * 3600
        return (max(TimeInterval(first), thirtyDaysAgo), TimeInterval(last))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            headerView
            HStack(spacing: 0) {
                if hasE2 {
                    Text("chart.yaxis.e2")
                        .font(yAxisFont)
                        .foregroundStyle(.pink)
                        .rotationEffect(.degrees(-90))
                        .fixedSize()
                        .frame(width: 16)
                }
                chartView
                if sim.hasCPA {
                    Text("chart.yaxis.cpa")
                        .font(yAxisFont)
                        .foregroundStyle(.indigo)
                        .rotationEffect(.degrees(-90))
                        .fixedSize()
                        .frame(width: 16)
                }
            }
            .background(GeometryReader { geo in
                Color.clear.onAppear { chartWidth = geo.size.width }
                    .onChange(of: geo.size.width) { _, newValue in chartWidth = newValue }
            })
            minimapView
                .padding(.horizontal, 4)
        }
        .animation(.easeInOut, value: sim.concPGmL)
        .onAppear {
            visibleDomainLength = (sizeClass == .compact) ? 144 : 168
            let thirtyDaysAgo = now.addingTimeInterval(-30 * 24 * 3600)
            let idealStart = now.addingTimeInterval(-visibleDomainLength * 3600 / 2)
            scrollPosition = max(idealStart, thirtyDaysAgo)
        }
        .onReceive(timer) { now = $0 }
    }

    private var headerView: some View {
        Text("chart.title")
            .font(.headline)
            .padding(.bottom, 8)
    }

    private var chartView: some View {
        Chart {
            // E2 line
            if hasE2 {
                ForEach(visibleDatedPoints) { pt in
                    LineMark(
                        x: .value("Time", pt.date),
                        y: .value("Conc", pt.conc),
                        series: .value("Series", "E2")
                    )
                    .interpolationMethod(.monotone)
                    .foregroundStyle(Color.pink)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                }
            }
            // CPA line only (no area — avoids stacking issue)
            if sim.hasCPA {
                ForEach(visibleScaledCPAPoints) { pt in
                    LineMark(
                        x: .value("Time", pt.date),
                        y: .value("Conc", pt.conc),
                        series: .value("Series", "CPA")
                    )
                    .interpolationMethod(.monotone)
                    .foregroundStyle(Color.indigo)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                }
            }
            // Dose event markers — stacked PointMarks for double border (outer ring + white + fill)
            ForEach(events) { event in
                if event.ester != .CPA, hasE2, let conc = calibratedE2(at: event.timestamp) {
                    PointMark(x: .value("Time", event.date), y: .value("Conc", conc))
                        .symbolSize(80).foregroundStyle(Color.pink)
                    PointMark(x: .value("Time", event.date), y: .value("Conc", conc))
                        .symbolSize(45).foregroundStyle(Color.white)
                    PointMark(x: .value("Time", event.date), y: .value("Conc", conc))
                        .symbolSize(18).foregroundStyle(Color.pink)
                }
                if event.ester == .CPA, sim.hasCPA, let conc = sim.concentrationCPA(at: event.timestamp) {
                    let scaledConc = conc * (maxE2 / maxCPA)
                    PointMark(x: .value("Time", event.date), y: .value("Conc", scaledConc))
                        .symbolSize(80).foregroundStyle(Color.indigo)
                    PointMark(x: .value("Time", event.date), y: .value("Conc", scaledConc))
                        .symbolSize(45).foregroundStyle(Color.white)
                    PointMark(x: .value("Time", event.date), y: .value("Conc", scaledConc))
                        .symbolSize(18).foregroundStyle(Color.indigo)
                }
            }
            // Lab result markers (green diamonds)
            if !labResults.isEmpty {
                CalibrationOverlay(labResults: labResults)
            }
            // Selected point — dashed RuleMark + stacked PointMarks
            if let sp = selectedPoint {
                RuleMark(x: .value("Time", sp.date))
                    .lineStyle(StrokeStyle(lineWidth: 1, dash: [4, 3]))
                    .foregroundStyle(Color.pink.opacity(0.5))
                if let cpa = selectedCPAPoint {
                    let scaledConc = cpa.conc * (maxE2 / maxCPA)
                    PointMark(x: .value("Time", cpa.date), y: .value("Conc", scaledConc))
                        .symbolSize(80).foregroundStyle(Color.white)
                    PointMark(x: .value("Time", cpa.date), y: .value("Conc", scaledConc))
                        .symbolSize(30).foregroundStyle(Color.indigo)
                }
                if hasE2 {
                    PointMark(x: .value("Time", sp.date), y: .value("Conc", sp.conc))
                        .symbolSize(80).foregroundStyle(Color.white)
                    PointMark(x: .value("Time", sp.date), y: .value("Conc", sp.conc))
                        .symbolSize(30).foregroundStyle(Color.pink)
                }
            }
            // Current time — always visible, stacked PointMarks with light color
            if let cp = currentPoint {
                if hasE2 {
                    PointMark(x: .value("Time", cp.date), y: .value("Conc", cp.conc))
                        .symbolSize(80).foregroundStyle(Color.white)
                    PointMark(x: .value("Time", cp.date), y: .value("Conc", cp.conc))
                        .symbolSize(30).foregroundStyle(Color(red: 1.0, green: 0.6, blue: 0.7))
                }
                if let cpa = currentCPAPoint {
                    let scaledConc = cpa.conc * (maxE2 / maxCPA)
                    PointMark(x: .value("Time", cpa.date), y: .value("Conc", scaledConc))
                        .symbolSize(80).foregroundStyle(Color.white)
                    PointMark(x: .value("Time", cpa.date), y: .value("Conc", scaledConc))
                        .symbolSize(30).foregroundStyle(Color(red: 0.6, green: 0.6, blue: 0.9))
                }
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: .day)) { value in
                AxisGridLine()
                AxisTick()
                AxisValueLabel {
                    if let date = value.as(Date.self) {
                        Text(date, format: .dateTime.month(.defaultDigits).day())
                            .font(.caption).lineLimit(2).minimumScaleFactor(0.7)
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 6)) { value in
                AxisGridLine()
                AxisValueLabel {
                    if let conc = value.as(Double.self) {
                        Text(conc >= 10 ? String(format: "%.0f", conc) : String(format: "%.1f", conc))
                            .foregroundStyle(.pink)
                            .rotationEffect(.degrees(yAxisValueRotation))
                            .fixedSize()
                            .frame(width: yAxisValueWidth)
                    }
                }
            }
            if sim.hasCPA {
                AxisMarks(position: .trailing, values: .automatic(desiredCount: 6)) { value in
                    AxisValueLabel {
                        if let scaled = value.as(Double.self) {
                            let original = scaled * (maxCPA / maxE2)
                            Text(original >= 10 ? String(format: "%.0f", original) : String(format: "%.1f", original))
                                .foregroundStyle(.indigo)
                                .rotationEffect(.degrees(yAxisValueRotation))
                                .fixedSize()
                                .frame(width: yAxisValueWidth)
                        }
                    }
                }
            }
        }
        .chartXScale(domain: scrollPosition...scrollPosition.addingTimeInterval(visibleDomainLength * 3600))
        .chartYScale(domain: yAxisDomain)
        .chartPlotStyle { plotArea in
            plotArea.clipped().drawingGroup()
        }
        .chartOverlay { proxy in
            GeometryReader { geo in
                if let plotFrameAnchor = proxy.plotFrame {
                let plotFrame = geo[plotFrameAnchor]

                // Gesture layer to capture touch position
                Rectangle()
                    .fill(.clear)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { value in
                                let loc = value.location
                                let xInPlot = loc.x - plotFrame.origin.x
                                guard let date: Date = proxy.value(atX: xInPlot) else { return }
                                selectedDate = date
                                touchY = loc.y
                            }
                            .onEnded { _ in
                                selectedDate = nil
                                tooltipAnimated = false
                            }
                    )

                // Tooltip display
                if let (date, e2, cpa) = tooltipData,
                   let xPos = proxy.position(forX: date) {
                    let halfW = max(tooltipSize.width / 2, 70)
                    let halfH = max(tooltipSize.height / 2, 30)

                    let anchorX = plotFrame.origin.x + xPos
                    let anchorY = touchY

                    // Horizontal: prefer right of dashed line, fall back to left
                    let gap: CGFloat = 12
                    let fitsRight = anchorX + gap + halfW * 2 <= plotFrame.maxX
                    let tooltipX = fitsRight ? anchorX + gap + halfW : anchorX - gap - halfW

                    // Vertical: prefer above touch point, fall back to below
                    let fitsAbove = anchorY - gap - halfH * 2 >= plotFrame.minY
                    let tooltipY = fitsAbove ? anchorY - gap - halfH : anchorY + gap + halfH

                    let target = CGPoint(x: tooltipX, y: tooltipY)

                    tooltipView(date: date, e2: e2, cpa: cpa)
                        .fixedSize()
                        .background(GeometryReader { tipGeo in
                            Color.clear.preference(key: TooltipSizeKey.self, value: tipGeo.size)
                        })
                        .transaction { $0.animation = nil }
                        .position(tooltipPosition)
                        .onChange(of: touchY) {
                            if tooltipAnimated {
                                withAnimation(.interactiveSpring(response: 0.3, dampingFraction: 0.8)) {
                                    tooltipPosition = target
                                }
                            } else {
                                tooltipPosition = target
                                tooltipAnimated = true
                            }
                        }
                        .onChange(of: date) {
                            if tooltipAnimated {
                                withAnimation(.interactiveSpring(response: 0.3, dampingFraction: 0.8)) {
                                    tooltipPosition = target
                                }
                            } else {
                                tooltipPosition = target
                                tooltipAnimated = true
                            }
                        }
                        .onAppear {
                            tooltipPosition = target
                            tooltipAnimated = true
                        }
                        .onDisappear {
                            tooltipAnimated = false
                        }
                }
                }
            }
            .onPreferenceChange(TooltipSizeKey.self) { tooltipSize = $0 }
        }
        .frame(minHeight: 260)
    }

    // MARK: - Scroll Minimap

    private var minimapView: some View {
        let cutoff = Date().addingTimeInterval(-30 * 24 * 3600)
        return ChartMinimapView(
            indexedPoints: rawIndexedPoints.filter { $0.date >= cutoff },
            indexedCPAPoints: rawIndexedCPAPoints.filter { $0.date >= cutoff },
            hasE2: hasE2,
            hasCPA: sim.hasCPA,
            yAxisDomain: yAxisDomain,
            totalTimeRange: totalTimeRange,
            visibleDomainLength: visibleDomainLength,
            scrollPosition: $scrollPosition
        )
    }

    // MARK: - Tooltip

    private func tooltipView(date: Date, e2: Double, cpa: Double?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(date, format: .dateTime.month(.defaultDigits).day().hour().minute())
                .font(.caption2)
                .foregroundStyle(.secondary)
            if hasE2 {
                HStack(spacing: 4) {
                    Text("label.e2")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(String(format: "%.1f", e2))
                        .font(.caption2).bold()
                        .foregroundStyle(.pink)
                    Text("pg/mL")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            if let cpa {
                HStack(spacing: 4) {
                    Text("label.cpa")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(String(format: "%.1f", cpa))
                        .font(.caption2).bold()
                        .foregroundStyle(.indigo)
                    Text("ng/mL")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(6)
        .background(RoundedRectangle(cornerRadius: 6).fill(.background).shadow(radius: 1))
        .fixedSize()
    }
}

// MARK: - Minimap (Equatable static chart + dynamic thumb overlay)

private struct MinimapChartContent: View, Equatable {
    let points: [IndexedPoint]
    let cpaPoints: [IndexedPoint]
    let hasE2: Bool
    let hasCPA: Bool
    let yAxisDomain: ClosedRange<Double>

    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.points == rhs.points &&
        lhs.cpaPoints == rhs.cpaPoints &&
        lhs.hasE2 == rhs.hasE2 &&
        lhs.hasCPA == rhs.hasCPA &&
        lhs.yAxisDomain == rhs.yAxisDomain
    }

    var body: some View {
        Chart {
            if hasE2 {
                ForEach(points) { pt in
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
                ForEach(cpaPoints) { pt in
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
        .chartYScale(domain: yAxisDomain)
        .frame(height: 40)
        .drawingGroup()
    }
}

private struct ChartMinimapView: View {
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
        MinimapChartContent(
            points: indexedPoints,
            cpaPoints: indexedCPAPoints,
            hasE2: hasE2,
            hasCPA: hasCPA,
            yAxisDomain: yAxisDomain
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

private struct TooltipSizeKey: PreferenceKey {
    static let defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) { value = nextValue() }
}

private func makePreviewData() -> (SimulationResult, [DoseEvent]) {
    let now = Int64(Date().timeIntervalSince1970)
    let start = now - 14 * 24 * 3600
    var events = [DoseEvent]()
    for day in 0..<14 {
        events.append(DoseEvent(route: .gel, timestamp: start + Int64(day) * 24 * 3600, doseMG: 2.0, ester: .E2))
    }
    for i in stride(from: 0, to: 14, by: 3) {
        events.append(DoseEvent(route: .oral, timestamp: start + Int64(i) * 24 * 3600, doseMG: 12.5, ester: .CPA))
    }
    let engine = SimulationEngine(
        events: events, bodyWeightKG: 60,
        startTimestamp: start, endTimestamp: now + 3 * 24 * 3600, numberOfSteps: 500
    )
    return (engine.run(), events)
}

#Preview {
    let (sim, events) = makePreviewData()
    ConcentrationChartView(sim: sim, events: events)
        .frame(height: 500)
        .padding()
}
