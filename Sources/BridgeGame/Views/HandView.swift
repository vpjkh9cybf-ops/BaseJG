import SwiftUI

struct HandView: View {
    let cards: [Card]
    let faceDown: Bool
    let isSmall: Bool
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
        .frame(height: isSmall ? 50 : 76)
    }

    // Face-up: show suits in columns
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
