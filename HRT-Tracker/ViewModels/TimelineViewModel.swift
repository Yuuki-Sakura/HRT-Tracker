import Foundation
import Combine
import SwiftUI
import SwiftData
import HRTModels
import HRTPKEngine
import HRTServices

@MainActor
final class TimelineViewModel: ObservableObject {
    @Published var events: [DoseEvent] = []
    @Published var labResults: [LabResult] = []
    @Published var result: SimulationResult?
    @Published var isSimulating: Bool = false
    @Published var bodyWeightKG: Double {
        didSet {
            UserDefaults.standard.set(bodyWeightKG, forKey: weightKey)
        }
    }

    // MARK: - HealthKit Properties

    #if !OPENSOURCE
    @Published var isHealthKitAuthorized: Bool {
        didSet { UserDefaults.standard.set(isHealthKitAuthorized, forKey: "hk.authorized") }
    }
    @Published var lastHealthKitSync: Date? {
        didSet { UserDefaults.standard.set(lastHealthKitSync?.timeIntervalSince1970 ?? 0, forKey: "hk.lastSync") }
    }
    @Published var healthKitError: String?

    // MARK: - Medications Properties

    @Published var isMedicationSyncEnabled: Bool {
        didSet { UserDefaults.standard.set(isMedicationSyncEnabled, forKey: "hk.medicationSync") }
    }
    @Published var medications: [MedicationInfo] = []
    @Published var medicationMappings: [MedicationMapping] = []
    @Published var unmappedMedications: [MedicationInfo] = []
    #else
    let isHealthKitAuthorized = false
    let lastHealthKitSync: Date? = nil
    var healthKitError: String?
    let isMedicationSyncEnabled = false
    let medications: [MedicationInfo] = []
    let medicationMappings: [MedicationMapping] = []
    let unmappedMedications: [MedicationInfo] = []
    #endif

    // MARK: - Template Properties

    @Published var templates: [DoseTemplate] = []

    private let weightKey = "user.weightKg"
    private var cancellables = Set<AnyCancellable>()
    private var simulationTask: Task<Void, Never>?
    private let modelContext: ModelContext

    #if !OPENSOURCE
    private let healthKitService: HealthKitServiceProtocol = HealthKitService.shared
    #endif

    var dayGroups: [DayGroup] {
        groupEventsByDay(events)
    }

    var eventCount: Int { events.count }

    /// Calibrated E2 concentrations (adjusted by lab results if available)
    var calibratedConcPGmL: [Double]? {
        guard let sim = result, !labResults.isEmpty else { return nil }
        let calibrated = LabCalibration.calibratedConcentration(sim: sim, labResults: labResults)
        // Only return if calibration actually changed something
        guard calibrated != sim.concPGmL else { return nil }
        return calibrated
    }

    var currentE2: Double? {
        let ts = Int64(Date().timeIntervalSince1970)
        guard let sim = result else { return nil }

        // Use calibrated value if lab data is available
        if !labResults.isEmpty {
            let points = LabCalibration.buildCalibrationPoints(sim: sim, labResults: labResults)
            if !points.isEmpty, let raw = sim.concentration(at: ts), raw > 0 {
                let ratio = LabCalibration.calibrationRatio(at: ts, points: points)
                return raw * ratio
            }
        }

        guard let conc = sim.concentration(at: ts), conc > 0 else { return nil }
        return conc
    }

    var currentCPA: Double? {
        let ts = Int64(Date().timeIntervalSince1970)
        guard let conc = result?.concentrationCPA(at: ts), conc > 0 else { return nil }
        return conc
    }

    var labCalibrationScale: Double? {
        guard let sim = result, !labResults.isEmpty else { return nil }
        let points = LabCalibration.buildCalibrationPoints(sim: sim, labResults: labResults)
        guard let first = points.first else { return nil }
        return first.ratio
    }

    /// Find the most recent DoseEvent matching a template (by ester + route).
    func lastDose(for template: DoseTemplate) -> DoseEvent? {
        events
            .filter { $0.ester == template.ester && $0.route == template.route }
            .max(by: { $0.timestamp < $1.timestamp })
    }

    init(modelContext: ModelContext) {
        self.modelContext = modelContext

        let saved = UserDefaults.standard.double(forKey: weightKey)
        self.bodyWeightKG = saved > 0 ? saved : 70.0

        #if !OPENSOURCE
        self.isHealthKitAuthorized = UserDefaults.standard.bool(forKey: "hk.authorized")

        let syncTS = UserDefaults.standard.double(forKey: "hk.lastSync")
        self.lastHealthKitSync = syncTS > 0 ? Date(timeIntervalSince1970: syncTS) : nil

        self.isMedicationSyncEnabled = UserDefaults.standard.bool(forKey: "hk.medicationSync")
        #endif

        setupSubscriptions()
        loadFromStore()
        runSimulation()
    }

    static var preview: TimelineViewModel {
        let container = try! HRTModelContainer.create(inMemory: true) // swiftlint:disable:this force_try
        let vm = TimelineViewModel(modelContext: container.mainContext)
        let now = Int64(Date().timeIntervalSince1970)
        let start = now - 14 * 24 * 3600
        var events = [DoseEvent]()
        let scrotalSite = Double(ApplicationSite.scrotum.rawValue)
        for day in 0..<14 {
            events.append(DoseEvent(route: .gel, timestamp: start + Int64(day) * 24 * 3600, doseMG: 1.5, ester: .E2, extras: [.applicationSite: scrotalSite]))
        }
        for i in stride(from: 0, to: 14, by: 3) {
            events.append(DoseEvent(route: .oral, timestamp: start + Int64(i) * 24 * 3600, doseMG: 12.5, ester: .CPA))
        }
        vm.events = events
        vm.templates = [
            DoseTemplate(name: "Gel", route: .gel, ester: .E2, doseMG: 1.5, extras: [.applicationSite: scrotalSite]),
            DoseTemplate(name: "CPA", route: .oral, ester: .CPA, doseMG: 12.5),
        ]
        vm.runSimulation()
        return vm
    }

    private func setupSubscriptions() {
        $bodyWeightKG
            .debounce(for: .milliseconds(500), scheduler: RunLoop.main)
            .sink { [weak self] _ in self?.runSimulation() }
            .store(in: &cancellables)

        #if canImport(WatchConnectivity)
        WatchConnectivityService.shared.$receivedEvents
            .removeDuplicates()
            .sink { [weak self] received in
                guard let self else { return }
                for event in received where !self.events.contains(where: { $0.id == event.id }) {
                    self.save(event)
                }
            }
            .store(in: &cancellables)
        #endif
    }

    // MARK: - CRUD

    func save(_ event: DoseEvent) {
        withAnimation {
            if let index = events.firstIndex(where: { $0.id == event.id }) {
                events[index] = event
            } else {
                events.append(event)
                events.sort { $0.timestamp < $1.timestamp }
            }
        }
        saveToStore(event)
        runSimulation()
    }

    func remove(_ event: DoseEvent) {
        withAnimation {
            events.removeAll { $0.id == event.id }
        }
        removeFromStore(event)
        runSimulation()
    }

    func addLabResult(_ result: LabResult) {
        labResults.append(result)
        saveLabResultToStore(result)
    }

    func updateLabResult(_ result: LabResult) {
        if let index = labResults.firstIndex(where: { $0.id == result.id }) {
            labResults[index] = result
            removeLabResultFromStore(result)
            saveLabResultToStore(result)
        }
    }

    func removeLabResult(_ result: LabResult) {
        labResults.removeAll { $0.id == result.id }
        removeLabResultFromStore(result)
    }

    func clearAllLabResults() {
        let toRemove = labResults
        labResults.removeAll()
        for lab in toRemove {
            removeLabResultFromStore(lab)
        }
    }

    func clearAllEvents() {
        let toRemove = events
        events.removeAll()
        for event in toRemove {
            removeFromStore(event)
        }
        result = nil
    }

    // MARK: - Simulation

    func runSimulation() {
        simulationTask?.cancel()
        guard !events.isEmpty else {
            result = nil
            isSimulating = false
            return
        }

        let sortedEvents = events
        let weight = bodyWeightKG
        isSimulating = true

        simulationTask = Task(priority: .userInitiated) {
            let startTime = (sortedEvents.first?.timestamp ?? 0) - 24 * 3600
            let endTime = (sortedEvents.last?.timestamp ?? startTime) + 24 * 14 * 3600
            let engine = SimulationEngine(
                events: sortedEvents,
                bodyWeightKG: weight,
                startTimestamp: startTime,
                endTimestamp: endTime,
                numberOfSteps: 1000
            )
            let simResult = engine.run()

            if Task.isCancelled { return }
            self.result = simResult
            self.isSimulating = false
        }
    }

    func concentration(at date: Date) -> Double? {
        result?.concentration(at: Int64(date.timeIntervalSince1970))
    }

    // MARK: - HealthKit Body Mass

    #if !OPENSOURCE
    func requestHealthKitAuthorization() async {
        do {
            try await healthKitService.requestAuthorizationIfNeeded()
            isHealthKitAuthorized = true
            healthKitError = nil
        } catch {
            healthKitError = error.localizedDescription
        }
    }

    func importWeightFromHealthKit() async {
        do {
            let kg = try await healthKitService.fetchLatestBodyMassKG()
            bodyWeightKG = kg
            lastHealthKitSync = Date()
            healthKitError = nil
        } catch {
            healthKitError = error.localizedDescription
        }
    }

    func syncWeightToHealthKit() async {
        do {
            try await healthKitService.saveBodyMassKG(bodyWeightKG)
            lastHealthKitSync = Date()
            healthKitError = nil
        } catch {
            healthKitError = error.localizedDescription
        }
    }

    /// Silently refresh weight from HealthKit in background.
    func refreshWeightSilently() async {
        do {
            let kg = try await healthKitService.fetchLatestBodyMassKG()
            bodyWeightKG = kg
            lastHealthKitSync = Date()
        } catch {
            // Silent — don't surface errors for background sync
        }
    }

    /// Start observing HealthKit changes for automatic sync.
    func startObservingHealthKit() {
        healthKitService.observeBodyMassChanges { [weak self] in
            Task { @MainActor in
                await self?.refreshWeightSilently()
            }
        }
        healthKitService.observeMedicationDoseEvents { [weak self] in
            Task { @MainActor in
                await self?.importDoseEventsFromHealthKit()
            }
        }
    }

    // MARK: - Medications

    func requestMedicationAuthorization() async {
        do {
            try await healthKitService.requestMedicationAuthorization()
            healthKitError = nil
        } catch {
            healthKitError = error.localizedDescription
        }
    }

    func fetchMedicationsFromHealthKit() async {
        do {
            medications = try await healthKitService.fetchMedications()
            healthKitError = nil
        } catch {
            healthKitError = error.localizedDescription
        }
    }

    func importDoseEventsFromHealthKit() async {
        do {
            let since = Calendar.current.date(byAdding: .month, value: -6, to: Date()) ?? Date()

            // Build mappings and collect mapped medication IDs
            var mappingsByID: [String: MedicationMapping] = [:]
            for medication in medications {
                var mapping = medicationMappings.first(where: { $0.id == medication.id })

                if mapping == nil {
                    if let recognized = MedicationRecognizer.recognize(medication.displayName) {
                        let strengthMG = MedicationRecognizer.parseStrengthMG(medication.displayName)
                        if recognized.ester == .CPA, let mg = strengthMG {
                            // CPA always oral + strength parsed → auto-map
                            let newMapping = MedicationMapping(
                                id: medication.id,
                                displayName: medication.displayName,
                                route: .oral,
                                ester: .CPA,
                                doseMG: mg
                            )
                            saveMedicationMapping(newMapping)
                            mapping = newMapping
                        } else if let route = medication.route, let mg = strengthMG {
                            // Ester recognized + route from HealthKit + strength parsed → auto-map
                            let newMapping = MedicationMapping(
                                id: medication.id,
                                displayName: medication.displayName,
                                route: route,
                                ester: recognized.ester,
                                doseMG: mg
                            )
                            saveMedicationMapping(newMapping)
                            mapping = newMapping
                        }
                        // else: can't fully resolve → fall through to unmapped
                    }
                }

                if let mapping {
                    mappingsByID[medication.id] = mapping
                } else if !unmappedMedications.contains(where: { $0.id == medication.id }) {
                    unmappedMedications.append(medication)
                }
            }

            let allDoseEvents = try await healthKitService.fetchDoseEventsForMedications(
                ids: Set(mappingsByID.keys),
                since: since
            )
            for info in allDoseEvents {
                if let existingID = UUID(uuidString: info.id),
                   events.contains(where: { $0.id == existingID }) {
                    continue
                }
                guard let mapping = mappingsByID[info.medicationConceptID] else { continue }
                if let event = MedicationDoseEventMapper.fromHealthKit(
                    info,
                    route: mapping.route,
                    ester: mapping.ester,
                    doseMG: mapping.doseMG,
                    extras: mapping.extras
                ) {
                    events.append(event)
                    saveToStore(event)
                }
            }
            events.sort { $0.timestamp < $1.timestamp }
            runSimulation()
            healthKitError = nil
        } catch {
            healthKitError = error.localizedDescription
        }
    }
    #endif

    // MARK: - Template CRUD

    func saveTemplate(_ template: DoseTemplate) {
        if let index = templates.firstIndex(where: { $0.id == template.id }) {
            templates[index] = template
        } else {
            templates.append(template)
        }
        saveTemplateToStore(template)
    }

    func removeTemplate(_ template: DoseTemplate) {
        templates.removeAll { $0.id == template.id }
        removeTemplateFromStore(template)
    }

    // MARK: - Medication Mapping CRUD

    func saveMedicationMapping(_ mapping: MedicationMapping) {
        if let index = medicationMappings.firstIndex(where: { $0.id == mapping.id }) {
            medicationMappings[index] = mapping
        } else {
            medicationMappings.append(mapping)
        }
        // Remove from unmapped list
        unmappedMedications.removeAll { $0.id == mapping.id }
        saveMappingToStore(mapping)
    }

    func removeMedicationMapping(_ mapping: MedicationMapping) {
        medicationMappings.removeAll { $0.id == mapping.id }
        removeMappingFromStore(mapping)
    }

    // MARK: - SwiftData persistence

    private func loadFromStore() {
        do {
            let eventRecords = try modelContext.fetch(FetchDescriptor<DoseEventRecord>())
            events = eventRecords.compactMap { $0.toDoseEvent() }.sorted { $0.timestamp < $1.timestamp }

            let labRecords = try modelContext.fetch(FetchDescriptor<LabResultRecord>())
            labResults = labRecords.compactMap { $0.toLabResult() }.sorted { $0.timestamp < $1.timestamp }

            let templateRecords = try modelContext.fetch(FetchDescriptor<DoseTemplateRecord>())
            templates = templateRecords.compactMap { $0.toDoseTemplate() }.sorted { $0.createdAt < $1.createdAt }

            let mappingRecords = try modelContext.fetch(FetchDescriptor<MedicationMappingRecord>())
            medicationMappings = mappingRecords.compactMap { $0.toMedicationMapping() }
        } catch {
            print("Failed to load from store: \(error)")
        }
    }

    private func saveToStore(_ event: DoseEvent) {

        let descriptor = FetchDescriptor<DoseEventRecord>(
            predicate: #Predicate { $0.eventID == event.id }
        )
        do {
            let existing = try modelContext.fetch(descriptor)
            if let record = existing.first {
                record.routeRaw = event.route.rawValue
                record.timestamp = event.timestamp
                record.doseMG = event.doseMG
                record.esterRaw = event.ester.rawValue
                if !event.extras.isEmpty {
                    let stringDict = Dictionary(uniqueKeysWithValues: event.extras.map { ($0.key.rawValue, $0.value) })
                    record.extrasData = try? JSONEncoder().encode(stringDict)
                } else {
                    record.extrasData = nil
                }
            } else {
                modelContext.insert(DoseEventRecord.from(event))
            }
            try modelContext.save()
        } catch {
            print("Failed to save event: \(error)")
        }
    }

    private func removeFromStore(_ event: DoseEvent) {

        let descriptor = FetchDescriptor<DoseEventRecord>(
            predicate: #Predicate { $0.eventID == event.id }
        )
        do {
            let existing = try modelContext.fetch(descriptor)
            for record in existing {
                modelContext.delete(record)
            }
            try modelContext.save()
        } catch {
            print("Failed to delete event: \(error)")
        }
    }

    private func saveLabResultToStore(_ result: LabResult) {

        modelContext.insert(LabResultRecord.from(result))
        try? modelContext.save()
    }

    private func removeLabResultFromStore(_ result: LabResult) {

        let descriptor = FetchDescriptor<LabResultRecord>(
            predicate: #Predicate { $0.resultID == result.id }
        )
        do {
            let existing = try modelContext.fetch(descriptor)
            for record in existing {
                modelContext.delete(record)
            }
            try modelContext.save()
        } catch {
            print("Failed to delete lab result: \(error)")
        }
    }

    private func saveTemplateToStore(_ template: DoseTemplate) {

        let descriptor = FetchDescriptor<DoseTemplateRecord>(
            predicate: #Predicate { $0.templateID == template.id }
        )
        do {
            let existing = try modelContext.fetch(descriptor)
            if let record = existing.first {
                record.name = template.name
                record.routeRaw = template.route.rawValue
                record.esterRaw = template.ester.rawValue
                record.doseMG = template.doseMG
                if !template.extras.isEmpty {
                    let stringDict = Dictionary(uniqueKeysWithValues: template.extras.map { ($0.key.rawValue, $0.value) })
                    record.extrasData = try? JSONEncoder().encode(stringDict)
                } else {
                    record.extrasData = nil
                }
            } else {
                modelContext.insert(DoseTemplateRecord.from(template))
            }
            try modelContext.save()
        } catch {
            print("Failed to save template: \(error)")
        }
    }

    private func removeTemplateFromStore(_ template: DoseTemplate) {

        let descriptor = FetchDescriptor<DoseTemplateRecord>(
            predicate: #Predicate { $0.templateID == template.id }
        )
        do {
            let existing = try modelContext.fetch(descriptor)
            for record in existing {
                modelContext.delete(record)
            }
            try modelContext.save()
        } catch {
            print("Failed to delete template: \(error)")
        }
    }

    private func saveMappingToStore(_ mapping: MedicationMapping) {

        let conceptID = mapping.id
        let descriptor = FetchDescriptor<MedicationMappingRecord>(
            predicate: #Predicate { $0.medicationConceptID == conceptID }
        )
        do {
            let existing = try modelContext.fetch(descriptor)
            if let record = existing.first {
                record.displayName = mapping.displayName
                record.routeRaw = mapping.route.rawValue
                record.esterRaw = mapping.ester.rawValue
                record.doseMG = mapping.doseMG
                if !mapping.extras.isEmpty {
                    let stringDict = Dictionary(uniqueKeysWithValues: mapping.extras.map { ($0.key.rawValue, $0.value) })
                    record.extrasData = try? JSONEncoder().encode(stringDict)
                } else {
                    record.extrasData = nil
                }
            } else {
                modelContext.insert(MedicationMappingRecord.from(mapping))
            }
            try modelContext.save()
        } catch {
            print("Failed to save mapping: \(error)")
        }
    }

    private func removeMappingFromStore(_ mapping: MedicationMapping) {

        let conceptID = mapping.id
        let descriptor = FetchDescriptor<MedicationMappingRecord>(
            predicate: #Predicate { $0.medicationConceptID == conceptID }
        )
        do {
            let existing = try modelContext.fetch(descriptor)
            for record in existing {
                modelContext.delete(record)
            }
            try modelContext.save()
        } catch {
            print("Failed to delete mapping: \(error)")
        }
    }

    // MARK: - Grouping

    private func groupEventsByDay(_ events: [DoseEvent]) -> [DayGroup] {
        let sorted = events.sorted { $0.timestamp < $1.timestamp }
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.setLocalizedDateFormatFromTemplate("yMMMMdEEEE")

        let grouped = Dictionary(grouping: sorted) { formatter.string(from: $0.date) }
        return grouped.map { DayGroup(day: $0.key, events: $0.value) }
            .sorted { ($0.events.first?.timestamp ?? 0) > ($1.events.first?.timestamp ?? 0) }
    }
}
