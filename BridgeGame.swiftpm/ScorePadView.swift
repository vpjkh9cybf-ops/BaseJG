// BRIDGE APP — Built 2026-06-07
import SwiftUI

struct ScorePadView: View {
    @EnvironmentObject var game: GameState

    var body: some View {
        VStack(spacing: 4) {
            Text("Score")
                .font(.callout.bold())
                .padding(.top, 4)

            HStack(spacing: 0) {
                Text("N-S")
                    .font(.caption.bold())
                    .frame(maxWidth: .infinity)
                Divider()
                Text("E-W")
                    .font(.caption.bold())
                    .frame(maxWidth: .infinity)
            }
            .frame(height: 22)

            Divider()

            if game.scoringMode == .chicago {
                // Chicago: show total scores and hand count
                HStack(spacing: 0) {
                    Text("\(game.rubberScore.nsBelow)")
                        .font(.callout.bold())
                        .frame(maxWidth: .infinity)
                    Divider()
                    Text("\(game.rubberScore.ewBelow)")
                        .font(.callout.bold())
                        .frame(maxWidth: .infinity)
                }
                .frame(height: 28)

                Divider()

                Text("Hand \(game.rubberScore.handHistory.count)/4")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.bottom, 2)
            } else {
                // Rubber: show above-the-line, game dots, partials below
                HStack(spacing: 0) {
                    Text("\(game.rubberScore.nsAbove)")
                        .font(.caption)
                        .frame(maxWidth: .infinity)
                    Divider()
                    Text("\(game.rubberScore.ewAbove)")
                        .font(.caption)
                        .frame(maxWidth: .infinity)
                }
                .frame(height: 22)

                HStack(spacing: 0) {
                    gameDotsView(count: game.rubberScore.nsGames)
                    Divider()
                    gameDotsView(count: game.rubberScore.ewGames)
                }

                Divider().background(Color.black)

                // Below the line — show partials (progress toward current game)
                HStack(spacing: 0) {
                    Text("\(game.rubberScore.nsPartial)")
                        .font(.callout.bold())
                        .frame(maxWidth: .infinity)
                    Divider()
                    Text("\(game.rubberScore.ewPartial)")
                        .font(.callout.bold())
                        .frame(maxWidth: .infinity)
                }
                .frame(height: 28)

                Divider()
            }

            // Vulnerability indicator
            Text("Vul: \(game.vulnerability.rawValue)")
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.bottom, 4)
        }
        .background(Color(.systemBackground))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.gray.opacity(0.3), lineWidth: 0.5)
        )
        .frame(maxWidth: 140)
    }

    private func gameDotsView(count: Int) -> some View {
        HStack(spacing: 2) {
            ForEach(0..<2, id: \.self) { i in
                Circle()
                    .fill(i < count ? Color.blue : Color.gray.opacity(0.2))
                    .frame(width: 8, height: 8)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 4)
    }
}

struct HandResultView: View {
    @EnvironmentObject var game: GameState
    let made: Bool
    let tricks: Int
    let score: Int

    private func trickSummary(contract: Contract) -> String {
        let ot = tricks - contract.tricksRequired
        if made {
            return ot == 0 ? "Exactly \(tricks) tricks" : "\(tricks) tricks (+\(ot))"
        } else {
            return "\(tricks) tricks (down \(-ot))"
        }
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.45).ignoresSafeArea()

            VStack(spacing: 16) {
                Text(made ? "Contract Made!" : "Down!")
                    .font(.title2.bold())
                    .foregroundColor(made ? .green : .red)

                if let c = game.contract {
                    Text(c.display)
                        .font(.largeTitle.bold())

                    Text("by \(c.declarer.name)")
                        .foregroundColor(.secondary)

                    Text(trickSummary(contract: c))
                }

                Text("\(made ? "+" : "")\(made ? score : -score) points")
                    .font(.title3)
                    .foregroundColor(made ? .green : .red)

                // Running score
                HStack(spacing: 24) {
                    VStack {
                        Text("N-S")
                            .font(.caption.bold())
                        Text("\(game.rubberScore.nsTotal)")
                            .font(.caption)
                    }
                    VStack {
                        Text("E-W")
                            .font(.caption.bold())
                        Text("\(game.rubberScore.ewTotal)")
                            .font(.caption)
                    }
                }
                .padding(.horizontal)
                .padding(.vertical, 6)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(8)

                Button("Next Hand") {
                    game.acknowledgeResult()
                }
                .buttonStyle(.borderedProminent)
                .padding(.top, 4)
            }
            .padding(24)
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .shadow(radius: 12)
            .padding(32)
        }
    }
}

struct RubberCompleteView: View {
    @EnvironmentObject var game: GameState

    var nsTotal: Int { game.rubberScore.nsTotal }
    var ewTotal: Int { game.rubberScore.ewTotal }

    var winner: String {
        nsTotal > ewTotal ? "North-South" : "East-West"
    }

    var isChicago: Bool { game.scoringMode == .chicago }

    var body: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()

            VStack(spacing: 20) {
                Text(isChicago ? "Chicago Complete!" : "Rubber Complete!")
                    .font(.largeTitle.bold())

                Text("\(winner) wins!")
                    .font(.title2)
                    .foregroundColor(.blue)

                HStack(spacing: 32) {
                    if isChicago {
                        scoreColumn(title: "N-S", total: nsTotal, isChicago: true)
                        scoreColumn(title: "E-W", total: ewTotal, isChicago: true)
                    } else {
                        scoreColumn(title: "N-S", above: game.rubberScore.nsAbove,
                                    below: game.rubberScore.nsBelow, total: nsTotal, isChicago: false)
                        scoreColumn(title: "E-W", above: game.rubberScore.ewAbove,
                                    below: game.rubberScore.ewBelow, total: ewTotal, isChicago: false)
                    }
                }

                Button(isChicago ? "New Chicago" : "New Rubber") {
                    game.startNewRubberAfterCompletion()
                }
                .buttonStyle(.borderedProminent)
                .padding(.top, 8)
            }
            .padding(28)
            .background(Color(.systemBackground))
            .cornerRadius(16)
            .shadow(radius: 16)
            .padding(24)
        }
    }

    private func scoreColumn(title: String, above: Int = 0, below: Int = 0, total: Int, isChicago: Bool) -> some View {
        VStack(spacing: 6) {
            Text(title).font(.headline)
            if !isChicago {
                Text("Above: \(above)").font(.caption)
                Text("Below: \(below)").font(.caption)
                Divider()
            }
            Text("Total: \(total)").font(.callout.bold())
        }
        .frame(minWidth: 90)
        .padding(10)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(8)
    }
}
