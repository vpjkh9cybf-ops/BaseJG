// Conventional Wisdom — modified 2026-08-15 01:53 UTC
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
    @State private var showSettings = false

    private let felt = Color(red: 0.08, green: 0.40, blue: 0.15)
    private let cardRed = Color(red: 1.0, green: 0.35, blue: 0.35)

    var body: some View {
        ZStack {
            felt.ignoresSafeArea()

            VStack(spacing: 0) {
                header
                Spacer(minLength: 20)
                // Four choices across the width — landscape has the room, and
                // each card carries its own explanation instead of leaving
                // captions floating beside a picker.
                HStack(alignment: .top, spacing: 18) {
                    MenuCard(icon: "suit.spade.fill",
                             tint: .white,
                             title: "New Rubber",
                             subtitle: "Two games to win. Points carry over above and below the line.") {
                        game.scoringMode = .rubber
                        game.startNewRubber()
                    }

                    MenuCard(icon: "square.grid.2x2.fill",
                             tint: Color(red: 1.0, green: 0.72, blue: 0.3),
                             title: "New Chicago",
                             subtitle: "Four deals, fixed vulnerability, game bonus paid every hand.") {
                        game.scoringMode = .chicago
                        game.startNewRubber()
                    }

                    MenuCard(icon: "graduationcap.fill",
                             tint: Color(red: 0.45, green: 0.8, blue: 1.0),
                             title: "Convention Practice",
                             subtitle: "Drill Stayman, transfers, Jacoby 2NT, weak twos, 2/1 and more on hands built for them.") {
                        showConventionPicker = true
                    }

                    MenuCard(icon: "slider.horizontal.3",
                             tint: Color(red: 0.72, green: 0.9, blue: 0.6),
                             title: "Convention Card",
                             subtitle: "Choose your variations — the AI bids whatever you set here.") {
                        showSettings = true
                    }
                }
                .padding(.horizontal, 32)
                Spacer(minLength: 20)
            }
            .padding(.vertical, 28)
        }
        .sheet(isPresented: $showConventionPicker) {
            ConventionPickerView().environmentObject(game)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView().environmentObject(game)
        }
    }

    private var header: some View {
        VStack(spacing: 8) {
            HStack(spacing: 16) {
                HStack(spacing: 6) {
                    Text("♠").foregroundColor(.white)
                    Text("♥").foregroundColor(cardRed)
                }
                .font(.system(size: 40, weight: .bold, design: .serif))

                Text("Conventional Wisdom")
                    .font(.system(size: 50, weight: .bold, design: .serif))
                    .foregroundColor(.white)

                HStack(spacing: 6) {
                    Text("♦").foregroundColor(cardRed)
                    Text("♣").foregroundColor(.white)
                }
                .font(.system(size: 40, weight: .bold, design: .serif))
            }
            .minimumScaleFactor(0.5)
            .lineLimit(1)

            Text("Contract Bridge · Rubber & Chicago · Standard American · SAYC")
                .font(.title3)
                .foregroundColor(.white.opacity(0.7))
        }
    }
}

/// A large tappable card. The whole thing is the button, and the explanation
/// lives on it rather than as loose text nearby.
struct MenuCard: View {
    let icon: String
    let tint: Color
    let title: String
    let subtitle: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 38, weight: .semibold))
                    .foregroundColor(tint)

                Text(title)
                    .font(.title2.bold())
                    .foregroundColor(.white)
                    .fixedSize(horizontal: false, vertical: true)

                Text(subtitle)
                    .font(.callout)
                    .foregroundColor(.white.opacity(0.78))
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 0)
            }
            .padding(22)
            .frame(maxWidth: .infinity, minHeight: 240, alignment: .topLeading)
            .background(Color.white.opacity(0.10))
            .cornerRadius(20)
            .overlay(
                RoundedRectangle(cornerRadius: 20)
                    .stroke(tint.opacity(0.5), lineWidth: 1.5)
            )
        }
        .buttonStyle(.plain)
        .contentShape(Rectangle())
    }
}

/// Multi-select drill picker. Every deal is then constructed so that one of the
/// chosen conventions actually comes up in the auction.
struct ConventionPickerView: View {
    @EnvironmentObject var game: GameState
    @Environment(\.dismiss) var dismiss
    @State private var selected: Set<PracticeConvention> = []

    private var countLabel: String {
        selected.count == 1 ? "1 convention selected"
                            : "\(selected.count) conventions selected"
    }

    private var allSelected: Bool {
        selected.count == PracticeConvention.allCases.count
    }

    var body: some View {
        NavigationView {
            List {
                Section {
                    Button(allSelected ? "Clear All" : "Select All") { toggleAll() }
                } footer: {
                    Text(selected.isEmpty
                         ? "Select at least one convention to begin."
                         : countLabel)
                }

                Section {
                    ForEach(PracticeConvention.allCases) { convention in
                        conventionRow(convention)
                    }
                } header: {
                    Text("Every deal is built so one of your selections comes up in the auction")
                }
            }
            .navigationTitle("Convention Practice")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Start") {
                        let chosen = selected
                        dismiss()
                        game.startPractice(conventions: chosen)
                    }
                    .disabled(selected.isEmpty)
                }
            }
        }
        .navigationViewStyle(.stack)
        .onAppear {
            if selected.isEmpty { selected = game.practiceConventions }
        }
    }

    private func conventionRow(_ convention: PracticeConvention) -> some View {
        Button {
            toggle(convention)
        } label: {
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: selected.contains(convention)
                      ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundColor(selected.contains(convention) ? .blue : .secondary)
                VStack(alignment: .leading, spacing: 4) {
                    Text(convention.rawValue)
                        .font(.headline)
                        .foregroundColor(.primary)
                    Text(convention.subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.vertical, 4)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func toggle(_ convention: PracticeConvention) {
        if selected.contains(convention) { selected.remove(convention) }
        else { selected.insert(convention) }
    }

    private func toggleAll() {
        selected = allSelected ? [] : Set(PracticeConvention.allCases)
    }
}

