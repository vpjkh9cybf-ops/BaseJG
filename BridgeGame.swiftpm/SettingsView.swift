// BRIDGE APP — Built 2026-06-07
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var game: GameState
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            Form {
                Section("Declarer Play") {
                    Toggle("Switch seats when North declares", isOn: $game.switchSeatsForDeclarer)
                    Text(game.switchSeatsForDeclarer
                         ? "You play North's cards (and South dummy) when North wins the bid."
                         : "AI plays as declarer when North wins the bid. You play South's dummy cards.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .navigationViewStyle(.stack)
    }
}
