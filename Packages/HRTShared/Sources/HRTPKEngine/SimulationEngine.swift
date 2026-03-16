import Foundation
import HRTModels

public struct SimulationEngine: Sendable {
    private let e2Models: [PrecomputedEventModel]
    private let cpaModels: [PrecomputedEventModel]
    private let plasmaVolumeML_E2: Double
    private let plasmaVolumeML_CPA: Double
    private let startTimeH: Double
    private let endTimeH: Double
    private let eventTimesH: [Double]
    public let numberOfSteps: Int

    public init(events: [DoseEvent], bodyWeightKG: Double, startTimestamp: Int64, endTimestamp: Int64, numberOfSteps: Int) {
        var e2 = [PrecomputedEventModel]()
        var cpa = [PrecomputedEventModel]()

        for event in events {
            guard event.route != .patchRemove else { continue }
            let model = PrecomputedEventModel(event: event, allEvents: events, bodyWeightKG: bodyWeightKG)
            if event.ester == .CPA {
                cpa.append(model)
            } else {
                e2.append(model)
            }
        }

        self.e2Models = e2
        self.cpaModels = cpa
        self.plasmaVolumeML_E2 = CorePK.vdPerKG * bodyWeightKG * 1000
        self.plasmaVolumeML_CPA = CPAPK.vdPerKG * bodyWeightKG * 1000
        self.startTimeH = Double(startTimestamp) / 3600.0
        self.endTimeH = Double(endTimestamp) / 3600.0
        self.eventTimesH = events.filter { $0.route != .patchRemove }.map { $0.timeH }
        self.numberOfSteps = numberOfSteps
    }

    public func run() -> SimulationResult {
        guard startTimeH < endTimeH, numberOfSteps > 1, plasmaVolumeML_E2 > 0 else {
            return SimulationResult(timestamps: [], concPGmL: [], auc: 0)
        }

        let stepSize = (endTimeH - startTimeH) / Double(numberOfSteps - 1)
        let hasCPA = !cpaModels.isEmpty

        // Build time grid: uniform steps + event timestamps
        var timeSet = Set<Double>()
        for i in 0..<numberOfSteps {
            timeSet.insert(startTimeH + Double(i) * stepSize)
        }
        for eth in eventTimesH where eth >= startTimeH && eth <= endTimeH {
            timeSet.insert(eth)
        }
        let sortedTimes = timeSet.sorted()
        let totalPoints = sortedTimes.count

        var tsArr = [Int64]()
        var e2Arr = [Double]()
        var cpaArr = hasCPA ? [Double]() : [Double]()
        tsArr.reserveCapacity(totalPoints)
        e2Arr.reserveCapacity(totalPoints)
        if hasCPA { cpaArr.reserveCapacity(totalPoints) }

        var aucE2 = 0.0
        var aucCPA = 0.0
        let e2Scale = 1e9 / plasmaVolumeML_E2   // mg → pg/mL
        let cpaScale = hasCPA ? 1e6 / plasmaVolumeML_CPA : 0.0  // mg → ng/mL
        var prevE2 = 0.0
        var prevCPA = 0.0

        for (idx, t) in sortedTimes.enumerated() {

            var totalE2 = 0.0
            for model in e2Models {
                totalE2 += model.amount(at: t)
            }
            let concE2 = totalE2 * e2Scale

            var concCPA = 0.0
            if hasCPA {
                var totalCPA = 0.0
                for model in cpaModels {
                    totalCPA += model.amount(at: t)
                }
                concCPA = totalCPA * cpaScale
            }

            tsArr.append(Int64(t * 3600.0))
            e2Arr.append(concE2)
            if hasCPA { cpaArr.append(concCPA) }

            if idx > 0 {
                let dt = t - sortedTimes[idx - 1]
                aucE2 += 0.5 * (concE2 + prevE2) * dt
                if hasCPA { aucCPA += 0.5 * (concCPA + prevCPA) * dt }
            }
            prevE2 = concE2
            prevCPA = concCPA
        }

        return SimulationResult(
            timestamps: tsArr,
            concPGmL: e2Arr,
            concNGmL_CPA: cpaArr,
            auc: aucE2,
            aucCPA: aucCPA
        )
    }
}

struct PrecomputedEventModel: Sendable {
    private let model: @Sendable (Double) -> Double

    init(event: DoseEvent, allEvents: [DoseEvent], bodyWeightKG: Double) {
        let params = ParameterResolver.resolve(event: event, bodyWeightKG: bodyWeightKG)
        let startTime = event.timeH
        let dose = event.doseMG

        switch event.route {
        case .injection:
            self.model = { timeH in
                let tau = timeH - startTime
                guard tau >= 0 else { return 0 }
                return ThreeCompartmentModel.injAmount(tau: tau, doseMG: dose, p: params)
            }
        case .gel, .oral:
            let oneCompP = PKParams(
                Frac_fast: 1.0, k1_fast: params.k1_fast, k1_slow: 0,
                k2: params.k2, k3: params.k3, F: params.F, rateMGh: params.rateMGh,
                F_fast: params.F, F_slow: params.F
            )
            self.model = { timeH in
                let tau = timeH - startTime
                guard tau >= 0 else { return 0 }
                return ThreeCompartmentModel.oneCompAmount(tau: tau, doseMG: dose, p: oneCompP)
            }
        case .sublingual:
            self.model = { timeH in
                let tau = timeH - startTime
                guard tau >= 0 else { return 0 }
                if params.k2 > 0 {
                    return ThreeCompartmentModel.dualAbsMixedAmount(tau: tau, doseMG: dose, p: params)
                } else {
                    return ThreeCompartmentModel.dualAbsAmount(tau: tau, doseMG: dose, p: params)
                }
            }
        case .patchApply:
            let wearH: Double
            if let days = event.extras[.patchWearDays] {
                wearH = days * 24
            } else {
                let remove = allEvents.first { $0.route == .patchRemove && $0.timeH > startTime }
                wearH = (remove?.timeH ?? .greatestFiniteMagnitude) - startTime
            }
            self.model = { timeH in
                let tau = timeH - startTime
                guard tau >= 0 else { return 0 }
                return ThreeCompartmentModel.patchAmount(tau: tau, doseMG: dose, wearH: wearH, p: params)
            }
        case .patchRemove:
            self.model = { _ in 0 }
        }
    }

    func amount(at timeH: Double) -> Double {
        model(timeH)
    }
}
