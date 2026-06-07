// BRIDGE APP — Built 2026-06-07
import SwiftUI

struct GameTableView: View {
    @EnvironmentObject var game: GameState

    // During bidding give the south area more room to fit the full bid grid.
    private var isBiddingPhase: Bool { game.phase == .bidding }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color(red: 0.08, green: 0.40, blue: 0.15)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    northArea
                        .frame(height: geo.size.height * (isBiddingPhase ? 0.13 : 0.22))

                    HStack(alignment: .center, spacing: 0) {
                        westArea.frame(width: geo.size.width * 0.18)
                        centerArea.frame(maxWidth: .infinity)
                        eastArea.frame(width: geo.size.width * 0.18)
                    }
                    .frame(height: geo.size.height * (isBiddingPhase ? 0.27 : 0.40))

                    southArea
                        .frame(height: geo.size.height * (isBiddingPhase ? 0.60 : 0.30))
                }
                .animation(.easeInOut(duration: 0.2), value: isBiddingPhase)

                overlayLayer
            }
        }
        .ignoresSafeArea(edges: .bottom)
    }

    // MARK: - North hand

    private func isNorthFaceUp() -> Bool {
        return game.dummy == .north && game.phase == .playing
    }

    private var northArea: some View {
        let northCards: [Card] = game.hands[.north] ?? []
        let isDummy: Bool = game.dummy == .north
        let northTappable: Bool = game.tappableSeat == .north
        let legal: Set<Card> = northTappable ? game.legalCards : []
        let tap: ((Card) -> Void)? = northTappable
            ? { (c: Card) in game.playCard(c, from: .north) }
            : nil

        return VStack(spacing: 4) {
            Text(isDummy ? "North (Dummy)" : "North")
                .font(.callout.bold())
                .foregroundColor(.white.opacity(0.85))
            HandView(cards: northCards, faceDown: !isNorthFaceUp(),
                     isSmall: true, legalCards: legal, onTap: tap)
        }
        .padding(.horizontal, 8)
        .padding(.top, 8)
    }

    // MARK: - West hand

    private var westArea: some View {
        return VStack(spacing: 4) {
            Text("West")
                .font(.callout.bold())
                .foregroundColor(.white.opacity(0.85))
            HandView(cards: game.hands[.west] ?? [], faceDown: true, isSmall: true)
                .rotationEffect(.degrees(90))
                .fixedSize()
        }
    }

    // MARK: - East hand

    private var eastArea: some View {
        return VStack(spacing: 4) {
            Text("East")
                .font(.callout.bold())
                .foregroundColor(.white.opacity(0.85))
            HandView(cards: game.hands[.east] ?? [], faceDown: true, isSmall: true)
                .rotationEffect(.degrees(-90))
                .fixedSize()
        }
    }

    // MARK: - Center

    private var centerArea: some View {
        return HStack(spacing: 10) {
            ScorePadView()
                .frame(maxHeight: 200)

            VStack(spacing: 8) {
                centerContent
                if !game.statusMessage.isEmpty {
                    Text(game.statusMessage)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.70))
                        .multilineTextAlignment(.center)
                }
            }

            if !game.auction.isEmpty {
                AuctionView(
                    auction: game.auction,
                    dealer: game.dealer,
                    contract: game.contract
                )
                .frame(maxWidth: 180, maxHeight: .infinity)
            }
        }
        .padding(.horizontal, 8)
    }

    @ViewBuilder
    private var centerContent: some View {
        if game.phase == .bidding {
            VStack(spacing: 6) {
                Text("Auction")
                    .font(.callout.bold())
                    .foregroundColor(.white.opacity(0.85))
                Text("\(game.currentBidder.name)'s turn")
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.65))
                if game.aiThinking {
                    ProgressView().tint(.white).scaleEffect(0.8)
                }
            }
        } else if game.phase == .playing {
            TrickAreaView(trick: game.currentTrick, contract: game.contract)
            ScoreTickerView(
                nsTricks: game.nsTricks,
                ewTricks: game.ewTricks,
                total: 13,
                contract: game.contract
            )
            .background(Color.white.opacity(0.92))
            .cornerRadius(8)
            if game.aiThinking {
                HStack(spacing: 4) {
                    ProgressView().tint(.white).scaleEffect(0.7)
                    Text("Thinking…")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.70))
                }
            }
        }
    }

    // MARK: - South hand

    private var southArea: some View {
        let southCards: [Card] = game.hands[.south] ?? []
        let isDeclarer: Bool = game.contract?.declarer == .south
        let southTappable: Bool = game.tappableSeat == .south
        let legal: Set<Card> = southTappable ? game.legalCards : []
        let tap: ((Card) -> Void)? = southTappable
            ? { (c: Card) in game.playCard(c, from: .south) }
            : nil

        return VStack(spacing: 6) {
            Text(isDeclarer ? "South — Declarer (You)" : "South (You)")
                .font(.callout.bold())
                .foregroundColor(.white.opacity(0.90))

            if game.phase == .playing {
                HandView(cards: southCards, faceDown: false, isSmall: false, isWide: true,
                         legalCards: legal, onTap: tap)
            } else {
                HandView(cards: southCards, faceDown: false, isSmall: false, isWide: true)
            }

            if game.phase == .bidding && game.isHumanTurn {
                BiddingBoxView()
                    .padding(.horizontal, 4)
            }
        }
        .padding(.horizontal, 8)
        .padding(.bottom, 8)
    }

    // MARK: - Overlays

    private var handResultData: (made: Bool, tricks: Int, score: Int)? {
        if case .handResult(let made, let tricks, let score) = game.phase {
            return (made: made, tricks: tricks, score: score)
        }
        return nil
    }

    @ViewBuilder
    private var overlayLayer: some View {
        if let r = handResultData {
            HandResultView(made: r.made, tricks: r.tricks, score: r.score)
        } else if game.phase == .rubberComplete {
            RubberCompleteView()
        }
    }
}
