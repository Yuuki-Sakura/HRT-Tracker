import Testing
import Foundation
@testable import HRTModels
@testable import HRTServices

@Suite("HRTServices Tests")
struct ServicesTests {

    @Test("Export JSON roundtrip")
    func testExport_JSON_Roundtrip() throws {
        let events = [
            DoseEvent(route: .injection, timestamp: 1_764_000_000, doseMG: 5.0, ester: .EV),
            DoseEvent(route: .oral, timestamp: 1_764_086_400, doseMG: 2.0, ester: .E2),
        ]
        let labResults = [
            LabResult(timestamp: 1_764_043_200, concValue: 85.3, unit: .pgPerML),
        ]

        let exportService = ExportService()
        let data = try exportService.exportJSON(events: events, labResults: labResults)

        let importService = ImportService()
        let bundle = try importService.importJSON(data: data)

        #expect(bundle.events.count == 2)
        #expect(bundle.labResults.count == 1)
        #expect(bundle.events[0].doseMG == 5.0)
    }

    @Test("Export CSV format")
    func testExport_CSV_Format() {
        let events = [
            DoseEvent(route: .injection, timestamp: 1_764_000_000, doseMG: 5.0, ester: .EV),
        ]

        let exportService = ExportService()
        let csv = exportService.exportCSV(events: events)

        #expect(csv.contains("id,route,timestamp,date,doseMG,ester,extras"))
        #expect(csv.contains("injection"))
        #expect(csv.contains("EV"))
    }

    @Test("WatchSync payload serialization")
    func testWatchSync_PayloadSerialization() throws {
        let event = DoseEvent(
            route: .injection,
            timestamp: 1_764_000_000,
            doseMG: 5.0,
            ester: .EV,
            extras: [.concentrationMGmL: 20.0]
        )

        let payload = DoseEventPayload(from: event)
        let data = try JSONEncoder().encode(payload)
        let decoded = try JSONDecoder().decode(DoseEventPayload.self, from: data)

        let roundtripped = decoded.toDoseEvent()
        #expect(roundtripped != nil)
        #expect(roundtripped?.route == .injection)
        #expect(roundtripped?.doseMG == 5.0)
        #expect(roundtripped?.ester == .EV)
    }

    @Test("HealthKit mock protocol")
    func testHealthKit_MockProtocol() async throws {
        struct MockHealthKit: HealthKitServiceProtocol {
            func requestAuthorizationIfNeeded() async throws {}
            func fetchLatestBodyMassKG() async throws -> Double { return 65.0 }
            func saveBodyMassKG(_ kg: Double) async throws {}
            func requestMedicationAuthorization() async throws {}
            func fetchMedications() async throws -> [MedicationInfo] { return [] }
            func fetchDoseEvents(for medicationConceptID: String, since: Date) async throws -> [MedicationDoseEventInfo] { return [] }
            func observeBodyMassChanges(handler: @escaping @Sendable () -> Void) {}
            func observeMedicationDoseEvents(handler: @escaping @Sendable () -> Void) {}
        }

        let mock = MockHealthKit()
        let weight = try await mock.fetchLatestBodyMassKG()
        #expect(weight == 65.0)
    }
}
