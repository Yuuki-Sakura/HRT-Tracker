import Foundation

public enum ApplicationSite: Int, CaseIterable, Identifiable, Codable, Sendable {
    // Gel sites (0-99)
    case leftUpperArm = 0
    case rightUpperArm = 1
    case leftInnerThigh = 2
    case rightInnerThigh = 3
    case abdomen = 4
    case leftShoulder = 5
    case rightShoulder = 6
    case scrotum = 7
    case leftButtock = 8
    case rightButtock = 9

    // Injection sites (100+)
    case leftDorsogluteal = 100
    case rightDorsogluteal = 101
    case leftVentrogluteal = 102
    case rightVentrogluteal = 103
    case leftVastusLateralis = 104
    case rightVastusLateralis = 105
    case leftDeltoid = 106
    case rightDeltoid = 107

    public var id: Int { rawValue }

    public static var gelSites: [ApplicationSite] {
        allCases.filter { $0.rawValue < 100 }
    }

    public static var patchSites: [ApplicationSite] {
        [.leftInnerThigh, .rightInnerThigh, .leftButtock, .rightButtock, .abdomen, .scrotum]
    }

    public static var injectionSites: [ApplicationSite] {
        allCases.filter { $0.rawValue >= 100 }
    }

    public var isScrotal: Bool { self == .scrotum }

    public var localizedName: String {
        switch self {
        case .leftUpperArm:        return String(localized: "site.leftUpperArm")
        case .rightUpperArm:       return String(localized: "site.rightUpperArm")
        case .leftInnerThigh:      return String(localized: "site.leftInnerThigh")
        case .rightInnerThigh:     return String(localized: "site.rightInnerThigh")
        case .abdomen:             return String(localized: "site.abdomen")
        case .leftShoulder:        return String(localized: "site.leftShoulder")
        case .rightShoulder:       return String(localized: "site.rightShoulder")
        case .scrotum:             return String(localized: "site.scrotum")
        case .leftButtock:         return String(localized: "site.leftButtock")
        case .rightButtock:        return String(localized: "site.rightButtock")
        case .leftDorsogluteal:    return String(localized: "site.leftDorsogluteal")
        case .rightDorsogluteal:   return String(localized: "site.rightDorsogluteal")
        case .leftVentrogluteal:   return String(localized: "site.leftVentrogluteal")
        case .rightVentrogluteal:  return String(localized: "site.rightVentrogluteal")
        case .leftVastusLateralis: return String(localized: "site.leftVastusLateralis")
        case .rightVastusLateralis: return String(localized: "site.rightVastusLateralis")
        case .leftDeltoid:         return String(localized: "site.leftDeltoid")
        case .rightDeltoid:        return String(localized: "site.rightDeltoid")
        }
    }
}
