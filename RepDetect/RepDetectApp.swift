import SwiftData
import SwiftUI

@main
struct RepDetectApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([PlanItem.self, WorkoutResultEntity.self])
        let config = ModelConfiguration(isStoredInMemoryOnly: false)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            fatalError("ModelContainer error: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
