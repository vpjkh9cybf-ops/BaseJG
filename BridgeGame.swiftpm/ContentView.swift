// BRIDGE APP — Built 2026-06-07
import SwiftUI

struct ContentView: View {
    @EnvironmentObject var game: GameState

    var body: some View {
        Group {
            if game.phase == .menu {
                MenuView()
            } else {
                GameTableView()
            }
        }
        .animation(.easeInOut(duration: 0.3), value: game.phase == .menu)
    }
}

struct MenuView: View {
    @EnvironmentObject var game: GameState
    @State private var showConventionPicker = false

    private var startTitle: String {
        game.scoringMode == .chicago ? "New Chicago" : "New Rubber"
    }

    var body: some View {
        ZStack {
            Color(red: 0.08, green: 0.40, blue: 0.15)
                .ignoresSafeArea()

            VStack(spacing: 28) {
                VStack(spacing: 8) {
                    Text("♠ ♥ Bridge ♦ ♣")
                        .font(.system(size: 42, weight: .bold, design: .serif))
                        .foregroundColor(.white)

                    Text("Standard American · SAYC · RKCB")
                        .font(.callout)
                        .foregroundColor(.white.opacity(0.7))
                }

                // Scoring mode picker
                VStack(spacing: 8) {
                    Text("Scoring")
                        .font(.caption.bold())
                        .foregroundColor(.white.opacity(0.6))
                    Picker("Scoring Mode", selection: $game.scoringMode) {
                        ForEach(ScoringMode.allCases, id: \.self) { mode in
                            Text(mode.rawValue).tag(mode)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 220)
                    Text(game.scoringMode == .chicago
                         ? "4 deals · fixed vulnerability · game bonus per hand"
                         : "2 games to win · points accumulate across hands")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.5))
                        .multilineTextAlignment(.center)
                        .frame(width: 240)
                }

                MenuButton(title: startTitle, icon: "suit.spade.fill") {
                    game.startNewRubber()
                }

                MenuButton(title: "Convention Practice", icon: "graduationcap.fill") {
                    showConventionPicker = true
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Conventions included:")
                        .font(.caption.bold())
                        .foregroundColor(.white.opacity(0.6))
                    ForEach([
                        "Stayman", "Jacoby Transfers",
                        "Jacoby 2NT", "RKCB (1430 / 0314)",
                        "Weak 2 openings", "Negative Doubles",
                        "2/1 Game Force", "Splinters", "Drury"
                    ], id: \.self) { conv in
                        Text("• \(conv)")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.55))
                    }
                }
            }
            .padding(40)
        }
        .sheet(isPresented: $showConventionPicker) { ConventionPickerView() }
    }
}

struct ConventionPickerView: View {
    @EnvironmentObject var game: GameState
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            List(PracticeConvention.allCases) { convention in
                Button {
                    dismiss()
                    game.startPractice(convention: convention)
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(convention.rawValue)
                            .font(.headline)
                            .foregroundColor(.primary)
                        Text(convention.subtitle)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Convention Practice")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }
}

struct MenuButton: View {
    let title: String
    let icon: String
    var disabled: Bool = false
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title3)
                Text(title)
                    .font(.title3.bold())
            }
            .foregroundColor(disabled ? .white.opacity(0.4) : .white)
            .frame(width: 220, height: 52)
            .background(disabled ? Color.white.opacity(0.1) : Color.blue.opacity(0.85))
            .cornerRadius(14)
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
        }
        .disabled(disabled)
    }
}
