// BRIDGE APP — Built 2026-06-07
import SwiftUI

struct BiddingBoxView: View {
    @EnvironmentObject var game: GameState

    private let strains: [Strain] = [.clubs, .diamonds, .hearts, .spades, .notrump]
    private let levels: [BidLevel] = BidLevel.allCases

    var body: some View {
        VStack(spacing: 8) {
            // Pass / Double / Redouble
            HStack(spacing: 10) {
                specialButton("Pass", color: .green, bid: .pass)
                specialButton("X",    color: .red,   bid: .double)
                specialButton("XX",   color: .purple, bid: .redouble)
            }

            Divider()

            // 7 levels × 5 strains grid — all bids visible, illegal ones dimmed
            VStack(spacing: 3) {
                ForEach(levels, id: \.rawValue) { level in
                    HStack(spacing: 3) {
                        ForEach(strains, id: \.rawValue) { strain in
                            contractCell(level: level, strain: strain)
                        }
                    }
                }
            }
        }
        .padding(10)
        .background(Color(.systemBackground).opacity(0.97))
        .cornerRadius(12)
        .shadow(radius: 6)
    }

    private func specialButton(_ label: String, color: Color, bid: Bid) -> some View {
        let enabled = game.legalBids.contains(bid)
        return Button {
            game.placeBid(bid)
        } label: {
            Text(label)
                .font(.callout.bold())
                .foregroundColor(enabled ? .white : .secondary)
                .frame(minWidth: 68, height: 42)
                .padding(.horizontal, 8)
                .background(enabled ? color : Color(.systemFill))
                .cornerRadius(8)
        }
        .disabled(!enabled)
    }

    private func contractCell(level: BidLevel, strain: Strain) -> some View {
        let bid = Bid.contract(level, strain)
        let legal = game.legalBids.contains(bid)
        return Button {
            game.placeBid(bid)
        } label: {
            VStack(spacing: 1) {
                Text("\(level.rawValue)")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundColor(legal ? .primary : Color.primary.opacity(0.18))
                Text(strain.display)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(legal ? strain.color : Color.secondary.opacity(0.25))
            }
            .frame(width: 50, height: 36)
            .background(legal ? Color(.secondarySystemBackground) : Color.clear)
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(legal ? Color.gray.opacity(0.3) : Color.clear, lineWidth: 0.5)
            )
        }
        .disabled(!legal)
    }
}
