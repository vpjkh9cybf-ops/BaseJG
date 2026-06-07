import SwiftUI

struct GameTableView: View {
    @EnvironmentObject var game: GameState

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color(red: 0.08, green: 0.40, blue: 0.15)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    northArea
                        .frame(height: geo.size.height * 0.22)

                    HStack(alignment: .center, spacing: 0) {
                        westArea.frame(width: geo.size.width * 0.18)
                        centerArea.frame(maxWidth: .infinity)
                        eastArea.frame(width: geo.size.width * 0.18)
                    }
                    .frame(height: geo.size.height * 0.40)

                    southArea
                        .frame(height: geo.size.height * 0.30)
                }

                overlayLayer
            }
        }
        .ignoresSafeArea(edges: .bottom)
    }

    // MARK: - North

    private var northArea: some View {
        let northCards = game.hands[.north] ?? []
        let isDummy    = game.dummy == .north
        var showFaceUp = false
        if case .playing = game.phase { showFaceUp = isDummy }

        let legal: Set<Card> = (game.tappableSeat == .north) ? game.legalCards : []
        let tap: ((Card) -> Void)? = (game.tappableSeat == .north)
            ? { [game] card in game.playCard(card, from: .north) }
            : nil

        return VStack(spacing: 4) {
            Text(isDummy ? "North (Dummy)" : "North")
                .font(.caption.bold())
                .foregroundColor(.white.opacity(0.8))
            HandView(cards: northCards, faceDown: !showFaceUp,
                     isSmall: true, legalCards: legal, onTap: tap)
        }
        .padding(.horizontal, 8)
        .padding(.top, 8)
    }

    // MARK: - West

    private var westArea: some View {
        VStack(spacing: 4) {
            Text("West")
                .font(.caption.bold())
                .foregroundColor(.white.opacity(0.8))
            HandView(cards: game.hands[.west] ?? [], faceDown: true, isSmall: true)
                .rotationEffect(.degrees(90))
                .fixedSize()
        }
    }

    // MARK: - East

    private var eastArea: some View {
        VStack(spacing: 4) {
            Text("East")
                .font(.caption.bold())
                .foregroundColor(.white.opacity(0.8))
            HandView(cards: game.hands[.east] ?? [], faceDown: true, isSmall: true)
                .rotationEffect(.degrees(-90))
                .fixedSize()
        }
    }

    // MARK: - Center

    private var centerArea: some View {
        HStack(spacing: 10) {
            ScorePadView()
                .frame(maxHeight: 180)

            VStack(spacing: 8) {
                centerContent
                if !game.statusMessage.isEmpty {
                    Text(game.statusMessage)
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.65))
                        .multilineTextAlignment(.center)
                }
            }

            if !game.auction.isEmpty {
                AuctionView(auction: game.auction, dealer: game.dealer, contract: game.contract)
                    .frame(maxWidth: 160, maxHeight: 220)
            }
        }
        .padding(.horizontal, 8)
    }

    @ViewBuilder
    private var centerContent: some View {
        if case .bidding = game.phase {
            VStack(spacing: 6) {
                Text("Auction")
                    .font(.caption.bold())
                    .foregroundColor(.white.opacity(0.8))
                Text("\(game.currentBidder.name)'s turn")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.6))
                if game.aiThinking { ProgressView().tint(.white).scaleEffect(0.8) }
            }
        } else if case .playing = game.phase {
            TrickAreaView(trick: game.currentTrick, contract: game.contract)
            ScoreTickerView(nsTricks: game.nsTricks, ewTricks: game.ewTricks,
                            total: 13, contract: game.contract)
                .background(Color.white.opacity(0.92))
                .cornerRadius(8)
            if game.aiThinking {
                HStack(spacing: 4) {
                    ProgressView().tint(.white).scaleEffect(0.7)
                    Text("Thinking…").font(.caption2).foregroundColor(.white.opacity(0.7))
                }
            }
        }
    }

    // MARK: - South

    private var southArea: some View {
        let southCards = game.hands[.south] ?? []
        let isDeclarer = game.contract?.declarer == .south

        let legal: Set<Card> = (game.tappableSeat == .south) ? game.legalCards : []
        let tap: ((Card) -> Void)? = (game.tappableSeat == .south)
            ? { [game] card in game.playCard(card, from: .south) }
            : nil

        return VStack(spacing: 6) {
            Text(isDeclarer ? "South — Declarer (You)" : "South (You)")
                .font(.caption.bold())
                .foregroundColor(.white.opacity(0.85))

            if case .playing = game.phase {
                HandView(cards: southCards, faceDown: false, isSmall: false,
                         legalCards: legal, onTap: tap)
            } else {
                HandView(cards: southCards, faceDown: false, isSmall: false)
            }

            if case .bidding = game.phase {
                if game.isHumanTurn {
                    BiddingBoxView()
                        .padding(.horizontal, 4)
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.bottom, 8)
    }

    // MARK: - Overlays

    @ViewBuilder
    private var overlayLayer: some View {
        if case .handResult(let made, let tricks, let score) = game.phase {
            HandResultView(made: made, tricks: tricks, score: score)
        } else if case .rubberComplete = game.phase {
            RubberCompleteView()
        }
    }
}
