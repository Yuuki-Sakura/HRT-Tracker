import Foundation
import SwiftData
import HRTModels

@Model
public final class MedicationMappingRecord {
    public var medicationConceptID: String = ""
    public var displayName: String = ""
    public var routeRaw: String = ""
    public var esterRaw: String = ""
    public var doseMG: Double = 0
    public var extrasData: Data?

    public init(medicationConceptID: String, displayName: String, routeRaw: String, esterRaw: String, doseMG: Double, extrasData: Data? = nil) {
        self.medicationConceptID = medicationConceptID
        self.displayName = displayName
        self.routeRaw = routeRaw
        self.esterRaw = esterRaw
        self.doseMG = doseMG
        self.extrasData = extrasData
    }

    public func toMedicationMapping() -> MedicationMapping? {
        guard let route = Route(rawValue: routeRaw),
              let ester = Ester(rawValue: esterRaw) else { return nil }
        // Treat doseMG == 0 as invalid (legacy mapping) — user must reconfigure
        guard doseMG > 0 else { return nil }

        var extras: [ExtraKey: Double] = [:]
        if let data = extrasData {
            if let dict = try? JSONDecoder().decode([String: Double].self, from: data) {
                for (key, value) in dict {
                    if let extraKey = ExtraKey(rawValue: key) {
                        extras[extraKey] = value
                    }
                }
            }
        }

        return MedicationMapping(
            id: medicationConceptID,
            displayName: displayName,
            route: route,
            ester: ester,
            doseMG: doseMG,
            extras: extras
        )
    }

    public static func from(_ mapping: MedicationMapping) -> MedicationMappingRecord {
        var extrasData: Data?
        if !mapping.extras.isEmpty {
            let stringDict = Dictionary(uniqueKeysWithValues: mapping.extras.map { ($0.key.rawValue, $0.value) })
            extrasData = try? JSONEncoder().encode(stringDict)
        }

        return MedicationMappingRecord(
            medicationConceptID: mapping.id,
            displayName: mapping.displayName,
            routeRaw: mapping.route.rawValue,
            esterRaw: mapping.ester.rawValue,
            doseMG: mapping.doseMG,
            extrasData: extrasData
        )
    }
}
