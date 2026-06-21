// BRIDGE APP — Built 2026-06-07
import SwiftUI

struct HandView: View {
    let cards: [Card]
    let faceDown: Bool
    let isSmall: Bool
    var isWide: Bool = false
    var isMedium: Bool = false
    var trumpSuit: Suit? = nil
    var legalCards: Set<Card> = []
    var onTap: ((Card) -> Void)? = nil

    // Group cards by suit, trump first
    private var bySuit: [(Suit, [Card])] {
        var order = Array(Suit.allCases.reversed())  // spades, hearts, diamonds, clubs
        if let trump = trumpSuit, let i = order.firstIndex(of: trump) {
            order.remove(at: i)
            order.insert(trump, at: 0)
        }
        return order.compactMap { suit in
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
            .frame(height: 180)
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
        .frame(height: isSmall ? 50 : 170)
    }

    // Face-up wide: all cards in one touching row, trump suit first
    private func faceUpLayoutWide(in geo: GeometryProxy) -> some View {
        let cardW: CGFloat = 86
        let n = cards.count
        // step ≤ cardW so cards always touch (never gap); fill available width
        let fillStep: CGFloat = n > 1 ? (geo.size.width - cardW) / CGFloat(n - 1) : 0
        let step: CGFloat = min(cardW, fillStep)
        var suitOrder: [Suit] = [.spades, .hearts, .diamonds, .clubs]
        if let trump = trumpSuit, let i = suitOrder.firstIndex(of: trump) {
            suitOrder.remove(at: i)
            suitOrder.insert(trump, at: 0)
        }
        let sorted = cards.sorted { a, b in
            let ai = suitOrder.firstIndex(of: a.suit) ?? suitOrder.count
            let bi = suitOrder.firstIndex(of: b.suit) ?? suitOrder.count
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
                        CardView(card: card, isHighlighted: isLegal, wideHand: true)
                    }
                    .disabled(!isLegal)
                    .opacity(isLegal || legalCards.isEmpty ? 1.0 : 0.55)
                    .offset(x: CGFloat(idx) * step)
                } else {
                    CardView(card: card, wideHand: true)
                        .offset(x: CGFloat(idx) * step)
                }
            }
        }
        .frame(width: geo.size.width, height: 180, alignment: .leading)
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

                    HStack(spacing: isSmall ? -4 : isMedium ? -10 : -6) {
                        ForEach(suitCards) { card in
                            let isLegal = legalCards.contains(card)
                            if onTap != nil {
                                Button {
                                    onTap?(card)
                                } label: {
                                    CardView(card: card, isHighlighted: isLegal, isSmall: isSmall, isMedium: isMedium)
                                }
                                .disabled(!isLegal)
                                .opacity(isLegal || legalCards.isEmpty ? 1.0 : 0.55)
                            } else {
                                CardView(card: card, isSmall: isSmall, isMedium: isMedium)
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
