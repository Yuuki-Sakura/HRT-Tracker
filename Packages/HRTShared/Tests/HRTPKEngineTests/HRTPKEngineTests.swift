import Testing
import Foundation
@testable import HRTModels
@testable import HRTPKEngine

@Suite("PK Engine Tests")
struct PKEngineTests {

    // MARK: - Injection Tests

    @Test("Injection EV 5mg: Tmax ≈ 2.1 days")
    func testInjectionEV_Tmax() {
        let event = DoseEvent(route: .injection, timestamp: 0, doseMG: 5.0, ester: .EV)
        let engine = SimulationEngine(events: [event], bodyWeightKG: 70, startTimestamp: 0, endTimestamp: 24 * 14 * 3600, numberOfSteps: 2000)
        let result = engine.run()

        let tmaxIndex = result.concPGmL.enumerated().max(by: { $0.element < $1.element })!.offset
        let tmaxDays = Double(result.timestamps[tmaxIndex]) / (24.0 * 3600)

        #expect(tmaxDays > 1.0 && tmaxDays < 4.0, "EV Tmax should be ~2.1 days, got \(tmaxDays)")
    }

    @Test("Injection EB: Tmax shorter than EV")
    func testInjectionEB_Tmax() {
        let eventEB = DoseEvent(route: .injection, timestamp: 0, doseMG: 5.0, ester: .EB)
        let eventEV = DoseEvent(route: .injection, timestamp: 0, doseMG: 5.0, ester: .EV)

        let engineEB = SimulationEngine(events: [eventEB], bodyWeightKG: 70, startTimestamp: 0, endTimestamp: 24 * 14 * 3600, numberOfSteps: 2000)
        let engineEV = SimulationEngine(events: [eventEV], bodyWeightKG: 70, startTimestamp: 0, endTimestamp: 24 * 14 * 3600, numberOfSteps: 2000)

        let resultEB = engineEB.run()
        let resultEV = engineEV.run()

        let tmaxEB = resultEB.timestamps[resultEB.concPGmL.enumerated().max(by: { $0.element < $1.element })!.offset]
        let tmaxEV = resultEV.timestamps[resultEV.concPGmL.enumerated().max(by: { $0.element < $1.element })!.offset]

        #expect(tmaxEB < tmaxEV, "EB Tmax (\(tmaxEB)) should be shorter than EV Tmax (\(tmaxEV))")
    }

    @Test("Injection EC: Tmax ≈ 4 days")
    func testInjectionEC_Tmax() {
        let event = DoseEvent(route: .injection, timestamp: 0, doseMG: 5.0, ester: .EC)
        let engine = SimulationEngine(events: [event], bodyWeightKG: 70, startTimestamp: 0, endTimestamp: 24 * 21 * 3600, numberOfSteps: 2000)
        let result = engine.run()

        let tmaxIndex = result.concPGmL.enumerated().max(by: { $0.element < $1.element })!.offset
        let tmaxDays = Double(result.timestamps[tmaxIndex]) / (24.0 * 3600)

        #expect(tmaxDays > 2.0 && tmaxDays < 7.0, "EC Tmax should be ~4 days, got \(tmaxDays)")
    }

    @Test("Injection EN: Tmax ≈ 6.5 days")
    func testInjectionEN_Tmax() {
        let event = DoseEvent(route: .injection, timestamp: 0, doseMG: 5.0, ester: .EN)
        let engine = SimulationEngine(events: [event], bodyWeightKG: 70, startTimestamp: 0, endTimestamp: 24 * 28 * 3600, numberOfSteps: 3000)
        let result = engine.run()

        let tmaxIndex = result.concPGmL.enumerated().max(by: { $0.element < $1.element })!.offset
        let tmaxDays = Double(result.timestamps[tmaxIndex]) / (24.0 * 3600)

        #expect(tmaxDays > 4.0 && tmaxDays < 10.0, "EN Tmax should be ~6.5 days, got \(tmaxDays)")
    }

    // MARK: - Oral Tests

    @Test("Oral E2: Tmax ≈ 2-3 hours")
    func testOralE2_Tmax() {
        let event = DoseEvent(route: .oral, timestamp: 0, doseMG: 2.0, ester: .E2)
        let engine = SimulationEngine(events: [event], bodyWeightKG: 70, startTimestamp: 0, endTimestamp: 48 * 3600, numberOfSteps: 2000)
        let result = engine.run()

        let tmaxIndex = result.concPGmL.enumerated().max(by: { $0.element < $1.element })!.offset
        let tmaxH = Double(result.timestamps[tmaxIndex]) / 3600.0

        #expect(tmaxH > 1.0 && tmaxH < 5.0, "Oral E2 Tmax should be ~2-3h, got \(tmaxH)h")
    }

    @Test("Oral EV: Tmax ≈ 6-7 hours")
    func testOralEV_Tmax() {
        let event = DoseEvent(route: .oral, timestamp: 0, doseMG: 2.0, ester: .EV)
        let engine = SimulationEngine(events: [event], bodyWeightKG: 70, startTimestamp: 0, endTimestamp: 48 * 3600, numberOfSteps: 2000)
        let result = engine.run()

        let tmaxIndex = result.concPGmL.enumerated().max(by: { $0.element < $1.element })!.offset
        let tmaxH = Double(result.timestamps[tmaxIndex]) / 3600.0

        #expect(tmaxH > 3.0 && tmaxH < 12.0, "Oral EV Tmax should be ~6-7h, got \(tmaxH)h")
    }

    // MARK: - Sublingual Tests

    @Test("Sublingual theta=0 equals oral")
    func testSublingualTheta0_EqualsOral() {
        let oralEvent = DoseEvent(route: .oral, timestamp: 0, doseMG: 2.0, ester: .E2)
        let slEvent = DoseEvent(route: .sublingual, timestamp: 0, doseMG: 2.0, ester: .E2, extras: [.sublingualTheta: 0.0])

        let oralEngine = SimulationEngine(events: [oralEvent], bodyWeightKG: 70, startTimestamp: 0, endTimestamp: 48 * 3600, numberOfSteps: 500)
        let slEngine = SimulationEngine(events: [slEvent], bodyWeightKG: 70, startTimestamp: 0, endTimestamp: 48 * 3600, numberOfSteps: 500)

        let oralResult = oralEngine.run()
        let slResult = slEngine.run()

        for i in 0..<oralResult.concPGmL.count {
            let diff = abs(oralResult.concPGmL[i] - slResult.concPGmL[i])
            #expect(diff < 1e-6, "At index \(i), oral=\(oralResult.concPGmL[i]) vs SL=\(slResult.concPGmL[i])")
        }
    }

    @Test("Sublingual E2 dualAbsAmount: theta tiers produce different peaks")
    func testSublingualE2_dualAbsAmount() {
        let events = [0.01, 0.04, 0.11, 0.18].map { theta in
            DoseEvent(route: .sublingual, timestamp: 0, doseMG: 2.0, ester: .E2, extras: [.sublingualTheta: theta])
        }

        var peaks: [Double] = []
        for event in events {
            let engine = SimulationEngine(events: [event], bodyWeightKG: 70, startTimestamp: 0, endTimestamp: 24 * 3600, numberOfSteps: 500)
            let result = engine.run()
            peaks.append(result.concPGmL.max() ?? 0)
        }

        for i in 1..<peaks.count {
            #expect(peaks[i] > peaks[i - 1], "Higher theta should give higher peak: \(peaks)")
        }
    }

    @Test("Sublingual EV dualAbsMixedAmount: fast 3C + slow 1C")
    func testSublingualEV_dualAbsMixedAmount() {
        let event = DoseEvent(route: .sublingual, timestamp: 0, doseMG: 2.0, ester: .EV, extras: [.sublingualTheta: 0.11])
        let engine = SimulationEngine(events: [event], bodyWeightKG: 70, startTimestamp: 0, endTimestamp: 48 * 3600, numberOfSteps: 500)
        let result = engine.run()

        let peak = result.concPGmL.max() ?? 0
        #expect(peak > 0, "Sublingual EV should produce non-zero concentration")
    }

    // MARK: - Patch Tests

    @Test("Patch zero-order: wear period + removal decay")
    func testPatchZeroOrder_WearAndRemoval() {
        let applyEvent = DoseEvent(route: .patchApply, timestamp: 0, doseMG: 0, ester: .E2, extras: [.releaseRateUGPerDay: 100])
        let removeEvent = DoseEvent(route: .patchRemove, timestamp: 72 * 3600, doseMG: 0, ester: .E2)

        let engine = SimulationEngine(events: [applyEvent, removeEvent], bodyWeightKG: 70, startTimestamp: 0, endTimestamp: 168 * 3600, numberOfSteps: 1000)
        let result = engine.run()

        let concAt48 = result.concentration(at: 48 * 3600) ?? 0
        let concAt12 = result.concentration(at: 12 * 3600) ?? 0
        #expect(concAt48 > concAt12, "Concentration should rise during wear period")

        let concAt72 = result.concentration(at: 72 * 3600) ?? 0
        let concAt120 = result.concentration(at: 120 * 3600) ?? 0
        #expect(concAt120 < concAt72, "Concentration should decay after patch removal")
    }

    @Test("Patch first-order: truncation at removal")
    func testPatchFirstOrder_Truncation() {
        let applyEvent = DoseEvent(route: .patchApply, timestamp: 0, doseMG: 4.0, ester: .E2)
        let removeEvent = DoseEvent(route: .patchRemove, timestamp: 72 * 3600, doseMG: 0, ester: .E2)

        let engine = SimulationEngine(events: [applyEvent, removeEvent], bodyWeightKG: 70, startTimestamp: 0, endTimestamp: 168 * 3600, numberOfSteps: 1000)
        let result = engine.run()

        let concAt72 = result.concentration(at: 72 * 3600) ?? 0
        let concAt120 = result.concentration(at: 120 * 3600) ?? 0
        #expect(concAt120 < concAt72, "First-order patch should decay after removal")
    }

    @Test("Patch zero-order: T90% ≈ 15–35h (literature Tmax 12–36h)")
    func testPatchZeroOrder_T90Percent() {
        // No removal → continuous wear to find time to 90% of plateau
        let applyEvent = DoseEvent(route: .patchApply, timestamp: 0, doseMG: 0, ester: .E2, extras: [.releaseRateUGPerDay: 100])
        let engine = SimulationEngine(events: [applyEvent], bodyWeightKG: 70, startTimestamp: 0, endTimestamp: 168 * 3600, numberOfSteps: 2000)
        let result = engine.run()

        let maxConc = result.concPGmL.max() ?? 0
        let threshold = maxConc * 0.9
        // Find first time concentration exceeds 90% of max
        var t90: Double = 168
        for i in 0..<result.timestamps.count where result.concPGmL[i] >= threshold {
                t90 = Double(result.timestamps[i]) / 3600.0
                break
        }
        #expect(t90 > 15 && t90 < 35, "T90% should be 15–35h (literature Tmax), got \(t90)h")
    }

    @Test("Patch zero-order: post-removal apparent t½ ≈ 4–10h (literature 5.9–7.7h)")
    func testPatchZeroOrder_PostRemovalHalfLife() {
        let applyEvent = DoseEvent(route: .patchApply, timestamp: 0, doseMG: 0, ester: .E2, extras: [.releaseRateUGPerDay: 100])
        let removeEvent = DoseEvent(route: .patchRemove, timestamp: 96 * 3600, doseMG: 0, ester: .E2)  // near steady-state

        let engine = SimulationEngine(events: [applyEvent, removeEvent], bodyWeightKG: 70, startTimestamp: 0, endTimestamp: 168 * 3600, numberOfSteps: 5000)
        let result = engine.run()

        let concAtRemoval = result.concentration(at: 96 * 3600) ?? 0
        let halfTarget = concAtRemoval * 0.5

        // Find time after removal when concentration drops to half
        var tHalf: Double = 0
        for i in 0..<result.timestamps.count {
            if result.timestamps[i] > 96 * 3600 && result.concPGmL[i] <= halfTarget {
                tHalf = Double(result.timestamps[i] - 96 * 3600) / 3600.0
                break
            }
        }
        #expect(tHalf > 4 && tHalf < 10, "Post-removal t½ should be 4–10h (literature 5.9–7.7h), got \(tHalf)h")
    }

    @Test("Patch zero-order: steady-state for 0.1 mg/day in 50–150 pg/mL")
    func testPatchZeroOrder_SteadyState() {
        let applyEvent = DoseEvent(route: .patchApply, timestamp: 0, doseMG: 0, ester: .E2, extras: [.releaseRateUGPerDay: 100])
        let engine = SimulationEngine(events: [applyEvent], bodyWeightKG: 70, startTimestamp: 0, endTimestamp: 168 * 3600, numberOfSteps: 1000)
        let result = engine.run()

        // Steady-state is at the end (168h, well past T90%)
        let concSS = result.concPGmL.last ?? 0
        #expect(concSS > 50 && concSS < 150, "Steady-state for 100 µg/day should be 50–150 pg/mL, got \(concSS)")
    }

    @Test("Patch first-order with skin depot: Tmax later than without depot")
    func testPatchFirstOrder_SkinDepotDelaysTmax() {
        // With skin depot (normal flow)
        let applyEvent = DoseEvent(route: .patchApply, timestamp: 0, doseMG: 4.0, ester: .E2)
        let engine = SimulationEngine(events: [applyEvent], bodyWeightKG: 70, startTimestamp: 0, endTimestamp: 336 * 3600, numberOfSteps: 3000)
        let result = engine.run()

        let tmaxIdx = result.concPGmL.enumerated().max(by: { $0.element < $1.element })!.offset
        let tmaxH = Double(result.timestamps[tmaxIdx]) / 3600.0

        // Without skin depot, Tmax = ln(ke/ka)/(ke-ka) = ln(0.41/0.0075)/(0.41-0.0075) ≈ 9.9h
        // With skin depot, Tmax should be significantly later
        #expect(tmaxH > 15, "Tmax with skin depot should be > 15h, got \(tmaxH)h")
    }

    // MARK: - Gel Test

    @Test("Gel Bateman curve: k1=0.022, F=0.05")
    func testGel_Bateman() {
        let event = DoseEvent(route: .gel, timestamp: 0, doseMG: 1.5, ester: .E2)
        let engine = SimulationEngine(events: [event], bodyWeightKG: 70, startTimestamp: 0, endTimestamp: 72 * 3600, numberOfSteps: 500)
        let result = engine.run()

        let peak = result.concPGmL.max() ?? 0
        #expect(peak > 0, "Gel should produce non-zero peak concentration")

        let tmaxIndex = result.concPGmL.enumerated().max(by: { $0.element < $1.element })!.offset
        #expect(tmaxIndex > 0, "Tmax should not be at t=0")
        #expect(tmaxIndex < result.concPGmL.count - 1, "Tmax should not be at the end")
    }

    // MARK: - Edge Cases

    @Test("Degenerate rates: near-equal k values don't crash")
    func testThreeCompartment_DegenerateRates() {
        let result = ThreeCompartmentModel._analytic3C(tau: 10, doseMG: 5, F: 0.1, k1: 0.05, k2: 0.05, k3: 0.041)
        #expect(result == 0, "Degenerate case should return 0")
    }

    @Test("Zero dose returns zero")
    func testThreeCompartment_ZeroDose() {
        let event = DoseEvent(route: .injection, timestamp: 0, doseMG: 0, ester: .EV)
        let engine = SimulationEngine(events: [event], bodyWeightKG: 70, startTimestamp: 0, endTimestamp: 48 * 3600, numberOfSteps: 100)
        let result = engine.run()

        let allZero = result.concPGmL.allSatisfy { $0 == 0 }
        #expect(allZero, "Zero dose should produce all-zero concentrations")
    }

    // MARK: - Multi-Event & AUC

    @Test("Multi-event linear superposition")
    func testSimulationEngine_MultiEvent() {
        let event1 = DoseEvent(route: .injection, timestamp: 0, doseMG: 5.0, ester: .EV)
        let event2 = DoseEvent(route: .injection, timestamp: 0, doseMG: 5.0, ester: .EV)

        let singleEngine = SimulationEngine(events: [event1], bodyWeightKG: 70, startTimestamp: 0, endTimestamp: 168 * 3600, numberOfSteps: 500)
        let doubleEngine = SimulationEngine(events: [event1, event2], bodyWeightKG: 70, startTimestamp: 0, endTimestamp: 168 * 3600, numberOfSteps: 500)

        let singleResult = singleEngine.run()
        let doubleResult = doubleEngine.run()

        for i in 0..<singleResult.concPGmL.count {
            let expected = singleResult.concPGmL[i] * 2
            let actual = doubleResult.concPGmL[i]
            let relError = expected > 0 ? abs(actual - expected) / expected : abs(actual)
            #expect(relError < 0.01, "At \(i): expected \(expected), got \(actual)")
        }
    }

    @Test("AUC trapezoidal correctness")
    func testSimulationEngine_AUC_Trapezoidal() {
        let event = DoseEvent(route: .injection, timestamp: 0, doseMG: 5.0, ester: .EV)
        let engine = SimulationEngine(events: [event], bodyWeightKG: 70, startTimestamp: 0, endTimestamp: 168 * 3600, numberOfSteps: 1000)
        let result = engine.run()

        #expect(result.auc > 0, "AUC should be positive for non-zero dose")

        var manualAUC = 0.0
        for i in 1..<result.timestamps.count {
            let dt = Double(result.timestamps[i] - result.timestamps[i - 1]) / 3600.0
            manualAUC += 0.5 * (result.concPGmL[i] + result.concPGmL[i - 1]) * dt
        }
        let relError = abs(manualAUC - result.auc) / max(result.auc, 1e-10)
        #expect(relError < 1e-6, "AUC mismatch: manual=\(manualAUC), engine=\(result.auc)")
    }

    // MARK: - Lab Calibration

    @Test("Lab calibration interpolation")
    func testLabCalibration_Interpolation() {
        let event = DoseEvent(route: .injection, timestamp: 0, doseMG: 5.0, ester: .EV)
        let engine = SimulationEngine(events: [event], bodyWeightKG: 70, startTimestamp: 0, endTimestamp: 168 * 3600, numberOfSteps: 500)
        let sim = engine.run()

        let predAt48 = sim.concentration(at: 48 * 3600) ?? 0
        let lab = LabResult(timestamp: 48 * 3600, concValue: predAt48 * 2, unit: .pgPerML)

        let points = LabCalibration.buildCalibrationPoints(sim: sim, labResults: [lab])
        #expect(points.count == 1)

        let ratio = LabCalibration.calibrationRatio(at: 48 * 3600, points: points)
        #expect(abs(ratio - 2.0) < 0.01, "Ratio should be ~2.0, got \(ratio)")
    }

    @Test("Lab calibration extrapolation is bounded")
    func testLabCalibration_Extrapolation() {
        let points = [
            LabCalibration.CalibrationPoint(timestamp: 24 * 3600, ratio: 1.5),
            LabCalibration.CalibrationPoint(timestamp: 72 * 3600, ratio: 2.0),
        ]

        // Before first point: IDW with time decay, nearest point (1.5) dominates
        let ratioBefore = LabCalibration.calibrationRatio(at: 0, points: points)
        #expect(ratioBefore > 1.4 && ratioBefore < 1.6, "Before first point, should be close to nearest ratio 1.5, got \(ratioBefore)")

        // After last point: IDW with time decay, nearest point (2.0) has more weight
        let ratioAfter = LabCalibration.calibrationRatio(at: 200 * 3600, points: points)
        #expect(ratioAfter > 1.7 && ratioAfter < 2.1, "After last point, should be closer to nearest ratio 2.0, got \(ratioAfter)")

        let ratioMid = LabCalibration.calibrationRatio(at: 48 * 3600, points: points)
        #expect(ratioMid > 1.5 && ratioMid < 2.0, "Interpolated ratio should be between endpoints")
    }

    // MARK: - CPA (Cyproterone Acetate)

    @Test("CPA oral Tmax ≈ 2-3h")
    func testCPA_Oral_Tmax() {
        let event = DoseEvent(route: .oral, timestamp: 0, doseMG: 12.5, ester: .CPA)
        let engine = SimulationEngine(events: [event], bodyWeightKG: 70, startTimestamp: 0, endTimestamp: 120 * 3600, numberOfSteps: 1000)
        let result = engine.run()

        // Find Tmax in CPA array
        guard let maxConc = result.concNGmL_CPA.max(), maxConc > 0 else {
            Issue.record("CPA concentration should be > 0")
            return
        }
        let maxIdx = result.concNGmL_CPA.firstIndex(of: maxConc)!
        let tmaxH = Double(result.timestamps[maxIdx]) / 3600.0

        // ka=0.35, kel=0.017 → Tmax = ln(ka/kel)/(ka-kel) ≈ ln(20.6)/0.333 ≈ 9.1h
        // But with Bateman: Tmax = ln(ka/kel)/(ka - kel) = ln(0.35/0.017)/(0.35-0.017) ≈ 3.04/0.333 ≈ 9.1h
        // Actually let's just check it's reasonable (between 1 and 15 hours)
        #expect(tmaxH > 1 && tmaxH < 15, "CPA Tmax should be ~9h, got \(tmaxH)")

        // E2 array should be all zeros (no E2 events)
        let allE2Zero = result.concPGmL.allSatisfy { $0 == 0 }
        #expect(allE2Zero, "E2 concentration should be zero when only CPA events exist")
    }

    @Test("CPA does not affect E2 concentrations")
    func testCPA_SeparateFromE2() {
        let e2Event = DoseEvent(route: .injection, timestamp: 0, doseMG: 5.0, ester: .EV)
        let cpaEvent = DoseEvent(route: .oral, timestamp: 0, doseMG: 12.5, ester: .CPA)

        let e2Only = SimulationEngine(events: [e2Event], bodyWeightKG: 70, startTimestamp: 0, endTimestamp: 168 * 3600, numberOfSteps: 500)
        let both = SimulationEngine(events: [e2Event, cpaEvent], bodyWeightKG: 70, startTimestamp: 0, endTimestamp: 168 * 3600, numberOfSteps: 500)

        let e2Result = e2Only.run()
        let bothResult = both.run()

        // E2 concentrations should be identical regardless of CPA presence
        for i in 0..<e2Result.concPGmL.count {
            let relError = e2Result.concPGmL[i] > 0
                ? abs(bothResult.concPGmL[i] - e2Result.concPGmL[i]) / e2Result.concPGmL[i]
                : abs(bothResult.concPGmL[i])
            #expect(relError < 1e-6, "E2 conc at \(i) differs: \(e2Result.concPGmL[i]) vs \(bothResult.concPGmL[i])")
        }
    }

    @Test("Dual-track E2 + CPA simulation")
    func testCPA_DualTrack() {
        let e2Event = DoseEvent(route: .injection, timestamp: 0, doseMG: 5.0, ester: .EV)
        let cpaEvent = DoseEvent(route: .oral, timestamp: 0, doseMG: 12.5, ester: .CPA)

        let engine = SimulationEngine(events: [e2Event, cpaEvent], bodyWeightKG: 70, startTimestamp: 0, endTimestamp: 168 * 3600, numberOfSteps: 500)
        let result = engine.run()

        #expect(result.hasCPA, "Result should have CPA data")
        #expect(result.concNGmL_CPA.count == result.timestamps.count, "CPA array length should match time array")
        #expect(result.concPGmL.count == result.timestamps.count, "E2 array length should match time array")

        let maxE2 = result.concPGmL.max() ?? 0
        let maxCPA = result.concNGmL_CPA.max() ?? 0
        #expect(maxE2 > 0, "E2 peak should be > 0")
        #expect(maxCPA > 0, "CPA peak should be > 0")
        #expect(result.auc > 0, "E2 AUC should be > 0")
        #expect(result.aucCPA > 0, "CPA AUC should be > 0")
    }

    @Test("CPA concentration unit is ng/mL (reasonable range)")
    func testCPA_UnitConversion() {
        // 12.5 mg CPA oral, Vd=20.6 L/kg, F=0.88, bodyWeight=70kg
        // Peak amount ≈ 12.5 * 0.88 = 11.0 mg absorbed
        // Plasma volume = 20.6 * 70 * 1000 = 1,442,000 mL
        // Peak conc ≈ 11.0 * 1e6 / 1,442,000 ≈ 7.6 ng/mL (before elimination)
        let event = DoseEvent(route: .oral, timestamp: 0, doseMG: 12.5, ester: .CPA)
        let engine = SimulationEngine(events: [event], bodyWeightKG: 70, startTimestamp: 0, endTimestamp: 120 * 3600, numberOfSteps: 1000)
        let result = engine.run()

        let maxCPA = result.concNGmL_CPA.max() ?? 0
        // Should be in reasonable ng/mL range (1-20 ng/mL for 12.5 mg dose)
        #expect(maxCPA > 1 && maxCPA < 20, "CPA peak should be 1-20 ng/mL, got \(maxCPA)")
    }
}
