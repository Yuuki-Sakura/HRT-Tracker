import Foundation
import SwiftData
import HRTModels

@Model
public final class LabResultRecord {
    public var resultID: UUID = UUID()
    public var timestamp: Int64 = 0
    public var concValue: Double = 0
    public var unitRaw: String = ""

    public init(resultID: UUID, timestamp: Int64, concValue: Double, unitRaw: String) {
        self.resultID = resultID
        self.timestamp = timestamp
        self.concValue = concValue
        self.unitRaw = unitRaw
    }

    public func toLabResult() -> LabResult? {
        guard let unit = ConcentrationUnit(rawValue: unitRaw) else { return nil }
        return LabResult(id: resultID, timestamp: timestamp, concValue: concValue, unit: unit)
    }

    public static func from(_ result: LabResult) -> LabResultRecord {
        LabResultRecord(
            resultID: result.id,
            timestamp: result.timestamp,
            concValue: result.concValue,
            unitRaw: result.unit.rawValue
        )
    }
}
