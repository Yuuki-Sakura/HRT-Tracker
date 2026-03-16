import Foundation
import HRTModels

/// Maps between app-internal `DoseEvent` and HealthKit `MedicationDoseEventInfo`.
public enum MedicationDoseEventMapper {

    // MARK: - MedicationDoseEventInfo → DoseEvent

    /// Convert a HealthKit dose event into an app DoseEvent.
    /// Requires route and ester context since HealthKit doesn't store those directly.
    public static func fromHealthKit(
        _ info: MedicationDoseEventInfo,
        route: Route,
        ester: Ester
    ) -> DoseEvent? {
        guard let doseMG = info.doseQuantity else { return nil }
        let timestamp = Int64(info.date.timeIntervalSince1970)
        return DoseEvent(
            id: UUID(uuidString: info.id) ?? UUID(),
            route: route,
            timestamp: timestamp,
            doseMG: doseMG,
            ester: ester
        )
    }
}
