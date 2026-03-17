import Foundation
import HRTModels

#if canImport(HealthKit) && !OPENSOURCE
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

        try await store.requestAuthorization(toShare: [], read: typesToRead)
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
            let descriptor = HKUserAnnotatedMedicationQueryDescriptor()
            let medications = try await descriptor.result(for: store)
            return medications
                .filter { !$0.isArchived }
                .map { med in
                    let name = med.nickname ?? ""
                    return MedicationInfo(
                        id: String(med.medication.identifier.hashValue),
                        displayName: name.isEmpty ? med.medication.displayText : name,
                        route: Self.route(from: med.medication.generalForm)
                    )
                }
        } else {
            throw HealthKitError.notAvailable
        }
    }

    @available(iOS 26.0, watchOS 26.0, *)
    private static func route(from form: HKMedicationGeneralForm) -> Route? {
        switch form {
        case .tablet, .capsule:                                return .oral
        case .injection:                                       return .injection
        case .gel:                                             return .gel
        case .patch:                                           return .patchApply
        case .cream, .ointment, .lotion, .topical:             return .gel
        default:                                               return nil
        }
    }

    public func fetchDoseEventsForMedications(ids: Set<String>, since: Date) async throws -> [MedicationDoseEventInfo] {
        if #available(iOS 26.0, watchOS 26.0, *) {
            let descriptor = HKUserAnnotatedMedicationQueryDescriptor()
            let medications = try await descriptor.result(for: store)
            let matched = medications.filter { ids.contains(String($0.medication.identifier.hashValue)) }

            var allEvents: [MedicationDoseEventInfo] = []
            for med in matched {
                let medPredicate = HKQuery.predicateForMedicationDoseEvent(
                    medicationConceptIdentifier: med.medication.identifier
                )
                let datePredicate = HKQuery.predicateForSamples(withStart: since, end: Date(), options: .strictStartDate)
                let predicate = NSCompoundPredicate(type: .and, subpredicates: [medPredicate, datePredicate])
                let samplePredicate = HKSamplePredicate.sample(type: .medicationDoseEventType(), predicate: predicate)
                let queryDescriptor = HKSampleQueryDescriptor(
                    predicates: [samplePredicate],
                    sortDescriptors: [SortDescriptor(\HKSample.startDate, order: .reverse)]
                )
                let results = try await queryDescriptor.result(for: store)
                let events = results.compactMap { $0 as? HKMedicationDoseEvent }
                let conceptID = String(med.medication.identifier.hashValue)
                allEvents += events.map { event in
                    MedicationDoseEventInfo(
                        id: event.uuid.uuidString,
                        medicationConceptID: conceptID,
                        date: event.startDate,
                        doseQuantity: event.doseQuantity,
                        logStatus: event.logStatus.rawValue
                    )
                }
            }
            return allEvents
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

    public func fetchDoseEventsForMedications(ids: Set<String>, since: Date) async throws -> [MedicationDoseEventInfo] {
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
