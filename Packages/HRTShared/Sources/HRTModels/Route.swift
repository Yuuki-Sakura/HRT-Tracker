import Foundation

public enum Route: String, CaseIterable, Identifiable, Codable, Sendable {
    case injection
    case patchApply
    case patchRemove
    case gel
    case oral
    case sublingual

    public var id: Self { self }

    /// Esters available for this route.
    public var availableEsters: [Ester] {
        switch self {
        case .injection: return [.EB, .EV, .EC, .EN]
        case .patchApply, .patchRemove, .gel: return [.E2]
        case .oral: return [.E2, .EV, .CPA]
        case .sublingual: return [.E2, .EV]
        }
    }

    public var localizedName: String {
        switch self {
        case .injection:  return String(localized: "route.injection")
        case .patchApply: return String(localized: "route.patchApply")
        case .patchRemove: return String(localized: "route.patchRemove")
        case .gel:        return String(localized: "route.gel")
        case .oral:       return String(localized: "route.oral")
        case .sublingual: return String(localized: "route.sublingual")
        }
    }
}
