import Foundation

public struct DoseTemplate: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var name: String
    public var route: Route
    public var ester: Ester
    public var doseMG: Double
    public var extras: [ExtraKey: Double]
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        name: String,
        route: Route,
        ester: Ester,
        doseMG: Double,
        extras: [ExtraKey: Double] = [:],
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.route = route
        self.ester = ester
        self.doseMG = doseMG
        self.extras = extras
        self.createdAt = createdAt
    }
}
