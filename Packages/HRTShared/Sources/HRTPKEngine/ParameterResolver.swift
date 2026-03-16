import Foundation
import HRTModels

public struct ParameterResolver: Sendable {
    public static func resolve(event: DoseEvent, bodyWeightKG: Double) -> PKParams {
        let k3 = (event.route == .injection) ? CorePK.kClearInjection : CorePK.kClear

        switch event.route {
        case .injection:
            let k1corr = CorePK.depotK1Corr
            let k1_fast = (TwoPartDepotPK.k1_fast[event.ester] ?? 0) * k1corr
            let k1_slow = (TwoPartDepotPK.k1_slow[event.ester] ?? 0) * k1corr
            let fracFast = TwoPartDepotPK.Frac_fast[event.ester] ?? 1.0

            let form = InjectionPK.formationFraction[event.ester] ?? 0.08
            let toE2 = EsterInfo.by(ester: event.ester).toE2Factor
            let F = form * toE2

            return PKParams(
                Frac_fast: fracFast,
                k1_fast: k1_fast,
                k1_slow: k1_slow,
                k2: EsterPK.k2[event.ester] ?? 0,
                k3: k3,
                F: F,
                rateMGh: 0,
                F_fast: F,
                F_slow: F
            )

        case .patchApply:
            let isScrotal: Bool = {
                guard let code = event.extras[.applicationSite] else { return false }
                return ApplicationSite(rawValue: Int(code))?.isScrotal ?? false
            }()
            let scrotalF = isScrotal ? PatchPK.scrotalMultiplier : 1.0

            if let rUG = event.extras[.releaseRateUGPerDay] {
                let rateMGh = rUG / 24_000.0
                return PKParams(Frac_fast: 1.0, k1_fast: 0, k1_slow: 0,
                                k2: PatchPK.kSkin, k3: k3,
                                F: scrotalF, rateMGh: rateMGh,
                                F_fast: scrotalF, F_slow: scrotalF)
            } else {
                let k1: Double = {
                    if case let .firstOrder(k1Val) = PatchPK.generic { return k1Val }
                    return 0
                }()
                return PKParams(Frac_fast: 1.0, k1_fast: k1, k1_slow: 0,
                                k2: PatchPK.kSkin, k3: k3,
                                F: scrotalF, rateMGh: 0,
                                F_fast: scrotalF, F_slow: scrotalF)
            }

        case .gel:
            let area = event.extras[.areaCM2] ?? 750
            let isScrotal: Bool = {
                guard let code = event.extras[.applicationSite] else { return false }
                return ApplicationSite(rawValue: Int(code))?.isScrotal ?? false
            }()
            let tuple = TransdermalGelPK.parameters(doseMG: event.doseMG, areaCM2: area, isScrotal: isScrotal)
            return PKParams(Frac_fast: 1.0, k1_fast: tuple.k1, k1_slow: 0,
                            k2: 0, k3: k3,
                            F: tuple.F, rateMGh: 0,
                            F_fast: tuple.F, F_slow: tuple.F)

        case .oral:
            if event.ester == .CPA {
                return PKParams(Frac_fast: 1.0, k1_fast: CPAPK.ka, k1_slow: 0,
                                k2: 0, k3: CPAPK.kel, F: CPAPK.bioavailability,
                                rateMGh: 0, F_fast: CPAPK.bioavailability, F_slow: CPAPK.bioavailability)
            }
            let k1Value = (event.ester == .EV) ? OralPK.kAbsEV : OralPK.kAbsE2
            let k2Value = (event.ester == .EV) ? (EsterPK.k2[.EV] ?? 0) : 0.0
            return PKParams(Frac_fast: 1.0, k1_fast: k1Value, k1_slow: 0,
                            k2: k2Value, k3: k3,
                            F: OralPK.bioavailability, rateMGh: 0,
                            F_fast: OralPK.bioavailability, F_slow: OralPK.bioavailability)

        case .patchRemove:
            return PKParams(Frac_fast: 0, k1_fast: 0, k1_slow: 0,
                            k2: 0, k3: k3,
                            F: 0, rateMGh: 0,
                            F_fast: 0, F_slow: 0)

        case .sublingual:
            let theta: Double = {
                if let th = event.extras[.sublingualTheta] {
                    return max(0.0, min(1.0, th))
                }
                return SublingualPK.theta
            }()
            let k1_fast = OralPK.kAbsSL
            let k1_slow = (event.ester == .EV) ? OralPK.kAbsEV : OralPK.kAbsE2
            let F_fast = 1.0
            let F_slow = OralPK.bioavailability
            let k2Value = (event.ester == .EV) ? (EsterPK.k2[.EV] ?? 0) : 0.0

            return PKParams(
                Frac_fast: max(0.0, min(1.0, theta)),
                k1_fast: k1_fast,
                k1_slow: k1_slow,
                k2: k2Value,
                k3: k3,
                F: 1.0,
                rateMGh: 0,
                F_fast: F_fast,
                F_slow: F_slow
            )
        }
    }
}
