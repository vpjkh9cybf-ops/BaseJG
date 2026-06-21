// BRIDGE APP — Built 2026-06-07
import SwiftUI

struct CardView: View {
    let card: Card
    var isHighlighted: Bool = false
    var isSmall: Bool = false
    var isMedium: Bool = false
    var wideHand: Bool = false
    var isCompact: Bool = false   // Compact trick area (when E/W dummy shown in center)

    private var width:   CGFloat {
        if isSmall   { return 34 }
        if isMedium  { return 60 }
        if isCompact { return 60 }
        if wideHand  { return 86 }
        return 80
    }
    private var height:  CGFloat {
        if isSmall   { return 50 }
        if isMedium  { return 84 }
        if isCompact { return 90 }
        if wideHand  { return 180 }
        return 170
    }
    private var radius:  CGFloat { isSmall ? 4 : (isMedium ? 7 : 8) }

    private var rankFont: Font {
        if isSmall   { return .system(size: 10, weight: .bold) }
        if isMedium  { return .system(size: 18, weight: .bold) }
        if isCompact { return .system(size: 28, weight: .bold) }
        if wideHand  { return .system(size: 60, weight: .bold) }
        return .system(size: 50, weight: .bold)
    }
    private var centerSuitFont: Font {
        if isSmall   { return .body }
        if isMedium  { return .title2 }
        if isCompact { return .system(size: 28) }
        if wideHand  { return .system(size: 60) }
        return .system(size: 50)
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
                // Rank only at top, centered
                Text(card.rank.display)
                    .font(rankFont)
                    .foregroundColor(card.suit.color)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, isSmall ? 2 : isMedium ? 4 : 6)
                    .padding(.horizontal, isSmall ? 2 : 4)

                Spacer(minLength: 0)

                // Suit symbol centered
                Text(card.suit.symbol)
                    .font(centerSuitFont)
                    .foregroundColor(card.suit.color)
                    .frame(maxWidth: .infinity, alignment: .center)

                Spacer(minLength: 0)
            }
        }
        .frame(width: width, height: height)
    }
}

struct FaceDownCardView: View {
    var isSmall: Bool = false

    private var width:  CGFloat { isSmall ? 34 : 66 }
    private var height: CGFloat { isSmall ? 50 : 170 }

    var body: some View {
        RoundedRectangle(cornerRadius: isSmall ? 4 : 8)
            .fill(
                LinearGradient(
                    colors: [Color.blue.opacity(0.8), Color.indigo.opacity(0.9)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: isSmall ? 3 : 7)
                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
                    .padding(isSmall ? 3 : 5)
            )
            .shadow(color: .black.opacity(0.2), radius: 2, x: 1, y: 1)
            .frame(width: width, height: height)
    }
}
