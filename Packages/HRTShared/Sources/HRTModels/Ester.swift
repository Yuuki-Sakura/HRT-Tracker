import Foundation

public enum Ester: String, CaseIterable, Identifiable, Codable, Sendable {
    case E2, EB, EV, EC, EN, CPA

    public var id: Self { self }

    public var fullName: String { EsterInfo.by(ester: self).fullName }

    public var localizedName: String {
        switch self {
        case .E2:  return String(localized: "ester.E2")
        case .EB:  return String(localized: "ester.EB")
        case .EV:  return String(localized: "ester.EV")
        case .EC:  return String(localized: "ester.EC")
        case .EN:  return String(localized: "ester.EN")
        case .CPA: return String(localized: "ester.CPA")
        }
    }

    public var isEstrogen: Bool {
        switch self {
        case .E2, .EB, .EV, .EC, .EN: return true
        case .CPA: return false
        }
    }
}
