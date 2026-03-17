import Foundation

/// Result of medication name recognition — ester only; route comes from HealthKit generalForm.
public struct MedicationRecognitionResult: Sendable, Equatable {
    public let ester: Ester
    public let confidence: Double // 0.0–1.0

    public init(ester: Ester, confidence: Double) {
        self.ester = ester
        self.confidence = confidence
    }
}

/// Recognizes HRT medication esters from display names in multiple languages.
/// Brand names sourced from mtf.wiki and common pharmacy databases.
public enum MedicationRecognizer {

    /// Attempt to recognize the medication ester from its display name.
    public static func recognize(_ displayName: String) -> MedicationRecognitionResult? {
        let name = displayName.lowercased()

        var bestMatch: (ester: Ester, score: Double)?

        for (ester, keywords) in esterKeywords {
            for keyword in keywords {
                let kw = keyword.lowercased()
                guard name.contains(kw) || kw.contains(name) else { continue }

                let score: Double
                if name == kw {
                    score = 1.0
                } else if name.contains(kw) {
                    let lengthRatio = Double(kw.count) / Double(name.count)
                    score = min(0.6 + lengthRatio * 0.3, 0.95)
                } else {
                    // kw contains name — partial match
                    score = 0.5
                }

                if bestMatch == nil || score > bestMatch!.score {
                    bestMatch = (ester, score)
                }
            }
        }

        guard let match = bestMatch else { return nil }
        return MedicationRecognitionResult(ester: match.ester, confidence: match.score)
    }

    /// Try to parse a strength in mg from a medication display name (e.g. "Androcur 12.5 mg" → 12.5).
    public static func parseStrengthMG(_ displayName: String) -> Double? {
        // Match patterns like "12.5mg", "12.5 mg", "2mg"
        let pattern = #"(\d+(?:\.\d+)?)\s*mg"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: displayName, range: NSRange(displayName.startIndex..., in: displayName)),
              let range = Range(match.range(at: 1), in: displayName) else {
            return nil
        }
        return Double(displayName[range])
    }

    // MARK: - Ester Keyword Database

    private static let esterKeywords: [(Ester, [String])] = [
        (.EV, evKeywords),
        (.E2, e2Keywords),
        (.EC, ecKeywords),
        (.EB, ebKeywords),
        (.EN, enKeywords),
        (.CPA, cpaKeywords),
    ]

    // MARK: EV — Estradiol Valerate

    private static let evKeywords: [String] = [
        "progynova",
        "补佳乐",
        "補佳樂",
        "progynon depot",
        "progynon-depot",
        "プロギノン・デポー",
        "プロギノンデポー",
        "富士日雌",
        "delestrogen",
        "estradiol valerate",
        "戊酸雌二醇",
        "climen",
        "克龄蒙",
        "仙琚",
        "仙静",
    ]

    // MARK: E2 — Estradiol (free / unesterified)

    private static let e2Keywords: [String] = [
        "oestrogel",
        "estrogel",
        "gynokadin",
        "爱斯妥",
        "エストロジェル",
        "ル・エストロジェル",
        "雌二醇凝胶",
        "sandrena",
        "サンドレナ",
        "divigel",
        "estreva",
        "oestraclin",
        "estraderm",
        "estradot",
        "climara",
        "estramon",
        "エストラーナ",
        "エストラーナテープ",
        "progynova ts",
        "vivelle",
        "vivelle-dot",
        "estrace",
        "estradiol",
        "雌二醇",
        "雌二醇贴片",
        "雌二醇貼片",
        "雌二醇凝膠",
        "雌二醇片",
        "雌二醇錠",
    ]

    // MARK: EC — Estradiol Cypionate

    private static let ecKeywords: [String] = [
        "estradiol cypionate",
        "depo-estradiol",
        "depo estradiol",
        "环戊丙酸雌二醇",
        "環戊丙酸雌二醇",
    ]

    // MARK: EB — Estradiol Benzoate

    private static let ebKeywords: [String] = [
        "estradiol benzoate",
        "苯甲酸雌二醇",
    ]

    // MARK: EN — Estradiol Enanthate

    private static let enKeywords: [String] = [
        "estradiol enanthate",
        "庚酸雌二醇",
    ]

    // MARK: CPA — Cyproterone Acetate

    private static let cpaKeywords: [String] = [
        "androcur",
        "安得卡",
        "cyproterone",
        "cyproterone acetate",
        "siterone",
        "华典",
        "diane-35",
        "达英-35",
        "达英35",
        "アンドロキュア",
        "酢酸シプロテロン",
        "色普龙",
        "色普龍",
        "醋酸环丙孕酮",
        "醋酸環丙孕酮",
    ]
}
