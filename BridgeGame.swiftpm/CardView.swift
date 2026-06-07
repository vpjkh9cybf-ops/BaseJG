// BRIDGE APP — Built 2026-06-07
import SwiftUI

struct CardView: View {
    let card: Card
    var isHighlighted: Bool = false
    var isSmall: Bool = false
    var isMedium: Bool = false
    var wideHand: Bool = false      // single-row south hand: bigger, no corner suit

    private var width:   CGFloat { isSmall ? 34 : (isMedium ? 44 : (wideHand ? 86 : 66)) }
    private var height:  CGFloat { isSmall ? 50 : (isMedium ? 62 : (wideHand ? 112 : 96)) }
    private var radius:  CGFloat { isSmall ? 4  : (isMedium ? 5  : 6 ) }
    private var topFont: Font    { isSmall ? .system(size: 8) : (isMedium ? .system(size: 10) : .caption) }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: radius)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.25), radius: 2, x: 1, y: 1)
                .overlay(
                    RoundedRectangle(cornerRadius: radius)
                        .stroke(isHighlighted ? Color.yellow : Color.gray.opacity(0.4), lineWidth: isHighlighted ? 2 : 0.5)
                )

            VStack(spacing: 1) {
                HStack {
                    VStack(spacing: 0) {
                        Text(card.rank.display)
                            .font(wideHand ? .footnote.bold() : topFont)
                            .foregroundColor(card.suit.color)
                        if !wideHand {
                            Text(card.suit.symbol)
                                .font(topFont)
                                .foregroundColor(card.suit.color)
                        }
                    }
                    Spacer()
                }
                .padding(.horizontal, isSmall ? 2 : 3)
                .padding(.top, isSmall ? 2 : 3)

                Spacer()

                Text(card.suit.symbol)
                    .font(isSmall ? .body : (isMedium ? .title3 : (wideHand ? .largeTitle : .title2)))
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
    private var height: CGFloat { isSmall ? 50 : 96 }

    var body: some View {
        RoundedRectangle(cornerRadius: isSmall ? 4 : 6)
            .fill(
                LinearGradient(
                    colors: [Color.blue.opacity(0.8), Color.indigo.opacity(0.9)],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
            )
            .overlay(
                RoundedRectangle(cornerRadius: isSmall ? 3 : 5)
                    .stroke(Color.white.opacity(0.3), lineWidth: 1)
                    .padding(isSmall ? 3 : 4)
            )
            .shadow(color: .black.opacity(0.2), radius: 2, x: 1, y: 1)
            .frame(width: width, height: height)
    }
}
