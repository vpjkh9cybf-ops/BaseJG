// Conventional Wisdom — modified 2026-08-14 13:00 UTC
import SwiftUI

struct HandView: View {
    @EnvironmentObject var game: GameState
    let cards: [Card]
    let faceDown: Bool
    let isSmall: Bool
    var isWide: Bool = false
    var isMedium: Bool = false
    /// Height of the horizontal fan used by South / a wide North.
    var wideHeight: CGFloat = 180
    /// Total row length for a face-down hand; cards squeeze together to fit it.
    var faceDownLength: CGFloat? = nil
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
            .frame(height: wideHeight)
        } else {
            faceUpLayout
        }
    }

    // Face-down: a row of card backs squeezed into faceDownLength when given one
    private var faceDownLayout: some View {
        let n = min(cards.count, 13)
        let w: CGFloat = isSmall ? 34 : 66
        let h: CGFloat = isSmall ? 50 : 170
        let natural = w + CGFloat(max(0, n - 1)) * (w - 10)
        let total = faceDownLength ?? natural
        let step: CGFloat = n > 1 ? max(6, min(w - 6, (total - w) / CGFloat(n - 1))) : 0
        let used = n == 0 ? 0 : w + CGFloat(n - 1) * step

        return ZStack(alignment: .leading) {
            ForEach(0..<n, id: \.self) { i in
                FaceDownCardView(isSmall: isSmall)
                    .offset(x: CGFloat(i) * step)
            }
        }
        .frame(width: used, height: h, alignment: .leading)
    }

    // Face-up wide: all cards in one touching row, trump suit first
    private func faceUpLayoutWide(in geo: GeometryProxy) -> some View {
        let cardH: CGFloat = wideHeight
        let cardW: CGFloat = cardH * CardView.aspect
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
                        CardView(card: card, isHighlighted: isLegal, explicitHeight: cardH)
                    }
                    .disabled(!isLegal)
                    .opacity(isLegal || legalCards.isEmpty ? 1.0 : 0.55)
                    .offset(x: CGFloat(idx) * step)
                } else {
                    CardView(card: card, explicitHeight: cardH)
                        .offset(x: CGFloat(idx) * step)
                }
            }
        }
        .frame(width: geo.size.width, height: cardH, alignment: .leading)
    }

    // Face-up: show suits in rows
    private var faceUpLayout: some View {
        VStack(alignment: .leading, spacing: 2) {
            ForEach(bySuit, id: \.0) { suit, suitCards in
                HStack(spacing: 2) {
                    Text(suit.symbol)
                        .foregroundColor(suit.color(alternate: game.conventionSettings.useAlternateColors))
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

/// Face-up dummy shown in the narrow East/West column.
///
/// Every dimension is derived from the column it is handed, so the hand is
/// bounded by construction and can never spill into the trick area. Cards are
/// made as large as that box allows, which keeps the rank indices readable.
struct SideDummyView: View {
    @EnvironmentObject var game: GameState
    let cards: [Card]
    let size: CGSize
    var trumpSuit: Suit? = nil
    var legalCards: Set<Card> = []
    var onTap: ((Card) -> Void)? = nil

    private var bySuit: [(Suit, [Card])] {
        var order = Array(Suit.allCases.reversed())
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

    private var rowCount: Int { max(1, bySuit.count) }
    private var rowSpacing: CGFloat { 4 }

    private var cardH: CGFloat {
        let gaps = rowSpacing * CGFloat(rowCount - 1)
        let byHeight = (size.height - gaps) / CGFloat(rowCount)
        // Also cap by width so a 2-row hand does not produce absurdly tall cards
        let byWidth = (size.width - 20) / CardView.aspect / 2.4
        return max(30, min(104, min(byHeight, byWidth)))
    }
    private var cardW:    CGFloat { cardH * CardView.aspect }
    private var symbolW:  CGFloat { max(11, cardH * 0.20) }
    private var longest:  Int     { bySuit.map { $0.1.count }.max() ?? 1 }

    /// Horizontal advance per card, shrunk until the longest suit fits the column.
    private var step: CGFloat {
        guard longest > 1 else { return cardW }
        let usable = size.width - symbolW - 8
        return max(cardW * 0.30, min(cardW, (usable - cardW) / CGFloat(longest - 1)))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: rowSpacing) {
            ForEach(bySuit, id: \.0) { suit, suitCards in
                suitRow(suit, suitCards)
            }
        }
        .frame(width: size.width, height: size.height, alignment: .topLeading)
    }

    private func suitRow(_ suit: Suit, _ suitCards: [Card]) -> some View {
        let used = cardW + CGFloat(max(0, suitCards.count - 1)) * step
        return HStack(spacing: 4) {
            Text(suit.symbol)
                .font(.system(size: symbolW, weight: .semibold))
                .foregroundColor(suit.color(alternate: game.conventionSettings.useAlternateColors))
                .frame(width: symbolW, alignment: .leading)

            ZStack(alignment: .leading) {
                ForEach(Array(suitCards.enumerated()), id: \.element.id) { idx, card in
                    cardCell(card).offset(x: CGFloat(idx) * step)
                }
            }
            .frame(width: used, height: cardH, alignment: .leading)

            Spacer(minLength: 0)
        }
        .frame(height: cardH)
    }

    @ViewBuilder
    private func cardCell(_ card: Card) -> some View {
        if onTap != nil {
            Button {
                onTap?(card)
            } label: {
                CardView(card: card,
                         isHighlighted: legalCards.contains(card),
                         explicitHeight: cardH)
            }
            .disabled(!legalCards.contains(card))
            .opacity(legalCards.contains(card) || legalCards.isEmpty ? 1.0 : 0.55)
        } else {
            CardView(card: card, explicitHeight: cardH)
        }
    }
}

// Compact text-only hand for auction/result panels
struct HandTextView: View {
    @EnvironmentObject var game: GameState
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
                        .foregroundColor(suit.color(alternate: game.conventionSettings.useAlternateColors))
                        .font(.caption)
                    Text(suitCards.map { $0.rank.display }.joined(separator: " "))
                        .font(.caption)
                }
            }
        }
    }
}
