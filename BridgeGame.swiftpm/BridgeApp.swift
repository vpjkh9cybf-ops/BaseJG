// Conventional Wisdom — modified 2026-06-07 03:07 UTC
import SwiftUI

@main
struct BridgeApp: App {
    @StateObject private var game = GameState()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(game)
                .preferredColorScheme(.light)
        }
    }
}
