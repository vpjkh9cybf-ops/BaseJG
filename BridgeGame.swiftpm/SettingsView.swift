// BRIDGE APP — Built 2026-06-07
import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var game: GameState
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            Form {
                Section("Game") {
                    Toggle("Switch seats when North declares", isOn: $game.switchSeatsForDeclarer)
                    Text(game.switchSeatsForDeclarer
                         ? "You play North's cards (and South dummy) when North wins the bid."
                         : "AI plays as declarer when North wins the bid. You play South's dummy cards.")
                        .font(.caption)
                        .foregroundColor(.secondary)

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

                    Picker("Scoring Mode", selection: $game.scoringMode) {
                        ForEach(ScoringMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Section("Stayman") {
                    Toggle("Enable Stayman", isOn: $game.conventionSettings.staymanEnabled)
                    if game.conventionSettings.staymanEnabled {
                        Picker("Variant", selection: $game.conventionSettings.staymanVariant) {
                            ForEach(StaymanVariant.allCases, id: \.self) { v in
                                Text(v.rawValue).tag(v)
                            }
                        }
                        .pickerStyle(.menu)
                    }
                }

                Section("Jacoby Transfers") {
                    Toggle("Enable Jacoby Transfers", isOn: $game.conventionSettings.jacobyTransfersEnabled)
                    if game.conventionSettings.jacobyTransfersEnabled {
                        Toggle("Active over interference", isOn: $game.conventionSettings.transfersOverInterference)
                        Stepper("Super-accept: \(game.conventionSettings.superAcceptThreshold)+ HCP",
                                value: $game.conventionSettings.superAcceptThreshold, in: 17...18)
                    }
                }

                Section("New Minor Forcing") {
                    Toggle("Enable NMF", isOn: $game.conventionSettings.nmfEnabled)
                    if game.conventionSettings.nmfEnabled {
                        Toggle("2\u{2663} rebid triggers NMF", isOn: $game.conventionSettings.nmfInclude2C)
                    }
                }

                Section("XYZ (Two-Way New Minor)") {
                    Toggle("Enable XYZ", isOn: $game.conventionSettings.xyzEnabled)
                }

                Section("Jacoby 2NT") {
                    Toggle("Enable Jacoby 2NT", isOn: $game.conventionSettings.jacoby2NTEnabled)
                }

                Section("Splinters") {
                    Toggle("Enable Splinters", isOn: $game.conventionSettings.splinterEnabled)
                    if game.conventionSettings.splinterEnabled {
                        Stepper("Min HCP: \(game.conventionSettings.splinterMinHCP)",
                                value: $game.conventionSettings.splinterMinHCP, in: 13...16)
                    }
                }

                Section("Takeout Doubles") {
                    Toggle("Enable Takeout Doubles", isOn: $game.conventionSettings.takeoutDoubleEnabled)
                    if game.conventionSettings.takeoutDoubleEnabled {
                        Stepper("Min HCP: \(game.conventionSettings.takeoutDoubleMinHCP)",
                                value: $game.conventionSettings.takeoutDoubleMinHCP, in: 12...14)
                    }
                }

                Section("Overcalls") {
                    Toggle("Enable Overcalls", isOn: $game.conventionSettings.overcallEnabled)
                    if game.conventionSettings.overcallEnabled {
                        Picker("Style", selection: $game.conventionSettings.overcallStyle) {
                            ForEach(OvercallStyle.allCases, id: \.self) { s in
                                Text(s.rawValue).tag(s)
                            }
                        }
                        .pickerStyle(.menu)
                        Stepper("2-level min HCP: \(game.conventionSettings.overcall2LevelMinHCP)",
                                value: $game.conventionSettings.overcall2LevelMinHCP, in: 8...14)
                    }
                }

                Section("Display") {
                    Toggle("Alt suit colors (\u{2663} blue / \u{2666} orange)", isOn: $game.conventionSettings.useAlternateColors)
                }

                Section {
                    Button("Reset to Defaults", role: .destructive) {
                        game.conventionSettings = ConventionSettings.defaults
                    }
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
