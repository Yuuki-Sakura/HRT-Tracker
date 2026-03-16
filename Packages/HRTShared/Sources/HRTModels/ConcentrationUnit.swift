import Foundation

public enum ConcentrationUnit: String, Codable, Sendable, CaseIterable, Identifiable {
    case pgPerML = "pg/mL"
    case pmolPerL = "pmol/L"

    public var id: Self { self }

    public static let conversionFactor: Double = 3.671 // pmol/L per pg/mL

    public func toPgPerML(_ value: Double) -> Double {
        switch self {
        case .pgPerML: return value
        case .pmolPerL: return value / Self.conversionFactor
        }
    }

    public func fromPgPerML(_ value: Double) -> Double {
        switch self {
        case .pgPerML: return value
        case .pmolPerL: return value * Self.conversionFactor
        }
    }
}
