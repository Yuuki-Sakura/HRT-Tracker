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
    #else
    let isHealthKitAuthorized = false
    let lastHealthKitSync: Date? = nil
    var healthKitError: String?
    let isMedicationSyncEnabled = false
    let medications: [MedicationInfo] = []
    #endif

    // MARK: - Reminder Properties

    @Published var templates: [DoseTemplate] = []
    @Published var pendingTemplateFromNotification: DoseTemplate?

    private let weightKey = "user.weightKg"
    private var cancellables = Set<AnyCancellable>()
    private var simulationTask: Task<Void, Never>?
    private var modelContext: ModelContext?

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

    /// Get templates that have reminders configured.
    var templatesWithReminders: [DoseTemplate] {
        templates.filter { $0.reminderIntervalHours != nil }
    }

    /// Find the most recent DoseEvent matching a template (by ester + route).
    func lastDose(for template: DoseTemplate) -> DoseEvent? {
        events
            .filter { $0.ester == template.ester && $0.route == template.route }
            .max(by: { $0.timestamp < $1.timestamp })
    }

    /// Compute the next reminder date for a specific template.
    func nextReminderDate(for template: DoseTemplate) -> Date? {
        guard let intervalHours = template.reminderIntervalHours, intervalHours > 0 else { return nil }

        let calendar = Calendar.current
        let timeSource = template.reminderTimeOfDay ?? {
            var c = calendar.dateComponents([.year, .month, .day], from: Date())
            c.hour = 9; c.minute = 0
            return calendar.date(from: c) ?? Date()
        }()
        let timeComponents = calendar.dateComponents([.hour, .minute], from: timeSource)

        let baseDate: Date
        if let lastDose = lastDose(for: template) {
            baseDate = lastDose.date.addingTimeInterval(intervalHours * 3600)
        } else {
            baseDate = Date()
        }

        var nextComponents = calendar.dateComponents([.year, .month, .day], from: baseDate)
        nextComponents.hour = timeComponents.hour
        nextComponents.minute = timeComponents.minute

        guard let candidate = calendar.date(from: nextComponents) else { return baseDate }
        var result = candidate
        while result <= Date() {
            guard let next = calendar.date(byAdding: .day, value: 1, to: result) else { break }
            result = next
        }
        return result
    }

    init() {
        let saved = UserDefaults.standard.double(forKey: weightKey)
        self.bodyWeightKG = saved > 0 ? saved : 70.0

        #if !OPENSOURCE
        self.isHealthKitAuthorized = UserDefaults.standard.bool(forKey: "hk.authorized")

        let syncTS = UserDefaults.standard.double(forKey: "hk.lastSync")
        self.lastHealthKitSync = syncTS > 0 ? Date(timeIntervalSince1970: syncTS) : nil

        self.isMedicationSyncEnabled = UserDefaults.standard.bool(forKey: "hk.medicationSync")
        #endif

        setupSubscriptions()
    }

    func configure(modelContext: ModelContext) {
        self.modelContext = modelContext
        loadFromStore()
        runSimulation()
    }

    static var preview: TimelineViewModel {
        let vm = TimelineViewModel()
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

        // Reschedule reminder for matching template after new dose
        updateRemindersAfterDose(event)
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
        if isMedicationSyncEnabled {
            healthKitService.observeMedicationDoseEvents { [weak self] in
                Task { @MainActor in
                    await self?.importDoseEventsFromHealthKit()
                }
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
            for medication in medications {
                let doseEvents = try await healthKitService.fetchDoseEvents(
                    for: medication.id,
                    since: since
                )
                for info in doseEvents {
                    // Skip if we already have this event
                    if let existingID = UUID(uuidString: info.id),
                       events.contains(where: { $0.id == existingID }) {
                        continue
                    }
                    // Default to injection/EV for imported events — user can edit later
                    if let event = MedicationDoseEventMapper.fromHealthKit(
                        info,
                        route: .injection,
                        ester: .EV
                    ) {
                        events.append(event)
                        saveToStore(event)
                    }
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

    // MARK: - Dose Reminders

    func scheduleAllReminders() {
        // Cancel all existing reminders first
        NotificationService.shared.cancelAllDoseReminders()

        for template in templatesWithReminders {
            scheduleReminder(for: template)
        }
    }

    func cancelAllReminders() {
        NotificationService.shared.cancelAllDoseReminders()
    }

    func updateRemindersAfterDose(_ event: DoseEvent) {
        // Find matching template and reschedule its reminder
        for template in templatesWithReminders {
            if event.ester == template.ester && event.route == template.route {
                scheduleReminder(for: template)
            }
        }
    }

    private func scheduleReminder(for template: DoseTemplate) {
        guard let nextDate = nextReminderDate(for: template) else { return }
        let title = String(localized: "notification.dose.title")
        let body = String(format: String(localized: "notification.dose.body.template"), template.name)
        NotificationService.shared.scheduleDoseReminder(
            id: template.id.uuidString,
            at: nextDate,
            title: title,
            body: body
        )
    }

    // MARK: - Template CRUD

    func saveTemplate(_ template: DoseTemplate) {
        if let index = templates.firstIndex(where: { $0.id == template.id }) {
            templates[index] = template
        } else {
            templates.append(template)
        }
        saveTemplateToStore(template)

        // Update reminder for this template
        if template.reminderIntervalHours != nil {
            scheduleReminder(for: template)
        } else {
            NotificationService.shared.cancelDoseReminder(id: template.id.uuidString)
        }
    }

    func removeTemplate(_ template: DoseTemplate) {
        templates.removeAll { $0.id == template.id }
        removeTemplateFromStore(template)
        NotificationService.shared.cancelDoseReminder(id: template.id.uuidString)
    }

    // MARK: - SwiftData persistence

    private func loadFromStore() {
        guard let context = modelContext else { return }
        do {
            let eventRecords = try context.fetch(FetchDescriptor<DoseEventRecord>())
            events = eventRecords.compactMap { $0.toDoseEvent() }.sorted { $0.timestamp < $1.timestamp }

            let labRecords = try context.fetch(FetchDescriptor<LabResultRecord>())
            labResults = labRecords.compactMap { $0.toLabResult() }.sorted { $0.timestamp < $1.timestamp }

            let templateRecords = try context.fetch(FetchDescriptor<DoseTemplateRecord>())
            templates = templateRecords.compactMap { $0.toDoseTemplate() }.sorted { $0.createdAt < $1.createdAt }
        } catch {
            print("Failed to load from store: \(error)")
        }
    }

    private func saveToStore(_ event: DoseEvent) {
        guard let context = modelContext else { return }
        let descriptor = FetchDescriptor<DoseEventRecord>(
            predicate: #Predicate { $0.eventID == event.id }
        )
        do {
            let existing = try context.fetch(descriptor)
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
                context.insert(DoseEventRecord.from(event))
            }
            try context.save()
        } catch {
            print("Failed to save event: \(error)")
        }
    }

    private func removeFromStore(_ event: DoseEvent) {
        guard let context = modelContext else { return }
        let descriptor = FetchDescriptor<DoseEventRecord>(
            predicate: #Predicate { $0.eventID == event.id }
        )
        do {
            let existing = try context.fetch(descriptor)
            for record in existing {
                context.delete(record)
            }
            try context.save()
        } catch {
            print("Failed to delete event: \(error)")
        }
    }

    private func saveLabResultToStore(_ result: LabResult) {
        guard let context = modelContext else { return }
        context.insert(LabResultRecord.from(result))
        try? context.save()
    }

    private func removeLabResultFromStore(_ result: LabResult) {
        guard let context = modelContext else { return }
        let descriptor = FetchDescriptor<LabResultRecord>(
            predicate: #Predicate { $0.resultID == result.id }
        )
        do {
            let existing = try context.fetch(descriptor)
            for record in existing {
                context.delete(record)
            }
            try context.save()
        } catch {
            print("Failed to delete lab result: \(error)")
        }
    }

    private func saveTemplateToStore(_ template: DoseTemplate) {
        guard let context = modelContext else { return }
        let descriptor = FetchDescriptor<DoseTemplateRecord>(
            predicate: #Predicate { $0.templateID == template.id }
        )
        do {
            let existing = try context.fetch(descriptor)
            if let record = existing.first {
                record.name = template.name
                record.routeRaw = template.route.rawValue
                record.esterRaw = template.ester.rawValue
                record.doseMG = template.doseMG
                record.reminderIntervalHours = template.reminderIntervalHours
                if let timeOfDay = template.reminderTimeOfDay {
                    let components = Calendar.current.dateComponents([.hour, .minute], from: timeOfDay)
                    record.reminderTimeMinutesSinceMidnight = (components.hour ?? 0) * 60 + (components.minute ?? 0)
                } else {
                    record.reminderTimeMinutesSinceMidnight = nil
                }
                if !template.extras.isEmpty {
                    let stringDict = Dictionary(uniqueKeysWithValues: template.extras.map { ($0.key.rawValue, $0.value) })
                    record.extrasData = try? JSONEncoder().encode(stringDict)
                } else {
                    record.extrasData = nil
                }
            } else {
                context.insert(DoseTemplateRecord.from(template))
            }
            try context.save()
        } catch {
            print("Failed to save template: \(error)")
        }
    }

    private func removeTemplateFromStore(_ template: DoseTemplate) {
        guard let context = modelContext else { return }
        let descriptor = FetchDescriptor<DoseTemplateRecord>(
            predicate: #Predicate { $0.templateID == template.id }
        )
        do {
            let existing = try context.fetch(descriptor)
            for record in existing {
                context.delete(record)
            }
            try context.save()
        } catch {
            print("Failed to delete template: \(error)")
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
