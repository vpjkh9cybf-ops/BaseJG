// BRIDGE APP — Built 2026-06-07
import SwiftUI

struct CardView: View {
    @EnvironmentObject var game: GameState
    let card: Card
    var isHighlighted: Bool = false
    var isSmall: Bool = false
    var isMedium: Bool = false
    var wideHand: Bool = false
    var isCompact: Bool = false   // Compact trick area (when E/W dummy shown in center)
    /// Overrides every preset. Width and all fonts scale from it, so a caller
    /// that knows how much room it has can hand the card an exact height.
    var explicitHeight: CGFloat? = nil

    /// Playing-card proportion (width / height) — held constant at every size.
    static let aspect: CGFloat = 0.47

    private var height: CGFloat {
        if let h = explicitHeight { return h }
        if isSmall   { return 50 }
        if isMedium  { return 84 }
        if isCompact { return 90 }
        if wideHand  { return 180 }
        return 170
    }

    private var width: CGFloat {
        if explicitHeight != nil { return height * CardView.aspect }
        if isSmall   { return 34 }
        if isMedium  { return 60 }
        if isCompact { return 60 }
        if wideHand  { return 86 }
        return 80
    }

    private var radius: CGFloat { max(3, height * 0.05) }

    // The rank is what the player actually reads, so it gets as much of the
    // card as the proportions allow at every size.
    private var rankFont:       Font { .system(size: max(9, height * 0.34), weight: .bold) }
    private var centerSuitFont: Font { .system(size: max(9, height * 0.32)) }

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
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                    .foregroundColor(card.suit.color(alternate: game.conventionSettings.useAlternateColors))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, max(1, height * 0.035))
                    .padding(.horizontal, max(1, width * 0.05))

                Spacer(minLength: 0)

                // Suit symbol centered
                Text(card.suit.symbol)
                    .font(centerSuitFont)
                    .minimumScaleFactor(0.6)
                    .lineLimit(1)
                    .foregroundColor(card.suit.color(alternate: game.conventionSettings.useAlternateColors))
                    .frame(maxWidth: .infinity, alignment: .center)

                Spacer(minLength: 0)
            }
        }
        .frame(width: width, height: height)
    }
}

struct FaceDownCardView: View {
    var isSmall: Bool = false
    var explicitHeight: CGFloat? = nil

    private var height: CGFloat { explicitHeight ?? (isSmall ? 50 : 170) }
    private var width:  CGFloat {
        if explicitHeight != nil { return height * CardView.aspect }
        return isSmall ? 34 : 66
    }
    private var radius: CGFloat { max(3, height * 0.05) }

    var body: some View {
        RoundedRectangle(cornerRadius: radius)
            .fill(
                LinearGradient(
                    colors: [Color.blue.opacity(0.8), Color.indigo.opacity(0.9)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: max(2, radius - 1))
                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
                    .padding(max(2, height * 0.06))
            )
            .shadow(color: .black.opacity(0.2), radius: 2, x: 1, y: 1)
            .frame(width: width, height: height)
    }
}
