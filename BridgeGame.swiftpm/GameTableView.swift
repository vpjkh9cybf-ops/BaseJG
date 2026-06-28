// BRIDGE APP — Built 2026-06-07
import SwiftUI

struct GameTableView: View {
    @EnvironmentObject var game: GameState
    @State private var showAuction: Bool = false
    @State private var showSettings: Bool = false

    private var isBiddingPhase: Bool { game.phase == .bidding }
    private var trump: Suit? { game.contract?.strain.suit }

    // Dummy is revealed only after the opening lead is played
    private var dummyRevealed: Bool {
        guard game.phase == .playing else { return false }
        return (game.currentTrick?.plays.count ?? 0) > 0 || !game.completedTricks.isEmpty
    }

    private var ewDummyRevealed: Bool {
        dummyRevealed && (game.dummy == .east || game.dummy == .west)
    }

    // North is displayed wide when it's the dummy or when switchSeats has N as declarer
    private var isNorthWideDummy: Bool {
        dummyRevealed && game.dummy == .north && game.contract?.declarer == .south
    }
    private var isNorthWideDeclarer: Bool {
        game.switchSeatsForDeclarer && game.contract?.declarer == .north && game.phase == .playing
    }
    // Also wide when North is declarer (seats not switched) — suit-row layout is too tall
    // for the small northRatio frame; use the horizontal fan so all cards and indices are visible
    private var isNorthFaceUpDeclarer: Bool {
        dummyRevealed && game.contract?.declarer == .north &&
        !game.switchSeatsForDeclarer && game.phase == .playing
    }
    private var northIsWide: Bool { isNorthWideDummy || isNorthWideDeclarer || isNorthFaceUpDeclarer }

    // Layout ratios for the north / mid / south rows
    private var northRatio: Double {
        if isBiddingPhase        { return 0.13 }
        if northIsWide           { return 0.22 }
        return 0.14
    }
    private var midRatio: Double {
        if isBiddingPhase        { return 0.58 }
        if northIsWide           { return 0.54 }
        return 0.56
    }
    private var southRatio: Double {
        if isBiddingPhase        { return 0.29 }
        if northIsWide           { return 0.24 }
        return 0.30
    }
    private var layoutKey: String {
        if isBiddingPhase  { return "bidding" }
        if northIsWide     { return "northWide" }
        return "playing"
    }

    private func isBidding(_ seat: Seat) -> Bool {
        game.phase == .bidding && game.currentBidder == seat
    }
    private func isVulnerable(_ seat: Seat) -> Bool {
        game.vulnerability.isVulnerable(seat)
    }
    private func seatColor(_ seat: Seat) -> Color {
        if isBidding(seat) { return .yellow }
        return isVulnerable(seat) ? .red : .white.opacity(0.85)
    }

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color(red: 0.08, green: 0.40, blue: 0.15)
                    .ignoresSafeArea()

                HStack(alignment: .top, spacing: 0) {
                    // Score column — always visible on far left
                    scoreColumn
                        .frame(width: 145)
                        .frame(maxHeight: .infinity)

                    // Main play area
                    VStack(spacing: 0) {
                        northArea
                            .frame(height: geo.size.height * northRatio)

                        HStack(alignment: .top, spacing: 0) {
                            let mainW = geo.size.width - 145
                            let westW = game.dummy == .west && ewDummyRevealed
                                ? mainW * 0.40
                                : ewDummyRevealed ? mainW * 0.10 : mainW * 0.20
                            let eastW = game.dummy == .east && ewDummyRevealed
                                ? mainW * 0.40
                                : ewDummyRevealed ? mainW * 0.10 : mainW * 0.20
                            westArea.frame(width: westW)
                            centerArea.frame(maxWidth: .infinity)
                            eastArea.frame(width: eastW)
                        }
                        .frame(height: geo.size.height * midRatio)
                        .clipped()

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
        .alert("Correct!", isPresented: $game.showCorrectPractice) {
            Button("Next Hand") { game.nextPracticeHand() }
            Button("OK", role: .cancel) { game.continuePracticeBid() }
        } message: {
            Text(game.practiceFeedbackMessage)
        }
        .alert("Convention Practice", isPresented: $game.showIncorrectPractice) {
            Button("Next Hand") { game.nextPracticeHand() }
            Button("Rebid") { game.rebidPracticeHand() }
            Button("Continue Anyway", role: .cancel) { game.continuePracticeBid() }
        } message: {
            Text(game.practiceFeedbackMessage)
        }
    }

    // MARK: - Score column (far left)

    private var scoreColumn: some View {
        VStack(spacing: 6) {
            if let convention = game.practiceConvention {
                VStack(spacing: 2) {
                    Text("PRACTICE")
                        .font(.system(size: 9, weight: .heavy))
                        .foregroundColor(.black)
                    Text(convention.rawValue)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.black)
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
                .frame(maxWidth: .infinity)
                .background(Color.yellow)
                .cornerRadius(6)
            }
            ScorePadView()

            if !isBiddingPhase, let c = game.contract {
                contractButton(c)
            }

            if game.phase == .playing, let c = game.contract {
                trickCountView(c)
                claimButton
                replayButtons
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

    private var replayButtons: some View {
        VStack(spacing: 4) {
            Button("↺ Rebid") { game.replayFromBidding() }
                .font(.caption2.bold())
                .foregroundColor(.white.opacity(0.65))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
                .background(Color.white.opacity(0.08))
                .cornerRadius(5)
            Button("↺ Replay Play") { game.replayFromPlay() }
                .font(.caption2.bold())
                .foregroundColor(.white.opacity(0.65))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 4)
                .background(Color.white.opacity(0.08))
                .cornerRadius(5)
        }
    }

    // MARK: - North hand

    private func isNorthFaceUp() -> Bool {
        guard game.phase == .playing else { return false }
        if game.dummy == .north { return dummyRevealed }
        // When North is declarer and human (South) is dummy, reveal North's hand after opening lead
        if game.contract?.declarer == .north && !game.switchSeatsForDeclarer { return dummyRevealed }
        if isNorthWideDeclarer { return true }
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
            if isDummy                                    { return prefix + "North (Dummy)"    }
            if isNorthWideDeclarer || isNorthFaceUpDeclarer { return prefix + "North — Declarer" }
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
        let isFaceUp = isDummy && dummyRevealed
        let westTappable: Bool = game.tappableSeat == .west
        let legal: Set<Card> = westTappable ? game.legalCards : []
        let tap: ((Card) -> Void)? = westTappable
            ? { (c: Card) in game.playCard(c, from: .west) }
            : nil

        return Group {
            if isFaceUp && ewDummyRevealed {
                VStack(spacing: 4) {
                    Text((isBidding(.west) ? "▶ " : "") + "West (Dummy)")
                        .font(.callout.bold())
                        .foregroundColor(seatColor(.west))
                    HandView(cards: game.hands[.west] ?? [], faceDown: false,
                             isSmall: false, isMedium: true,
                             trumpSuit: trump, legalCards: legal, onTap: tap)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 4)
            } else {
                ZStack(alignment: .top) {
                    HandView(cards: game.hands[.west] ?? [], faceDown: !isFaceUp, isSmall: true,
                             trumpSuit: trump, legalCards: legal, onTap: tap)
                        .rotationEffect(.degrees(90))
                        .fixedSize()
                    Text((isBidding(.west) ? "▶ " : "") + (isDummy ? "West\n(Dummy)" : "West"))
                        .font(.callout.bold())
                        .foregroundColor(seatColor(.west))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Color(red: 0.08, green: 0.40, blue: 0.15).opacity(0.9))
                        .cornerRadius(4)
                        .padding(.top, 4)
                }
            }
        }
    }

    // MARK: - East hand

    private var eastArea: some View {
        let isDummy  = game.dummy == .east
        let isFaceUp = isDummy && dummyRevealed
        let eastTappable: Bool = game.tappableSeat == .east
        let legal: Set<Card> = eastTappable ? game.legalCards : []
        let tap: ((Card) -> Void)? = eastTappable
            ? { (c: Card) in game.playCard(c, from: .east) }
            : nil

        return Group {
            if isFaceUp && ewDummyRevealed {
                VStack(spacing: 4) {
                    Text((isBidding(.east) ? "▶ " : "") + "East (Dummy)")
                        .font(.callout.bold())
                        .foregroundColor(seatColor(.east))
                    HandView(cards: game.hands[.east] ?? [], faceDown: false,
                             isSmall: false, isMedium: true,
                             trumpSuit: trump, legalCards: legal, onTap: tap)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 4)
            } else {
                ZStack(alignment: .top) {
                    HandView(cards: game.hands[.east] ?? [], faceDown: !isFaceUp, isSmall: true,
                             trumpSuit: trump, legalCards: legal, onTap: tap)
                        .rotationEffect(.degrees(-90))
                        .fixedSize()
                    Text((isBidding(.east) ? "▶ " : "") + (isDummy ? "East\n(Dummy)" : "East"))
                        .font(.callout.bold())
                        .foregroundColor(seatColor(.east))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Color(red: 0.08, green: 0.40, blue: 0.15).opacity(0.9))
                        .cornerRadius(4)
                        .padding(.top, 4)
                }
            }
        }
    }

    // MARK: - Center

    private var centerArea: some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                centerContent
                if !game.auction.isEmpty && !isBiddingPhase && showAuction {
                    AuctionView(auction: game.auction, dealer: game.dealer, contract: game.contract,
                                alternateColors: game.conventionSettings.useAlternateColors)
                        .frame(maxWidth: 175, maxHeight: .infinity)
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
        .padding(.top, isBiddingPhase ? 8 : 0)
    }

    @ViewBuilder
    private var centerContent: some View {
        if game.phase == .bidding {
            VStack(spacing: 10) {
                // Thinking indicator — only when AI is active
                if game.aiThinking {
                    HStack(spacing: 6) {
                        ProgressView().tint(.white).scaleEffect(0.7)
                        Text("\(game.currentBidder.name) is thinking…")
                            .font(.caption.bold())
                            .foregroundColor(.white.opacity(0.75))
                    }
                } else if !game.isHumanTurn {
                    Text("\(game.currentBidder.name)'s turn")
                        .font(.caption.bold())
                        .foregroundColor(.white.opacity(0.75))
                }

                // Auction + bidding box side by side — auction takes natural height
                HStack(alignment: .top, spacing: 8) {
                    if !game.auction.isEmpty {
                        AuctionView(auction: game.auction, dealer: game.dealer, contract: game.contract,
                                    alternateColors: game.conventionSettings.useAlternateColors)
                            .frame(minWidth: 160, maxWidth: 200)
                    }
                    if game.isHumanTurn {
                        BiddingBoxView()
                    }
                }

                // Info area — one clearly styled block per item, in priority order
                biddingInfoArea
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

    // MARK: - Bidding info area

    @ViewBuilder
    private var biddingInfoArea: some View {
        // Practice hint — large, prominent coaching tip (shown before human bids)
        if !game.practiceHint.isEmpty {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "lightbulb.fill")
                    .font(.footnote)
                    .foregroundColor(.yellow)
                VStack(alignment: .leading, spacing: 3) {
                    Text("Convention Tip")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundColor(.yellow)
                    Text(game.practiceHint)
                        .font(.footnote)
                        .foregroundColor(.white.opacity(0.95))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.black.opacity(0.55))
            .cornerRadius(10)
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.yellow.opacity(0.45), lineWidth: 1)
            )
        }

        // Bid warning — advisory (shown after human commits a bid)
        if let warning = game.bidWarning {
            BidWarningView(analysis: warning)
        }

        // AI bid explanation — only when no practice hint is showing
        if !game.biddingNote.isEmpty && game.practiceHint.isEmpty {
            Text(game.biddingNote)
                .font(.caption)
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color.black.opacity(0.72))
                .cornerRadius(8)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.white.opacity(0.18), lineWidth: 0.5)
                )
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.2), value: game.biddingNote)
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
