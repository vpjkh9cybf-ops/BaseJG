// BRIDGE APP — Built 2026-06-07
import SwiftUI

struct GameTableView: View {
    @EnvironmentObject var game: GameState
    @State private var showAuction: Bool = false
    @State private var showSettings: Bool = false

    private var isBiddingPhase: Bool { game.phase == .bidding }
    private var trump: Suit? { game.contract?.strain.suit }

    // North is displayed wide when it's the dummy or when switchSeats has N as declarer
    private var isNorthWideDummy: Bool { game.dummy == .north && game.contract?.declarer == .south }
    private var isNorthWideDeclarer: Bool {
        game.switchSeatsForDeclarer && game.contract?.declarer == .north && game.phase == .playing
    }
    private var northIsWide: Bool { isNorthWideDummy || isNorthWideDeclarer }

    // E/W dummy shown large in center instead of rotated side column
    private var isEWDummyActive: Bool {
        guard game.phase == .playing, let d = game.dummy else { return false }
        return d == .east || d == .west
    }

    // Layout ratios for the north / mid / south rows
    private var northRatio: Double {
        if isBiddingPhase        { return 0.09 }
        if northIsWide           { return 0.22 }
        if isEWDummyActive       { return 0.09 }
        return 0.14
    }
    private var midRatio: Double {
        if isBiddingPhase        { return 0.62 }
        if northIsWide           { return 0.54 }
        if isEWDummyActive       { return 0.63 }
        return 0.56
    }
    private var southRatio: Double {
        if isBiddingPhase        { return 0.29 }
        if northIsWide           { return 0.24 }
        if isEWDummyActive       { return 0.28 }
        return 0.30
    }
    private var layoutKey: String {
        if isBiddingPhase  { return "bidding" }
        if northIsWide     { return "northWide" }
        if isEWDummyActive { return "ewDummy" }
        return "playing"
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

                HStack(alignment: .top, spacing: 0) {
                    // Score column — always visible on far left
                    scoreColumn
                        .frame(width: 110)
                        .frame(maxHeight: .infinity)

                    // Main play area
                    VStack(spacing: 0) {
                        northArea
                            .frame(height: geo.size.height * northRatio)

                        HStack(alignment: .center, spacing: 0) {
                            let sideW = (geo.size.width - 110) * 0.20
                            westArea.frame(width: sideW)
                            centerArea.frame(maxWidth: .infinity)
                            eastArea.frame(width: sideW)
                        }
                        .frame(height: geo.size.height * midRatio)

                        southArea
                            .frame(height: geo.size.height * southRatio)
                    }
                    .animation(.easeInOut(duration: 0.25), value: layoutKey)
                    .onChange(of: isBiddingPhase) { newVal in
                        if newVal { showAuction = false }
                    }
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
        .alert("Claim Denied", isPresented: $game.claimDenied) {
            Button("OK", role: .cancel) {}
        } message: {
            Text("The opponents still hold winning cards. You cannot claim all remaining tricks.")
        }
    }

    // MARK: - Score column (far left)

    private var scoreColumn: some View {
        VStack(spacing: 6) {
            ScorePadView()

            if !isBiddingPhase, let c = game.contract {
                contractButton(c)
            }

            if game.phase == .playing, let c = game.contract {
                trickCountView(c)
                claimButton
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 4)
        .padding(.top, 8)
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

    private var claimButton: some View {
        Button {
            game.claimTricks()
        } label: {
            Text("Claim")
                .font(.callout.bold())
                .foregroundColor(.white)
                .padding(.vertical, 6)
                .frame(maxWidth: .infinity)
                .background(game.canClaim() ? Color.blue : Color.gray.opacity(0.5))
                .cornerRadius(6)
        }
        .disabled(!game.canClaim())
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
            if isDummy             { return prefix + "North (Dummy)"      }
            if isNorthWideDeclarer { return prefix + "North — Declarer"   }
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
        let isDummy  = game.dummy == .west
        let isFaceUp = isDummy && game.phase == .playing
        let westTappable: Bool = !isEWDummyActive && game.tappableSeat == .west
        let legal: Set<Card> = westTappable ? game.legalCards : []
        let tap: ((Card) -> Void)? = westTappable
            ? { (c: Card) in game.playCard(c, from: .west) }
            : nil
        let label = (isBidding(.west) ? "▶ " : "") + (isDummy ? "West\n(Dummy)" : "West")

        return VStack(spacing: 4) {
            Text(label)
                .font(.callout.bold())
                .foregroundColor(seatColor(.west))
                .multilineTextAlignment(.center)
            if isEWDummyActive && isDummy {
                // Dummy is shown large in center — just show label here
                Text("↓ center")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.5))
            } else {
                HandView(cards: game.hands[.west] ?? [], faceDown: !isFaceUp, isSmall: true,
                         trumpSuit: trump, legalCards: legal, onTap: tap)
                    .rotationEffect(.degrees(90))
                    .fixedSize()
            }
        }
    }

    // MARK: - East hand

    private var eastArea: some View {
        let isDummy  = game.dummy == .east
        let isFaceUp = isDummy && game.phase == .playing
        let eastTappable: Bool = !isEWDummyActive && game.tappableSeat == .east
        let legal: Set<Card> = eastTappable ? game.legalCards : []
        let tap: ((Card) -> Void)? = eastTappable
            ? { (c: Card) in game.playCard(c, from: .east) }
            : nil
        let label = (isBidding(.east) ? "▶ " : "") + (isDummy ? "East\n(Dummy)" : "East")

        return VStack(spacing: 4) {
            Text(label)
                .font(.callout.bold())
                .foregroundColor(seatColor(.east))
                .multilineTextAlignment(.center)
            if isEWDummyActive && isDummy {
                Text("↓ center")
                    .font(.caption2)
                    .foregroundColor(.white.opacity(0.5))
            } else {
                HandView(cards: game.hands[.east] ?? [], faceDown: !isFaceUp, isSmall: true,
                         trumpSuit: trump, legalCards: legal, onTap: tap)
                    .rotationEffect(.degrees(-90))
                    .fixedSize()
            }
        }
    }

    // MARK: - Center

    private var centerArea: some View {
        VStack(spacing: 6) {
            if isEWDummyActive {
                ewDummyAndTrickLayout
            } else {
                HStack(spacing: 6) {
                    centerContent
                    if !game.auction.isEmpty && !isBiddingPhase && showAuction {
                        AuctionView(auction: game.auction, dealer: game.dealer, contract: game.contract)
                            .frame(maxWidth: 175, maxHeight: .infinity)
                    }
                }
            }

            if !game.statusMessage.isEmpty {
                Text(game.statusMessage)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.70))
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.horizontal, 6)
    }

    // E/W dummy shown face-up horizontally above the compact trick area
    @ViewBuilder
    private var ewDummyAndTrickLayout: some View {
        let dummySeat = game.dummy!
        let dummyCards = game.hands[dummySeat] ?? []
        let dummyTappable = game.tappableSeat == dummySeat
        let legal: Set<Card> = dummyTappable ? game.legalCards : []
        let tap: ((Card) -> Void)? = dummyTappable
            ? { (c: Card) in game.playCard(c, from: dummySeat) }
            : nil

        VStack(spacing: 4) {
            Text("\(dummySeat.name) (Dummy)")
                .font(.callout.bold())
                .foregroundColor(.white.opacity(0.85))

            GeometryReader { geo in
                HandView(cards: dummyCards, faceDown: false, isSmall: false, isWide: true,
                         trumpSuit: trump, legalCards: legal, onTap: tap)
                    .frame(width: geo.size.width, height: 180)
            }
            .frame(height: 180)

            HStack(spacing: 8) {
                TrickAreaView(trick: game.currentTrick, contract: game.contract, compact: true)
                if !game.auction.isEmpty && showAuction {
                    AuctionView(auction: game.auction, dealer: game.dealer, contract: game.contract)
                        .frame(maxWidth: 150, maxHeight: .infinity)
                }
            }
        }
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
                    AuctionView(auction: game.auction, dealer: game.dealer, contract: game.contract)
                        .frame(maxWidth: 300, maxHeight: .infinity)
                }
            }
        } else if game.phase == .playing {
            VStack(spacing: 4) {
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
