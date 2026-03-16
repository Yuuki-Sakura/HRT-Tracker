import Testing
import Foundation
@testable import HRTModels

@Suite("HRTModels Tests")
struct ModelsTests {

    @Test("DoseEvent Codable roundtrip")
    func testDoseEvent_CodableRoundtrip() throws {
        let event = DoseEvent(
            route: .injection,
            timestamp: 1_764_000_000,
            doseMG: 5.0,
            ester: .EV,
            extras: [.concentrationMGmL: 10.0]
        )

        let data = try JSONEncoder().encode(event)
        let decoded = try JSONDecoder().decode(DoseEvent.self, from: data)

        #expect(decoded.id == event.id)
        #expect(decoded.route == event.route)
        #expect(decoded.timestamp == event.timestamp)
        #expect(decoded.doseMG == event.doseMG)
        #expect(decoded.ester == event.ester)
        #expect(decoded.extras[.concentrationMGmL] == 10.0)
    }

    @Test("LabResult Codable roundtrip")
    func testLabResult_CodableRoundtrip() throws {
        let result = LabResult(timestamp: 1_764_000_000, concValue: 85.3, unit: .pgPerML)

        let data = try JSONEncoder().encode(result)
        let decoded = try JSONDecoder().decode(LabResult.self, from: data)

        #expect(decoded.id == result.id)
        #expect(decoded.timestamp == result.timestamp)
        #expect(decoded.concValue == result.concValue)
        #expect(decoded.unit == result.unit)
    }

    @Test("DoseTemplate Codable roundtrip")
    func testDoseTemplate_CodableRoundtrip() throws {
        let template = DoseTemplate(
            name: "Test Template",
            route: .injection,
            ester: .EV,
            doseMG: 5.0,
            extras: [.concentrationMGmL: 20.0]
        )

        let data = try JSONEncoder().encode(template)
        let decoded = try JSONDecoder().decode(DoseTemplate.self, from: data)

        #expect(decoded.id == template.id)
        #expect(decoded.name == template.name)
        #expect(decoded.route == template.route)
        #expect(decoded.ester == template.ester)
        #expect(decoded.doseMG == template.doseMG)
    }

    @Test("DoseEvent date computed property")
    func testDoseEvent_DateComputed() {
        let timestamp: Int64 = 1_764_000_000
        let event = DoseEvent(route: .injection, timestamp: timestamp, doseMG: 5.0, ester: .EV)
        let expectedDate = Date(timeIntervalSince1970: Double(timestamp))

        #expect(event.date == expectedDate)
    }

    @Test("EsterInfo toE2Factor correctness")
    func testEsterInfo_ToE2Factor() {
        let e2Info = EsterInfo.by(ester: .E2)
        #expect(e2Info.toE2Factor == 1.0)

        let evInfo = EsterInfo.by(ester: .EV)
        let expectedFactor = 272.38 / 356.50
        #expect(abs(evInfo.toE2Factor - expectedFactor) < 1e-6)

        let ebInfo = EsterInfo.by(ester: .EB)
        let expectedEB = 272.38 / 376.50
        #expect(abs(ebInfo.toE2Factor - expectedEB) < 1e-6)
    }

    @Test("Route all cases coverage")
    func testRoute_AllCases() {
        let allRoutes = Route.allCases
        #expect(allRoutes.count == 6)
        #expect(allRoutes.contains(.injection))
        #expect(allRoutes.contains(.patchApply))
        #expect(allRoutes.contains(.patchRemove))
        #expect(allRoutes.contains(.gel))
        #expect(allRoutes.contains(.oral))
        #expect(allRoutes.contains(.sublingual))
    }

    @Test("ConcentrationUnit conversion")
    func testConcentrationUnit_Conversion() {
        let pgValue: Double = 100.0
        let pmolValue = ConcentrationUnit.pmolPerL.fromPgPerML(pgValue)
        let backToPg = ConcentrationUnit.pmolPerL.toPgPerML(pmolValue)
        #expect(abs(backToPg - pgValue) < 1e-6)
    }
}
