import Foundation

public struct SimulationResult: Equatable, Sendable {
    public let timestamps: [Int64]
    public let concPGmL: [Double]
    public let concNGmL_CPA: [Double]
    public let auc: Double
    public let aucCPA: Double

    public init(timestamps: [Int64], concPGmL: [Double], auc: Double) {
        self.timestamps = timestamps
        self.concPGmL = concPGmL
        self.concNGmL_CPA = []
        self.auc = auc
        self.aucCPA = 0
    }

    public init(timestamps: [Int64], concPGmL: [Double], concNGmL_CPA: [Double], auc: Double, aucCPA: Double) {
        self.timestamps = timestamps
        self.concPGmL = concPGmL
        self.concNGmL_CPA = concNGmL_CPA
        self.auc = auc
        self.aucCPA = aucCPA
    }

    public var hasCPA: Bool { !concNGmL_CPA.isEmpty }

    public func concentration(at ts: Int64) -> Double? {
        _interpolate(data: concPGmL, at: ts)
    }

    public func concentrationCPA(at ts: Int64) -> Double? {
        guard hasCPA else { return nil }
        return _interpolate(data: concNGmL_CPA, at: ts)
    }

    private func _interpolate(data: [Double], at ts: Int64) -> Double? {
        guard !timestamps.isEmpty, timestamps.count == data.count else { return nil }
        if ts <= timestamps[0] { return data[0] }
        if ts >= timestamps[timestamps.count - 1] { return data[timestamps.count - 1] }

        var low = 0
        var high = timestamps.count - 1
        while high - low > 1 {
            let mid = (low + high) / 2
            if timestamps[mid] == ts {
                return data[mid]
            } else if timestamps[mid] < ts {
                low = mid
            } else {
                high = mid
            }
        }

        let t0 = Double(timestamps[low])
        let t1 = Double(timestamps[high])
        let c0 = data[low]
        let c1 = data[high]
        guard t1 > t0 else { return c0 }
        let ratio = (Double(ts) - t0) / (t1 - t0)
        return c0 + (c1 - c0) * ratio
    }
}
