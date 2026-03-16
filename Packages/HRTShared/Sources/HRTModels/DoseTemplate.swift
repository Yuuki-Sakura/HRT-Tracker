import Foundation

public struct DoseTemplate: Identifiable, Codable, Equatable, Sendable {
    public var id: UUID
    public var name: String
    public var route: Route
    public var ester: Ester
    public var doseMG: Double
    public var extras: [ExtraKey: Double]
    public var createdAt: Date
    public var reminderIntervalHours: Double?   // nil = 不提醒
    public var reminderTimeOfDay: Date?         // nil = 使用默认 9:00

    public init(
        id: UUID = UUID(),
        name: String,
        route: Route,
        ester: Ester,
        doseMG: Double,
        extras: [ExtraKey: Double] = [:],
        createdAt: Date = Date(),
        reminderIntervalHours: Double? = nil,
        reminderTimeOfDay: Date? = nil
    ) {
        self.id = id
        self.name = name
        self.route = route
        self.ester = ester
        self.doseMG = doseMG
        self.extras = extras
        self.createdAt = createdAt
        self.reminderIntervalHours = reminderIntervalHours
        self.reminderTimeOfDay = reminderTimeOfDay
    }
}
