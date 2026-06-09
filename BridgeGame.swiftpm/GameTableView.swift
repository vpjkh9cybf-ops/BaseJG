// BRIDGE APP — Built 2026-06-07
import SwiftUI

struct GameTableView: View {
    @EnvironmentObject var game: GameState
    @State private var showAuction: Bool = false
    @State private var showSettings: Bool = false

    private var isBiddingPhase: Bool { game.phase == .bidding }
    private var isNorthWideDummy: Bool { game.dummy == .north && game.contract?.declarer == .south }
    private var isNorthWideDeclarer: Bool {
        game.switchSeatsForDeclarer && game.contract?.declarer == .north && game.phase == .playing
    }
    private var northIsWide: Bool { isNorthWideDummy || isNorthWideDeclarer }
    private var trump: Suit? { game.contract?.strain.suit }

    // Layout ratios
    private var northRatio: Double {
        if isBiddingPhase { return 0.09 }
        return northIsWide ? 0.22 : 0.14
    }
    private var midRatio: Double {
        if isBiddingPhase { return 0.62 }
        return northIsWide ? 0.54 : 0.56
    }
    private var southRatio: Double {
        if isBiddingPhase { return 0.29 }
        return northIsWide ? 0.24 : 0.30
    }
    private var layoutKey: String {
        isBiddingPhase ? "bidding" : (northIsWide ? "northWide" : "playing")
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

                // Gear button — top-right corner
                VStack {
                    HStack {
                        Spacer()
                        Button { showSettings = true } label: {
                            Image(systemName: "gearshape.fill")
                                .font(.title3)
                                .foregroundColor(.white.opacity(0.7))
                                .padding(10)
                        }
                    }
                    Spacer()
                }
            }
        }
        .ignoresSafeArea(edges: .bottom)
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
    }

    // MARK: - North hand

    private func isNorthFaceUp() -> Bool {
        guard game.phase == .playing else { return false }
        if game.dummy == .north { return true }
        if isNorthWideDeclarer   { return true }
        return false
    }

    private var northArea: some View {
        let northCards: [Card] = game.hands[.north] ?? []
        let isDummy: Bool = game.dummy == .north
        let northTappable: Bool = game.tappableSeat == .north
        let legal: Set<Card> = northTappable ? game.legalCards : []
        let tap: ((Card) -> Void)? = northTappable
            ? { (c: Card) in game.playCard(c, from: .north) }
            : nil
        let label: String = {
            let prefix = isBidding(.north) ? "▶ " : ""
            if isDummy          { return prefix + "North (Dummy)"   }
            if isNorthWideDeclarer { return prefix + "North — Declarer" }
            return prefix + "North"
        }()

        return VStack(spacing: 4) {
            Text(label)
                .font(.callout.bold())
                .foregroundColor(seatColor(.north))
            if northIsWide {
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
        let isDummy = game.dummy == .west
        let isFaceUp = isDummy && game.phase == .playing
        let westTappable: Bool = game.tappableSeat == .west
        let legal: Set<Card> = westTappable ? game.legalCards : []
        let tap: ((Card) -> Void)? = westTappable
            ? { (c: Card) in game.playCard(c, from: .west) }
            : nil
        let label = (isBidding(.west) ? "▶ " : "") + (isDummy ? "West (Dummy)" : "West")

        return VStack(spacing: 4) {
            Text(label)
                .font(.callout.bold())
                .foregroundColor(seatColor(.west))
            HandView(cards: game.hands[.west] ?? [], faceDown: !isFaceUp, isSmall: true,
                     trumpSuit: trump, legalCards: legal, onTap: tap)
                .rotationEffect(.degrees(90))
                .fixedSize()
        }
    }

    // MARK: - East hand

    private var eastArea: some View {
        let isDummy = game.dummy == .east
        let isFaceUp = isDummy && game.phase == .playing
        let eastTappable: Bool = game.tappableSeat == .east
        let legal: Set<Card> = eastTappable ? game.legalCards : []
        let tap: ((Card) -> Void)? = eastTappable
            ? { (c: Card) in game.playCard(c, from: .east) }
            : nil
        let label = (isBidding(.east) ? "▶ " : "") + (isDummy ? "East (Dummy)" : "East")

        return VStack(spacing: 4) {
            Text(label)
                .font(.callout.bold())
                .foregroundColor(seatColor(.east))
            HandView(cards: game.hands[.east] ?? [], faceDown: !isFaceUp, isSmall: true,
                     trumpSuit: trump, legalCards: legal, onTap: tap)
                .rotationEffect(.degrees(-90))
                .fixedSize()
        }
    }

    // MARK: - Center

    private var centerArea: some View {
        return HStack(spacing: 6) {
            leftColumn

            VStack(spacing: 6) {
                centerContent
                if !game.statusMessage.isEmpty {
                    Text(game.statusMessage)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.70))
                        .multilineTextAlignment(.center)
                }
            }

            // Auction history: only during play when toggled
            if !game.auction.isEmpty && !isBiddingPhase && showAuction {
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
                HStack(spacing: 6) {
                    Text("\(game.currentBidder.name)'s turn")
                        .font(.caption.bold())
                        .foregroundColor(.white.opacity(0.75))
                    if game.aiThinking {
                        ProgressView().tint(.white).scaleEffect(0.7)
                    }
                }
                if game.isHumanTurn {
                    BiddingBoxView()
                } else if !game.auction.isEmpty {
                    AuctionView(
                        auction: game.auction,
                        dealer: game.dealer,
                        contract: game.contract
                    )
                    .frame(maxWidth: 300, maxHeight: .infinity)
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
        let isDummy: Bool = game.dummy == .south
        let southTappable: Bool = game.tappableSeat == .south
        let legal: Set<Card> = southTappable ? game.legalCards : []
        let tap: ((Card) -> Void)? = southTappable
            ? { (c: Card) in game.playCard(c, from: .south) }
            : nil

        let southLabel: String = {
            let prefix = isBidding(.south) ? "▶ " : ""
            if isDeclarer { return prefix + "South — Declarer (You)" }
            if isDummy    { return prefix + "South (Dummy)" }
            return prefix + "South (You)"
        }()

        return VStack(spacing: 6) {
            Text(southLabel)
                .font(.callout.bold())
                .foregroundColor(seatColor(.south))

            HandView(cards: southCards, faceDown: false, isSmall: false, isWide: true,
                     trumpSuit: trump, legalCards: legal,
                     onTap: southTappable ? tap : nil)
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
