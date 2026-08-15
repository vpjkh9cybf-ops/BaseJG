// Conventional Wisdom — modified 2026-06-27 18:34 UTC
import SwiftUI

struct ScorePadView: View {
    @EnvironmentObject var game: GameState

    private var isChicago: Bool { game.scoringMode == .chicago }
    private var handCount: Int  { game.rubberScore.handHistory.count }

    // Above-line entries: (ns, ew) per hand — only non-zero entries
    private var aboveEntries: [(ns: Int, ew: Int)] {
        game.rubberScore.handHistory.compactMap { hr in
            guard hr.scoringMode == .rubber else { return nil }
            if hr.made {
                let above = abs(hr.netScore) - hr.belowLineScore
                guard above > 0 else { return nil }
                return hr.declarerIsNS ? (above, 0) : (0, above)
            } else {
                let penalty = abs(hr.netScore)
                return hr.declarerIsNS ? (0, penalty) : (penalty, 0)
            }
        }
    }

    // Below-line entries grouped by game (each inner array is one game's hands)
    // Last inner array is the current in-progress game
    private var belowGames: [[(ns: Int, ew: Int)]] {
        var result: [[(ns: Int, ew: Int)]] = [[]]
        var nsAcc = 0, ewAcc = 0
        for hr in game.rubberScore.handHistory where hr.scoringMode == .rubber && hr.made {
            let b = hr.belowLineScore
            if hr.declarerIsNS {
                result[result.count - 1].append((b, 0))
                nsAcc += b
                if nsAcc >= 100 { nsAcc = 0; ewAcc = 0; result.append([]) }
            } else {
                result[result.count - 1].append((0, b))
                ewAcc += b
                if ewAcc >= 100 { nsAcc = 0; ewAcc = 0; result.append([]) }
            }
        }
        return result
    }

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

            if isChicago {
                // Chicago: running totals + hand counter
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

                Text("Hand \(min(handCount + 1, 4)) of 4")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.bottom, 2)

            } else {
                // Rubber: above-line entries
                if aboveEntries.isEmpty {
                    Spacer().frame(height: 18)
                } else {
                    aboveEntriesView
                }

                // The line
                Rectangle().fill(Color.primary).frame(height: 2).padding(.horizontal, 2)

                // Below-line entries by game
                belowGamesView

                Divider()

                // Game dots
                HStack(spacing: 0) {
                    gameDotsView(count: game.rubberScore.nsGames)
                    Divider()
                    gameDotsView(count: game.rubberScore.ewGames)
                }

                Divider()

                // Running totals
                HStack(spacing: 0) {
                    Text("\(game.rubberScore.nsAbove + game.rubberScore.nsBelow)")
                        .font(.caption.bold())
                        .frame(maxWidth: .infinity)
                    Divider()
                    Text("\(game.rubberScore.ewAbove + game.rubberScore.ewBelow)")
                        .font(.caption.bold())
                        .frame(maxWidth: .infinity)
                }
                .frame(height: 18)

                Divider()

                Text("Vul: \(game.vulnerability.rawValue)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
                    .padding(.bottom, 4)
            }
        }
        .background(Color(.systemBackground))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.gray.opacity(0.3), lineWidth: 0.5)
        )
        .frame(maxWidth: 145)
    }

    private var aboveEntriesView: some View {
        VStack(spacing: 0) {
            ForEach(aboveEntries.indices, id: \.self) { i in
                scoreRow(ns: aboveEntries[i].ns, ew: aboveEntries[i].ew, bold: false)
            }
        }
    }

    @ViewBuilder
    private var belowGamesView: some View {
        if belowGames.allSatisfy({ $0.isEmpty }) {
            Spacer().frame(height: 18)
        } else {
            belowGamesContent(belowGames)
        }
    }

    private func belowGamesContent(_ games: [[(ns: Int, ew: Int)]]) -> some View {
        VStack(spacing: 0) {
            ForEach(games.indices, id: \.self) { gi in
                if gi > 0 && !games[gi - 1].isEmpty {
                    Rectangle().fill(Color.primary).frame(height: 0.5)
                }
                ForEach(games[gi].indices, id: \.self) { hi in
                    scoreRow(ns: games[gi][hi].ns, ew: games[gi][hi].ew, bold: true)
                }
            }
        }
    }

    private func scoreRow(ns: Int, ew: Int, bold: Bool) -> some View {
        HStack(spacing: 0) {
            Text(ns > 0 ? "\(ns)" : "")
                .font(bold ? .system(size: 10, weight: .bold) : .system(size: 9))
                .frame(maxWidth: .infinity)
            Divider()
            Text(ew > 0 ? "\(ew)" : "")
                .font(bold ? .system(size: 10, weight: .bold) : .system(size: 9))
                .frame(maxWidth: .infinity)
        }
        .frame(height: 14)
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

                HStack(spacing: 24) {
                    VStack {
                        Text("N-S").font(.caption.bold())
                        Text("\(game.rubberScore.nsTotal)").font(.caption)
                    }
                    VStack {
                        Text("E-W").font(.caption.bold())
                        Text("\(game.rubberScore.ewTotal)").font(.caption)
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

                HStack(spacing: 12) {
                    Button("↺ Rebid") { game.replayFromBidding() }
                        .font(.caption.bold())
                    Button("↺ Replay Play") { game.replayFromPlay() }
                        .font(.caption.bold())
                }
                .foregroundColor(.secondary)
                .padding(.bottom, 4)
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

    private var isChicago: Bool { game.scoringMode == .chicago }
    private var nsTotal: Int { game.rubberScore.nsTotal }
    private var ewTotal: Int { game.rubberScore.ewTotal }

    private var winner: String {
        if nsTotal == ewTotal { return "Tie" }
        return nsTotal > ewTotal ? "North-South" : "East-West"
    }

    var body: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()

            VStack(spacing: 20) {
                Text(isChicago ? "Chicago Complete!" : "Rubber Complete!")
                    .font(.largeTitle.bold())

                Text(nsTotal == ewTotal ? "It's a tie!" : "\(winner) wins!")
                    .font(.title2)
                    .foregroundColor(.blue)

                HStack(spacing: 32) {
                    if isChicago {
                        chicagoColumn(title: "N-S", total: nsTotal)
                        chicagoColumn(title: "E-W", total: ewTotal)
                    } else {
                        rubberColumn(title: "N-S",
                                     above: game.rubberScore.nsAbove,
                                     below: game.rubberScore.nsBelow,
                                     total: nsTotal)
                        rubberColumn(title: "E-W",
                                     above: game.rubberScore.ewAbove,
                                     below: game.rubberScore.ewBelow,
                                     total: ewTotal)
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

    private func rubberColumn(title: String, above: Int, below: Int, total: Int) -> some View {
        VStack(spacing: 6) {
            Text(title).font(.headline)
            Text("Above: \(above)").font(.caption)
            Text("Below: \(below)").font(.caption)
            Divider()
            Text("Total: \(total)").font(.callout.bold())
        }
        .frame(minWidth: 90)
        .padding(10)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(8)
    }

    private func chicagoColumn(title: String, total: Int) -> some View {
        VStack(spacing: 6) {
            Text(title).font(.headline)
            Text("Total: \(total)").font(.title3.bold())
        }
        .frame(minWidth: 90)
        .padding(10)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(8)
    }
}
