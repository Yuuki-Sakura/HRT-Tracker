import Foundation
import SwiftData
import HRTModels

@Model
public final class DoseTemplateRecord {
    @Attribute(.unique) public var templateID: UUID
    public var name: String
    public var routeRaw: String
    public var esterRaw: String
    public var doseMG: Double
    public var extrasData: Data?
    public var createdAt: Date
    public var reminderIntervalHours: Double?
    public var reminderTimeMinutesSinceMidnight: Int?

    public init(templateID: UUID, name: String, routeRaw: String, esterRaw: String, doseMG: Double, extrasData: Data?, createdAt: Date, reminderIntervalHours: Double? = nil, reminderTimeMinutesSinceMidnight: Int? = nil) {
        self.templateID = templateID
        self.name = name
        self.routeRaw = routeRaw
        self.esterRaw = esterRaw
        self.doseMG = doseMG
        self.extrasData = extrasData
        self.createdAt = createdAt
        self.reminderIntervalHours = reminderIntervalHours
        self.reminderTimeMinutesSinceMidnight = reminderTimeMinutesSinceMidnight
    }

    public func toDoseTemplate() -> DoseTemplate? {
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

        var reminderTimeOfDay: Date?
        if let minutes = reminderTimeMinutesSinceMidnight {
            var components = Calendar.current.dateComponents([.year, .month, .day], from: Date())
            components.hour = minutes / 60
            components.minute = minutes % 60
            reminderTimeOfDay = Calendar.current.date(from: components)
        }

        return DoseTemplate(
            id: templateID,
            name: name,
            route: route,
            ester: ester,
            doseMG: doseMG,
            extras: extras,
            createdAt: createdAt,
            reminderIntervalHours: reminderIntervalHours,
            reminderTimeOfDay: reminderTimeOfDay
        )
    }

    public static func from(_ template: DoseTemplate) -> DoseTemplateRecord {
        var extrasData: Data?
        if !template.extras.isEmpty {
            let stringDict = Dictionary(uniqueKeysWithValues: template.extras.map { ($0.key.rawValue, $0.value) })
            extrasData = try? JSONEncoder().encode(stringDict)
        }

        var reminderTimeMinutes: Int?
        if let timeOfDay = template.reminderTimeOfDay {
            let components = Calendar.current.dateComponents([.hour, .minute], from: timeOfDay)
            reminderTimeMinutes = (components.hour ?? 0) * 60 + (components.minute ?? 0)
        }

        return DoseTemplateRecord(
            templateID: template.id,
            name: template.name,
            routeRaw: template.route.rawValue,
            esterRaw: template.ester.rawValue,
            doseMG: template.doseMG,
            extrasData: extrasData,
            createdAt: template.createdAt,
            reminderIntervalHours: template.reminderIntervalHours,
            reminderTimeMinutesSinceMidnight: reminderTimeMinutes
        )
    }
}
