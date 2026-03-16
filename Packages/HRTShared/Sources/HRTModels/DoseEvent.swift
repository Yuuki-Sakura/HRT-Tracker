import Foundation

public struct DoseEvent: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var route: Route
    public var timestamp: Int64
    public var doseMG: Double
    public var ester: Ester
    public var extras: [ExtraKey: Double]

    public var date: Date {
        Date(timeIntervalSince1970: TimeInterval(timestamp))
    }

    /// Hours since epoch — used internally by PK engine
    public var timeH: Double {
        Double(timestamp) / 3600.0
    }

    public init(
        id: UUID = UUID(),
        route: Route,
        timestamp: Int64,
        doseMG: Double,
        ester: Ester,
        extras: [ExtraKey: Double] = [:]
    ) {
        self.id = id
        self.route = route
        self.timestamp = timestamp
        self.doseMG = doseMG
        self.ester = ester
        self.extras = extras
    }

}
