// BRIDGE APP — Built 2026-06-07
import SwiftUI

struct HandView: View {
    let cards: [Card]
    let faceDown: Bool
    let isSmall: Bool
    var isWide: Bool = false
    var legalCards: Set<Card> = []
    var onTap: ((Card) -> Void)? = nil

    // Group cards by suit for display
    private var bySuit: [(Suit, [Card])] {
        Suit.allCases.reversed().compactMap { suit in
            let suitCards = cards.filter { $0.suit == suit }
            guard !suitCards.isEmpty else { return nil }
            return (suit, suitCards.sorted(by: { $0.rank > $1.rank }))
        }
    }

    var body: some View {
        if faceDown {
            faceDownLayout
        } else if isWide {
            GeometryReader { geo in
                faceUpLayoutWide(in: geo)
            }
            .frame(height: 96)
        } else {
            faceUpLayout
        }
    }

    // Face-down: show a row of card backs
    private var faceDownLayout: some View {
        HStack(spacing: -10) {
            ForEach(0..<min(cards.count, 13), id: \.self) { _ in
                FaceDownCardView(isSmall: isSmall)
            }
        }
        .frame(height: isSmall ? 50 : 96)
    }

    // Face-up wide: all cards in one row filling available width
    private func faceUpLayoutWide(in geo: GeometryProxy) -> some View {
        let cardW: CGFloat = 66
        let n = cards.count
        let step: CGFloat = n > 1 ? (geo.size.width - cardW) / CGFloat(n - 1) : 0
        let sorted = cards.sorted { a, b in
            let order: [Suit] = [.spades, .hearts, .diamonds, .clubs]
            let ai = order.firstIndex(of: a.suit) ?? 0
            let bi = order.firstIndex(of: b.suit) ?? 0
            if ai != bi { return ai < bi }
            return a.rank > b.rank
        }
        return ZStack(alignment: .leading) {
            ForEach(Array(sorted.enumerated()), id: \.element.id) { idx, card in
                let isLegal = legalCards.contains(card)
                if onTap != nil {
                    Button {
                        onTap?(card)
                    } label: {
                        CardView(card: card, isHighlighted: isLegal, isSmall: false)
                    }
                    .disabled(!isLegal)
                    .opacity(isLegal || legalCards.isEmpty ? 1.0 : 0.55)
                    .offset(x: CGFloat(idx) * step)
                } else {
                    CardView(card: card, isSmall: false)
                        .offset(x: CGFloat(idx) * step)
                }
            }
        }
        .frame(width: geo.size.width, height: 96, alignment: .leading)
    }

    // Face-up: show suits in rows
    private var faceUpLayout: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(bySuit, id: \.0) { suit, suitCards in
                HStack(spacing: 2) {
                    Text(suit.symbol)
                        .foregroundColor(suit.color)
                        .font(isSmall ? .caption : .callout)
                        .frame(width: isSmall ? 14 : 18, alignment: .leading)

                    HStack(spacing: isSmall ? -4 : -6) {
                        ForEach(suitCards) { card in
                            let isLegal = legalCards.contains(card)
                            if onTap != nil {
                                Button {
                                    onTap?(card)
                                } label: {
                                    CardView(card: card, isHighlighted: isLegal, isSmall: isSmall)
                                }
                                .disabled(!isLegal)
                                .opacity(isLegal || legalCards.isEmpty ? 1.0 : 0.55)
                            } else {
                                CardView(card: card, isSmall: isSmall)
                            }
                        }
                    }
                }
            }
        }
    }
}

// Compact text-only hand for auction/result panels
struct HandTextView: View {
    let cards: [Card]

    private var bySuit: [(Suit, [Card])] {
        Suit.allCases.reversed().compactMap { suit in
            let sc = cards.filter { $0.suit == suit }
            return sc.isEmpty ? nil : (suit, sc.sorted(by: { $0.rank > $1.rank }))
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(bySuit, id: \.0) { suit, suitCards in
                HStack(spacing: 3) {
                    Text(suit.symbol)
                        .foregroundColor(suit.color)
                        .font(.caption)
                    Text(suitCards.map { $0.rank.display }.joined(separator: " "))
                        .font(.caption)
                }
            }
        }
    }
}
