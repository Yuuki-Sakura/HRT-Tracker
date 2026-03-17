import SwiftUI
import Combine
import Charts
import HRTModels
import HRTPKEngine

struct IndexedPoint: Identifiable, Equatable {
    let id: Int
    let date: Date
    let conc: Double
}

struct ConcentrationChartView: View {
    let sim: SimulationResult
    var events: [DoseEvent] = []
    var labResults: [LabResult] = []

    // Pre-computed data points (depend only on immutable `sim`, no need to recompute per frame)
    let datedPoints: [(date: Date, conc: Double)]
    let maxE2: Double
    let hasE2: Bool
    let maxCPA: Double
    let scaledCPAPoints: [(date: Date, conc: Double)]
    // Pre-indexed arrays for minimap (avoids Array(enumerated()) allocation per frame)
    private let rawIndexedPoints: [IndexedPoint]
    private let rawIndexedCPAPoints: [IndexedPoint]
    // Cached calibration points (immutable for the lifetime of the view)
    let calibrationPoints: [LabCalibration.CalibrationPoint]

    @State var visibleDomainLength: Double = 48
    @State var baseVisibleDomainLength: Double = 48
    @State var isPinching: Bool = false
    @State var pinchAnchorFraction: CGFloat = 0.5
    @State var pinchStartScrollTime: TimeInterval = 0
    let minVisibleHours: Double = 12
    let maxVisibleHours: Double = 30 * 24
    @Environment(\.horizontalSizeClass) var sizeClass
    @State var now = Date()
    @State var scrollPosition: Date = Date()
    @State var selectedDate: Date?
    @State var tooltipSize: CGSize = .zero
    @State var tooltipPosition: CGPoint = .zero
    @State var touchY: CGFloat = 0
    @State var lastFitsRight: Bool?
    @State var lastFitsAbove: Bool?
    @State var isFlipAnimating = false
    @State var chartWidth: CGFloat = 0
    private let timer = Timer.publish(every: 60, tolerance: 5, on: .main, in: .common).autoconnect()

    /// Y-axis title font based on available chart width
    var yAxisFont: Font {
        chartWidth > 500 ? .callout : .caption2
    }

    /// Y-axis value label rotation and width based on available chart width
    var yAxisValueRotation: Double {
        chartWidth > 500 ? 0 : -90
    }

    var yAxisValueWidth: CGFloat {
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

        self.calibrationPoints = labResults.isEmpty
            ? []
            : LabCalibration.buildCalibrationPoints(sim: sim, labResults: labResults)
    }

    /// Trim leading consecutive zero-concentration points, keeping one zero point before the first nonzero as a transition.
    private static func trimLeadingZeros(_ points: [(date: Date, conc: Double)]) -> [(date: Date, conc: Double)] {
        guard let firstNonZero = points.firstIndex(where: { $0.conc > 0 }) else { return points }
        if firstNonZero == 0 { return points }
        let keepFrom = max(0, firstNonZero - 1)
        return Array(points[keepFrom...])
    }

    /// Data points filtered to the visible time window (+ 1-point margin) to reduce Chart mark count
    var visibleDatedPoints: [IndexedPoint] {
        Self.filterToVisibleRange(datedPoints, start: scrollPosition, hours: visibleDomainLength)
    }

    var visibleScaledCPAPoints: [IndexedPoint] {
        Self.filterToVisibleRange(scaledCPAPoints, start: scrollPosition, hours: visibleDomainLength)
    }

    /// Binary-search filter: keeps only points within [start - margin, end + margin]
    static func filterToVisibleRange(
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

    var yAxisDomain: ClosedRange<Double> {
        0.0...(maxE2 * 1.1)
    }

    /// Calibrated E2 concentration at a given timestamp
    func calibratedE2(at ts: Int64) -> Double? {
        guard let raw = sim.concentration(at: ts) else { return nil }
        guard !calibrationPoints.isEmpty else { return raw }
        return raw * LabCalibration.calibrationRatio(at: ts, points: calibrationPoints)
    }

    var currentPoint: (conc: Double, date: Date)? {
        let ts = Int64(now.timeIntervalSince1970)
        if let c = calibratedE2(at: ts) { return (c, Date(timeIntervalSince1970: TimeInterval(ts))) }
        return nil
    }

    var currentCPAPoint: (conc: Double, date: Date)? {
        let ts = Int64(now.timeIntervalSince1970)
        if let c = sim.concentrationCPA(at: ts) { return (c, Date(timeIntervalSince1970: TimeInterval(ts))) }
        return nil
    }

    var selectedPoint: (conc: Double, date: Date)? {
        guard let date = selectedDate else { return nil }
        let ts = Int64(date.timeIntervalSince1970)
        if let c = calibratedE2(at: ts) { return (c, date) }
        return nil
    }

    var selectedCPAPoint: (conc: Double, date: Date)? {
        guard let date = selectedDate, sim.hasCPA else { return nil }
        let ts = Int64(date.timeIntervalSince1970)
        if let c = sim.concentrationCPA(at: ts) { return (c, date) }
        return nil
    }

    var tooltipData: (date: Date, e2: Double, cpa: Double?)? {
        guard let sp = selectedPoint else { return nil }
        return (sp.date, sp.conc, selectedCPAPoint?.conc)
    }

    /// Total time range of the data, capped to at most 30 days ago
    var totalTimeRange: (start: TimeInterval, end: TimeInterval) {
        guard let first = sim.timestamps.first, let last = sim.timestamps.last else {
            return (0, 1)
        }
        let thirtyDaysAgo = now.timeIntervalSince1970 - 30 * 24 * 3600
        return (max(TimeInterval(first), thirtyDaysAgo), TimeInterval(last))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("chart.title")
                .font(.headline)
                .padding(.bottom, 8)
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
        }
        .animation(.easeInOut, value: sim.concPGmL)
        .onAppear {
            visibleDomainLength = (sizeClass == .compact) ? 144 : 168
            baseVisibleDomainLength = visibleDomainLength
            let visibleSeconds = visibleDomainLength * 3600
            let dataStart = Date(timeIntervalSince1970: totalTimeRange.start)

            // Center on now, but don't scroll before data start
            let idealStart = now.addingTimeInterval(-visibleSeconds / 2)
            scrollPosition = max(idealStart, dataStart)
        }
        .onReceive(timer) { now = $0 }
    }

    private var minimapView: some View {
        let cutoff = now.addingTimeInterval(-30 * 24 * 3600)
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
}

// MARK: - Preview

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
