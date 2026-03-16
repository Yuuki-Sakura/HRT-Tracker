import Foundation

public struct LabResult: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var timestamp: Int64
    public var concValue: Double
    public var unit: ConcentrationUnit

    public var date: Date {
        Date(timeIntervalSince1970: TimeInterval(timestamp))
    }

    /// Hours since epoch — used internally by PK engine
    public var timeH: Double {
        Double(timestamp) / 3600.0
    }

    public var concInPgPerML: Double {
        unit.toPgPerML(concValue)
    }

    public init(
        id: UUID = UUID(),
        timestamp: Int64,
        concValue: Double,
        unit: ConcentrationUnit
    ) {
        self.id = id
        self.timestamp = timestamp
        self.concValue = concValue
        self.unit = unit
    }
}
