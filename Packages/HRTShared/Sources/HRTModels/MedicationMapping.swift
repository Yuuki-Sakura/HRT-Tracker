import Foundation

/// Maps a HealthKit medication (by concept ID) to a specific route, ester, and per-dose strength.
public struct MedicationMapping: Identifiable, Codable, Equatable, Sendable {
    /// HealthKit medication concept identifier.
    public var id: String
    /// Display name from HealthKit (cached for offline display).
    public var displayName: String
    public var route: Route
    public var ester: Ester
    /// Milligrams per single dose (tablet/patch/application). HealthKit `doseQuantity` is multiplied by this.
    public var doseMG: Double
    /// Route-specific extra parameters (patch wear days, release rate, sublingual theta, application site, etc.)
    public var extras: [ExtraKey: Double]

    public init(id: String, displayName: String, route: Route, ester: Ester, doseMG: Double, extras: [ExtraKey: Double] = [:]) {
        self.id = id
        self.displayName = displayName
        self.route = route
        self.ester = ester
        self.doseMG = doseMG
        self.extras = extras
    }
}
