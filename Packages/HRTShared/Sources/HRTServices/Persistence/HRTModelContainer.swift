import Foundation
import SwiftData

public enum HRTModelContainer {
    public static func create(inMemory: Bool = false, cloudKit: Bool = false, deleteStoreOnFailure: Bool = false) throws -> ModelContainer {
        let schema = Schema([
            DoseEventRecord.self,
            LabResultRecord.self,
            DoseTemplateRecord.self,
            MedicationMappingRecord.self,
        ])

        #if !OPENSOURCE
        if cloudKit && !inMemory {
            // Try CloudKit first, fall back to local if it fails
            do {
                let config = ModelConfiguration(
                    schema: schema,
                    isStoredInMemoryOnly: false,
                    cloudKitDatabase: .private("iCloud.com.hrt.tracker")
                )
                return try ModelContainer(for: schema, configurations: [config])
            } catch {
                print("CloudKit ModelContainer failed, falling back to local: \(error)")
            }
        }
        #endif

        let config = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: inMemory,
            cloudKitDatabase: .none
        )

        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            guard deleteStoreOnFailure, !inMemory else { throw error }
            print("ModelContainer failed, deleting store and retrying: \(error)")
            Self.deleteStoreFiles(at: config.url)
            return try ModelContainer(for: schema, configurations: [config])
        }
    }

    private static func deleteStoreFiles(at url: URL) {
        let fm = FileManager.default
        let base = url.path()
        for suffix in ["", "-wal", "-shm"] {
            try? fm.removeItem(atPath: base + suffix)
        }
    }
}
