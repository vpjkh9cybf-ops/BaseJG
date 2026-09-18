// Conventional Wisdom — modified 2026-08-14 13:21 UTC
import SwiftUI

// Auction context helpers
struct AuctionContext {
    let seat: Seat
    let auction: [(seat: Seat, bid: Bid)]

    var partner: Seat { seat.partner }

    var myBids: [(seat: Seat, bid: Bid)] { auction.filter { $0.seat == seat } }
    var partnerBids: [(seat: Seat, bid: Bid)] { auction.filter { $0.seat == partner } }
    var leftOpponentBids: [(seat: Seat, bid: Bid)] { auction.filter { $0.seat == seat.prev } }
    var rightOpponentBids: [(seat: Seat, bid: Bid)] { auction.filter { $0.seat == seat.next } }

    var myLastContractBid: Bid? { myBids.reversed().first(where: { $0.bid.isSuitBid })?.bid }
    var partnerLastContractBid: Bid? { partnerBids.reversed().first(where: { $0.bid.isSuitBid })?.bid }
    var partnerFirstContractBid: Bid? { partnerBids.first(where: { $0.bid.isSuitBid })?.bid }
    var myLastBid: Bid? { myBids.last?.bid }
    var partnerLastBid: Bid? { partnerBids.last?.bid }

    var highestCurrentBid: Bid? { auction.reversed().first(where: { $0.bid.isSuitBid })?.bid }

    /// The bid that opened the auction, and who made it.
    var openingEntry: (seat: Seat, bid: Bid)? { auction.first(where: { $0.bid.isSuitBid }) }

    /// True when I already passed at my first turn — Drury and some 2/1
    /// agreements only apply to (or only apply away from) a passed hand.
    var iAmPassedHand: Bool { myBids.first?.bid == .pass }
    var partnerIsPassedHand: Bool { partnerBids.first?.bid == .pass }

    var opponentIntervened: Bool {
        let opBids = (leftOpponentBids + rightOpponentBids)
        return opBids.contains(where: { $0.bid.isSuitBid || $0.bid == .double })
    }

    var isOpeningPosition: Bool {
        auction.allSatisfy { $0.bid == .pass }
    }

    /// I have not taken a call yet — an earlier pass does not count as acting.
    var iHaveNotActed: Bool { myBids.allSatisfy { $0.bid == .pass } }

    // Round counting is done on contract bids only. Counting raw entries breaks
    // as soon as anyone passes first, which is exactly the passed-hand auction
    // that Drury exists for.
    var myContractBidCount: Int { myBids.filter { $0.bid.isSuitBid }.count }
    var partnerContractBidCount: Int { partnerBids.filter { $0.bid.isSuitBid }.count }

    var partnerOpenedCleanly: Bool {
        guard iHaveNotActed,
              let _ = partnerLastContractBid,
              (leftOpponentBids + rightOpponentBids).allSatisfy({ $0.bid == .pass })
        else { return false }
        return true
    }

    var iOpenedTheAuction: Bool { openingEntry?.seat == seat }
    var partnerOpenedTheAuction: Bool { openingEntry?.seat == partner }

    var iRebidding: Bool {
        iOpenedTheAuction && myContractBidCount == 1 && partnerContractBidCount == 1
    }

    var partnerRebid: Bool {
        partnerOpenedTheAuction && partnerContractBidCount == 2 && myContractBidCount == 1
    }

    var partnerAskedForAces: Bool {
        partnerLastBid == .contract(.four, .notrump) && !myBids.isEmpty
    }

    var iAskedForAces: Bool {
        myLastBid == .contract(.four, .notrump)
    }

    // True when I've just asked Blackwood and partner's response just came in
    var justReceivedBlackwoodResponse: Bool {
        guard myBids.count >= 1, partnerBids.count >= 1 else { return false }
        // My second-to-last bid was 4NT
        let myReversed = myBids.reversed()
        let mySecondLast = myReversed.dropFirst().first?.bid
        return mySecondLast == .contract(.four, .notrump)
    }
}

/// The bidding engine. It is an instance rather than a namespace of static
/// functions so the partnership's convention card can be carried through every
/// decision without threading a parameter into forty call sites.
struct BiddingAI {

    let settings: ConventionSettings

    init(settings: ConventionSettings = ConventionSettings()) {
        self.settings = settings
    }

    // MARK: - Convention card shorthands

    private var rkcbFlavor: RKCBFlavor {
        settings.slamAskStyle == .rkcb0314 ? .f0314 : .f1430
    }
    private var usesKeyCards: Bool { settings.slamAskStyle != .standardBW }
    private var overcall1LevelMin: Int { settings.overcallStyle == .light ? 8 : 10 }

    // MARK: - Entry point

    func selectBid(
        hand: [Card],
        seat: Seat,
        auction: [(seat: Seat, bid: Bid)],
        vulnerability: Vulnerability
    ) -> Bid {
        let eval = HandEvaluator.evaluate(hand)
        let ctx  = AuctionContext(seat: seat, auction: auction)

        if ctx.isOpeningPosition { return openingBid(eval: eval, hand: hand, vulnerability: vulnerability) }

        // Exclusion RKCB — partner jumped to five of a brand-new suit over an
        // agreed trump fit, asking for key cards outside it.
        if let excluded = partnerMadeExclusionAsk(ctx) {
            return exclusionResponse(hand: hand, ctx: ctx, excluding: excluded)
        }

        // Answer partner's key-card ask before anything else can talk over it.
        if partnerAskedKeyCards(ctx) {
            return slamAskResponse(eval: eval, hand: hand, ctx: ctx)
        }

        if ctx.partnerOpenedCleanly, let partnerOpen = ctx.partnerLastContractBid {
            return respond(to: partnerOpen, eval: eval, hand: hand, ctx: ctx)
        }

        if ctx.iRebidding, let myOpen = ctx.myLastContractBid, let partnerResp = ctx.partnerLastContractBid {
            return rebid(myOpen: myOpen, partnerResp: partnerResp, eval: eval, hand: hand, ctx: ctx)
        }

        if ctx.partnerRebid {
            return responderRebid(eval: eval, hand: hand, ctx: ctx)
        }

        // I asked for key cards; partner just answered — place the contract
        if ctx.justReceivedBlackwoodResponse, let bwResp = ctx.partnerLastContractBid {
            return slamFollowup(response: bwResp, eval: eval, hand: hand, ctx: ctx)
        }

        if ctx.opponentIntervened {
            return competitiveBid(eval: eval, hand: hand, ctx: ctx)
        }

        // Opener answering a checkback lands here — it is a third-round bid, so
        // neither the rebid nor the responder-rebid branch catches it.
        if let answer = checkbackAnswer(eval: eval, hand: hand, ctx: ctx) { return answer }

        return lateBid(eval: eval, hand: hand, ctx: ctx)
    }

    // MARK: - Opening Bids

    private func openingBid(eval: HandEvaluation, hand: [Card], vulnerability: Vulnerability) -> Bid {
        let hcp = eval.hcp

        if hcp < 12 { return preemptBid(eval: eval, hand: hand, vulnerability: vulnerability) }

        // Strong 2♣ (22+ balanced or 20+ with long suit)
        if hcp >= 22 || (hcp >= 20 && eval.totalPoints >= 25) {
            return .contract(.two, .clubs)
        }

        // 2NT (20–21 balanced)
        if hcp >= 20 && hcp <= 21 && eval.isBalanced {
            return .contract(.two, .notrump)
        }

        // 1NT (15–17 balanced)
        if hcp >= 15 && hcp <= 17 && eval.isBalanced {
            return .contract(.one, .notrump)
        }

        // 5-card majors (higher suit first if tied)
        if eval.length(.spades) >= 5 && eval.length(.spades) >= eval.length(.hearts) {
            return .contract(.one, .spades)
        }
        if eval.length(.hearts) >= 5 {
            return .contract(.one, .hearts)
        }

        // Balanced 12–14: open longer minor; 3-3 open 1♣, 4-4 open 1♦
        if eval.isBalanced {
            let d = eval.length(.diamonds), c = eval.length(.clubs)
            if d > c { return .contract(.one, .diamonds) }
            if c > d { return .contract(.one, .clubs) }
            // Tied: 3-3 → 1♣, 4-4 → 1♦
            return d >= 4 ? .contract(.one, .diamonds) : .contract(.one, .clubs)
        }

        // Unbalanced: open longest suit (prefer diamonds over clubs when equal and long)
        if eval.length(.diamonds) > eval.length(.clubs) { return .contract(.one, .diamonds) }
        return .contract(.one, .clubs)
    }

    private func preemptBid(eval: HandEvaluation, hand: [Card], vulnerability: Vulnerability) -> Bid {
        let hcp = eval.hcp

        // ── Weak twos, in the style the partnership plays ────────────────────
        if settings.weakTwoEnabled && settings.weakTwoStyle.hcpRange.contains(hcp) {
            let needsGoodSuit = settings.weakTwoStyle == .disciplined

            for suit in [Suit.spades, .hearts, .diamonds] where eval.length(suit) >= 6 {
                if !needsGoodSuit || eval.isSolidOrSemi(suit, in: hand) {
                    return .contract(.two, suit.strain)
                }
            }
            // A disciplined partnership still preempts a ragged suit when the
            // vulnerability makes it cheap.
            if needsGoodSuit && (vulnerability == .neither || vulnerability == .northSouth) {
                for suit in [Suit.spades, .hearts, .diamonds] where eval.length(suit) >= 6 {
                    return .contract(.two, suit.strain)
                }
            }
            // Aggressive style will open a strong 5-card major
            if settings.weakTwoStyle == .aggressive {
                for suit in [Suit.spades, .hearts]
                where eval.length(suit) >= 5 && eval.isSolidOrSemi(suit, in: hand) {
                    return .contract(.two, suit.strain)
                }
            }
        }

        // 3-level preempt (4–9 HCP, 7-card suit)
        if hcp >= 4 && hcp <= 9 {
            for suit in Suit.allCases.reversed() where eval.length(suit) >= 7 {
                return .contract(.three, suit.strain)
            }
        }
        return .pass
    }

    // MARK: - Responses

    private func respond(to open: Bid, eval: HandEvaluation, hand: [Card], ctx: AuctionContext) -> Bid {
        guard let level = open.level, let strain = open.strain else { return .pass }

        switch (level, strain) {
        case (.one, .notrump):  return respondToOneNT(eval: eval, hand: hand)
        case (.two, .notrump):  return respondToTwoNT(eval: eval, hand: hand)
        case (.two, .clubs):    return respondToTwoClubs(eval: eval)
        case (.one, .hearts), (.one, .spades):
            return respondToOneMajor(open: open, openStrain: strain, eval: eval, hand: hand, ctx: ctx)
        case (.one, .clubs), (.one, .diamonds):
            return respondToOneMinor(open: open, openStrain: strain, eval: eval, hand: hand)
        case (.two, .hearts), (.two, .spades), (.two, .diamonds):
            return respondToWeakTwo(open: open, openStrain: strain, eval: eval)
        default:
            return .pass
        }
    }

    // Response to 1NT (15–17)
    private func respondToOneNT(eval: HandEvaluation, hand: [Card]) -> Bid {
        let hcp = eval.hcp
        let sp = eval.length(.spades)
        let h  = eval.length(.hearts)
        let d  = eval.length(.diamonds)
        let c  = eval.length(.clubs)
        let transfers = settings.jacobyTransfersEnabled

        // ── Texas: 6+ major with game values and no slam ambition ───────────
        if transfers && settings.texasTransfers == .on && hcp >= 9 && hcp <= 15 {
            if sp >= 6 && sp >= h { return .contract(.four, .hearts)   }  // 4♥ → 4♠
            if h  >= 6            { return .contract(.four, .diamonds) }  // 4♦ → 4♥
        }

        // ── Long major with game values ─────────────────────────────────────
        if sp >= 6 && hcp >= 9 {
            return transfers ? .contract(.two, .hearts) : .contract(.four, .spades)
        }
        if h >= 6 && hcp >= 9 {
            return transfers ? .contract(.two, .diamonds) : .contract(.four, .hearts)
        }
        // Weak with a 6-card major: transfer and pass, or leave 1NT alone
        if sp >= 6 { return transfers ? .contract(.two, .hearts)   : .pass }
        if h  >= 6 { return transfers ? .contract(.two, .diamonds) : .pass }

        // ── Four-suit transfers put weak long minors into the picture ───────
        if transfers && settings.transferStyle == .fourSuit && hcp < 8 {
            if c >= 6 { return .contract(.two, .spades)  }  // 2♠  → 3♣
            if d >= 6 { return .contract(.two, .notrump) }  // 2NT → 3♦
        }

        // ── Garbage / Crawling Stayman: weak, short clubs, both majors ──────
        if settings.staymanEnabled && settings.staymanVariant == .garbage
            && hcp < 8 && c <= 2 && sp >= 4 && h >= 4 {
            return .contract(.two, .clubs)
        }

        if hcp < 8 {
            if transfers && sp >= 5 { return .contract(.two, .hearts)   }
            if transfers && h  >= 5 { return .contract(.two, .diamonds) }
            return .pass
        }

        // ── 8+ HCP with a 5-card major ──────────────────────────────────────
        if sp >= 5 && sp >= h {
            if transfers { return .contract(.two, .hearts) }
            return hcp >= 10 ? .contract(.three, .spades) : .contract(.two, .spades)
        }
        if h >= 5 {
            if transfers { return .contract(.two, .diamonds) }
            return hcp >= 10 ? .contract(.three, .hearts) : .contract(.two, .hearts)
        }

        // ── Stayman with a 4-card major ─────────────────────────────────────
        if settings.staymanEnabled && (sp >= 4 || h >= 4) { return .contract(.two, .clubs) }

        // ── Slam tries ──────────────────────────────────────────────────────
        if settings.gerberEnabled && hcp >= 16 { return .contract(.four, .clubs)   }
        if hcp >= 15                           { return .contract(.four, .notrump) }
        if hcp >= 10                           { return .contract(.three, .notrump) }
        return .contract(.two, .notrump)
    }

    // Response to 2NT (20–21)
    private func respondToTwoNT(eval: HandEvaluation, hand: [Card]) -> Bid {
        let hcp = eval.hcp
        let sp = eval.length(.spades)
        let h  = eval.length(.hearts)
        if hcp == 0 && sp < 5 && h < 5 { return .pass }
        if settings.jacobyTransfersEnabled && sp >= 5 { return .contract(.three, .hearts)   }
        if settings.jacobyTransfersEnabled && h  >= 5 { return .contract(.three, .diamonds) }
        if settings.staymanEnabled && (sp >= 4 || h >= 4) { return .contract(.three, .clubs) }
        if settings.gerberEnabled && hcp >= 11 { return .contract(.four, .clubs) }
        if hcp >= 10 { return .contract(.six, .notrump)   }
        if hcp >= 4  { return .contract(.three, .notrump) }
        return .pass
    }

    // Response to 2♣ (strong)
    private func respondToTwoClubs(eval: HandEvaluation) -> Bid {
        let hcp = eval.hcp
        if hcp < 8 { return .contract(.two, .diamonds) } // Waiting
        if eval.length(.spades) >= 5   { return .contract(.two, .spades)      }
        if eval.length(.hearts) >= 5   { return .contract(.two, .hearts)      }
        if eval.length(.diamonds) >= 5 { return .contract(.three, .diamonds)  }
        if eval.length(.clubs) >= 5    { return .contract(.three, .clubs)     }
        return .contract(.two, .notrump) // Balanced positive
    }

    // Response to 1♥ or 1♠
    private func respondToOneMajor(
        open: Bid,
        openStrain: Strain,
        eval: HandEvaluation,
        hand: [Card],
        ctx: AuctionContext
    ) -> Bid {
        let hcp = eval.hcp
        let tp  = eval.totalPoints
        guard let openSuit = openStrain.suit else { return .pass }
        let fit = eval.length(openSuit)
        let passed = ctx.iAmPassedHand

        if hcp < 6 { return .pass }

        // ── Drury — only ever by a passed hand ──────────────────────────────
        if settings.druryEnabled && passed && fit >= 3 && tp >= 10 && tp <= 12 {
            if settings.druryStyle == .twoWay {
                return fit >= 4 ? .contract(.two, .diamonds) : .contract(.two, .clubs)
            }
            return .contract(.two, .clubs)
        }

        // ── Splinter — more descriptive than 2NT, so it is offered first ────
        if settings.splinterEnabled && fit >= 4 {
            let side = Suit.allCases.filter { $0 != openSuit }.sorted { eval.length($0) < eval.length($1) }
            if let short = side.first, eval.length(short) <= 1,
               let spl = splinterBid(openSuit: openSuit, singletonSuit: short) {
                if hcp >= settings.splinterMinHCP { return spl }
                if settings.miniSplinters && hcp >= 10 && hcp < settings.splinterMinHCP { return spl }
            }
        }

        // ── Jacoby 2NT: 4+ fit, 13+ HCP, game-forcing ───────────────────────
        if settings.jacoby2NTEnabled && !passed && fit >= 4 && hcp >= 13 {
            return .contract(.two, .notrump)
        }

        // ── Limit raise (Drury unavailable or not a passed hand) ────────────
        if fit >= 3 && tp >= 10 && tp <= 12 && hcp <= 11 {
            return .contract(.three, openStrain)
        }

        // Game raise with fit (13+ TP)
        if fit >= 3 && tp >= 13 { return .contract(.four, openStrain) }

        // Simple raise (6–9 HCP, 3+ fit)
        if fit >= 3 && hcp >= 6 { return .contract(.two, openStrain) }

        // After 1♥: show 4-card spades regardless of strength
        if openStrain == .hearts && eval.length(.spades) >= 4 {
            return .contract(.one, .spades)
        }

        // ── Strong hand with no fit ─────────────────────────────────────────
        if hcp >= 13 {
            let twoOverOneOn = settings.twoOverOneEnabled &&
                !(settings.twoOverOneScope == .gameForcingUnpassed && passed)

            if twoOverOneOn {
                if openStrain == .spades {
                    if eval.length(.hearts) >= 5   { return .contract(.two, .hearts)   }
                    if eval.length(.clubs) >= 5    { return .contract(.two, .clubs)    }
                    if eval.length(.diamonds) >= 5 { return .contract(.two, .diamonds) }
                } else { // after 1♥: spades already shown above with 4+
                    if eval.length(.clubs) >= 5    { return .contract(.two, .clubs)    }
                    if eval.length(.diamonds) >= 5 { return .contract(.two, .diamonds) }
                    if eval.length(.spades) >= 5   { return .contract(.two, .spades)   }
                }
                if eval.isBalanced { return .contract(.three, .notrump) }
                return .contract(.two, .notrump)
            }

            // Without 2/1 the same hands go through a forcing 1NT or a jump
            // shift, so nothing below game is promised by a plain 2-level bid.
            if eval.isBalanced { return .contract(.three, .notrump) }
            for suit in [Suit.spades, .hearts, .diamonds, .clubs] where suit != openSuit {
                if eval.length(suit) >= 5 {
                    let jump = Bid.contract(.three, suit.strain)
                    if jump.isHigherThan(open) { return jump }
                }
            }
            return .contract(.two, .notrump)
        }

        // 1NT response — forcing or semi-forcing per the partnership's agreement
        return .contract(.one, .notrump)
    }

    // Response to 1♣ or 1♦
    private func respondToOneMinor(open: Bid, openStrain: Strain, eval: HandEvaluation, hand: [Card]) -> Bid {
        let hcp = eval.hcp
        if hcp < 6 { return .pass }
        guard let openSuit = openStrain.suit else { return .pass }

        // Majors first
        if eval.length(.spades) >= 4 { return .contract(.one, .spades) }
        if eval.length(.hearts) >= 4 { return .contract(.one, .hearts) }

        // ── Inverted minors outrank a notrump response with real support ────
        if settings.minorRaiseStyle == .inverted && eval.length(openSuit) >= 5 {
            // Single raise is 10+ and forcing; the jump raise is preemptive
            return hcp >= 10 ? .contract(.two, openStrain) : .contract(.three, openStrain)
        }

        // NT responses (balanced, no 4-card major)
        if hcp >= 13 && hcp <= 15 && eval.isBalanced { return .contract(.three, .notrump) }
        if hcp >= 10 && hcp <= 12 && eval.isBalanced { return .contract(.two, .notrump)   }
        if hcp >= 6  && hcp <= 9  && eval.isBalanced { return .contract(.one, .notrump)   }

        // Standard minor raises — check the HIGHER level first
        if eval.length(openSuit) >= 5 && hcp >= 13 { return .contract(.three, openStrain) }
        if eval.length(openSuit) >= 5              { return .contract(.two, openStrain)   }

        // Show the other minor
        let otherMinor: Strain = (openStrain == .clubs) ? .diamonds : .clubs
        if let om = otherMinor.suit, eval.length(om) >= 4 && hcp >= 10 {
            return .contract(.two, otherMinor)
        }

        return .contract(.one, .notrump)
    }

    private func respondToWeakTwo(open: Bid, openStrain: Strain, eval: HandEvaluation) -> Bid {
        let hcp = eval.hcp
        guard let openSuit = openStrain.suit else { return .pass }
        let fit = eval.length(openSuit)

        if hcp >= 14 && fit >= 3 { return .contract(.four, openStrain) }
        if fit >= 3              { return .contract(.three, openStrain) }  // preemptive / invitational raise
        if hcp >= 14 {
            for suit in [Suit.spades, .hearts, .diamonds, .clubs] where suit != openSuit {
                if eval.length(suit) >= 5 {
                    let b = Bid.contract(.three, suit.strain)
                    if b.isHigherThan(open) { return b }
                }
            }
            return .contract(.two, .notrump)   // the ask — Ogust or feature
        }
        return .pass
    }

    // MARK: - Rebids (opener's second bid)

    private func rebid(
        myOpen: Bid,
        partnerResp: Bid,
        eval: HandEvaluation,
        hand: [Card],
        ctx: AuctionContext
    ) -> Bid {
        guard let openStrain = myOpen.strain, let openLevel = myOpen.level else { return .pass }

        if openStrain == .notrump && openLevel == .one {
            return rebidAfterOneNT(partnerResp: partnerResp, eval: eval, hand: hand)
        }
        if openStrain == .notrump && openLevel == .two {
            return rebidAfterTwoNT(partnerResp: partnerResp, eval: eval, hand: hand)
        }
        if openStrain == .clubs && openLevel == .two {
            return rebidAfterTwoClubs(partnerResp: partnerResp, eval: eval, hand: hand)
        }
        // A weak two describes the hand in one bid; opener never invents a
        // second one beyond answering the ask.
        if openLevel == .two {
            return rebidAfterWeakTwo(openStrain: openStrain, partnerResp: partnerResp,
                                     eval: eval, hand: hand)
        }
        if openLevel == .three { return .pass }   // preempt: already said everything

        if openStrain.isMajor {
            return rebidAfterMajorOpen(openStrain: openStrain, partnerResp: partnerResp,
                                       eval: eval, hand: hand, ctx: ctx)
        }
        return rebidAfterMinorOpen(openStrain: openStrain, partnerResp: partnerResp,
                                   eval: eval, hand: hand, ctx: ctx)
    }

    /// Does opener hold a maximum with real support — worth jumping a level?
    private func superAccepts(_ suit: Suit, eval: HandEvaluation) -> Bool {
        eval.hcp >= settings.superAcceptThreshold && eval.length(suit) >= 4
    }

    private func staymanReply(eval: HandEvaluation) -> Bid {
        if settings.staymanVariant == .puppet {
            // Puppet looks for a 5-card major first; 2♦ denies one.
            if eval.length(.spades) >= 5 { return .contract(.two, .spades) }
            if eval.length(.hearts) >= 5 { return .contract(.two, .hearts) }
            return .contract(.two, .diamonds)
        }
        // Standard: bid hearts first holding both majors, so 2♠ over 2♥ still
        // finds the spade fit.
        if eval.length(.hearts) >= 4 { return .contract(.two, .hearts) }
        if eval.length(.spades) >= 4 { return .contract(.two, .spades) }
        return .contract(.two, .diamonds)
    }

    private func gerberResponse(hand: [Card]) -> Bid {
        let aces = hand.filter { $0.rank == .ace }.count
        switch aces {
        case 0, 4: return .contract(.four, .diamonds)
        case 1:    return .contract(.four, .hearts)
        case 2:    return .contract(.four, .spades)
        default:   return .contract(.four, .notrump)
        }
    }

    private func rebidAfterOneNT(partnerResp: Bid, eval: HandEvaluation, hand: [Card]) -> Bid {
        guard let respStrain = partnerResp.strain, let respLevel = partnerResp.level else { return .pass }
        let transfers = settings.jacobyTransfersEnabled

        // ── Gerber ──────────────────────────────────────────────────────────
        if settings.gerberEnabled && partnerResp == .contract(.four, .clubs) {
            return gerberResponse(hand: hand)
        }

        // ── Texas transfer completion ───────────────────────────────────────
        if transfers && settings.texasTransfers == .on && respLevel == .four {
            if respStrain == .diamonds { return .contract(.four, .hearts) }
            if respStrain == .hearts   { return .contract(.four, .spades) }
        }

        // ── Stayman ─────────────────────────────────────────────────────────
        if settings.staymanEnabled && respLevel == .two && respStrain == .clubs {
            return staymanReply(eval: eval)
        }

        // ── Major transfers ─────────────────────────────────────────────────
        if transfers && respLevel == .two && respStrain == .diamonds {
            return superAccepts(.hearts, eval: eval) ? .contract(.three, .hearts) : .contract(.two, .hearts)
        }
        if transfers && respLevel == .two && respStrain == .hearts {
            return superAccepts(.spades, eval: eval) ? .contract(.three, .spades) : .contract(.two, .spades)
        }

        // ── Minor transfers (four-suit only) — must precede the 2NT invite ──
        if transfers && settings.transferStyle == .fourSuit && respLevel == .two {
            if respStrain == .spades  { return .contract(.three, .clubs)    }
            if respStrain == .notrump { return .contract(.three, .diamonds) }
        }

        if respLevel == .two && respStrain == .notrump {
            return eval.hcp >= 17 ? .contract(.three, .notrump) : .pass
        }
        if respLevel == .four && respStrain == .notrump {
            return eval.hcp >= 17 ? .contract(.six, .notrump) : .pass
        }
        return .pass
    }

    private func rebidAfterTwoNT(partnerResp: Bid, eval: HandEvaluation, hand: [Card]) -> Bid {
        guard let respStrain = partnerResp.strain, let respLevel = partnerResp.level else { return .pass }

        if settings.gerberEnabled && partnerResp == .contract(.four, .clubs) {
            return gerberResponse(hand: hand)
        }
        // Puppet Stayman over 2NT: 5-card major first, 3♦ shows a 4-card major
        if settings.staymanEnabled && respLevel == .three && respStrain == .clubs {
            if eval.length(.spades) >= 5 { return .contract(.three, .spades) }
            if eval.length(.hearts) >= 5 { return .contract(.three, .hearts) }
            if eval.length(.spades) >= 4 || eval.length(.hearts) >= 4 {
                return .contract(.three, .diamonds)
            }
            return .contract(.three, .notrump)
        }
        if settings.jacobyTransfersEnabled && respLevel == .three {
            if respStrain == .diamonds { return .contract(.three, .hearts) }
            if respStrain == .hearts   { return .contract(.three, .spades) }
        }
        return .pass
    }

    private func rebidAfterTwoClubs(partnerResp: Bid, eval: HandEvaluation, hand: [Card]) -> Bid {
        guard let respStrain = partnerResp.strain, let respLevel = partnerResp.level else { return .pass }

        if respLevel == .two && respStrain == .diamonds {
            if eval.length(.spades) >= 5   { return .contract(.two, .spades)      }
            if eval.length(.hearts) >= 5   { return .contract(.two, .hearts)      }
            if eval.length(.diamonds) >= 5 { return .contract(.three, .diamonds)  }
            if eval.length(.clubs) >= 5    { return .contract(.three, .clubs)     }
            if eval.isBalanced             { return .contract(.two, .notrump)     }
            return .contract(.three, .clubs)
        }

        if eval.hcp >= 24 && eval.isBalanced { return .contract(.six, .notrump) }
        if respStrain.isMajor, let suit = respStrain.suit, eval.length(suit) >= 3 {
            return .contract(.four, respStrain)
        }
        return .contract(.three, .notrump)
    }

    /// Opener's reply after a weak two — this is where Ogust and feature-asks
    /// actually differ.
    private func rebidAfterWeakTwo(
        openStrain: Strain,
        partnerResp: Bid,
        eval: HandEvaluation,
        hand: [Card]
    ) -> Bid {
        guard let openSuit = openStrain.suit else { return .pass }
        let maximum = eval.hcp >= settings.weakTwoStyle.hcpRange.upperBound - 2
        let goodSuit = eval.isSolidOrSemi(openSuit, in: hand)

        if partnerResp == .contract(.two, .notrump) {
            switch settings.weakTwoResponse {
            case .ogust:
                if  goodSuit &&  maximum { return .contract(.three, .spades)   }
                if  goodSuit && !maximum { return .contract(.three, .hearts)   }
                if !goodSuit &&  maximum { return .contract(.three, .diamonds) }
                return .contract(.three, .clubs)
            case .feature, .mcCabe:
                if maximum {
                    for suit in [Suit.clubs, .diamonds, .hearts, .spades] where suit != openSuit {
                        let hasTopHonour = hand.contains {
                            $0.suit == suit && ($0.rank == .ace || $0.rank == .king)
                        }
                        if hasTopHonour {
                            let b = Bid.contract(.three, suit.strain)
                            if b.isHigherThan(partnerResp) { return b }
                        }
                    }
                }
                return .contract(.three, openStrain)
            }
        }

        // Partner raised or bid a new suit — the weak two already told the story
        return .pass
    }

    private func druryReply(openStrain: Strain, eval: HandEvaluation) -> Bid {
        let hcp = eval.hcp
        if hcp >= 16 { return .contract(.four, openStrain)  }
        if hcp >= 14 { return .contract(.three, openStrain) }
        // Minimum — how that is shown is the difference between the styles
        if settings.druryStyle == .reverse {
            return .contract(.two, openStrain)     // rebidding the major = minimum
        }
        return .contract(.two, .diamonds)          // 2♦ = minimum
    }

    private func rebidAfterMajorOpen(
        openStrain: Strain,
        partnerResp: Bid,
        eval: HandEvaluation,
        hand: [Card],
        ctx: AuctionContext
    ) -> Bid {
        guard let respStrain = partnerResp.strain, let respLevel = partnerResp.level else { return .pass }
        let hcp = eval.hcp
        guard let openSuit = openStrain.suit else { return .pass }

        // ── Support Double ──────────────────────────────────────────────────
        if settings.supportDoubles, ctx.opponentIntervened, respLevel == .one,
           respStrain != openStrain, let respSuit = respStrain.suit,
           eval.length(respSuit) == 3 {
            return .double
        }

        // ── Drury (partner is a passed hand) ────────────────────────────────
        if settings.druryEnabled, ctx.partnerIsPassedHand, respLevel == .two,
           respStrain == .clubs || (settings.druryStyle == .twoWay && respStrain == .diamonds) {
            return druryReply(openStrain: openStrain, eval: eval)
        }

        // ── Jacoby 2NT (4+ fit, game force) ─────────────────────────────────
        // 3M = 6-card trump suit, 3-new = shortness, 4-new = 5-card side suit,
        // 4M = minimum or balanced.
        if settings.jacoby2NTEnabled && respLevel == .two && respStrain == .notrump {
            if eval.length(openSuit) >= 6 { return .contract(.three, openStrain) }
            for suit in [Suit.clubs, .diamonds, .hearts, .spades] where suit != openSuit {
                if eval.length(suit) <= 1 { return .contract(.three, suit.strain) }
            }
            for suit in [Suit.clubs, .diamonds, .hearts, .spades] where suit != openSuit {
                if eval.length(suit) >= 5 { return .contract(.four, suit.strain) }
            }
            return .contract(.four, openStrain)
        }

        // ── Simple raise ────────────────────────────────────────────────────
        if respStrain == openStrain {
            if hcp >= 17 { return .contract(.four, openStrain)  }
            if hcp >= 15 { return .contract(.three, openStrain) }
            return .pass
        }

        // ── 1NT response ────────────────────────────────────────────────────
        if respLevel == .one && respStrain == .notrump {
            if hcp >= 19 { return .contract(.three, openStrain) }
            if hcp >= 17 { return .contract(.two, openStrain)   }
            if hcp >= 15 || eval.length(openSuit) >= 6 {
                if eval.length(openSuit) >= 6 { return .contract(.two, openStrain) }
                for suit in [Suit.diamonds, .clubs] where eval.length(suit) >= 4 {
                    return .contract(.two, suit.strain)
                }
                return .contract(.two, openStrain)
            }
            // 12–14: rebid a 6-card suit, or show a cheaper 4-card suit
            if eval.length(openSuit) >= 6 { return .contract(.two, openStrain) }
            let lowers: [Suit] = openStrain == .spades ? [.hearts, .diamonds, .clubs] : [.diamonds, .clubs]
            for suit in lowers where eval.length(suit) >= 4 {
                return .contract(.two, suit.strain)
            }
            // Nothing natural left to say. A forcing 1NT still has to be answered.
            if settings.oneNTResponseStyle == .forcing { return .contract(.two, openStrain) }
            return .pass
        }

        // ── 2/1 game-force response ─────────────────────────────────────────
        if respLevel == .two {
            let fit2 = (respStrain.suit.map { eval.length($0) } ?? 0)
            if fit2 >= 4 { return .contract(.three, respStrain) }
            if hcp >= 15 || eval.length(openSuit) >= 6 { return .contract(.two, openStrain) }
            if eval.isBalanced { return .contract(.two, .notrump) }
            return .contract(.two, openStrain)
        }

        // ── 1♠ over 1♥ ──────────────────────────────────────────────────────
        if openStrain == .hearts && respStrain == .spades && respLevel == .one {
            if eval.length(.spades) >= 4 {
                if hcp >= 16 { return .contract(.four, .spades)  }
                if hcp >= 14 { return .contract(.three, .spades) }
                return .contract(.two, .spades)
            }
            if hcp >= 19 { return .contract(.three, .hearts) }
            if hcp >= 16 { return .contract(.two, .hearts)   }
            return .pass
        }

        return highestSafeBid(eval: eval, above: ctx.highestCurrentBid)
    }

    private func rebidAfterMinorOpen(
        openStrain: Strain,
        partnerResp: Bid,
        eval: HandEvaluation,
        hand: [Card],
        ctx: AuctionContext
    ) -> Bid {
        guard let respStrain = partnerResp.strain, let respLevel = partnerResp.level else { return .pass }
        let hcp = eval.hcp
        guard let openSuit = openStrain.suit else { return .pass }

        // ── Inverted minors: partner's single raise is forcing, 10+ ─────────
        if settings.minorRaiseStyle == .inverted && respStrain == openStrain {
            if respLevel == .two {
                if hcp >= 18 { return .contract(.three, .notrump) }
                // Show a stopper on the way, else rebid the minor
                for suit in [Suit.hearts, .spades, .diamonds, .clubs] where suit != openSuit {
                    let hasStopper = eval.length(suit) >= 3
                    if hasStopper && hcp >= 15 { return .contract(.two, suit.strain) }
                }
                return .contract(.three, openStrain)
            }
            if respLevel == .three { return .pass }   // preemptive raise
        }

        // ── Partner bid a major at the 1-level ──────────────────────────────
        if respStrain.isMajor && respLevel == .one, let respSuit = respStrain.suit {
            let fit = eval.length(respSuit)
            if fit >= 4 && hcp >= 17 { return .contract(.three, respStrain) }
            if fit >= 4              { return .contract(.two,   respStrain) }
            if eval.isBalanced {
                if hcp >= 18 { return .contract(.three, .notrump) }
                if hcp >= 15 { return .contract(.two,   .notrump) }
                return .contract(.one, .notrump)
            }
            let otherMajor: Suit = (respSuit == .hearts) ? .spades : .hearts
            if eval.length(otherMajor) >= 4 && hcp >= 17 {
                return .contract(.one, otherMajor.strain)
            }
            if eval.length(openSuit) >= 5 && hcp >= 15 { return .contract(.two, openStrain) }
            return .contract(.one, .notrump)
        }

        // ── Partner bid 1NT ─────────────────────────────────────────────────
        if respStrain == .notrump && respLevel == .one {
            if eval.isBalanced {
                if hcp >= 18 { return .contract(.three, .notrump) }
                if hcp >= 15 { return .contract(.two,   .notrump) }
                return .pass
            }
            if eval.length(openSuit) >= 6 { return .contract(.two, openStrain) }
            if hcp >= 17                  { return .contract(.two, openStrain) }
            return .pass
        }

        // ── Partner raised the minor (standard methods) ─────────────────────
        if respStrain == openStrain {
            if hcp >= 19 { return .contract(.five, openStrain)  }
            if hcp >= 17 { return .contract(.four, openStrain)  }
            if hcp >= 14 { return .contract(.three, openStrain) }
            return .pass
        }

        if respStrain == .notrump && respLevel == .two {
            return hcp >= 15 ? .contract(.three, .notrump) : .pass
        }
        if respStrain == .notrump && respLevel == .three {
            return hcp >= 16 ? .contract(.six, .notrump) : .pass
        }

        return .pass
    }

    // MARK: - Responder Rebid

    private func responderRebid(eval: HandEvaluation, hand: [Card], ctx: AuctionContext) -> Bid {
        let hcp = eval.hcp
        guard let partnerRebidBid = ctx.partnerLastContractBid else { return .pass }
        guard let myResp = ctx.myLastContractBid else { return .pass }
        let partnerFirstBid = ctx.partnerFirstContractBid

        // ── After a key-card ask ────────────────────────────────────────────
        if partnerAskedKeyCards(ctx) { return slamAskResponse(eval: eval, hand: hand, ctx: ctx) }
        if iAskedKeyCards(ctx) {
            return slamFollowup(response: partnerRebidBid, eval: eval, hand: hand, ctx: ctx)
        }

        // ── After Drury ─────────────────────────────────────────────────────
        let druryStart: Bool = settings.druryEnabled && ctx.iAmPassedHand &&
            (myResp == .contract(.two, .clubs) ||
             (settings.druryStyle == .twoWay && myResp == .contract(.two, .diamonds)))

        if druryStart, let openMajor = partnerFirstBid?.strain,
           openMajor.isMajor, partnerFirstBid?.level == .one {
            if let level = partnerRebidBid.level, let strain = partnerRebidBid.strain {
                // Minimum shown — sign off in the major
                if settings.druryStyle == .reverse && level == .two && strain == openMajor {
                    return .pass
                }
                if settings.druryStyle != .reverse && level == .two && strain == .diamonds {
                    return .contract(.two, openMajor)
                }
                if level == .three && strain == openMajor { return .contract(.four, openMajor) }
                if level == .four { return .pass }
            }
            return .pass
        }

        // Which opening partner actually made decides whether my 2♣/2♦/2♥ was
        // Stayman, a transfer, or a plain 2/1 response.
        let partnerOpenedOneNT = partnerFirstBid == .contract(.one, .notrump)
        let partnerOpenedOneMajor = partnerFirstBid?.level == .one
            && partnerFirstBid?.strain?.isMajor == true

        // ── After Stayman ───────────────────────────────────────────────────
        if settings.staymanEnabled && partnerOpenedOneNT
            && myResp == .contract(.two, .clubs) && !druryStart {
            let forcing = settings.staymanVariant == .forcing

            if let level = partnerRebidBid.level, let strain = partnerRebidBid.strain,
               level == .two && strain.isMajor, let majorSuit = strain.suit {
                let fit = eval.length(majorSuit)
                if fit >= 4 && hcp >= 8  { return .contract(.four, strain) }
                if fit >= 4              { return forcing ? .contract(.four, strain) : .contract(.three, strain) }
                if hcp >= 10 || forcing  { return .contract(.three, .notrump) }
                if hcp >= 8              { return .contract(.two,   .notrump) }
                return .pass
            }

            // Partner denied a major (2♦)
            if settings.smolen == .on && hcp >= 10 {
                let sp = eval.length(.spades), h = eval.length(.hearts)
                if sp >= 5 && h == 4 { return .contract(.three, .hearts) }  // Smolen
                if h >= 5 && sp == 4 { return .contract(.three, .spades) }  // Smolen
            }
            if hcp >= 10 || forcing { return .contract(.three, .notrump) }
            if hcp >= 8             { return .contract(.two,   .notrump) }
            return .pass
        }

        // ── After Jacoby 2NT ────────────────────────────────────────────────
        if settings.jacoby2NTEnabled && partnerOpenedOneMajor
            && myResp == .contract(.two, .notrump),
           let partnerOpenMajor = partnerFirstBid?.strain {
            if partnerRebidBid == .contract(.four, partnerOpenMajor) { return .pass }
            if hcp >= 16 {
                let ask = keyCardAsk(trump: partnerOpenMajor.suit)
                if ask.isHigherThan(partnerRebidBid) { return ask }
            }
            let game = Bid.contract(.four, partnerOpenMajor)
            if game.isHigherThan(partnerRebidBid) { return game }
            return .pass
        }

        // ── After a transfer ────────────────────────────────────────────────
        if settings.jacobyTransfersEnabled && partnerOpenedOneNT && !druryStart {
            if myResp == .contract(.two, .diamonds) {
                if partnerRebidBid == .contract(.three, .hearts) {   // super-accept
                    return hcp >= 8 ? .contract(.four, .hearts) : .pass
                }
                if hcp >= 10 { return .contract(.four, .hearts)  }
                if hcp >= 8  { return .contract(.three, .hearts) }
                return .pass
            }
            if myResp == .contract(.two, .hearts) {
                if partnerRebidBid == .contract(.three, .spades) {   // super-accept
                    return hcp >= 8 ? .contract(.four, .spades) : .pass
                }
                if hcp >= 10 { return .contract(.four, .spades)  }
                if hcp >= 8  { return .contract(.three, .spades) }
                return .pass
            }
            // Four-suit transfer completions
            if settings.transferStyle == .fourSuit,
               myResp == .contract(.two, .spades) || myResp == .contract(.two, .notrump) {
                return hcp >= 11 ? .contract(.three, .notrump) : .pass
            }
        }

        // ── After 2/1 game force ────────────────────────────────────────────
        if let myLevel = myResp.level, myLevel == .two, let mySuit = myResp.strain?.suit,
           let myStrain = myResp.strain {
            let prLevel  = partnerRebidBid.level
            let prStrain = partnerRebidBid.strain
            let highest  = ctx.highestCurrentBid ?? .contract(.one, .clubs)
            // Without 2/1 as a game force, a minimum may stop below game.
            let forcedToGame = settings.twoOverOneEnabled &&
                !(settings.twoOverOneScope == .gameForcingUnpassed && ctx.iAmPassedHand)

            if prStrain == myStrain {
                let game4 = Bid.contract(.four, myStrain)
                if eval.length(mySuit) >= 5 && game4.isHigherThan(highest) { return game4 }
                let threeNT = Bid.contract(.three, .notrump)
                if threeNT.isHigherThan(highest) { return threeNT }
                return .pass
            }
            if prStrain?.isMajor == true, let prSuit = prStrain?.suit, let prLvl = prLevel,
               prLvl == .three, let prS = prStrain {
                if eval.length(prSuit) >= 3 { return .contract(.four, prS) }
                if eval.length(mySuit) >= 5 { return .contract(.four, myStrain) }
                return .contract(.three, .notrump)
            }
            if prStrain == .notrump && prLevel == .two {
                if eval.length(mySuit) >= 6 { return .contract(.four, myStrain) }
                if forcedToGame || hcp >= 13 { return .contract(.three, .notrump) }
                return .pass
            }
            if forcedToGame || hcp >= 13 {
                if eval.length(mySuit) >= 5 {
                    let game4 = Bid.contract(.four, myStrain)
                    if game4.isHigherThan(highest) { return game4 }
                }
                let threeNT = Bid.contract(.three, .notrump)
                if threeNT.isHigherThan(highest) { return threeNT }
            }
        }

        // ── After a simple raise of partner's major ─────────────────────────
        if let partnerOpenMajor = partnerFirstBid?.strain, partnerOpenMajor.isMajor,
           myResp.strain == partnerOpenMajor {
            if hcp >= 10 { return .contract(.four, partnerOpenMajor) }
            return .pass
        }

        // ── Checkback after partner's cheap rebid ───────────────────────────
        if let checkback = checkbackBid(eval: eval, ctx: ctx, myResp: myResp,
                                        partnerFirstBid: partnerFirstBid,
                                        partnerRebidBid: partnerRebidBid) {
            return checkback
        }

        // ── Fourth suit forcing ─────────────────────────────────────────────
        if isFourthSuit(partnerRebidBid, ctx: ctx) {
            if settings.fourthSuitStyle == .gameForcing || hcp >= 12 {
                if eval.isBalanced { return .contract(.three, .notrump) }
            }
        }

        // ── General late-game push ──────────────────────────────────────────
        if hcp >= 12 {
            if eval.length(.spades) >= 5 { return .contract(.four, .spades) }
            if eval.length(.hearts) >= 5 { return .contract(.four, .hearts) }
            if eval.isBalanced           { return .contract(.three, .notrump) }
        }

        return .pass
    }

    /// Responder's artificial game try after opener's cheap rebid: New Minor
    /// Forcing, or the XYZ relay when the partnership plays two-way new minor.
    private func checkbackBid(
        eval: HandEvaluation,
        ctx: AuctionContext,
        myResp: Bid,
        partnerFirstBid: Bid?,
        partnerRebidBid: Bid
    ) -> Bid? {
        let hcp = eval.hcp
        guard hcp >= 11,
              let openStrain = partnerFirstBid?.strain, openStrain.isMinor,
              partnerFirstBid?.level == .one,
              myResp.level == .one, myResp.strain?.isMajor == true else { return nil }

        // XYZ: after two one-level bids, 2♣ is the weak/invitational relay and
        // 2♦ is the game force.
        if settings.xyzEnabled && partnerRebidBid.level == .one {
            return hcp >= 13 ? .contract(.two, .diamonds) : .contract(.two, .clubs)
        }

        guard settings.nmfEnabled else { return nil }

        // NMF is on over a 1NT rebid, and over a 2♣ rebid when agreed.
        let triggered = partnerRebidBid == .contract(.one, .notrump)
            || (settings.nmfInclude2C && partnerRebidBid == .contract(.two, .clubs))
        guard triggered else { return nil }

        let newMinor: Strain = openStrain == .clubs ? .diamonds : .clubs
        let bid = Bid.contract(.two, newMinor)
        guard bid.isHigherThan(partnerRebidBid) else {
            // No room for the checkback — just place the contract
            return hcp >= 13 ? .contract(.three, .notrump) : .contract(.two, .notrump)
        }
        return bid
    }

    /// Opener's answer to New Minor Forcing or an XYZ relay.
    private func checkbackAnswer(eval: HandEvaluation, hand: [Card], ctx: AuctionContext) -> Bid? {
        guard ctx.iOpenedTheAuction, ctx.myContractBidCount == 2,
              let last = ctx.partnerLastBid, last.isSuitBid,
              let myFirst = ctx.myBids.first(where: { $0.bid.isSuitBid })?.bid,
              myFirst.strain?.isMinor == true,
              let respMajor = ctx.partnerBids.first(where: { $0.bid.isSuitBid })?.bid.strain,
              respMajor.isMajor, let respSuit = respMajor.suit else { return nil }

        // XYZ relay: 2♣ simply asks opener to bid 2♦
        if settings.xyzEnabled && last == .contract(.two, .clubs) {
            return .contract(.two, .diamonds)
        }

        // Only a 1NT rebid (or an agreed 2♣ rebid) sets up New Minor Forcing —
        // otherwise partner's minor is natural and must not be read as a relay.
        let myRebid = ctx.myBids.filter { $0.bid.isSuitBid }.last?.bid
        let nmfWasOn = myRebid == .contract(.one, .notrump)
            || (settings.nmfInclude2C && myRebid == .contract(.two, .clubs))

        guard settings.nmfEnabled, nmfWasOn, last.level == .two,
              last.strain?.isMinor == true, last.strain != myFirst.strain else { return nil }

        // Show 3-card support for partner's major, then a 4-card other major,
        // otherwise sign back into notrump.
        if eval.length(respSuit) >= 3 {
            return eval.hcp >= 14 ? .contract(.three, respMajor) : .contract(.two, respMajor)
        }
        let otherMajor: Suit = respSuit == .hearts ? .spades : .hearts
        if eval.length(otherMajor) >= 4 {
            let b = Bid.contract(.two, otherMajor.strain)
            if b.isHigherThan(last) { return b }
        }
        return .contract(.two, .notrump)
    }

    /// True when the bid names the one suit neither partner has mentioned.
    private func isFourthSuit(_ bid: Bid, ctx: AuctionContext) -> Bool {
        guard let strain = bid.strain, strain != .notrump else { return false }
        let named = Set(ctx.auction.dropLast().compactMap { $0.bid.strain })
        return !named.contains(strain) && named.count == 3
    }

    // MARK: - Slam bidding

    // Determine the agreed trump suit from the auction context
    private func agreedTrumpSuit(ctx: AuctionContext) -> Suit? {
        let allSuitBids = ctx.auction.filter { $0.bid.isSuitBid && $0.bid.strain != .notrump }
        for suit in [Suit.spades, .hearts] {
            if (ctx.myBids.contains   { $0.bid.strain == suit.strain }) &&
               (ctx.partnerBids.contains { $0.bid.strain == suit.strain }) {
                return suit
            }
        }
        if let s = ctx.partnerBids.last(where: { $0.bid.strain?.isMajor == true })?.bid.strain?.suit { return s }
        if let s = ctx.myBids.last(where: { $0.bid.strain?.isMajor == true })?.bid.strain?.suit { return s }
        return allSuitBids.last?.bid.strain?.suit
    }

    /// Kickback moves the ask to four of the suit above trumps, freeing the
    /// five-level. With spades agreed that is 4NT anyway.
    private func kickbackAsk(for trump: Suit) -> Bid {
        switch trump {
        case .clubs:    return .contract(.four, .diamonds)
        case .diamonds: return .contract(.four, .hearts)
        case .hearts:   return .contract(.four, .spades)
        case .spades:   return .contract(.four, .notrump)
        }
    }

    /// The bid this partnership uses to ask for key cards.
    private func keyCardAsk(trump: Suit?) -> Bid {
        guard settings.kickbackEnabled, let t = trump else { return .contract(.four, .notrump) }
        return kickbackAsk(for: t)
    }

    private func partnerAskedKeyCards(_ ctx: AuctionContext) -> Bool {
        guard !ctx.myBids.isEmpty, let last = ctx.partnerLastBid else { return false }
        if last == .contract(.four, .notrump) { return true }
        if settings.kickbackEnabled, let t = agreedTrumpSuit(ctx: ctx), t != .spades {
            return last == kickbackAsk(for: t)
        }
        return false
    }

    private func iAskedKeyCards(_ ctx: AuctionContext) -> Bool {
        guard let last = ctx.myLastBid else { return false }
        if last == .contract(.four, .notrump) { return true }
        if settings.kickbackEnabled, let t = agreedTrumpSuit(ctx: ctx), t != .spades {
            return last == kickbackAsk(for: t)
        }
        return false
    }

    // Count RKCB key cards: 4 aces + king of agreed trump suit (max 5)
    private func keyCardCount(hand: [Card], trumpSuit: Suit?) -> Int {
        let aces = hand.filter { $0.rank == .ace }.count
        let trumpKing: Int = trumpSuit.map { suit in
            hand.contains { $0.suit == suit && $0.rank == .king } ? 1 : 0
        } ?? 0
        return min(aces + trumpKing, 5)
    }

    /// Answer partner's ask, in whichever scheme the partnership plays.
    private func slamAskResponse(eval: HandEvaluation, hand: [Card], ctx: AuctionContext) -> Bid {
        let trump = agreedTrumpSuit(ctx: ctx)

        // Standard Blackwood counts aces only.
        if !usesKeyCards {
            let aces = hand.filter { $0.rank == .ace }.count
            switch aces {
            case 0, 4: return .contract(.five, .clubs)
            case 1:    return .contract(.five, .diamonds)
            case 2:    return .contract(.five, .hearts)
            default:   return .contract(.five, .spades)
            }
        }

        let keyCards = keyCardCount(hand: hand, trumpSuit: trump)
        let hasQueenOfTrump = trump.map { suit in
            hand.contains { $0.suit == suit && $0.rank == .queen }
        } ?? false

        switch rkcbFlavor {
        case .f1430:
            switch keyCards {
            case 1, 4: return .contract(.five, .clubs)
            case 0, 3: return .contract(.five, .diamonds)
            default:   return hasQueenOfTrump ? .contract(.five, .spades) : .contract(.five, .hearts)
            }
        case .f0314:
            switch keyCards {
            case 0, 3: return .contract(.five, .clubs)
            case 1, 4: return .contract(.five, .diamonds)
            default:   return hasQueenOfTrump ? .contract(.five, .spades) : .contract(.five, .hearts)
            }
        }
    }

    /// Place the contract once partner has answered.
    private func slamFollowup(
        response: Bid,
        eval: HandEvaluation,
        hand: [Card],
        ctx: AuctionContext
    ) -> Bid {
        let trump = agreedTrumpSuit(ctx: ctx)
        let agreedStrain: Strain = trump.map { $0.strain } ?? .notrump

        if !usesKeyCards {
            let myAces = hand.filter { $0.rank == .ace }.count
            let partnerAces: Int = {
                switch response {
                case .contract(.five, .clubs):    return 0   // 0 or 4 — read low
                case .contract(.five, .diamonds): return 1
                case .contract(.five, .hearts):   return 2
                case .contract(.five, .spades):   return 3
                default:                          return 0
                }
            }()
            let total = myAces + partnerAces
            if total < 3 { return .contract(.five, agreedStrain) }
            if total == 4 && eval.hcp >= 15 { return .contract(.seven, agreedStrain) }
            return .contract(.six, agreedStrain)
        }

        let myKeyCards = keyCardCount(hand: hand, trumpSuit: trump)

        // Decode partner's count (take the lower ambiguous value — conservative)
        let partnerKeyCards: Int = {
            switch (rkcbFlavor, response) {
            case (.f1430, .contract(.five, .clubs)):    return 1  // 1 or 4
            case (.f1430, .contract(.five, .diamonds)): return 0  // 0 or 3
            case (.f0314, .contract(.five, .clubs)):    return 0  // 0 or 3
            case (.f0314, .contract(.five, .diamonds)): return 1  // 1 or 4
            case (_, .contract(.five, .hearts)):        return 2  // 2, no Q
            case (_, .contract(.five, .spades)):        return 2  // 2, with Q
            default:                                    return 0
            }
        }()

        let hasPartnerQueenOfTrump = (response == .contract(.five, .spades))
        let totalKeyCards = myKeyCards + partnerKeyCards

        if totalKeyCards < 4 { return .contract(.five, agreedStrain) }

        let hasQueenOfTrump = trump.map { suit in
            hand.contains { $0.suit == suit && $0.rank == .queen }
        } ?? false
        let trumpQueenAccounted = hasQueenOfTrump || hasPartnerQueenOfTrump || (totalKeyCards == 5)

        if totalKeyCards == 5 && trumpQueenAccounted && eval.hcp >= 13 {
            return .contract(.seven, agreedStrain)
        }
        return .contract(.six, agreedStrain)
    }

    // ── Exclusion RKCB ──────────────────────────────────────────────────────

    /// Jump to five of a brand-new suit over an agreed fit — a natural bid there
    /// essentially never occurs, which is what makes the ask readable.
    private func exclusionAsk(ctx: AuctionContext, eval: HandEvaluation) -> Bid? {
        guard settings.exclusionRKCB, eval.hcp >= 15,
              let trump = agreedTrumpSuit(ctx: ctx), eval.length(trump) >= 4,
              let highest = ctx.highestCurrentBid else { return nil }
        let named = Set(ctx.auction.compactMap { $0.bid.strain })
        for suit in Suit.allCases where suit != trump {
            if eval.length(suit) == 0 && !named.contains(suit.strain) {
                let ask = Bid.contract(.five, suit.strain)
                if ask.isHigherThan(highest) { return ask }
            }
        }
        return nil
    }

    private func partnerMadeExclusionAsk(_ ctx: AuctionContext) -> Suit? {
        guard settings.exclusionRKCB, !ctx.myBids.isEmpty,
              let last = ctx.partnerLastBid, last.level == .five,
              let strain = last.strain, strain != .notrump, let suit = strain.suit,
              agreedTrumpSuit(ctx: ctx) != nil else { return nil }
        // Only a suit nobody has bid before now reads as the ask
        let earlier = ctx.auction.dropLast()
        if earlier.contains(where: { $0.bid.strain == strain }) { return nil }
        return suit
    }

    private func exclusionResponse(hand: [Card], ctx: AuctionContext, excluding: Suit) -> Bid {
        guard let ask = ctx.partnerLastBid else { return .pass }
        let trump = agreedTrumpSuit(ctx: ctx)
        // Key cards outside the excluded suit
        let aces = hand.filter { $0.rank == .ace && $0.suit != excluding }.count
        let trumpKing: Int = trump.map { suit in
            hand.contains { $0.suit == suit && $0.rank == .king } ? 1 : 0
        } ?? 0
        let keyCards = min(aces + trumpKing, 4)
        let hasQueen = trump.map { suit in
            hand.contains { $0.suit == suit && $0.rank == .queen }
        } ?? false

        // Step responses: 0, 1, 2 without the trump queen, 2 with it
        let step: Int
        switch keyCards {
        case 0:  step = 0
        case 1:  step = 1
        default: step = hasQueen ? 3 : 2
        }
        return stepBid(above: ask, steps: step)
    }

    private func stepBid(above ask: Bid, steps: Int) -> Bid {
        var count = 0
        for level in BidLevel.allCases {
            for strain in Strain.allCases {
                let b = Bid.contract(level, strain)
                if b.isHigherThan(ask) {
                    if count == steps { return b }
                    count += 1
                }
            }
        }
        return .pass
    }

    // ── Control-showing cue bids ────────────────────────────────────────────

    /// The cheapest side suit where I hold a control, at the level just above
    /// the current bid. Italian style counts second-round controls too.
    private func controlCueBid(eval: HandEvaluation, hand: [Card], ctx: AuctionContext, trump: Suit) -> Bid? {
        // Only ever cue once; after that, ask or bid the contract.
        if ctx.myBids.contains(where: { entry in
            guard let s = entry.bid.strain, let suit = s.suit else { return false }
            return suit != trump && entry.bid.level == .four
        }) { return nil }

        guard let highest = ctx.highestCurrentBid else { return nil }

        for suit in Suit.allCases where suit != trump {
            let hasAce  = hand.contains { $0.suit == suit && $0.rank == .ace }
            let isVoid  = eval.length(suit) == 0
            let hasKing = hand.contains { $0.suit == suit && $0.rank == .king }
            let isSingleton = eval.length(suit) == 1

            let control = settings.cueBidStyle == .italian
                ? (hasAce || isVoid || hasKing || isSingleton)
                : (hasAce || isVoid)

            guard control else { continue }
            let cue = Bid.contract(.four, suit.strain)
            if cue.isHigherThan(highest) && cue.isHigherThan(Bid.contract(.three, trump.strain)) {
                return cue
            }
        }
        return nil
    }

    // MARK: - Competitive Bidding

    /// True when the opponents, not us, opened the auction with 1NT.
    private func opponentsOpenedOneNT(_ ctx: AuctionContext) -> Bool {
        guard let opening = ctx.openingEntry else { return false }
        return opening.bid == .contract(.one, .notrump)
            && opening.seat != ctx.seat && opening.seat != ctx.partner
    }

    /// The partnership's agreed defence to a 1NT opening.
    private func defendOneNT(eval: HandEvaluation, hand: [Card], ctx: AuctionContext) -> Bid? {
        guard ctx.iHaveNotActed, settings.ntDefense != .natural else { return nil }
        let hcp = eval.hcp
        guard hcp >= 8 else { return nil }
        let sp = eval.length(.spades), h = eval.length(.hearts)
        let d  = eval.length(.diamonds), c = eval.length(.clubs)
        let hasSixCardSuit = [sp, h, d, c].contains { $0 >= 6 }

        switch settings.ntDefense {
        case .landy:
            if sp >= 4 && h >= 4 { return .contract(.two, .clubs) }
            return nil

        case .cappelletti:
            if sp >= 4 && h >= 4                  { return .contract(.two, .diamonds) }
            if sp >= 5 && (d >= 4 || c >= 4)      { return .contract(.two, .spades)   }
            if h  >= 5 && (d >= 4 || c >= 4)      { return .contract(.two, .hearts)   }
            if d >= 5 && c >= 5                   { return .contract(.two, .notrump)  }
            if hasSixCardSuit                     { return .contract(.two, .clubs)    }
            return nil

        case .dont:
            if h >= 5 && sp >= 5                          { return .contract(.two, .hearts)   }
            if d >= 5 && (h >= 4 || sp >= 4)              { return .contract(.two, .diamonds) }
            if c >= 5 && (d >= 4 || h >= 4 || sp >= 4)    { return .contract(.two, .clubs)    }
            if hasSixCardSuit                             { return .double }
            return nil

        case .meckwell:
            if d >= 5 && c >= 5              { return .double }
            if sp >= 4 && h >= 4             { return .double }
            if c >= 5 && (sp >= 4 || h >= 4) { return .contract(.two, .clubs)    }
            if d >= 5 && (sp >= 4 || h >= 4) { return .contract(.two, .diamonds) }
            if h  >= 5                       { return .contract(.two, .hearts)   }
            if sp >= 5                       { return .contract(.two, .spades)   }
            return nil

        case .natural:
            return nil
        }
    }

    private func michaelsRangeOK(_ hcp: Int) -> Bool {
        switch settings.michaelsStyle {
        case .weakOrStrong: return (hcp >= 6 && hcp <= 11) || hcp >= 16
        case .weakOnly:     return hcp >= 6 && hcp <= 11
        case .strongOnly:   return hcp >= 13
        }
    }

    /// Michaels and the Unusual 2NT both show 5-5 in a known pair of suits.
    private func twoSuitedOvercall(
        eval: HandEvaluation,
        ctx: AuctionContext,
        oppSuit: Suit,
        highest: Bid
    ) -> Bid? {
        guard ctx.iHaveNotActed, michaelsRangeOK(eval.hcp) else { return nil }

        if settings.unusual2NTEnabled {
            let unbid = Suit.allCases.filter { $0 != oppSuit }.sorted { $0.rawValue < $1.rawValue }
            if unbid.count >= 2, eval.length(unbid[0]) >= 5, eval.length(unbid[1]) >= 5 {
                let nt2 = Bid.contract(.two, .notrump)
                if nt2.isHigherThan(highest) { return nt2 }
            }
        }

        if settings.michaelsEnabled {
            let cue = Bid.contract(.two, oppSuit.strain)
            if cue.isHigherThan(highest) {
                if oppSuit.strain.isMinor {
                    if eval.length(.hearts) >= 5 && eval.length(.spades) >= 5 { return cue }
                } else {
                    let otherMajor: Suit = oppSuit == .hearts ? .spades : .hearts
                    let minorLong = eval.length(.clubs) >= 5 || eval.length(.diamonds) >= 5
                    if eval.length(otherMajor) >= 5 && minorLong { return cue }
                }
            }
        }
        return nil
    }

    /// Is a negative double still takeout at this level?
    private func negativeDoubleAllowed(_ overcall: Bid) -> Bool {
        guard settings.negativeDoubleEnabled,
              let lvl = overcall.level, let strain = overcall.strain else { return false }
        switch settings.negativeDoubleLevel {
        case .through2S: return lvl.rawValue < 2 || (lvl == .two   && strain <= .spades)
        case .through3S: return lvl.rawValue < 3 || (lvl == .three && strain <= .spades)
        case .through4H: return lvl.rawValue < 4 || (lvl == .four  && strain <= .hearts)
        case .unlimited: return true
        }
    }

    private func competitiveBid(eval: HandEvaluation, hand: [Card], ctx: AuctionContext) -> Bid {
        let hcp = eval.hcp
        guard let highest = ctx.highestCurrentBid else {
            return openingBid(eval: eval, hand: hand, vulnerability: .neither)
        }

        // ── Defence to their 1NT opening ────────────────────────────────────
        if opponentsOpenedOneNT(ctx) {
            if let bid = defendOneNT(eval: eval, hand: hand, ctx: ctx) {
                if bid == .double || bid.isHigherThan(highest) { return bid }
            }
        }

        // ── Transfers surviving interference, when that is the agreement ────
        if settings.jacobyTransfersEnabled && settings.transfersOverInterference,
           ctx.iHaveNotActed, ctx.partnerLastContractBid == .contract(.one, .notrump) {
            if eval.length(.spades) >= 5 {
                let t = Bid.contract(.two, .hearts)
                if t.isHigherThan(highest) { return t }
            }
            if eval.length(.hearts) >= 5 {
                let t = Bid.contract(.two, .diamonds)
                if t.isHigherThan(highest) { return t }
            }
        }

        // ── Lebensohl: partner opened 1NT and RHO overcalled at the 2-level ──
        if settings.lebensohl != .off, ctx.iHaveNotActed,
           ctx.partnerLastContractBid == .contract(.one, .notrump),
           let rho = ctx.rightOpponentBids.last?.bid, rho.isSuitBid, rho.level == .two {
            if hcp < 8 {
                let relay = Bid.contract(.two, .notrump)
                if relay.isHigherThan(highest) { return relay }
            }
            if hcp >= 10 {
                let threeNT = Bid.contract(.three, .notrump)
                if threeNT.isHigherThan(highest) { return threeNT }
            }
        }

        // ── Negative Double ─────────────────────────────────────────────────
        if ctx.iHaveNotActed,
           let partnerOpen = ctx.partnerLastContractBid,
           partnerOpen.level == .one,
           let partnerOpenSuit = partnerOpen.strain?.suit,
           let rhoLast = ctx.rightOpponentBids.last?.bid,
           rhoLast.isSuitBid,
           let rhoBidSuit = rhoLast.strain?.suit,
           hcp >= 6,
           negativeDoubleAllowed(rhoLast) {
            let hasUnbidMajor = [Suit.hearts, .spades].contains { suit in
                suit != partnerOpenSuit && suit != rhoBidSuit && eval.length(suit) >= 4
            }
            if hasUnbidMajor { return .double }
        }

        // ── Two-suited overcalls ────────────────────────────────────────────
        if let oppSuit = highest.strain?.suit,
           let twoSuited = twoSuitedOvercall(eval: eval, ctx: ctx, oppSuit: oppSuit, highest: highest) {
            return twoSuited
        }

        // ── Takeout Double ──────────────────────────────────────────────────
        if settings.takeoutDoubleEnabled,
           ctx.iHaveNotActed,
           ctx.partnerBids.allSatisfy({ $0.bid == .pass }),
           let oppSuit = highest.strain?.suit,
           hcp >= settings.takeoutDoubleMinHCP {
            let otherSuits = Suit.allCases.filter { $0 != oppSuit }
            let supportCount = otherSuits.filter { eval.length($0) >= 3 }.count
            let shortage = eval.length(oppSuit) <= 1
            if shortage && supportCount == 3 { return .double }
            if eval.length(oppSuit) <= 2 && supportCount == 3
                && hcp >= settings.takeoutDoubleMinHCP + 1 { return .double }
            if eval.length(oppSuit) <= 2 && supportCount >= 2
                && hcp >= settings.takeoutDoubleMinHCP + 4 { return .double }
        }

        // ── Overcalls ───────────────────────────────────────────────────────
        if settings.overcallEnabled && ctx.iHaveNotActed {
            // 1NT overcall (15–18 balanced)
            if hcp >= 15 && hcp <= 18 && eval.isBalanced {
                let nt1 = Bid.contract(.one, .notrump)
                if nt1.isHigherThan(highest) { return nt1 }
            }
            // Simple overcall, at the floor this partnership plays
            for suit in [Suit.spades, .hearts, .diamonds, .clubs] where eval.length(suit) >= 5 {
                let lvl1 = Bid.contract(.one, suit.strain)
                if lvl1.isHigherThan(highest) && hcp >= overcall1LevelMin { return lvl1 }
                let lvl2 = Bid.contract(.two, suit.strain)
                if lvl2.isHigherThan(highest) && hcp >= settings.overcall2LevelMinHCP { return lvl2 }
            }
            // Preemptive jump overcall
            if hcp >= 5 && hcp <= 10 {
                for suit in [Suit.spades, .hearts, .diamonds, .clubs] where eval.length(suit) >= 6 {
                    let jmp = Bid.contract(.two, suit.strain)
                    if jmp.isHigherThan(highest) { return jmp }
                }
            }
        }

        // ── Raise Partner's Suit ────────────────────────────────────────────
        if let partnerSuit = ctx.partnerLastContractBid?.strain {
            let fit = eval.length(partnerSuit.suit ?? .clubs)
            if fit >= 3 && hcp >= 6 {
                for raiseLvl: BidLevel in [.two, .three] {
                    let b = Bid.contract(raiseLvl, partnerSuit)
                    if b.isHigherThan(highest) { return b }
                }
            }
        }

        return .pass
    }

    private func lateBid(eval: HandEvaluation, hand: [Card], ctx: AuctionContext) -> Bid {
        let hcp = eval.hcp
        guard let highest = ctx.highestCurrentBid else { return .pass }

        // Slam exploration once a major fit is in place
        if let partnerBid = ctx.partnerLastContractBid,
           partnerBid.strain?.isMajor == true,
           let suit = partnerBid.strain?.suit,
           let partnerStrain = partnerBid.strain {
            let fit = eval.length(suit)

            if fit >= 3 && hcp >= 17 {
                // Exclusion asks about everything except a void
                if let excl = exclusionAsk(ctx: ctx, eval: eval) { return excl }
                // A control cue below the ask keeps the auction informative
                if let cue = controlCueBid(eval: eval, hand: hand, ctx: ctx, trump: suit) { return cue }
                let ask = keyCardAsk(trump: suit)
                if ask.isHigherThan(highest) { return ask }
            }
            if fit >= 3 && hcp >= 10 {
                let game4M = Bid.contract(.four, partnerStrain)
                if game4M.isHigherThan(highest) { return game4M }
            }
        }

        if eval.isBalanced && hcp >= 13 {
            let threeNT = Bid.contract(.three, .notrump)
            if threeNT.isHigherThan(highest) { return threeNT }
        }

        if hcp >= 14 {
            for suit in [Suit.spades, .hearts, .diamonds, .clubs] where eval.length(suit) >= 5 {
                let b = Bid.contract(.three, suit.strain)
                if b.isHigherThan(highest) { return b }
            }
        }

        return .pass
    }

    // MARK: - Helpers

    private func splinterBid(openSuit: Suit, singletonSuit: Suit) -> Bid? {
        switch (openSuit, singletonSuit) {
        case (.hearts, .spades):   return .contract(.three, .spades)
        case (.hearts, .clubs):    return .contract(.four, .clubs)
        case (.hearts, .diamonds): return .contract(.four, .diamonds)
        case (.spades, .hearts):   return .contract(.four, .hearts)
        case (.spades, .clubs):    return .contract(.four, .clubs)
        case (.spades, .diamonds): return .contract(.four, .diamonds)
        default: return nil
        }
    }

    private func highestSafeBid(eval: HandEvaluation, above: Bid?) -> Bid {
        let above = above ?? .contract(.one, .clubs)
        for level in BidLevel.allCases {
            for strain in Strain.allCases {
                let b = Bid.contract(level, strain)
                if b.isHigherThan(above) { return b }
            }
        }
        return .pass
    }

    // MARK: - Bid Explanation

    func bidNote(bid: Bid, seat: Seat, auction: [(seat: Seat, bid: Bid)]) -> String {
        if bid == .pass { return "" }
        if bid == .redouble { return "Redouble: confident the contract can be made" }

        let ctx = AuctionContext(seat: seat, auction: auction)

        // Double
        if bid == .double {
            if opponentsOpenedOneNT(ctx) && settings.ntDefense == .dont {
                return "DONT double: a one-suited hand — partner bids 2♣ to ask which"
            }
            if opponentsOpenedOneNT(ctx) && settings.ntDefense == .meckwell {
                return "Meckwell double: both minors, or a major — partner relays to find out"
            }
            if ctx.iHaveNotActed && ctx.partnerBids.allSatisfy({ $0.bid == .pass }) {
                return "Takeout double: \(settings.takeoutDoubleMinHCP)+ HCP, short in their suit, support for the unbid suits"
            }
            if settings.supportDoubles && ctx.iHaveNotActed
                && ctx.partnerLastContractBid != nil && !ctx.opponentIntervened {
                return "Support double: exactly 3-card support for partner's suit"
            }
            return "Negative double: 6+ HCP, showing the unbid major(s) — takeout \(settings.negativeDoubleLevel.rawValue.lowercased())"
        }

        guard let bidLevel = bid.level, let bidStrain = bid.strain else { return "" }

        // ── Opening bids ────────────────────────────────────────────────────
        if ctx.isOpeningPosition {
            switch (bidLevel, bidStrain) {
            case (.one, .notrump): return "1NT opening: 15-17 HCP, balanced"
            case (.two, .clubs):   return "Strong 2♣: 22+ HCP (or 20+ with a long suit)"
            case (.two, .notrump): return "2NT opening: 20-21 HCP, balanced"
            case (.two, let s) where s != .clubs:
                let r = settings.weakTwoStyle.hcpRange
                return "Weak 2\(s.display): \(r.lowerBound)-\(r.upperBound) HCP, 6-card \(s.display) suit (\(settings.weakTwoStyle.rawValue))"
            case (.three, let s):
                return "Preempt 3\(s.display): 4-9 HCP, 7-card \(s.display) suit"
            default:
                return "Opening: 12+ HCP, longest suit first"
            }
        }

        // ── Defence to their 1NT ────────────────────────────────────────────
        if opponentsOpenedOneNT(ctx) && ctx.myBids.count <= 1 && settings.ntDefense != .natural {
            return "\(settings.ntDefense.rawValue) defence to 1NT: \(settings.ntDefense.detail)"
        }

        // ── Responder's first bid ───────────────────────────────────────────
        if ctx.partnerOpenedCleanly,
           let partnerOpen = ctx.partnerLastContractBid,
           let openLevel = partnerOpen.level, let openStrain = partnerOpen.strain {

            // After 1NT
            if openLevel == .one && openStrain == .notrump {
                switch bid {
                case .contract(.two, .clubs):
                    return "Stayman (\(settings.staymanVariant.rawValue)): asking for a 4-card major"
                case .contract(.two, .diamonds):  return "Jacoby Transfer → ♥: 5+ hearts"
                case .contract(.two, .hearts):    return "Jacoby Transfer → ♠: 5+ spades"
                case .contract(.two, .spades):
                    return settings.transferStyle == .fourSuit
                        ? "Four-suit transfer → ♣: 6+ clubs, weak"
                        : "2♠: natural, invitational"
                case .contract(.two, .notrump):
                    return settings.transferStyle == .fourSuit
                        ? "Four-suit transfer → ♦: 6+ diamonds, weak"
                        : "Invitational: 8-9 HCP, no 4-card major"
                case .contract(.three, .notrump): return "3NT: 10-14 HCP, balanced — to play"
                case .contract(.four, .clubs):    return "Gerber 4♣: asking how many aces"
                case .contract(.four, .diamonds): return "Texas Transfer → ♥: 6+ hearts, game values"
                case .contract(.four, .notrump):  return "Quantitative 4NT: 15+ HCP, slam invite"
                case .contract(.four, .hearts):
                    return settings.texasTransfers == .on
                        ? "Texas Transfer → ♠: 6+ spades, game values"
                        : "4♥: 6+ hearts, game values"
                case .contract(.four, .spades):   return "4♠: 6+ spades, game values"
                default: return ""
                }
            }

            // After 2NT
            if openLevel == .two && openStrain == .notrump {
                switch bid {
                case .contract(.three, .clubs):    return "Puppet Stayman: asking for a 5-card major first"
                case .contract(.three, .diamonds): return "Jacoby Transfer → ♥: 5+ hearts"
                case .contract(.three, .hearts):   return "Jacoby Transfer → ♠: 5+ spades"
                case .contract(.three, .notrump):  return "3NT: balanced, to play"
                case .contract(.four, .clubs):     return "Gerber 4♣: asking how many aces"
                case .contract(.six, .notrump):    return "6NT: 10+ HCP, balanced slam"
                default: return ""
                }
            }

            // After 2♣
            if openLevel == .two && openStrain == .clubs {
                if bid == .contract(.two, .diamonds) { return "2♦ waiting: 0-7 HCP" }
                if bid == .contract(.two, .notrump)  { return "2NT positive: 8+ HCP, balanced" }
                return "Positive response to 2♣: 8+ HCP, 5-card \(bidStrain.display) suit"
            }

            // After a weak two
            if openLevel == .two && openStrain.isMajor {
                if bid == .contract(.two, .notrump) {
                    return settings.weakTwoResponse == .feature
                        ? "2NT: asking opener to show an outside ace or king"
                        : "Ogust 2NT: asking about suit quality and overall strength"
                }
                if bidStrain == openStrain { return "Preemptive raise of the \(openStrain.display) opening" }
                return "Game try: 14+ HCP"
            }

            // After 1M
            if openLevel == .one && openStrain.isMajor, let openSuit = openStrain.suit {
                if bid == .contract(.two, .notrump) {
                    return "Jacoby 2NT: 13+ HCP, 4+ \(openStrain.display) — game force"
                }
                if bid == .contract(.two, .clubs) && ctx.iAmPassedHand && settings.druryEnabled {
                    return "\(settings.druryStyle.rawValue): 3+ \(openStrain.display), 10-12 points by a passed hand"
                }
                if bid == .contract(.two, .diamonds) && ctx.iAmPassedHand
                    && settings.druryEnabled && settings.druryStyle == .twoWay {
                    return "Two-Way Drury 2♦: 4+ \(openStrain.display), 10-12 points by a passed hand"
                }
                if bid == .contract(.four, openStrain) { return "Game raise: 13+ TP, 3+ \(openStrain.display)" }
                if bid == .contract(.two, openStrain)  { return "Simple raise: 6-9 HCP, 3+ \(openStrain.display)" }
                if bid == .contract(.three, openStrain) { return "Limit raise: 10-12 points, 3+ \(openStrain.display)" }
                if bid == .contract(.four, .notrump) {
                    return usesKeyCards
                        ? "RKCB (4NT): key card ask with \(openStrain.display) agreed"
                        : "Blackwood 4NT: asking how many aces"
                }
                if bid == .contract(.one, .notrump) {
                    return settings.oneNTResponseStyle == .forcing
                        ? "1NT forcing: 6-12 HCP, no \(openStrain.display) fit — opener must bid again"
                        : "1NT semi-forcing: 6-12 HCP, no \(openStrain.display) fit"
                }
                let splinterBids: [Bid] = openSuit == .hearts
                    ? [.contract(.three, .spades), .contract(.four, .clubs), .contract(.four, .diamonds)]
                    : [.contract(.four, .hearts), .contract(.four, .clubs), .contract(.four, .diamonds)]
                if settings.splinterEnabled && splinterBids.contains(bid) {
                    return "Splinter: 4+ \(openStrain.display), singleton/void in \(bidStrain.display), \(settings.splinterMinHCP)+ HCP"
                }
                if bidLevel == .two && bidStrain != openStrain && settings.twoOverOneEnabled {
                    return "2/1 Game Force: 13+ HCP, 5-card \(bidStrain.display)"
                }
                if bidLevel == .one { return "New suit: 4+ \(bidStrain.display), 6+ HCP" }
                return ""
            }

            // After 1m
            if openLevel == .one && openStrain.isMinor {
                if bidLevel == .one && bidStrain.isMajor {
                    return "New major: 4+ \(bidStrain.display), 6+ HCP"
                }
                if bidStrain == openStrain && settings.minorRaiseStyle == .inverted {
                    return bidLevel == .two
                        ? "Inverted minor raise: 10+ HCP, 5+ \(openStrain.display) — forcing"
                        : "Inverted jump raise: preemptive, under 10 HCP"
                }
                if bid == .contract(.one, .notrump)   { return "1NT: 6-9 HCP, no 4-card major" }
                if bid == .contract(.two, .notrump)   { return "2NT: 10-12 HCP, balanced" }
                if bid == .contract(.three, .notrump) { return "3NT: 13-15 HCP, balanced — to play" }
                if bidStrain == openStrain { return "Minor raise: 5-card support" }
                return ""
            }
        }

        // ── Opener's rebid after Jacoby 2NT ─────────────────────────────────
        if ctx.iRebidding,
           let myOpen = ctx.myLastContractBid,
           myOpen.level == .one, myOpen.strain?.isMajor == true,
           let openStrain = myOpen.strain,
           ctx.partnerLastContractBid == .contract(.two, .notrump) {
            if bid == .contract(.four, openStrain)  { return "Jacoby 2NT reply: balanced minimum — sign off at game" }
            if bid == .contract(.three, openStrain) { return "Jacoby 2NT reply: 6-card \(openStrain.display) suit" }
            if bidLevel == .three                   { return "Jacoby 2NT reply: singleton in \(bidStrain.display)" }
            if bidLevel == .four && bidStrain != openStrain {
                return "Jacoby 2NT reply: 5-card side suit in \(bidStrain.display)"
            }
            return ""
        }

        // ── Ogust replies ───────────────────────────────────────────────────
        if ctx.iRebidding, ctx.partnerLastContractBid == .contract(.two, .notrump),
           ctx.myLastContractBid?.level == .two, settings.weakTwoResponse == .ogust,
           bidLevel == .three {
            switch bidStrain {
            case .clubs:    return "Ogust 3♣: bad suit, bad hand"
            case .diamonds: return "Ogust 3♦: bad suit, good hand"
            case .hearts:   return "Ogust 3♥: good suit, bad hand"
            case .spades:   return "Ogust 3♠: good suit, good hand"
            default: break
            }
        }

        // ── Key card response ───────────────────────────────────────────────
        if ctx.partnerAskedForAces && bidLevel == .five {
            if !usesKeyCards {
                switch bidStrain {
                case .clubs:    return "Blackwood 5♣: 0 or 4 aces"
                case .diamonds: return "Blackwood 5♦: 1 ace"
                case .hearts:   return "Blackwood 5♥: 2 aces"
                case .spades:   return "Blackwood 5♠: 3 aces"
                default: return ""
                }
            }
            let low  = rkcbFlavor == .f1430 ? "1 or 4" : "0 or 3"
            let high = rkcbFlavor == .f1430 ? "0 or 3" : "1 or 4"
            switch bidStrain {
            case .clubs:    return "RKCB 5♣: \(low) key cards"
            case .diamonds: return "RKCB 5♦: \(high) key cards"
            case .hearts:   return "RKCB 5♥: 2 key cards, no queen of trump"
            case .spades:   return "RKCB 5♠: 2 key cards + queen of trump"
            default: return ""
            }
        }

        // ── The ask itself ──────────────────────────────────────────────────
        if bid == .contract(.four, .notrump) {
            return usesKeyCards
                ? "RKCB (4NT): asking for key cards — 4 aces plus the king of trumps"
                : "Blackwood (4NT): asking how many aces"
        }
        if settings.kickbackEnabled, bidLevel == .four,
           let t = agreedTrumpSuit(ctx: ctx), t != .spades, bid == kickbackAsk(for: t) {
            return "Kickback \(bid.display): key card ask with \(t.strain.display) agreed"
        }
        if settings.exclusionRKCB, bidLevel == .five, partnerMadeExclusionAsk(ctx) == nil,
           isBrandNewSuit(bid, ctx: ctx) {
            return "Exclusion RKCB \(bid.display): key card ask ignoring \(bidStrain.display) — void there"
        }

        // ── Slam bids ───────────────────────────────────────────────────────
        if bidLevel == .six   { return "Small slam: contract for 12 of 13 tricks" }
        if bidLevel == .seven { return "Grand slam: contract for all 13 tricks" }

        // ── Competitive first bid ───────────────────────────────────────────
        if ctx.opponentIntervened && ctx.iHaveNotActed {
            if bid == .contract(.two, .notrump) && settings.unusual2NTEnabled {
                return "Unusual 2NT: at least 5-5 in the two lowest unbid suits"
            }
            if settings.michaelsEnabled, bidLevel == .two,
               let opp = ctx.highestCurrentBid?.strain, opp == bidStrain {
                return "Michaels cue bid (\(settings.michaelsStyle.rawValue)): a 5-5 two-suiter"
            }
            if bidStrain == .notrump {
                return "\(bidLevel.rawValue)NT overcall: 15-18 HCP, balanced, stopper in their suit"
            }
            if bidLevel.rawValue >= 3 {
                return "Jump overcall: 5-10 HCP, 6-card \(bidStrain.display) suit — preemptive"
            }
            let floor = bidLevel == .one ? overcall1LevelMin : settings.overcall2LevelMinHCP
            return "Overcall: \(floor)+ HCP, 5-card \(bidStrain.display) suit (\(settings.overcallStyle.rawValue))"
        }

        return ""
    }

    private func isBrandNewSuit(_ bid: Bid, ctx: AuctionContext) -> Bool {
        guard let strain = bid.strain, strain != .notrump else { return false }
        return !ctx.auction.contains { $0.bid.strain == strain }
    }
}
