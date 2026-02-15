import SwiftUI

@main
struct StickballTrackerApp: App {
    @StateObject private var cloudService = CloudSyncService()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(cloudService)
                .preferredColorScheme(.dark)
        }
    }
}
