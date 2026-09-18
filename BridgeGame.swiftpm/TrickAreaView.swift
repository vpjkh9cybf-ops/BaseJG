// Conventional Wisdom — modified 2026-08-14 13:00 UTC
import SwiftUI

struct TrickAreaView: View {
    let trick: Trick?
    let contract: Contract?
    /// Space the centre column can actually spare. Card size is derived from it
    /// so the trick never overflows and gets clipped by the table layout.
    var available: CGSize = CGSize(width: 300, height: 530)

    private let gap: CGFloat = 6

    // Three card rows stack vertically; the middle row holds two cards side by side.
    private var slotH: CGFloat {
        let byHeight = (available.height - gap * 4) / 3
        let byWidth  = ((available.width - gap * 4) / 2) / CardView.aspect
        return max(52, min(170, min(byHeight, byWidth)))
    }
    private var slotW:  CGFloat { slotH * CardView.aspect }
    private var frameW: CGFloat { slotW * 2 + gap * 4 }
    private var frameH: CGFloat { slotH * 3 + gap * 4 }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.green.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.green.opacity(0.2), lineWidth: 1)
                )

            if let trick = trick {
                VStack(spacing: gap * 0.4) {
                    trickCard(for: .north, in: trick)
                    HStack(spacing: gap * 2) {
                        trickCard(for: .west, in: trick)
                        trickCard(for: .east, in: trick)
                    }
                    trickCard(for: .south, in: trick)
                }
            } else {
                Text("—")
                    .foregroundColor(.secondary)
                    .font(.caption)
            }
        }
        .frame(width: frameW, height: frameH)
    }

    @ViewBuilder
    private func trickCard(for seat: Seat, in trick: Trick) -> some View {
        if let card = trick.card(for: seat) {
            CardView(card: card, explicitHeight: slotH)
        } else {
            RoundedRectangle(cornerRadius: max(3, slotH * 0.05))
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                .frame(width: slotW, height: slotH)
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
                    .font(.caption)
                    .foregroundColor(.secondary)

                Divider()

                HStack(spacing: 16) {
                    VStack {
                        Text("NS")
                            .font(.caption.bold())
                        Text("\(nsTricks)")
                            .font(.title3.bold())
                            .foregroundColor(c.declarer.isNorthSouth ? .green : .primary)
                    }
                    VStack {
                        Text("EW")
                            .font(.caption.bold())
                        Text("\(ewTricks)")
                            .font(.title3.bold())
                            .foregroundColor(!c.declarer.isNorthSouth ? .green : .primary)
                    }
                }

                Text("Need \(c.tricksRequired)")
                    .font(.caption)
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
