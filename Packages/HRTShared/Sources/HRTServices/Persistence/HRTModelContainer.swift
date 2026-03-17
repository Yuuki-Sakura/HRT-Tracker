import Foundation
import SwiftData

public enum HRTModelContainer {
    public static func create() throws -> ModelContainer {
        let schema = Schema([
            DoseEventRecord.self,
            LabResultRecord.self,
            DoseTemplateRecord.self,
            MedicationMappingRecord.self,
        ])

        #if !OPENSOURCE
        let config = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .private("iCloud.sakura.hrttracker")
        )
        #else
        let config = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .none
        )
        #endif

        return try ModelContainer(for: schema, configurations: [config])
    }
}
