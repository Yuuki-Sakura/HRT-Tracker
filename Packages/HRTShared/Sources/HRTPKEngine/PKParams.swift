import Foundation

public struct PKParams: Sendable {
    public let Frac_fast: Double
    public let k1_fast: Double
    public let k1_slow: Double
    public let k2: Double
    public let k3: Double
    public let F: Double
    public let rateMGh: Double
    public let F_fast: Double
    public let F_slow: Double

    public init(
        Frac_fast: Double,
        k1_fast: Double,
        k1_slow: Double,
        k2: Double,
        k3: Double,
        F: Double,
        rateMGh: Double,
        F_fast: Double,
        F_slow: Double
    ) {
        self.Frac_fast = Frac_fast
        self.k1_fast = k1_fast
        self.k1_slow = k1_slow
        self.k2 = k2
        self.k3 = k3
        self.F = F
        self.rateMGh = rateMGh
        self.F_fast = F_fast
        self.F_slow = F_slow
    }
}
