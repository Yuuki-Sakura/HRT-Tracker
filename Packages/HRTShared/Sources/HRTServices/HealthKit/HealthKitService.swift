import Foundation

#if canImport(HealthKit) && !os(macOS) && !OPENSOURCE
import HealthKit

public final class HealthKitService: HealthKitServiceProtocol, @unchecked Sendable {
    public static let shared = HealthKitService()

    private let store = HKHealthStore()
    private var bodyMassObserverQuery: HKObserverQuery?
    private var medicationObserverQuery: HKObserverQuery?

    private init() {}

    // MARK: - Body Mass Authorization & Queries

    public func requestAuthorizationIfNeeded() async throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw HealthKitError.notAvailable
        }

        let bodyMass = HKQuantityType(.bodyMass)
        let typesToRead: Set<HKSampleType> = [bodyMass]
        let typesToWrite: Set<HKSampleType> = [bodyMass]

        try await store.requestAuthorization(toShare: typesToWrite, read: typesToRead)
    }

    public func fetchLatestBodyMassKG() async throws -> Double {
        let bodyMass = HKQuantityType(.bodyMass)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(sampleType: bodyMass, predicate: nil, limit: 1, sortDescriptors: [sortDescriptor]) { _, samples, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let sample = samples?.first as? HKQuantitySample else {
                    continuation.resume(throwing: HealthKitError.noData)
                    return
                }
                let kg = sample.quantity.doubleValue(for: .gramUnit(with: .kilo))
                continuation.resume(returning: kg)
            }
            self.store.execute(query)
        }
    }

    public func saveBodyMassKG(_ kg: Double) async throws {
        let bodyMass = HKQuantityType(.bodyMass)
        let quantity = HKQuantity(unit: .gramUnit(with: .kilo), doubleValue: kg)
        let sample = HKQuantitySample(type: bodyMass, quantity: quantity, start: Date(), end: Date())

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            store.save(sample) { _, error in
                if let error = error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume()
                }
            }
        }
    }

    // MARK: - Medications (iOS 26+)

    public func requestMedicationAuthorization() async throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw HealthKitError.notAvailable
        }

        if #available(iOS 26.0, watchOS 26.0, *) {
            let medicationType = HKObjectType.userAnnotatedMedicationType()
            try await store.requestPerObjectReadAuthorization(for: medicationType, predicate: nil)
        } else {
            throw HealthKitError.notAvailable
        }
    }

    public func fetchMedications() async throws -> [MedicationInfo] {
        if #available(iOS 26.0, watchOS 26.0, *) {
            let predicate = NSPredicate(
                format: "%K == NO",
                HKUserAnnotatedMedicationPredicateKeyPathIsArchived
            )
            let descriptor = HKUserAnnotatedMedicationQueryDescriptor(predicate: predicate)
            let medications = try await descriptor.result(for: store)
            return medications.map { med in
                MedicationInfo(
                    id: med.medication.identifier.description,
                    displayName: med.nickname ?? med.medication.displayText
                )
            }
        } else {
            throw HealthKitError.notAvailable
        }
    }

    public func fetchDoseEvents(for medicationConceptID: String, since: Date) async throws -> [MedicationDoseEventInfo] {
        if #available(iOS 26.0, watchOS 26.0, *) {
            let doseEventType = HKSampleType.medicationDoseEventType()
            let datePredicate = HKQuery.predicateForSamples(withStart: since, end: Date(), options: .strictStartDate)
            let medPredicate = NSPredicate(
                format: "%K == %@",
                HKPredicateKeyPathMedicationConceptIdentifier,
                medicationConceptID
            )
            let compoundPredicate = NSCompoundPredicate(andPredicateWithSubpredicates: [datePredicate, medPredicate])

            return try await withCheckedThrowingContinuation { continuation in
                let query = HKSampleQuery(
                    sampleType: doseEventType,
                    predicate: compoundPredicate,
                    limit: HKObjectQueryNoLimit,
                    sortDescriptors: [NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)]
                ) { _, samples, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                        return
                    }
                    let events = (samples as? [HKMedicationDoseEvent]) ?? []
                    let infos = events.map { event in
                        return MedicationDoseEventInfo(
                            id: event.uuid.uuidString,
                            medicationConceptID: medicationConceptID,
                            date: event.startDate,
                            doseQuantity: event.doseQuantity,
                            logStatus: event.logStatus.rawValue
                        )
                    }
                    continuation.resume(returning: infos)
                }
                self.store.execute(query)
            }
        } else {
            throw HealthKitError.notAvailable
        }
    }

    // MARK: - Observer Queries

    public func observeBodyMassChanges(handler: @escaping @Sendable () -> Void) {
        if let existing = bodyMassObserverQuery {
            store.stop(existing)
        }
        let bodyMass = HKQuantityType(.bodyMass)
        let query = HKObserverQuery(sampleType: bodyMass, predicate: nil) { _, completionHandler, error in
            if error == nil {
                handler()
            }
            completionHandler()
        }
        bodyMassObserverQuery = query
        store.execute(query)
    }

    public func observeMedicationDoseEvents(handler: @escaping @Sendable () -> Void) {
        if let existing = medicationObserverQuery {
            store.stop(existing)
        }
        if #available(iOS 26.0, watchOS 26.0, *) {
            let doseEventType = HKSampleType.medicationDoseEventType()
            let query = HKObserverQuery(sampleType: doseEventType, predicate: nil) { _, completionHandler, error in
                if error == nil {
                    handler()
                }
                completionHandler()
            }
            medicationObserverQuery = query
            store.execute(query)
        }
    }
}

public enum HealthKitError: Error, LocalizedError {
    case notAvailable
    case noData

    public var errorDescription: String? {
        switch self {
        case .notAvailable: return "HealthKit is not available on this device"
        case .noData: return "No data found in HealthKit"
        }
    }
}
#else
public final class HealthKitService: HealthKitServiceProtocol, @unchecked Sendable {
    public static let shared = HealthKitService()
    private init() {}

    public func requestAuthorizationIfNeeded() async throws {
        throw HealthKitError.notAvailable
    }

    public func fetchLatestBodyMassKG() async throws -> Double {
        throw HealthKitError.notAvailable
    }

    public func saveBodyMassKG(_ kg: Double) async throws {
        throw HealthKitError.notAvailable
    }

    public func requestMedicationAuthorization() async throws {
        throw HealthKitError.notAvailable
    }

    public func fetchMedications() async throws -> [MedicationInfo] {
        throw HealthKitError.notAvailable
    }

    public func fetchDoseEvents(for medicationConceptID: String, since: Date) async throws -> [MedicationDoseEventInfo] {
        throw HealthKitError.notAvailable
    }

    public func observeBodyMassChanges(handler: @escaping @Sendable () -> Void) {}

    public func observeMedicationDoseEvents(handler: @escaping @Sendable () -> Void) {}
}

public enum HealthKitError: Error, LocalizedError {
    case notAvailable
    case noData

    public var errorDescription: String? {
        switch self {
        case .notAvailable: return "HealthKit is not available on this platform"
        case .noData: return "No data found"
        }
    }
}
#endif
