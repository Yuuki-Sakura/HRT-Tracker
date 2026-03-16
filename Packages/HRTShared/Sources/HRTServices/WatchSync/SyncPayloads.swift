import Foundation
import HRTModels

public struct DoseEventPayload: Codable, Sendable {
    public let id: String
    public let route: String
    public let timestamp: Int64
    public let doseMG: Double
    public let ester: String
    public let extras: [String: Double]

    public init(from event: DoseEvent) {
        self.id = event.id.uuidString
        self.route = event.route.rawValue
        self.timestamp = event.timestamp
        self.doseMG = event.doseMG
        self.ester = event.ester.rawValue
        self.extras = Dictionary(uniqueKeysWithValues: event.extras.map { ($0.key.rawValue, $0.value) })
    }

    public func toDoseEvent() -> DoseEvent? {
        guard let uuid = UUID(uuidString: id),
              let route = Route(rawValue: route),
              let ester = Ester(rawValue: ester) else { return nil }

        var extraKeys: [ExtraKey: Double] = [:]
        for (key, value) in extras {
            if let extraKey = ExtraKey(rawValue: key) {
                extraKeys[extraKey] = value
            }
        }

        return DoseEvent(id: uuid, route: route, timestamp: timestamp, doseMG: doseMG, ester: ester, extras: extraKeys)
    }
}

public struct ChartPointPayload: Codable, Sendable {
    public let timestamp: Int64
    public let concPGmL: Double

    public init(timestamp: Int64, concPGmL: Double) {
        self.timestamp = timestamp
        self.concPGmL = concPGmL
    }
}

public struct WatchSyncSnapshot: Codable, Sendable {
    public let events: [DoseEventPayload]
    public let chartPoints: [ChartPointPayload]
    public let bodyWeightKG: Double

    public init(events: [DoseEventPayload], chartPoints: [ChartPointPayload], bodyWeightKG: Double) {
        self.events = events
        self.chartPoints = chartPoints
        self.bodyWeightKG = bodyWeightKG
    }
}
