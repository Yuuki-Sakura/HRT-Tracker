import Foundation

public struct EsterInfo: Sendable {
    public let ester: Ester
    public let fullName: String
    public let molecularWeight: Double

    public static let e2MolecularWeight: Double = 272.38

    public var toE2Factor: Double {
        guard ester != .E2, ester != .CPA else { return 1.0 }
        return EsterInfo.e2MolecularWeight / molecularWeight
    }

    private static let all: [Ester: EsterInfo] = [
        .E2: EsterInfo(ester: .E2, fullName: "Estradiol", molecularWeight: 272.38),
        .EB: EsterInfo(ester: .EB, fullName: "Estradiol Benzoate", molecularWeight: 376.50),
        .EV: EsterInfo(ester: .EV, fullName: "Estradiol Valerate", molecularWeight: 356.50),
        .EC: EsterInfo(ester: .EC, fullName: "Estradiol Cypionate", molecularWeight: 396.58),
        .EN: EsterInfo(ester: .EN, fullName: "Estradiol Enanthate", molecularWeight: 384.56),
        .CPA: EsterInfo(ester: .CPA, fullName: "Cyproterone Acetate", molecularWeight: 416.94),
    ]

    public static func by(ester: Ester) -> EsterInfo {
        all[ester]!
    }
}
