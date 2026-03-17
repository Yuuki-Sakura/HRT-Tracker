import Foundation
import SwiftData
import HRTModels

@Model
public final class DoseTemplateRecord {
    public var templateID: UUID = UUID()
    public var name: String = ""
    public var routeRaw: String = ""
    public var esterRaw: String = ""
    public var doseMG: Double = 0
    public var extrasData: Data?
    public var createdAt: Date = Date()

    public init(templateID: UUID, name: String, routeRaw: String, esterRaw: String, doseMG: Double, extrasData: Data?, createdAt: Date) {
        self.templateID = templateID
        self.name = name
        self.routeRaw = routeRaw
        self.esterRaw = esterRaw
        self.doseMG = doseMG
        self.extrasData = extrasData
        self.createdAt = createdAt
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

        return DoseTemplate(
            id: templateID,
            name: name,
            route: route,
            ester: ester,
            doseMG: doseMG,
            extras: extras,
            createdAt: createdAt
        )
    }

    public static func from(_ template: DoseTemplate) -> DoseTemplateRecord {
        var extrasData: Data?
        if !template.extras.isEmpty {
            let stringDict = Dictionary(uniqueKeysWithValues: template.extras.map { ($0.key.rawValue, $0.value) })
            extrasData = try? JSONEncoder().encode(stringDict)
        }

        return DoseTemplateRecord(
            templateID: template.id,
            name: template.name,
            routeRaw: template.route.rawValue,
            esterRaw: template.ester.rawValue,
            doseMG: template.doseMG,
            extrasData: extrasData,
            createdAt: template.createdAt
        )
    }
}
