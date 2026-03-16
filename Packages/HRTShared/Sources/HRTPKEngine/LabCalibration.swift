import Foundation
import HRTModels

public struct LabCalibration: Sendable {

    public struct CalibrationPoint: Sendable {
        public let timestamp: Int64
        public let ratio: Double

        public init(timestamp: Int64, ratio: Double) {
            self.timestamp = timestamp
            self.ratio = ratio
        }
    }

    public static func buildCalibrationPoints(
        sim: SimulationResult?,
        labResults: [LabResult]
    ) -> [CalibrationPoint] {
        guard let sim = sim, !labResults.isEmpty else { return [] }

        var points: [CalibrationPoint] = []

        for lab in labResults {
            let obs = lab.concInPgPerML
            guard obs > 0 else { continue }

            guard let pred = sim.concentration(at: lab.timestamp) else { continue }
            guard pred >= 1.0 else { continue }

            let ratio = max(0.01, min(100.0, obs / pred))
            points.append(CalibrationPoint(timestamp: lab.timestamp, ratio: ratio))
        }

        points.sort { $0.timestamp < $1.timestamp }
        return points
    }

    public static func calibrationRatio(
        at ts: Int64,
        points: [CalibrationPoint]
    ) -> Double {
        guard !points.isEmpty else { return 1.0 }
        if points.count == 1 { return points[0].ratio }

        // Check for exact match
        for p in points where p.timestamp == ts {
            return p.ratio
        }

        // IDW + exponential time decay
        let tau: Double = 30.0 * 86400.0   // 30-day decay constant (seconds)
        let p: Double = 2.0                 // IDW power
        let epsilon: Double = 3600.0        // 1 hour, prevent division by zero

        var weightedSum = 0.0
        var weightSum = 0.0

        for point in points {
            let age = abs(Double(ts - point.timestamp))
            let decay = exp(-age / tau)
            let dist = max(age, epsilon)
            let w = decay / pow(dist, p)
            weightedSum += w * point.ratio
            weightSum += w
        }

        let r = weightedSum / weightSum
        return max(0.01, min(100.0, r))
    }

    public static func calibratedConcentration(
        sim: SimulationResult,
        labResults: [LabResult]
    ) -> [Double] {
        let points = buildCalibrationPoints(sim: sim, labResults: labResults)
        guard !points.isEmpty else { return sim.concPGmL }

        return zip(sim.timestamps, sim.concPGmL).map { (t, c) in
            c * calibrationRatio(at: t, points: points)
        }
    }
}
