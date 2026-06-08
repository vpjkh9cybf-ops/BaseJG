// BRIDGE APP — Built 2026-06-07
import SwiftUI

struct CardView: View {
    let card: Card
    var isHighlighted: Bool = false
    var isSmall: Bool = false
    var isMedium: Bool = false
    var wideHand: Bool = false      // single-row south/dummy hand: wider card

    private var width:   CGFloat { isSmall ? 34 : (isMedium ? 44 : (wideHand ? 86 : 80)) }
    private var height:  CGFloat { isSmall ? 50 : (isMedium ? 62 : (wideHand ? 132 : 120)) }
    private var radius:  CGFloat { isSmall ? 4  : (isMedium ? 5  : 7 ) }

    private var rankFont: Font {
        if isSmall   { return .system(size: 10, weight: .bold) }
        if isMedium  { return .system(size: 13, weight: .bold) }
        if wideHand  { return .system(size: 36, weight: .bold) }
        return .system(size: 30, weight: .bold)
    }
    private var indexSuitFont: Font {
        if isSmall   { return .system(size: 8) }
        if isMedium  { return .system(size: 10) }
        if wideHand  { return .system(size: 24) }
        return .system(size: 20)
    }
    private var centerSuitFont: Font {
        if isSmall  { return .body }
        if isMedium { return .title3 }
        if wideHand { return .largeTitle }
        return .title
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: radius)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.25), radius: 2, x: 1, y: 1)
                .overlay(
                    RoundedRectangle(cornerRadius: radius)
                        .stroke(isHighlighted ? Color.yellow : Color.gray.opacity(0.4),
                                lineWidth: isHighlighted ? 2 : 0.5)
                )

            VStack(spacing: 0) {
                // Centered rank + suit index
                VStack(spacing: isSmall ? 0 : 1) {
                    Text(card.rank.display)
                        .font(rankFont)
                        .foregroundColor(card.suit.color)
                    Text(card.suit.symbol)
                        .font(indexSuitFont)
                        .foregroundColor(card.suit.color)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, isSmall ? 2 : 4)

                Spacer()

                Text(card.suit.symbol)
                    .font(centerSuitFont)
                    .foregroundColor(card.suit.color)

                Spacer()
            }
        }
        .frame(width: width, height: height)
    }
}

struct FaceDownCardView: View {
    var isSmall: Bool = false

    private var width:  CGFloat { isSmall ? 34 : 66 }
    private var height: CGFloat { isSmall ? 50 : 120 }

    var body: some View {
        RoundedRectangle(cornerRadius: isSmall ? 4 : 7)
            .fill(
                LinearGradient(
                    colors: [Color.blue.opacity(0.8), Color.indigo.opacity(0.9)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: isSmall ? 3 : 6)
                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
                    .padding(isSmall ? 3 : 5)
            )
            .shadow(color: .black.opacity(0.2), radius: 2, x: 1, y: 1)
            .frame(width: width, height: height)
    }
}
