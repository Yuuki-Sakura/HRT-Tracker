import Foundation
import SwiftData
import HRTModels

@Model
public final class DoseEventRecord {
    public var eventID: UUID = UUID()
    public var routeRaw: String = ""
    public var timestamp: Int64 = 0
    public var doseMG: Double = 0
    public var esterRaw: String = ""
    public var extrasData: Data?

    public init(eventID: UUID, routeRaw: String, timestamp: Int64, doseMG: Double, esterRaw: String, extrasData: Data?) {
        self.eventID = eventID
        self.routeRaw = routeRaw
        self.timestamp = timestamp
        self.doseMG = doseMG
        self.esterRaw = esterRaw
        self.extrasData = extrasData
    }

    public func toDoseEvent() -> DoseEvent? {
        guard let route = Route(rawValue: routeRaw),
              let ester = Ester(rawValue: esterRaw) else { return nil }

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

        return DoseEvent(
            id: eventID,
            route: route,
            timestamp: timestamp,
            doseMG: doseMG,
            ester: ester,
            extras: extras
        )
    }

    public static func from(_ event: DoseEvent) -> DoseEventRecord {
        var extrasData: Data?
        if !event.extras.isEmpty {
            let stringDict = Dictionary(uniqueKeysWithValues: event.extras.map { ($0.key.rawValue, $0.value) })
            extrasData = try? JSONEncoder().encode(stringDict)
        }

        return DoseEventRecord(
            eventID: event.id,
            routeRaw: event.route.rawValue,
            timestamp: event.timestamp,
            doseMG: event.doseMG,
            esterRaw: event.ester.rawValue,
            extrasData: extrasData
        )
    }
}
