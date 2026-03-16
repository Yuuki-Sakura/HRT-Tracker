import Foundation
import SwiftData
import HRTModels

public struct MigrationService: Sendable {
    public static func migrateLegacyDataIfNeeded(context: ModelContext) {
        let migrationKey = "hrt.migration.v1.complete"
        guard !UserDefaults.standard.bool(forKey: migrationKey) else { return }

        guard let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return }
        let legacyFile = appSupport.appendingPathComponent("dose_events.json")

        guard FileManager.default.fileExists(atPath: legacyFile.path) else {
            UserDefaults.standard.set(true, forKey: migrationKey)
            return
        }

        do {
            let data = try Data(contentsOf: legacyFile)
            let events = try JSONDecoder().decode([DoseEvent].self, from: data)

            for event in events {
                let record = DoseEventRecord.from(event)
                context.insert(record)
            }

            try context.save()
            try FileManager.default.removeItem(at: legacyFile)
            UserDefaults.standard.set(true, forKey: migrationKey)
        } catch {
            print("Migration failed: \(error)")
        }
    }
}
