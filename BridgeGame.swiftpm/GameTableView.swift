import SwiftUI

struct GameTableView: View {
    @EnvironmentObject var game: GameState

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color(red: 0.08, green: 0.40, blue: 0.15)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    NorthAreaView()
                        .frame(height: geo.size.height * 0.22)

                    HStack(alignment: .center, spacing: 0) {
                        SideHandView(seat: .west)
                            .frame(width: geo.size.width * 0.18)
                        CenterAreaView()
                            .frame(maxWidth: .infinity)
                        SideHandView(seat: .east)
                            .frame(width: geo.size.width * 0.18)
                    }
                    .frame(height: geo.size.height * 0.40)

                    SouthAreaView()
                        .frame(height: geo.size.height * 0.30)
                }

                TableOverlayView()
            }
        }
        .ignoresSafeArea(edges: .bottom)
    }
}

// MARK: - Overlay

struct TableOverlayView: View {
    @EnvironmentObject var game: GameState

    var body: some View {
        if case .handResult(let made, let tricks, let score) = game.phase {
            HandResultView(made: made, tricks: tricks, score: score)
        }
        if game.phase == .rubberComplete {
            RubberCompleteView()
        }
    }
}

// MARK: - North

struct NorthAreaView: View {
    @EnvironmentObject var game: GameState

    private var cards: [Card]    { game.hands[.north] ?? [] }
    private var isDummy: Bool    { game.dummy == .north }
    private var isPlaying: Bool  { game.phase == .playing }
    private var isTappable: Bool { game.tappableSeat == .north }

    var body: some View {
        VStack(spacing: 4) {
            Text(isDummy ? "North (Dummy)" : "North")
                .font(.caption.bold())
                .foregroundColor(.white.opacity(0.8))
            if isTappable {
                HandView(cards: cards, faceDown: false, isSmall: true,
                         legalCards: game.legalCards,
                         onTap: { card in game.playCard(card, from: .north) })
            } else if isPlaying && isDummy {
                HandView(cards: cards, faceDown: false, isSmall: true)
            } else {
                HandView(cards: cards, faceDown: true, isSmall: true)
            }
        }
        .padding(.horizontal, 8)
        .padding(.top, 8)
    }
}

// MARK: - East / West

struct SideHandView: View {
    @EnvironmentObject var game: GameState
    let seat: Seat

    var body: some View {
        VStack(spacing: 4) {
            Text(seat.name)
                .font(.caption.bold())
                .foregroundColor(.white.opacity(0.8))
            HandView(cards: game.hands[seat] ?? [], faceDown: true, isSmall: true)
                .rotationEffect(.degrees(seat == .west ? 90 : -90))
                .fixedSize()
        }
    }
}

// MARK: - Center

struct CenterAreaView: View {
    @EnvironmentObject var game: GameState

    var body: some View {
        HStack(spacing: 10) {
            ScorePadView()
                .frame(maxHeight: 180)

            VStack(spacing: 8) {
                CenterContentView()
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
}

struct CenterContentView: View {
    @EnvironmentObject var game: GameState

    var body: some View {
        Group {
            if game.phase == .bidding {
                VStack(spacing: 6) {
                    Text("Auction")
                        .font(.caption.bold())
                        .foregroundColor(.white.opacity(0.8))
                    Text("\(game.currentBidder.name)'s turn")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.6))
                    if game.aiThinking {
                        ProgressView().tint(.white).scaleEffect(0.8)
                    }
                }
            } else if game.phase == .playing {
                VStack(spacing: 8) {
                    TrickAreaView(trick: game.currentTrick, contract: game.contract)
                    ScoreTickerView(nsTricks: game.nsTricks, ewTricks: game.ewTricks,
                                    total: 13, contract: game.contract)
                        .background(Color.white.opacity(0.92))
                        .cornerRadius(8)
                    if game.aiThinking {
                        HStack(spacing: 4) {
                            ProgressView().tint(.white).scaleEffect(0.7)
                            Text("Thinking…")
                                .font(.caption2)
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }
                }
            }
        }
    }
}

// MARK: - South

struct SouthAreaView: View {
    @EnvironmentObject var game: GameState

    private var cards: [Card]    { game.hands[.south] ?? [] }
    private var isDeclarer: Bool { game.contract?.declarer == .south }
    private var isTappable: Bool { game.tappableSeat == .south }

    var body: some View {
        VStack(spacing: 6) {
            Text(isDeclarer ? "South — Declarer (You)" : "South (You)")
                .font(.caption.bold())
                .foregroundColor(.white.opacity(0.85))

            if isTappable {
                HandView(cards: cards, faceDown: false, isSmall: false,
                         legalCards: game.legalCards,
                         onTap: { card in game.playCard(card, from: .south) })
            } else {
                HandView(cards: cards, faceDown: false, isSmall: false)
            }

            if game.phase == .bidding && game.isHumanTurn {
                BiddingBoxView()
                    .padding(.horizontal, 4)
            }
        }
        .padding(.horizontal, 8)
        .padding(.bottom, 8)
    }
}
