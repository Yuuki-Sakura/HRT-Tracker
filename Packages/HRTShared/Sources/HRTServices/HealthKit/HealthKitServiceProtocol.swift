import Foundation

public protocol HealthKitServiceProtocol: Sendable {
    // MARK: - Body Mass
    func requestAuthorizationIfNeeded() async throws
    func fetchLatestBodyMassKG() async throws -> Double
    func saveBodyMassKG(_ kg: Double) async throws

    // MARK: - Medications (iOS 26+)
    func requestMedicationAuthorization() async throws
    func fetchMedications() async throws -> [MedicationInfo]
    func fetchDoseEvents(for medicationConceptID: String, since: Date) async throws -> [MedicationDoseEventInfo]

    // MARK: - Observer Queries
    func observeBodyMassChanges(handler: @escaping @Sendable () -> Void)
    func observeMedicationDoseEvents(handler: @escaping @Sendable () -> Void)
}

/// Platform-agnostic representation of a medication from HealthKit
public struct MedicationInfo: Identifiable, Sendable {
    public var id: String
    public var displayName: String

    public init(id: String, displayName: String) {
        self.id = id
        self.displayName = displayName
    }
}

/// Platform-agnostic representation of a medication dose event from HealthKit
public struct MedicationDoseEventInfo: Identifiable, Sendable {
    public var id: String
    public var medicationConceptID: String
    public var date: Date
    public var doseQuantity: Double?
    public var logStatus: Int

    public init(id: String, medicationConceptID: String, date: Date, doseQuantity: Double?, logStatus: Int = 0) {
        self.id = id
        self.medicationConceptID = medicationConceptID
        self.date = date
        self.doseQuantity = doseQuantity
        self.logStatus = logStatus
    }
}
