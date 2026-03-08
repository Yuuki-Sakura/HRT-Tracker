import Foundation
import HealthKit

@MainActor
final class HealthKitService {
    static let shared = HealthKitService()

    private let store = HKHealthStore()

    private init() {}

    private var bodyMassReadTypes: Set<HKObjectType> {
        var types: Set<HKObjectType> = []

        if let bodyMassType = HKObjectType.quantityType(forIdentifier: .bodyMass) {
            types.insert(bodyMassType)
        }

        return types
    }

    private var bodyMassShareTypes: Set<HKSampleType> {
        var types: Set<HKSampleType> = []

        if let bodyMassType = HKObjectType.quantityType(forIdentifier: .bodyMass) {
            types.insert(bodyMassType)
        }

        return types
    }

    func requestAuthorizationIfNeeded() async throws {
        guard HKHealthStore.isHealthDataAvailable() else {
            throw NSError(
                domain: "HealthKitService",
                code: 1,
                userInfo: [NSLocalizedDescriptionKey: "HealthKit 不可用"]
            )
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            store.requestAuthorization(toShare: bodyMassShareTypes, read: bodyMassReadTypes) { success, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                if success {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: NSError(
                        domain: "HealthKitService",
                        code: 2,
                        userInfo: [NSLocalizedDescriptionKey: "HealthKit 授权失败"]
                    ))
                }
            }
        }
    }

    func fetchLatestBodyMassKG() async throws -> Double {
        guard let bodyMassType = HKObjectType.quantityType(forIdentifier: .bodyMass) else {
            throw NSError(
                domain: "HealthKitService",
                code: 3,
                userInfo: [NSLocalizedDescriptionKey: "无法读取体重类型"]
            )
        }

        return try await withCheckedThrowingContinuation { continuation in
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
            let query = HKSampleQuery(sampleType: bodyMassType, predicate: nil, limit: 1, sortDescriptors: [sort]) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let sample = samples?.first as? HKQuantitySample else {
                    continuation.resume(throwing: NSError(
                        domain: "HealthKitService",
                        code: 4,
                        userInfo: [NSLocalizedDescriptionKey: "HealthKit 中没有体重记录"]
                    ))
                    return
                }

                let valueKG = sample.quantity.doubleValue(for: HKUnit.gramUnit(with: .kilo))
                continuation.resume(returning: valueKG)
            }
            store.execute(query)
        }
    }

    func saveBodyMassKG(_ weightKG: Double, at date: Date = Date()) async throws {
        guard let bodyMassType = HKObjectType.quantityType(forIdentifier: .bodyMass) else {
            throw NSError(
                domain: "HealthKitService",
                code: 5,
                userInfo: [NSLocalizedDescriptionKey: "无法写入体重类型"]
            )
        }

        let quantity = HKQuantity(unit: HKUnit.gramUnit(with: .kilo), doubleValue: weightKG)
        let sample = HKQuantitySample(type: bodyMassType, quantity: quantity, start: date, end: date)

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            store.save(sample) { success, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                if success {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: NSError(
                        domain: "HealthKitService",
                        code: 6,
                        userInfo: [NSLocalizedDescriptionKey: "写入 HealthKit 体重失败"]
                    ))
                }
            }
        }
    }

}
