import SwiftUI

struct GameTableView: View {
    @EnvironmentObject var game: GameState

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Green felt background
                Color(red: 0.08, green: 0.40, blue: 0.15)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    northArea
                        .frame(height: geo.size.height * 0.22)

                    HStack(alignment: .center, spacing: 0) {
                        westArea
                            .frame(width: geo.size.width * 0.18)
                        centerArea
                            .frame(maxWidth: .infinity)
                        eastArea
                            .frame(width: geo.size.width * 0.18)
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
        let isDummy = game.dummy == .north
        let isPlaying: Bool = {
            if case .playing = game.phase { return true }
            return false
        }()
        let showFaceUp = isDummy && isPlaying

        return VStack(spacing: 4) {
            Text(isDummy ? "North (Dummy)" : "North")
                .font(.caption.bold())
                .foregroundColor(.white.opacity(0.8))

            HandView(
                cards: northCards,
                faceDown: !showFaceUp,
                isSmall: true,
                legalCards: (game.tappableSeat == .north) ? game.legalCards : [],
                onTap: (game.tappableSeat == .north) ? { card in game.playCard(card, from: .north) } : nil
            )
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
            let westCards = game.hands[.west] ?? []
            HandView(cards: westCards, faceDown: true, isSmall: true)
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
            let eastCards = game.hands[.east] ?? []
            HandView(cards: eastCards, faceDown: true, isSmall: true)
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
                if case .bidding = game.phase {
                    VStack(spacing: 6) {
                        Text("Auction")
                            .font(.caption.bold())
                            .foregroundColor(.white.opacity(0.8))
                        Text("\(game.currentBidder.name)'s turn")
                            .font(.caption2)
                            .foregroundColor(.white.opacity(0.6))
                        if game.aiThinking {
                            ProgressView()
                                .tint(.white)
                                .scaleEffect(0.8)
                        }
                    }
                } else if case .playing = game.phase {
                    TrickAreaView(trick: game.currentTrick, contract: game.contract)
                    ScoreTickerView(
                        nsTricks: game.nsTricks,
                        ewTricks: game.ewTricks,
                        total: 13,
                        contract: game.contract
                    )
                    .background(Color(.systemBackground).opacity(0.92))
                    .cornerRadius(8)
                    if game.aiThinking {
                        HStack(spacing: 4) {
                            ProgressView().tint(.white).scaleEffect(0.7)
                            Text("Thinking…").font(.caption2).foregroundColor(.white.opacity(0.7))
                        }
                    }
                }

                if !game.statusMessage.isEmpty {
                    Text(game.statusMessage)
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.65))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 4)
                }
            }

            if !game.auction.isEmpty {
                AuctionView(auction: game.auction, dealer: game.dealer, contract: game.contract)
                    .frame(maxWidth: 160, maxHeight: 220)
            }
        }
        .padding(.horizontal, 8)
    }

    // MARK: - South

    private var southArea: some View {
        let southCards = game.hands[.south] ?? []
        let isDeclarer = game.contract?.declarer == .south

        return VStack(spacing: 6) {
            Text(isDeclarer ? "South — Declarer (You)" : "South (You)")
                .font(.caption.bold())
                .foregroundColor(.white.opacity(0.85))

            if case .playing = game.phase {
                HandView(
                    cards: southCards,
                    faceDown: false,
                    isSmall: false,
                    legalCards: (game.tappableSeat == .south) ? game.legalCards : [],
                    onTap: (game.tappableSeat == .south) ? { card in game.playCard(card, from: .south) } : nil
                )
            } else {
                HandView(cards: southCards, faceDown: false, isSmall: false)
            }

            if case .bidding = game.phase {
                if game.isHumanTurn && !game.aiThinking {
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
        switch game.phase {
        case .handResult(let made, let tricks, let score):
            HandResultView(made: made, tricks: tricks, score: score)
        case .rubberComplete:
            RubberCompleteView()
        default:
            EmptyView()
        }
    }
}
