import SwiftUI
import SwiftData

@main
struct wallpaperApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            MediaItem.self,
            Album.self,
            Rule.self,
            ScreenProfile.self,
            History.self,
        ])
        let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)

        do {
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            fatalError("Could not create ModelContainer: \(error)")
        }
    }()

    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(sharedModelContainer)
    }
}
