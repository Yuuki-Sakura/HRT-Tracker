import Foundation
import HRTModels

/// Maps between app-internal `DoseEvent` and HealthKit `MedicationDoseEventInfo`.
public enum MedicationDoseEventMapper {

    // MARK: - MedicationDoseEventInfo → DoseEvent

    /// Convert a HealthKit dose event into an app DoseEvent.
    /// `doseMG` is the per-dose strength from the mapping; it is multiplied by `doseQuantity` (tablet count).
    /// `extras` are route-specific parameters from the mapping (patch wear days, release rate, etc.).
    public static func fromHealthKit(
        _ info: MedicationDoseEventInfo,
        route: Route,
        ester: Ester,
        doseMG: Double,
        extras: [ExtraKey: Double] = [:]
    ) -> DoseEvent? {
        guard let quantity = info.doseQuantity, quantity > 0 else { return nil }
        let totalMG = quantity * doseMG
        let timestamp = Int64(info.date.timeIntervalSince1970)
        return DoseEvent(
            id: UUID(uuidString: info.id) ?? UUID(),
            route: route,
            timestamp: timestamp,
            doseMG: totalMG,
            ester: ester,
            extras: extras
        )
    }
}
