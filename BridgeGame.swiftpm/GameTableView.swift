// BRIDGE APP — Built 2026-06-07
import SwiftUI

struct GameTableView: View {
    @EnvironmentObject var game: GameState
    @State private var showAuction: Bool = false

    private var isBiddingPhase: Bool { game.phase == .bidding }
    // North is face-up dummy in a wide row when south is declarer
    private var isNorthWideDummy: Bool { game.dummy == .north && game.contract?.declarer == .south }
    private var trump: Suit? { game.contract?.strain.suit }

    // Layout ratios — three named states
    private var northRatio: Double {
        if isBiddingPhase { return 0.10 }
        return isNorthWideDummy ? 0.20 : 0.16
    }
    private var midRatio: Double {
        if isBiddingPhase { return 0.18 }
        return isNorthWideDummy ? 0.51 : 0.55
    }
    private var southRatio: Double {
        isBiddingPhase ? 0.72 : 0.29
    }
    private var layoutKey: String {
        isBiddingPhase ? "bidding" : (isNorthWideDummy ? "northDummy" : "playing")
    }

    private func isBidding(_ seat: Seat) -> Bool {
        game.phase == .bidding && game.currentBidder == seat
    }
    private func seatColor(_ seat: Seat) -> Color {
        isBidding(seat) ? .yellow : .white.opacity(0.85)
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color(red: 0.08, green: 0.40, blue: 0.15)
                    .ignoresSafeArea()

                VStack(spacing: 0) {
                    northArea
                        .frame(height: geo.size.height * northRatio)

                    HStack(alignment: .center, spacing: 0) {
                        westArea.frame(width: geo.size.width * 0.18)
                        centerArea.frame(maxWidth: .infinity)
                        eastArea.frame(width: geo.size.width * 0.18)
                    }
                    .frame(height: geo.size.height * midRatio)

                    southArea
                        .frame(height: geo.size.height * southRatio)
                }
                .animation(.easeInOut(duration: 0.25), value: layoutKey)
                .onChange(of: isBiddingPhase) { newVal in
                    if newVal { showAuction = false }
                }

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
        let label = (isBidding(.north) ? "▶ " : "") + (isDummy ? "North (Dummy)" : "North")

        return VStack(spacing: 4) {
            Text(label)
                .font(.callout.bold())
                .foregroundColor(seatColor(.north))
            if isNorthWideDummy {
                // Dummy shows wide like South, sorted trump-first
                HandView(cards: northCards, faceDown: false, isSmall: false, isWide: true,
                         trumpSuit: trump, legalCards: legal, onTap: tap)
            } else {
                HandView(cards: northCards, faceDown: !isNorthFaceUp(),
                         isSmall: true, trumpSuit: trump, legalCards: legal, onTap: tap)
            }
        }
        .padding(.horizontal, 8)
        .padding(.top, 8)
    }

    // MARK: - West hand

    private var westArea: some View {
        return VStack(spacing: 4) {
            Text((isBidding(.west) ? "▶ " : "") + "West")
                .font(.callout.bold())
                .foregroundColor(seatColor(.west))
            HandView(cards: game.hands[.west] ?? [], faceDown: true, isSmall: true,
                     trumpSuit: trump)
                .rotationEffect(.degrees(90))
                .fixedSize()
        }
    }

    // MARK: - East hand

    private var eastArea: some View {
        return VStack(spacing: 4) {
            Text((isBidding(.east) ? "▶ " : "") + "East")
                .font(.callout.bold())
                .foregroundColor(seatColor(.east))
            HandView(cards: game.hands[.east] ?? [], faceDown: true, isSmall: true,
                     trumpSuit: trump)
                .rotationEffect(.degrees(-90))
                .fixedSize()
        }
    }

    // MARK: - Center

    private var centerArea: some View {
        return HStack(spacing: 6) {
            // Compact left column: score + contract + trick count all stacked
            leftColumn

            // Center: trick area only (no ScoreTickerView — counts are in left column)
            VStack(spacing: 6) {
                centerContent
                if !game.statusMessage.isEmpty {
                    Text(game.statusMessage)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.70))
                        .multilineTextAlignment(.center)
                }
            }

            // Auction history: always during bidding, only when toggled during play
            if !game.auction.isEmpty && (isBiddingPhase || showAuction) {
                AuctionView(
                    auction: game.auction,
                    dealer: game.dealer,
                    contract: game.contract
                )
                .frame(maxWidth: 175, maxHeight: .infinity)
            }
        }
        .padding(.horizontal, 6)
    }

    private var leftColumn: some View {
        VStack(spacing: 4) {
            ScorePadView()
            if !isBiddingPhase, let c = game.contract {
                contractButton(c)
            }
            if game.phase == .playing, let c = game.contract {
                trickCountView(c)
            }
        }
        .frame(maxWidth: 120)
    }

    private func contractButton(_ c: Contract) -> some View {
        Button { showAuction.toggle() } label: {
            VStack(spacing: 2) {
                Text(c.display)
                    .font(.callout.bold())
                    .foregroundColor(.primary)
                Text("by \(c.declarer.name)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(showAuction ? "▲ Hide" : "▼ Bids")
                    .font(.caption2)
                    .foregroundColor(.blue)
            }
            .padding(5)
            .frame(maxWidth: .infinity)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(6)
            .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.blue.opacity(0.3), lineWidth: 0.5))
        }
    }

    private func trickCountView(_ c: Contract) -> some View {
        VStack(spacing: 3) {
            HStack(spacing: 12) {
                VStack(spacing: 1) {
                    Text("NS").font(.caption2.bold())
                    Text("\(game.nsTricks)").font(.title3.bold())
                        .foregroundColor(c.declarer.isNorthSouth ? .green : .primary)
                }
                VStack(spacing: 1) {
                    Text("EW").font(.caption2.bold())
                    Text("\(game.ewTricks)").font(.title3.bold())
                        .foregroundColor(!c.declarer.isNorthSouth ? .green : .primary)
                }
            }
            Text("Need \(c.tricksRequired)")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(5)
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(6)
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

        let southLabel = (isBidding(.south) ? "▶ " : "") + (isDeclarer ? "South — Declarer (You)" : "South (You)")
        return VStack(spacing: 6) {
            Text(southLabel)
                .font(.callout.bold())
                .foregroundColor(seatColor(.south))

            if game.phase == .playing {
                HandView(cards: southCards, faceDown: false, isSmall: false, isWide: true,
                         trumpSuit: trump, legalCards: legal, onTap: tap)
            } else {
                HandView(cards: southCards, faceDown: false, isSmall: false, isWide: true,
                         trumpSuit: trump)
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
