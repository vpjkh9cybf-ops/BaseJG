import SwiftUI

struct CardView: View {
    let card: Card
    var isHighlighted: Bool = false
    var isSmall: Bool = false

    private var width:  CGFloat { isSmall ? 34  : 52  }
    private var height: CGFloat { isSmall ? 50  : 76  }
    private var font:   Font    { isSmall ? .caption : .callout }
    private var topFont: Font   { isSmall ? .system(size: 8) : .caption2 }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: isSmall ? 4 : 6)
                .fill(Color(.systemBackground))
                .shadow(color: .black.opacity(0.25), radius: 2, x: 1, y: 1)
                .overlay(
                    RoundedRectangle(cornerRadius: isSmall ? 4 : 6)
                        .stroke(isHighlighted ? Color.yellow : Color.gray.opacity(0.4), lineWidth: isHighlighted ? 2 : 0.5)
                )

            VStack(spacing: 1) {
                HStack {
                    VStack(spacing: 0) {
                        Text(card.rank.display)
                            .font(topFont)
                            .foregroundColor(card.suit.color)
                        Text(card.suit.symbol)
                            .font(topFont)
                            .foregroundColor(card.suit.color)
                    }
                    Spacer()
                }
                .padding(.horizontal, isSmall ? 2 : 3)
                .padding(.top, isSmall ? 2 : 3)

                Spacer()

                Text(card.suit.symbol)
                    .font(isSmall ? .body : .title3)
                    .foregroundColor(card.suit.color)

                Spacer()
            }
        }
        .frame(width: width, height: height)
    }
}

struct FaceDownCardView: View {
    var isSmall: Bool = false

    private var width:  CGFloat { isSmall ? 34 : 52 }
    private var height: CGFloat { isSmall ? 50 : 76 }

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

#Preview {
    HStack(spacing: 4) {
        CardView(card: Card(suit: .spades, rank: .ace))
        CardView(card: Card(suit: .hearts, rank: .king), isHighlighted: true)
        CardView(card: Card(suit: .diamonds, rank: .queen), isSmall: true)
        FaceDownCardView()
        FaceDownCardView(isSmall: true)
    }
    .padding()
}
