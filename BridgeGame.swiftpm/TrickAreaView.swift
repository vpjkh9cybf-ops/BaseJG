// BRIDGE APP — Built 2026-06-07
import SwiftUI

struct TrickAreaView: View {
    let trick: Trick?
    let contract: Contract?

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.green.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.green.opacity(0.2), lineWidth: 1)
                )

            if let trick = trick {
                VStack(spacing: 2) {
                    // North card
                    trickCard(for: .north, in: trick)
                    HStack(spacing: 20) {
                        // West card
                        trickCard(for: .west, in: trick)
                        // East card
                        trickCard(for: .east, in: trick)
                    }
                    // South card
                    trickCard(for: .south, in: trick)
                }
            } else {
                Text("—")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
        }
        .frame(width: 160, height: 160)
    }

    @ViewBuilder
    private func trickCard(for seat: Seat, in trick: Trick) -> some View {
        if let card = trick.card(for: seat) {
            CardView(card: card, isSmall: true)
        } else {
            RoundedRectangle(cornerRadius: 4)
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                .frame(width: 34, height: 50)
        }
    }
}

struct ScoreTickerView: View {
    let nsTricks: Int
    let ewTricks: Int
    let total: Int
    let contract: Contract?

    var body: some View {
        VStack(spacing: 4) {
            if let c = contract {
                Text(c.display)
                    .font(.headline)
                    .foregroundColor(.primary)
                Text("by \(c.declarer.name)")
                    .font(.caption2)
                    .foregroundColor(.secondary)

                Divider()

                HStack(spacing: 16) {
                    VStack {
                        Text("NS")
                            .font(.caption2.bold())
                        Text("\(nsTricks)")
                            .font(.title3.bold())
                            .foregroundColor(c.declarer.isNorthSouth ? .green : .primary)
                    }
                    VStack {
                        Text("EW")
                            .font(.caption2.bold())
                        Text("\(ewTricks)")
                            .font(.title3.bold())
                            .foregroundColor(!c.declarer.isNorthSouth ? .green : .primary)
                    }
                }

                Text("Need \(c.tricksRequired)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            } else {
                Text("Bidding…")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
        }
        .padding(8)
        .frame(minWidth: 80)
    }
}
