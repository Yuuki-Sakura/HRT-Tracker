import Foundation
import HRTModels

public enum CorePK: Sendable {
    public static let vdPerKG: Double = 2.0
    public static let kClear: Double = 0.41
    public static let kClearInjection: Double = 0.041
    public static let depotK1Corr: Double = 1.0
}

public enum TwoPartDepotPK: Sendable {
    public static let Frac_fast: [Ester: Double] = [
        .EB: 0.90,
        .EV: 0.40,
        .EC: 0.229164549,
        .EN: 0.05,
    ]

    public static let k1_fast: [Ester: Double] = [
        .EB: 0.144,
        .EV: 0.0216,
        .EC: 0.005035046,
        .EN: 0.0010,
    ]

    public static let k1_slow: [Ester: Double] = [
        .EB: 0.114,
        .EV: 0.0138,
        .EC: 0.004510574,
        .EN: 0.0050,
    ]
}

public enum InjectionPK: Sendable {
    public static let formationFraction: [Ester: Double] = [
        .EB: 0.10922376473734707,
        .EV: 0.062258288229969413,
        .EC: 0.117255838,
        .EN: 0.12,
    ]
}

public enum EsterPK: Sendable {
    public static let k2: [Ester: Double] = [
        .EB: 0.090,
        .EV: 0.070,
        .EC: 0.045,
        .EN: 0.015,
    ]
}

public enum PatchRelease: Sendable {
    case firstOrder(k1: Double)
    case zeroOrder(rateMGh: Double)
}

public enum PatchPK: Sendable {
    /// Skin-depot-to-plasma transfer rate (h⁻¹).
    /// Derived from Vivelle-Dot post-removal t½ = 5.9–7.7 h (FDA Label 2014, NDA 020538).
    /// Since k_el (0.41) >> k_skin, post-removal decay is governed by k_skin,
    /// giving apparent t½ ≈ ln2/0.10 = 6.93 h, consistent with literature range.
    public static let kSkin: Double = 0.10
    public static let generic: PatchRelease = .firstOrder(k1: 0.0075)
    /// Scrotal bioavailability multiplier: Premoli et al. (2005), ~5× drug delivery.
    public static let scrotalMultiplier: Double = 5.0
}

public enum TransdermalGelPK: Sendable {
    private static let baseK1: Double = 0.022
    private static let Fmax: Double = 0.05
    /// Scrotal bioavailability: ~5× base, per Premoli et al. (2005) estradiol patch data (n=35).
    private static let FmaxScrotal: Double = 0.25

    public static func parameters(doseMG: Double, areaCM2: Double, isScrotal: Bool = false) -> (k1: Double, F: Double) {
        guard doseMG > 0 else { return (0, 0) }
        return (baseK1, isScrotal ? FmaxScrotal : Fmax)
    }
}

public enum OralPK: Sendable {
    public static let kAbsE2: Double = 0.32
    public static let kAbsEV: Double = 0.05
    public static let bioavailability: Double = 0.03
    public static let kAbsSL: Double = 1.8
}

public enum CPAPK: Sendable {
    /// Volume of distribution (L/kg). Literature: 20.6 ± 3.5 (PMID 2977383)
    public static let vdPerKG: Double = 20.6
    /// Oral absorption rate constant (h⁻¹). Literature Tmax 2-3h → ka ≈ 0.35
    public static let ka: Double = 0.35
    /// Elimination rate constant (h⁻¹). t½ ≈ 40.8h (literature 38-53h, PMID 9349934)
    public static let kel: Double = 0.017
    /// Oral bioavailability. Literature: 88 ± 20% (PMID 880829, PMID 1036708)
    public static let bioavailability: Double = 0.88
}

public enum SublingualTier: String, CaseIterable, Identifiable, Sendable {
    case quick, casual, standard, strict
    public var id: Self { self }
}

public enum SublingualTheta: Sendable {
    public static let recommended: [SublingualTier: Double] = [
        .quick: 0.01,
        .casual: 0.04,
        .standard: 0.11,
        .strict: 0.18
    ]
    public static let holdMinutes: [SublingualTier: Double] = [
        .quick: 2,
        .casual: 5,
        .standard: 10,
        .strict: 15
    ]
    public static let thetaRangeLow: [SublingualTier: Double] = [
        .quick: 0.004,
        .casual: 0.021,
        .standard: 0.064,
        .strict: 0.115
    ]
    public static let thetaRangeHigh: [SublingualTier: Double] = [
        .quick: 0.012,
        .casual: 0.057,
        .standard: 0.156,
        .strict: 0.253
    ]
}
