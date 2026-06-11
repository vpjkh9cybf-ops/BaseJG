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

                Section("Slam Conventions") {
                    Picker("RKCB Response Style", selection: $game.rkcbFlavor) {
                        ForEach(RKCBFlavor.allCases, id: \.self) { flavor in
                            Text(flavor.rawValue).tag(flavor)
                        }
                    }
                    .pickerStyle(.segmented)
                    Text(game.rkcbFlavor == .f1430
                         ? "1430: 5\u{2663} = 1 or 4 key cards, 5\u{2666} = 0 or 3 key cards"
                         : "0314: 5\u{2663} = 0 or 3 key cards, 5\u{2666} = 1 or 4 key cards")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text("Key cards = 4 aces + king of agreed trump suit. 5\u{2665} = 2 no trump Q, 5\u{2660} = 2 with trump Q.")
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
