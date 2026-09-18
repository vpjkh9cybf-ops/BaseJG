// Conventional Wisdom — modified 2026-06-27 19:57 UTC
import SwiftUI

struct BiddingBoxView: View {
    @EnvironmentObject var game: GameState

    private let strains: [Strain] = [.clubs, .diamonds, .hearts, .spades, .notrump]
    private let levels: [BidLevel] = BidLevel.allCases

    var body: some View {
        VStack(spacing: 5) {
            // Pass / Double / Redouble
            HStack(spacing: 5) {
                specialButton("Pass", color: .green, bid: .pass)
                specialButton("X",    color: .red,   bid: .double)
                specialButton("XX",   color: .purple, bid: .redouble)
            }

            Divider().padding(.vertical, 1)

            // 7 levels × 5 strains grid — all bids visible, illegal ones dimmed
            VStack(spacing: 2) {
                ForEach(levels, id: \.rawValue) { level in
                    HStack(spacing: 2) {
                        ForEach(strains, id: \.rawValue) { strain in
                            contractCell(level: level, strain: strain)
                        }
                    }
                }
            }
        }
        .padding(6)
        .background(Color(.systemBackground).opacity(0.97))
        .cornerRadius(10)
        .shadow(radius: 4)
    }

    private func specialButton(_ label: String, color: Color, bid: Bid) -> some View {
        let enabled = game.legalBids.contains(bid)
        return Button {
            game.placeBid(bid)
        } label: {
            Text(label)
                .font(.callout.bold())
                .foregroundColor(enabled ? .white : .secondary)
                .frame(minWidth: 56, minHeight: 32)
                .padding(.horizontal, 4)
                .background(enabled ? color : Color(.systemFill))
                .cornerRadius(7)
        }
        .disabled(!enabled)
    }

    private func contractCell(level: BidLevel, strain: Strain) -> some View {
        let bid = Bid.contract(level, strain)
        let legal = game.legalBids.contains(bid)
        return Button {
            game.placeBid(bid)
        } label: {
            VStack(spacing: 0) {
                Text("\(level.rawValue)")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(legal ? .primary : Color.primary.opacity(0.18))
                Text(strain.display)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(legal ? strain.color(alternate: game.conventionSettings.useAlternateColors) : Color.secondary.opacity(0.25))
            }
            .frame(width: 46, height: 34)
            .background(legal ? Color(.secondarySystemBackground) : Color.clear)
            .cornerRadius(5)
            .overlay(
                RoundedRectangle(cornerRadius: 5)
                    .stroke(legal ? Color.gray.opacity(0.3) : Color.clear, lineWidth: 0.5)
            )
        }
        .disabled(!legal)
    }
}
