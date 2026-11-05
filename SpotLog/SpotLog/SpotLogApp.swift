import SwiftUI
import SwiftData

@main
struct SpotLogApp: App {
    var body: some Scene {
        WindowGroup {
            HomePage()
        }
        .modelContainer(for: FavoritePlaces.self)
    }
}
