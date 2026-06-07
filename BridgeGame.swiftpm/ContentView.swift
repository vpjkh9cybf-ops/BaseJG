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

    var body: some View {
        ZStack {
            Color(red: 0.08, green: 0.40, blue: 0.15)
                .ignoresSafeArea()

            VStack(spacing: 32) {
                VStack(spacing: 8) {
                    Text("♠ ♥ Bridge ♦ ♣")
                        .font(.system(size: 42, weight: .bold, design: .serif))
                        .foregroundColor(.white)

                    Text("Standard American · Rubber Bridge")
                        .font(.callout)
                        .foregroundColor(.white.opacity(0.7))
                }

                VStack(spacing: 16) {
                    MenuButton(title: "New Rubber", icon: "suit.spade.fill") {
                        game.startNewRubber()
                    }

                    MenuButton(title: "Continue", icon: "arrow.right.circle.fill", disabled: true) {
                        // Future: resume saved game
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Conventions included:")
                        .font(.caption.bold())
                        .foregroundColor(.white.opacity(0.6))
                    ForEach([
                        "Stayman", "Jacoby Transfers",
                        "Jacoby 2NT", "Blackwood",
                        "Weak 2 openings", "Negative Doubles",
                        "2/1 Game Force", "Limit Raises"
                    ], id: \.self) { conv in
                        Text("• \(conv)")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.55))
                    }
                }
                .padding(.top, 8)
            }
            .padding(40)
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
