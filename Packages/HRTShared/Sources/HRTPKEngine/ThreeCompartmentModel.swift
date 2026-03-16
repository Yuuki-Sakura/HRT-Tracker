import Foundation

public struct ThreeCompartmentModel: Sendable {

    public static func dualAbs3CAmount(tau: Double, doseMG: Double, p: PKParams) -> Double {
        guard doseMG > 0 else { return 0 }
        let f = max(0.0, min(1.0, p.Frac_fast))
        let doseF = doseMG * f
        let doseS = doseMG * (1.0 - f)
        let amtF = _analytic3C(tau: tau, doseMG: doseF, F: p.F_fast, k1: p.k1_fast, k2: p.k2, k3: p.k3)
        let amtS = _analytic3C(tau: tau, doseMG: doseS, F: p.F_slow, k1: p.k1_slow, k2: p.k2, k3: p.k3)
        return amtF + amtS
    }

    public static func dualAbsMixedAmount(tau: Double, doseMG: Double, p: PKParams) -> Double {
        guard doseMG > 0 else { return 0 }
        let f = max(0.0, min(1.0, p.Frac_fast))
        let doseF = doseMG * f
        let doseS = doseMG * (1.0 - f)
        let amtF = _analytic3C(tau: tau, doseMG: doseF, F: p.F_fast, k1: p.k1_fast, k2: p.k2, k3: p.k3)
        let amtS = _batemanAmount(doseMG: doseS, F: p.F_slow, ka: p.k1_slow, ke: p.k3, t: tau)
        return amtF + amtS
    }

    public static func dualAbsAmount(tau: Double, doseMG: Double, p: PKParams) -> Double {
        guard doseMG > 0 else { return 0 }
        let f = max(0.0, min(1.0, p.Frac_fast))
        let doseF = doseMG * f
        let doseS = doseMG * (1.0 - f)
        let amtF = _batemanAmount(doseMG: doseF, F: p.F_fast, ka: p.k1_fast, ke: p.k3, t: tau)
        let amtS = _batemanAmount(doseMG: doseS, F: p.F_slow, ka: p.k1_slow, ke: p.k3, t: tau)
        return amtF + amtS
    }

    public static func injAmount(tau: Double, doseMG: Double, p: PKParams) -> Double {
        let dose_fast = doseMG * p.Frac_fast
        let dose_slow = doseMG * (1.0 - p.Frac_fast)
        let amount_from_fast = _analytic3C(tau: tau, doseMG: dose_fast, F: p.F, k1: p.k1_fast, k2: p.k2, k3: p.k3)
        let amount_from_slow = _analytic3C(tau: tau, doseMG: dose_slow, F: p.F, k1: p.k1_slow, k2: p.k2, k3: p.k3)
        return amount_from_fast + amount_from_slow
    }

    public static func oneCompAmount(tau: Double, doseMG: Double, p: PKParams) -> Double {
        _batemanAmount(doseMG: doseMG, F: p.F, ka: p.k1_fast, ke: p.k3, t: tau)
    }

    /// Transdermal patch plasma amount with skin-depot intermediate compartment.
    ///
    /// Model: Patch → Skin Depot (k_skin = p.k2) → Plasma (k_el = p.k3) → Elimination
    ///
    /// The stratum corneum acts as a rate-limiting reservoir (Vivelle-Dot FDA Label 2014,
    /// NDA 020538). Adding this compartment yields:
    /// - Time to 90% steady-state ≈ 23 h (literature Tmax 12–36 h)
    /// - Post-removal apparent t½ ≈ 6.9 h (literature 5.9–7.7 h)
    ///
    /// Falls back to the legacy single-compartment model when p.k2 == 0.
    public static func patchAmount(tau: Double, doseMG: Double, wearH: Double, p: PKParams) -> Double {
        if p.rateMGh > 0 {
            return _patchZeroOrder(tau: tau, wearH: wearH, p: p)
        } else {
            return _patchFirstOrder(tau: tau, doseMG: doseMG, wearH: wearH, p: p)
        }
    }

    // MARK: - Patch skin-depot helpers

    /// Zero-order patch: constant release rate R (mg/h) into skin depot.
    ///
    /// During wear (tau ≤ wearH):
    ///   S(t) = R/kS * (1 - e^(-kS*t))
    ///   P(t) = R/kE * [1 - kE/(kE-kS)*e^(-kS*t) + kS/(kE-kS)*e^(-kE*t)]
    ///
    /// After removal (dt = tau - wearH):
    ///   Skin depot continues to drain; plasma receives from residual skin amount.
    ///   P(dt) = S_rem * kS/(kE-kS) * (e^(-kS*dt) - e^(-kE*dt)) + P_rem * e^(-kE*dt)
    private static func _patchZeroOrder(tau: Double, wearH: Double, p: PKParams) -> Double {
        let R = p.rateMGh * p.F
        let kS = p.k2       // k_skin
        let kE = p.k3       // k_el

        // Fallback: no skin depot → legacy single-compartment
        guard kS > 1e-12 else {
            if tau <= wearH {
                return R / kE * (1 - exp(-kE * tau))
            } else {
                let amtAtRemoval = R / kE * (1 - exp(-kE * wearH))
                return amtAtRemoval * exp(-kE * (tau - wearH))
            }
        }

        let diff = kE - kS
        // Degenerate case: kS ≈ kE
        if abs(diff) < 1e-9 {
            let kS2 = kS + 1e-6
            let p2 = PKParams(Frac_fast: p.Frac_fast, k1_fast: p.k1_fast, k1_slow: p.k1_slow,
                              k2: kS2, k3: kE, F: p.F, rateMGh: p.rateMGh,
                              F_fast: p.F_fast, F_slow: p.F_slow)
            return _patchZeroOrder(tau: tau, wearH: wearH, p: p2)
        }

        if tau <= wearH {
            return R / kE * (1.0 - kE / diff * exp(-kS * tau) + kS / diff * exp(-kE * tau))
        } else {
            let sRem = R / kS * (1.0 - exp(-kS * wearH))
            let pRem = R / kE * (1.0 - kE / diff * exp(-kS * wearH) + kS / diff * exp(-kE * wearH))
            let dt = tau - wearH
            return sRem * kS / diff * (exp(-kS * dt) - exp(-kE * dt)) + pRem * exp(-kE * dt)
        }
    }

    /// First-order patch: exponential release from patch matrix into skin depot.
    ///
    /// During wear: uses the existing three-compartment analytic solution
    ///   _analytic3C(k1=k_release, k2=k_skin, k3=k_el)
    ///
    /// After removal: computes residual skin-depot and plasma amounts,
    /// then solves the two-compartment drain (same as zero-order post-removal).
    private static func _patchFirstOrder(tau: Double, doseMG: Double, wearH: Double, p: PKParams) -> Double {
        let kRel = p.k1_fast  // k_release (patch to skin)
        let kS = p.k2         // k_skin (skin to plasma)
        let kE = p.k3         // k_el (plasma clearance)

        // Fallback: no skin depot → legacy one-compartment Bateman
        guard kS > 1e-12 else {
            let oneCompP = PKParams(Frac_fast: 1.0, k1_fast: kRel, k1_slow: 0,
                                     k2: 0, k3: kE, F: p.F, rateMGh: 0,
                                     F_fast: p.F, F_slow: p.F)
            if tau <= wearH {
                return oneCompAmount(tau: tau, doseMG: doseMG, p: oneCompP)
            } else {
                let amtAtRemoval = oneCompAmount(tau: wearH, doseMG: doseMG, p: oneCompP)
                return amtAtRemoval * exp(-kE * (tau - wearH))
            }
        }

        if tau <= wearH {
            return _analytic3C(tau: tau, doseMG: doseMG, F: p.F, k1: kRel, k2: kS, k3: kE)
        } else {
            // Skin depot amount at removal (Bateman equation for compartment 2)
            let sRem: Double
            if abs(kRel - kS) < 1e-9 {
                sRem = doseMG * p.F * kRel * wearH * exp(-kS * wearH)
            } else {
                sRem = doseMG * p.F * kRel / (kRel - kS) * (exp(-kS * wearH) - exp(-kRel * wearH))
            }
            let pRem = _analytic3C(tau: wearH, doseMG: doseMG, F: p.F, k1: kRel, k2: kS, k3: kE)

            let diff = kE - kS
            let dt = tau - wearH
            if abs(diff) < 1e-9 {
                let kS2 = kS + 1e-6
                return sRem * kS2 / (kE - kS2) * (exp(-kS2 * dt) - exp(-kE * dt)) + pRem * exp(-kE * dt)
            }
            return sRem * kS / diff * (exp(-kS * dt) - exp(-kE * dt)) + pRem * exp(-kE * dt)
        }
    }

    // MARK: - Private helpers

    static func _analytic3C(tau: Double, doseMG: Double, F: Double, k1: Double, k2: Double, k3: Double) -> Double {
        guard k1 > 0, doseMG > 0 else { return 0 }

        let k1_k2 = k1 - k2
        let k1_k3 = k1 - k3
        let k2_k3 = k2 - k3

        if abs(k1_k2) < 1e-9 || abs(k1_k3) < 1e-9 || abs(k2_k3) < 1e-9 {
            return 0
        }

        let term1 = exp(-k1 * tau) / (k1_k2 * k1_k3)
        let term2 = exp(-k2 * tau) / (-k1_k2 * k2_k3)
        let term3 = exp(-k3 * tau) / (k1_k3 * k2_k3)

        return doseMG * F * k1 * k2 * (term1 + term2 + term3)
    }

    static func _batemanAmount(doseMG: Double, F: Double, ka: Double, ke: Double, t: Double) -> Double {
        guard doseMG > 0, ka > 0 else { return 0 }
        if abs(ka - ke) < 1e-9 {
            return doseMG * F * ka * t * exp(-ke * t)
        }
        return doseMG * F * ka / (ka - ke) * (exp(-ke * t) - exp(-ka * t))
    }
}
