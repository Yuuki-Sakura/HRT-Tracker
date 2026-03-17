import SwiftUI
import Charts
import HRTModels
import HRTPKEngine

// MARK: - Chart Content + Tooltip

extension ConcentrationChartView {
    var chartView: some View {
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
                        .symbolSize(45).foregroundStyle(Color(.systemBackground))
                    PointMark(x: .value("Time", event.date), y: .value("Conc", conc))
                        .symbolSize(18).foregroundStyle(Color.pink)
                }
                if event.ester == .CPA, sim.hasCPA, let conc = sim.concentrationCPA(at: event.timestamp) {
                    let scaledConc = conc * (maxE2 / maxCPA)
                    PointMark(x: .value("Time", event.date), y: .value("Conc", scaledConc))
                        .symbolSize(80).foregroundStyle(Color.indigo)
                    PointMark(x: .value("Time", event.date), y: .value("Conc", scaledConc))
                        .symbolSize(45).foregroundStyle(Color(.systemBackground))
                    PointMark(x: .value("Time", event.date), y: .value("Conc", scaledConc))
                        .symbolSize(18).foregroundStyle(Color.indigo)
                }
            }
            // Lab result markers (green diamonds)
            if !labResults.isEmpty {
                CalibrationOverlay(labResults: labResults)
            }
        }
        .chartXAxis {
            AxisMarks(values: .stride(by: visibleDomainLength <= 48 ? .hour : .day, count: visibleDomainLength <= 48 ? 6 : 1)) { value in
                AxisGridLine()
                AxisTick()
                AxisValueLabel {
                    if let date = value.as(Date.self) {
                        if visibleDomainLength <= 48 {
                            Text(date, format: .dateTime.hour())
                                .font(.caption).lineLimit(1).minimumScaleFactor(0.7)
                        } else {
                            Text(date, format: .dateTime.month(.defaultDigits).day())
                                .font(.caption).lineLimit(2).minimumScaleFactor(0.7)
                        }
                    }
                }
            }
        }
        .chartYAxis {
            if hasE2 {
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

                // Gesture layer: UIKit handles all touches
                ChartGestureOverlay(
                    onDrag: { location in
                        let xInPlot = location.x
                        guard let date: Date = proxy.value(atX: xInPlot) else { return }
                        selectedDate = date
                        touchY = plotFrame.origin.y + location.y

                        // Calculate tooltip position immediately
                        if let xPos = proxy.position(forX: date) {
                            let halfW = max(tooltipSize.width / 2, 70)
                            let halfH = max(tooltipSize.height / 2, 30)
                            let anchorX = plotFrame.origin.x + xPos
                            let anchorY = plotFrame.origin.y + location.y
                            let gap: CGFloat = 12

                            let fitsRight = anchorX + gap + halfW * 2 <= plotFrame.maxX
                            let fitsAbove = anchorY - gap - halfH * 2 >= plotFrame.minY
                            let tx = fitsRight ? anchorX + gap + halfW : anchorX - gap - halfW
                            let ty = fitsAbove ? anchorY - gap - halfH : anchorY + gap + halfH
                            let newPos = CGPoint(x: tx, y: ty)

                            let flipped = (lastFitsRight != nil && fitsRight != lastFitsRight)
                                        || (lastFitsAbove != nil && fitsAbove != lastFitsAbove)
                            lastFitsRight = fitsRight
                            lastFitsAbove = fitsAbove

                            if flipped {
                                isFlipAnimating = true
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                                    isFlipAnimating = false
                                }
                            }

                            if isFlipAnimating {
                                withAnimation(.easeInOut(duration: 0.2)) { tooltipPosition = newPos }
                            } else {
                                tooltipPosition = newPos
                            }
                        }
                    },
                    onDragEnd: {
                        selectedDate = nil
                        lastFitsRight = nil
                        lastFitsAbove = nil
                    },
                    onPinchStart: { center in
                        isPinching = true
                        baseVisibleDomainLength = visibleDomainLength
                        pinchStartScrollTime = scrollPosition.timeIntervalSince1970
                        selectedDate = nil
                        pinchAnchorFraction = max(0, min(1, center.x / plotFrame.width))
                    },
                    onPinchChange: { scale, panTranslation in
                        let totalHours = (totalTimeRange.end - totalTimeRange.start) / 3600
                        let effectiveMax = max(minVisibleHours, min(maxVisibleHours, totalHours))
                        let clamped = max(minVisibleHours, min(effectiveMax, baseVisibleDomainLength / Double(scale)))
                        visibleDomainLength = clamped

                        let anchorTime = pinchStartScrollTime + Double(pinchAnchorFraction) * baseVisibleDomainLength * 3600
                        var newStart = anchorTime - Double(pinchAnchorFraction) * clamped * 3600
                        newStart -= Double(panTranslation.width / plotFrame.width) * clamped * 3600

                        let maxStart = totalTimeRange.end - clamped * 3600
                        scrollPosition = Date(timeIntervalSince1970: max(totalTimeRange.start, min(maxStart, newStart)))
                    },
                    onPinchEnd: {
                        isPinching = false
                        baseVisibleDomainLength = visibleDomainLength
                    }
                )
                .frame(width: plotFrame.width, height: plotFrame.height)
                .position(x: plotFrame.midX, y: plotFrame.midY)

                // Point indicators clipped to plot area
                ZStack {
                    // Current time indicator
                    if let cp = currentPoint, hasE2,
                       let xPos = proxy.position(forX: cp.date),
                       let yPos = proxy.position(forY: cp.conc) {
                        let x = xPos
                        let y = yPos
                        Circle().fill(Color(.systemBackground)).frame(width: 10, height: 10).position(x: x, y: y)
                        Circle().fill(Color(red: 1.0, green: 0.6, blue: 0.7)).frame(width: 6, height: 6).position(x: x, y: y)
                    }
                    if let cpa = currentCPAPoint {
                        let scaledConc = cpa.conc * (maxE2 / maxCPA)
                        if let xPos = proxy.position(forX: cpa.date),
                           let yPos = proxy.position(forY: scaledConc) {
                            let x = xPos
                            let y = yPos
                            Circle().fill(Color(.systemBackground)).frame(width: 10, height: 10).position(x: x, y: y)
                            Circle().fill(Color(red: 0.6, green: 0.6, blue: 0.9)).frame(width: 6, height: 6).position(x: x, y: y)
                        }
                    }

                    // Selected point indicator
                    if let sp = selectedPoint {
                        if let xPos = proxy.position(forX: sp.date) {
                            DashedLine()
                                .stroke(Color.pink.opacity(0.5), style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                                .frame(width: 1, height: plotFrame.height)
                                .position(x: xPos, y: plotFrame.height / 2)
                        }
                        if hasE2,
                           let xPos = proxy.position(forX: sp.date),
                           let yPos = proxy.position(forY: sp.conc) {
                            Circle().fill(Color(.systemBackground)).frame(width: 10, height: 10).position(x: xPos, y: yPos)
                            Circle().fill(Color.pink).frame(width: 6, height: 6).position(x: xPos, y: yPos)
                        }
                        if let cpa = selectedCPAPoint {
                            let scaledConc = cpa.conc * (maxE2 / maxCPA)
                            if let xPos = proxy.position(forX: cpa.date),
                               let yPos = proxy.position(forY: scaledConc) {
                                Circle().fill(Color(.systemBackground)).frame(width: 10, height: 10).position(x: xPos, y: yPos)
                                Circle().fill(Color.indigo).frame(width: 6, height: 6).position(x: xPos, y: yPos)
                            }
                        }
                    }
                }
                .frame(width: plotFrame.width, height: plotFrame.height)
                .clipped()
                .position(x: plotFrame.midX, y: plotFrame.midY)

                // Tooltip display
                if let (date, e2, cpa) = tooltipData {
                    tooltipView(date: date, e2: e2, cpa: cpa)
                        .fixedSize()
                        .onGeometryChange(for: CGSize.self) { $0.size } action: { tooltipSize = $0 }
                        .position(tooltipPosition)
                }
                }
            }
        }
        .frame(minHeight: 260)
    }

    func tooltipView(date: Date, e2: Double, cpa: Double?) -> some View {
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

/// Vertical line shape for selection indicator
private struct DashedLine: Shape {
    func path(in rect: CGRect) -> Path {
        Path { p in
            p.move(to: CGPoint(x: rect.midX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.midX, y: rect.maxY))
        }
    }
}
