// Conventional Wisdom — modified 2026-08-15 01:52 UTC
import SwiftUI

struct GameTableView: View {
    @EnvironmentObject var game: GameState
    @State private var showAuction: Bool = false
    @State private var showSettings: Bool = false
    @State private var confirmExit: Bool = false

    private let scoreColumnW: CGFloat = 145

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

    // North is displayed wide when it's the dummy or when North is declarer
    private var isNorthWideDummy: Bool {
        dummyRevealed && game.dummy == .north && game.contract?.declarer == .south
    }
    private var isNorthWideDeclarer: Bool {
        game.switchSeatsForDeclarer && game.contract?.declarer == .north && game.phase == .playing
    }
    // Also wide when North is declarer but seats were not switched — the suit-row
    // layout is too tall for the small north frame to show every index.
    private var isNorthFaceUpDeclarer: Bool {
        game.contract?.declarer == .north &&
        !game.switchSeatsForDeclarer && game.phase == .playing
    }
    private var northIsWide: Bool { isNorthWideDummy || isNorthWideDeclarer || isNorthFaceUpDeclarer }

    // MARK: - Layout ratios for the north / mid / south rows

    private var northRatio: Double {
        if isBiddingPhase { return 0.13 }
        if northIsWide    { return 0.22 }
        return 0.14
    }
    private var midRatio: Double {
        if isBiddingPhase { return 0.58 }
        if northIsWide    { return 0.53 }
        return 0.56
    }
    private var southRatio: Double {
        if isBiddingPhase { return 0.29 }
        if northIsWide    { return 0.25 }
        return 0.30
    }
    private var layoutKey: String {
        if isBiddingPhase { return "bidding" }
        if northIsWide    { return "northWide" }
        return "playing"
    }

    /// Width of a side (East/West) column. The revealed dummy gets a real column
    /// but is hard-capped so it can never encroach on the trick area.
    private func sideWidth(_ seat: Seat, mainW: CGFloat) -> CGFloat {
        guard ewDummyRevealed else { return mainW * 0.20 }
        if game.dummy == seat { return min(300, mainW * 0.34) }
        return mainW * 0.11
    }

    /// Box the East/West dummy is allowed to paint into.
    private func dummySize(_ seat: Seat, geo: GeometryProxy) -> CGSize {
        let mainW = geo.size.width - scoreColumnW
        let w = sideWidth(seat, mainW: mainW) - 10
        let h = geo.size.height * midRatio - 30   // seat label + padding
        return CGSize(width: max(90, w), height: max(90, h))
    }

    /// Space left in the middle once both side columns are subtracted.
    private func trickSize(geo: GeometryProxy) -> CGSize {
        let mainW = geo.size.width - scoreColumnW
        let w = mainW - sideWidth(.west, mainW: mainW) - sideWidth(.east, mainW: mainW) - 16
        let h = geo.size.height * midRatio - 44    // status line + padding
        return CGSize(width: max(140, w), height: max(150, h))
    }

    private func fanHeight(_ ratio: Double, geo: GeometryProxy, chrome: CGFloat) -> CGFloat {
        max(90, min(180, geo.size.height * ratio - chrome))
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

    // MARK: - Body

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color(red: 0.08, green: 0.40, blue: 0.15)
                    .ignoresSafeArea()

                HStack(alignment: .top, spacing: 0) {
                    scoreColumn
                        .frame(width: scoreColumnW)
                        .frame(maxHeight: .infinity)

                    tableColumn(geo: geo)
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
        .alert("Leave this game?", isPresented: $confirmExit) {
            Button("Leave", role: .destructive) { game.returnToMenu() }
            Button("Keep Playing", role: .cancel) {}
        } message: {
            Text("The hand in progress and the current score will be discarded.")
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

    private func tableColumn(geo: GeometryProxy) -> some View {
        let mainW = geo.size.width - scoreColumnW
        return VStack(spacing: 0) {
            northArea(geo: geo)
                .frame(height: geo.size.height * northRatio)

            HStack(alignment: .top, spacing: 0) {
                westArea(geo: geo).frame(width: sideWidth(.west, mainW: mainW))
                centerArea(geo: geo).frame(maxWidth: .infinity)
                eastArea(geo: geo).frame(width: sideWidth(.east, mainW: mainW))
            }
            .frame(height: geo.size.height * midRatio)
            .clipped()

            southArea(geo: geo)
                .frame(height: geo.size.height * southRatio)
        }
        .animation(.easeInOut(duration: 0.25), value: layoutKey)
        .onChange(of: isBiddingPhase) { newVal in
            if newVal { showAuction = false }
        }
    }

    // MARK: - Score column (far left)

    private var practiceBadgeText: String {
        game.practiceConvention?.rawValue ?? "Free deal"
    }

    private var scoreColumn: some View {
        VStack(spacing: 6) {
            if !game.practiceConventions.isEmpty {
                practiceBadge
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

            // Pinned to the bottom of the column, clear of every hand
            exitButton
        }
        .padding(.horizontal, 4)
        .padding(.top, 8)
        .padding(.bottom, 8)
    }

    private var exitButton: some View {
        Button { confirmExit = true } label: {
            HStack(spacing: 5) {
                Image(systemName: "house.fill")
                Text("Main Menu").font(.caption.bold())
            }
            .foregroundColor(.white.opacity(0.85))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .background(Color.black.opacity(0.30))
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(Color.white.opacity(0.25), lineWidth: 0.5)
            )
        }
    }

    private var practiceBadge: some View {
        VStack(spacing: 2) {
            Text("PRACTICE")
                .font(.system(size: 9, weight: .heavy))
                .foregroundColor(.black)
            Text(practiceBadgeText)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.black)
                .multilineTextAlignment(.center)
            if game.practiceConventions.count > 1 {
                Text("\(game.practiceConventions.count) in rotation")
                    .font(.system(size: 9))
                    .foregroundColor(.black.opacity(0.6))
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .frame(maxWidth: .infinity)
        .background(Color.yellow)
        .cornerRadius(6)
    }

    private func contractButton(_ c: Contract) -> some View {
        Button { showAuction.toggle() } label: {
            VStack(spacing: 2) {
                HStack(spacing: 1) {
                    Text("\(c.level.rawValue)")
                        .foregroundColor(.primary)
                    Text(c.strain.display)
                        .foregroundColor(c.strain.color(alternate: game.conventionSettings.useAlternateColors))
                    if c.doubled == .doubled {
                        Text("X").foregroundColor(.red)
                    } else if c.doubled == .redoubled {
                        Text("XX").foregroundColor(.purple)
                    }
                }
                .font(.callout.bold())
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
        if game.contract?.declarer == .north && !game.switchSeatsForDeclarer { return true }
        if isNorthWideDeclarer { return true }
        return false
    }

    private var northLabel: String {
        let prefix = isBidding(.north) ? "▶ " : ""
        if game.dummy == .north { return prefix + "North (Dummy)" }
        if isNorthWideDeclarer || isNorthFaceUpDeclarer { return prefix + "North — Declarer" }
        return prefix + "North"
    }

    private func northArea(geo: GeometryProxy) -> some View {
        let northCards: [Card] = game.hands[.north] ?? []
        let northTappable: Bool = game.tappableSeat == .north
        let legal: Set<Card> = northTappable ? game.legalCards : []
        let tap: ((Card) -> Void)? = northTappable
            ? { (c: Card) in game.playCard(c, from: .north) }
            : nil
        let fanH = fanHeight(northRatio, geo: geo, chrome: 34)

        return VStack(spacing: 4) {
            Text(northLabel)
                .font(.callout.bold())
                .foregroundColor(seatColor(.north))
            if northIsWide {
                HandView(cards: northCards, faceDown: false, isSmall: false, isWide: true,
                         wideHeight: fanH, trumpSuit: trump, legalCards: legal, onTap: tap)
            } else {
                HandView(cards: northCards, faceDown: !isNorthFaceUp(),
                         isSmall: true, trumpSuit: trump, legalCards: legal, onTap: tap)
            }
        }
        .padding(.horizontal, 8)
        .padding(.top, 8)
    }

    // MARK: - Side hands

    /// Face-down side hand, rotated to sit vertically. rotationEffect does not
    /// change the layout frame, so the frame is set explicitly on both sides of
    /// the rotation — otherwise the pre-rotation width bleeds into neighbours.
    private func rotatedSideHand(_ seat: Seat, degrees: Double, isFaceUp: Bool,
                                 legal: Set<Card>, tap: ((Card) -> Void)?,
                                 maxLength: CGFloat) -> some View {
        let cards = game.hands[seat] ?? []
        let n = min(max(cards.count, 1), 13)
        let length = max(60, min(maxLength, 34 + CGFloat(n - 1) * 22))
        return HandView(cards: cards, faceDown: !isFaceUp, isSmall: true,
                        faceDownLength: length, trumpSuit: trump,
                        legalCards: legal, onTap: tap)
            .frame(width: length, height: 50)
            .rotationEffect(.degrees(degrees))
            .frame(width: 50, height: length)
    }

    private func sideLabel(_ seat: Seat, name: String, isDummy: Bool) -> some View {
        Text((isBidding(seat) ? "▶ " : "") + (isDummy ? "\(name)\n(Dummy)" : name))
            .font(.callout.bold())
            .foregroundColor(seatColor(seat))
            .multilineTextAlignment(.center)
            .padding(.horizontal, 6).padding(.vertical, 2)
            .background(Color(red: 0.08, green: 0.40, blue: 0.15).opacity(0.9))
            .cornerRadius(4)
            .padding(.top, 4)
    }

    private func westArea(geo: GeometryProxy) -> some View {
        let isDummy  = game.dummy == .west
        let isFaceUp = isDummy && dummyRevealed
        let westTappable: Bool = game.tappableSeat == .west
        let legal: Set<Card> = westTappable ? game.legalCards : []
        let tap: ((Card) -> Void)? = westTappable
            ? { (c: Card) in game.playCard(c, from: .west) }
            : nil
        let box = dummySize(.west, geo: geo)
        let rotLength = geo.size.height * midRatio - 20

        return Group {
            if isFaceUp && ewDummyRevealed {
                VStack(spacing: 4) {
                    Text((isBidding(.west) ? "▶ " : "") + "West (Dummy)")
                        .font(.callout.bold())
                        .foregroundColor(seatColor(.west))
                    SideDummyView(cards: game.hands[.west] ?? [], size: box,
                                  trumpSuit: trump, legalCards: legal, onTap: tap)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 4)
            } else {
                ZStack(alignment: .top) {
                    rotatedSideHand(.west, degrees: 90, isFaceUp: isFaceUp,
                                    legal: legal, tap: tap, maxLength: rotLength)
                    sideLabel(.west, name: "West", isDummy: isDummy)
                }
            }
        }
    }

    private func eastArea(geo: GeometryProxy) -> some View {
        let isDummy  = game.dummy == .east
        let isFaceUp = isDummy && dummyRevealed
        let eastTappable: Bool = game.tappableSeat == .east
        let legal: Set<Card> = eastTappable ? game.legalCards : []
        let tap: ((Card) -> Void)? = eastTappable
            ? { (c: Card) in game.playCard(c, from: .east) }
            : nil
        let box = dummySize(.east, geo: geo)
        let rotLength = geo.size.height * midRatio - 20

        return Group {
            if isFaceUp && ewDummyRevealed {
                VStack(spacing: 4) {
                    Text((isBidding(.east) ? "▶ " : "") + "East (Dummy)")
                        .font(.callout.bold())
                        .foregroundColor(seatColor(.east))
                    SideDummyView(cards: game.hands[.east] ?? [], size: box,
                                  trumpSuit: trump, legalCards: legal, onTap: tap)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 4)
            } else {
                ZStack(alignment: .top) {
                    rotatedSideHand(.east, degrees: -90, isFaceUp: isFaceUp,
                                    legal: legal, tap: tap, maxLength: rotLength)
                    sideLabel(.east, name: "East", isDummy: isDummy)
                }
            }
        }
    }

    // MARK: - Center

    private func centerArea(geo: GeometryProxy) -> some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                centerContent(geo: geo)
                if !game.auction.isEmpty && !isBiddingPhase && showAuction {
                    AuctionView(auction: game.auction, dealer: game.dealer, contract: game.contract,
                                alternateColors: game.conventionSettings.useAlternateColors)
                        .frame(maxWidth: 175)
                }
            }

            if !game.statusMessage.isEmpty {
                Text(game.statusMessage)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.70))
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
        }
        .padding(.horizontal, 6)
        .padding(.top, isBiddingPhase ? 8 : 0)
    }

    @ViewBuilder
    private func centerContent(geo: GeometryProxy) -> some View {
        if game.phase == .bidding {
            biddingCenter
        } else if game.phase == .playing {
            playingCenter(geo: geo)
        }
    }

    private func playingCenter(geo: GeometryProxy) -> some View {
        // When the auction panel is open it takes width away from the trick area.
        let base = trickSize(geo: geo)
        let w = showAuction && !game.auction.isEmpty ? base.width - 181 : base.width
        return VStack(spacing: 4) {
            TrickAreaView(trick: game.currentTrick, contract: game.contract,
                          available: CGSize(width: max(140, w), height: base.height))
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

    private var biddingCenter: some View {
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

    private var southLabel: String {
        let prefix = isBidding(.south) ? "▶ " : ""
        if game.contract?.declarer == .south { return prefix + "South — Declarer (You)" }
        if game.dummy == .south              { return prefix + "South (Dummy)" }
        return prefix + "South (You)"
    }

    private func southArea(geo: GeometryProxy) -> some View {
        let southCards: [Card] = game.hands[.south] ?? []
        let southTappable: Bool = game.tappableSeat == .south
        let legal: Set<Card> = southTappable ? game.legalCards : []
        let tap: ((Card) -> Void)? = southTappable
            ? { (c: Card) in game.playCard(c, from: .south) }
            : nil
        let fanH = fanHeight(southRatio, geo: geo, chrome: 36)

        return VStack(spacing: 6) {
            Text(southLabel)
                .font(.callout.bold())
                .foregroundColor(seatColor(.south))

            HandView(cards: southCards, faceDown: false, isSmall: false, isWide: true,
                     wideHeight: fanH, trumpSuit: trump, legalCards: legal, onTap: tap)
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
