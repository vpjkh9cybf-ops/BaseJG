import Foundation

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
    var myLastBid: Bid? { myBids.last?.bid }
    var partnerLastBid: Bid? { partnerBids.last?.bid }

    var highestCurrentBid: Bid? { auction.reversed().first(where: { $0.bid.isSuitBid })?.bid }

    var opponentIntervened: Bool {
        let opBids = (leftOpponentBids + rightOpponentBids)
        return opBids.contains(where: { $0.bid.isSuitBid || $0.bid == .double })
    }

    var isOpeningPosition: Bool {
        auction.allSatisfy { $0.bid == .pass }
    }

    // Partner opened, no-one else has bid, I haven't bid
    var partnerOpenedCleanly: Bool {
        guard myBids.isEmpty,
              let _ = partnerLastContractBid,
              (leftOpponentBids + rightOpponentBids).allSatisfy({ $0.bid == .pass })
        else { return false }
        return true
    }

    // I opened, partner responded, now I rebid
    var iRebidding: Bool {
        myBids.count == 1 && partnerBids.count == 1 && myBids[0].bid.isSuitBid
    }

    // Partner opened, I responded, partner rebid, now I continue
    var partnerRebid: Bool {
        partnerBids.count == 2 && myBids.count == 1
    }

    // RKCB / Blackwood context: partner bid 4NT to ask for aces
    var partnerAskedForAces: Bool {
        partnerLastBid == .contract(.four, .notrump) && myBids.isEmpty == false
    }

    // I bid 4NT to ask
    var iAskedForAces: Bool {
        myLastBid == .contract(.four, .notrump)
    }
}

struct BiddingAI {

    static func selectBid(
        hand: [Card],
        seat: Seat,
        auction: [(seat: Seat, bid: Bid)],
        vulnerability: Vulnerability
    ) -> Bid {
        let eval = HandEvaluator.evaluate(hand)
        let ctx  = AuctionContext(seat: seat, auction: auction)

        // Opening position
        if ctx.isOpeningPosition { return openingBid(eval: eval, hand: hand, vulnerability: vulnerability) }

        // Responding to partner's clean open
        if ctx.partnerOpenedCleanly, let partnerOpen = ctx.partnerLastContractBid {
            return respond(to: partnerOpen, eval: eval, hand: hand, ctx: ctx)
        }

        // I rebid (I opened, partner responded)
        if ctx.iRebidding, let myOpen = ctx.myLastContractBid, let partnerResp = ctx.partnerLastContractBid {
            return rebid(myOpen: myOpen, partnerResp: partnerResp, eval: eval, hand: hand, ctx: ctx)
        }

        // Partner rebid, I continue (responder rebid)
        if ctx.partnerRebid {
            return responderRebid(eval: eval, hand: hand, ctx: ctx)
        }

        // Overcall / competitive
        if ctx.opponentIntervened {
            return competitiveBid(eval: eval, hand: hand, ctx: ctx)
        }

        // Late auction / unclear - best guess
        return lateBid(eval: eval, hand: hand, ctx: ctx)
    }

    // MARK: - Opening Bids

    private static func openingBid(eval: HandEvaluation, hand: [Card], vulnerability: Vulnerability) -> Bid {
        let hcp = eval.hcp

        // Preempts (weak hands with long suits)
        if hcp < 12 {
            return preemptBid(eval: eval, hand: hand, vulnerability: vulnerability)
        }

        // Strong 2♣ (22+ or game force)
        if hcp >= 22 || (hcp >= 20 && eval.totalPoints >= 25) {
            return .contract(.two, .clubs)
        }

        // 2NT (20-21 balanced)
        if hcp >= 20 && hcp <= 21 && eval.isBalanced {
            return .contract(.two, .notrump)
        }

        // 1NT (15-17 balanced)
        if hcp >= 15 && hcp <= 17 && eval.isBalanced {
            return .contract(.one, .notrump)
        }

        // 5-card majors
        if eval.length(.spades) >= 5 && eval.length(.spades) >= eval.length(.hearts) {
            return .contract(.one, .spades)
        }
        if eval.length(.hearts) >= 5 {
            return .contract(.one, .hearts)
        }

        // 12-14 balanced → open a minor (then bid NT at rebid)
        if eval.isBalanced {
            // Open 1♣ unless long diamonds
            return eval.length(.diamonds) >= eval.length(.clubs) ? .contract(.one, .diamonds) : .contract(.one, .clubs)
        }

        // Unbalanced: open longest suit (min 3)
        if eval.length(.diamonds) > eval.length(.clubs) {
            return .contract(.one, .diamonds)
        }
        return .contract(.one, .clubs)
    }

    private static func preemptBid(eval: HandEvaluation, hand: [Card], vulnerability: Vulnerability) -> Bid {
        let hcp = eval.hcp
        // Weak 2s (5-10 HCP, 6-card suit, not clubs)
        if hcp >= 5 && hcp <= 10 {
            for suit in [Suit.spades, .hearts, .diamonds] {
                if eval.length(suit) >= 6 {
                    return .contract(.two, suit.strain)
                }
            }
        }
        // 3-level preempt (7 cards)
        if hcp >= 4 && hcp <= 9 {
            for suit in Suit.allCases.reversed() {
                if eval.length(suit) >= 7 {
                    return .contract(.three, suit.strain)
                }
            }
        }
        return .pass
    }

    // MARK: - Responses

    private static func respond(to open: Bid, eval: HandEvaluation, hand: [Card], ctx: AuctionContext) -> Bid {
        guard let level = open.level, let strain = open.strain else { return .pass }
        let hcp = eval.hcp

        switch (level, strain) {
        case (.one, .notrump):
            return respondToOneNT(eval: eval, hand: hand)

        case (.two, .notrump):
            return respondToTwoNT(eval: eval, hand: hand)

        case (.two, .clubs):
            return respondToTwoClubs(eval: eval)

        case (.one, .hearts), (.one, .spades):
            return respondToOneMajor(open: open, openStrain: strain, eval: eval, hand: hand)

        case (.one, .clubs), (.one, .diamonds):
            return respondToOneMinor(open: open, openStrain: strain, eval: eval, hand: hand)

        case (.two, .hearts), (.two, .spades), (.two, .diamonds):
            // Responding to weak 2
            return respondToWeakTwo(open: open, openStrain: strain, eval: eval)

        default:
            return hcp >= 6 ? .pass : .pass
        }
    }

    // Response to 1NT (15-17)
    private static func respondToOneNT(eval: HandEvaluation, hand: [Card]) -> Bid {
        let hcp = eval.hcp
        let sp = eval.length(.spades)
        let h  = eval.length(.hearts)

        // Garbage — pass with < 8 HCP (no major)
        // Weak signoff with 5-card major
        if hcp < 8 {
            if sp >= 5 { return .contract(.two, .hearts) }   // Jacoby transfer to spades
            if h  >= 5 { return .contract(.two, .diamonds) } // Jacoby transfer to hearts
            return .pass
        }

        // Game-forcing hands: use Stayman or transfers
        if hcp >= 8 {
            // Jacoby transfer with 5+ major
            if sp >= 5 && sp >= h { return .contract(.two, .hearts) }   // → 2♠
            if h  >= 5            { return .contract(.two, .diamonds) } // → 2♥
            // Stayman with 4-card major
            if sp >= 4 || h >= 4 { return .contract(.two, .clubs) }
            // No major: NT
            if hcp >= 10 && hcp <= 14 { return .contract(.three, .notrump) }
            if hcp >= 8  && hcp <= 9  { return .contract(.two, .notrump) }
            if hcp >= 15              { return .contract(.four, .notrump) } // Quantitative
        }
        return .contract(.three, .notrump)
    }

    // Response to 2NT (20-21)
    private static func respondToTwoNT(eval: HandEvaluation, hand: [Card]) -> Bid {
        let hcp = eval.hcp
        let sp = eval.length(.spades)
        let h  = eval.length(.hearts)
        if hcp == 0 && sp < 5 && h < 5 { return .pass }
        if sp >= 5 { return .contract(.three, .hearts) }   // Jacoby transfer
        if h  >= 5 { return .contract(.three, .diamonds) } // Jacoby transfer
        if sp >= 4 || h >= 4 { return .contract(.three, .clubs) } // Puppet Stayman
        if hcp >= 4  { return .contract(.three, .notrump) }
        if hcp >= 10 { return .contract(.six, .notrump)   }
        return .pass
    }

    // Response to 2♣ (strong)
    private static func respondToTwoClubs(eval: HandEvaluation) -> Bid {
        let hcp = eval.hcp
        // Waiting 2♦ on most hands
        if hcp < 8 { return .contract(.two, .diamonds) }
        // Positive with 5-card suit and 8+ HCP
        if eval.length(.spades) >= 5  { return .contract(.two, .spades)  }
        if eval.length(.hearts) >= 5  { return .contract(.two, .hearts)  }
        if eval.length(.diamonds) >= 5 { return .contract(.three, .diamonds) }
        if eval.length(.clubs) >= 5   { return .contract(.three, .clubs)  }
        return .contract(.two, .notrump) // 8+ HCP balanced positive
    }

    // Response to 1♥ or 1♠
    private static func respondToOneMajor(open: Bid, openStrain: Strain, eval: HandEvaluation, hand: [Card]) -> Bid {
        let hcp = eval.hcp
        let tp  = eval.totalPoints
        guard let openSuit = openStrain.suit else { return .pass }
        let fit = eval.length(openSuit)
        let otherMajor: Strain = openStrain == .spades ? .hearts : .spades

        if hcp < 6 { return .pass }

        // Jacoby 2NT (4+ fit, 12+ HCP, game-forcing)
        if fit >= 4 && hcp >= 12 {
            return .contract(.two, .notrump)
        }

        // Limit raise / game raise
        if fit >= 3 && tp >= 10 && tp <= 11 {
            return .contract(.three, openStrain)  // Limit raise (invitational)
        }
        if fit >= 3 && tp >= 12 {
            return .contract(.four, openStrain)   // Game raise
        }

        // Simple raise
        if fit >= 3 && hcp >= 6 && hcp <= 9 {
            return .contract(.two, openStrain)
        }

        // New suit (game-forcing 2/1)
        let lowerMajor: Strain = (openStrain == .spades) ? .hearts : .notrump
        if hcp >= 13 {
            // 2/1 game force in lower suit if we have 4+
            if openStrain == .spades && eval.length(.hearts) >= 4 {
                return .contract(.two, .hearts)
            }
            if openStrain == .spades && eval.length(.diamonds) >= 4 {
                return .contract(.two, .diamonds)
            }
            return .contract(.three, .notrump)
        }

        // Respond 1♠ to 1♥ if 4 spades and < game force
        if openStrain == .hearts && eval.length(.spades) >= 4 && hcp >= 6 {
            return .contract(.one, .spades)
        }

        // 1NT (semi-forcing: 6-11, no fit)
        if hcp >= 6 { return .contract(.one, .notrump) }

        return .pass
    }

    // Response to 1♣ or 1♦
    private static func respondToOneMinor(open: Bid, openStrain: Strain, eval: HandEvaluation, hand: [Card]) -> Bid {
        let hcp = eval.hcp
        if hcp < 6 { return .pass }

        // Majors first
        if eval.length(.spades) >= 4 { return .contract(.one, .spades) }
        if eval.length(.hearts) >= 4 { return .contract(.one, .hearts) }

        // NT responses
        if hcp >= 13 && hcp <= 15 && eval.isBalanced { return .contract(.three, .notrump) }
        if hcp >= 10 && hcp <= 12 && eval.isBalanced { return .contract(.two, .notrump)  }
        if hcp >= 6  && hcp <= 9  && eval.isBalanced { return .contract(.one, .notrump)  }

        // Raise minor
        let openSuit = openStrain.suit!
        if eval.length(openSuit) >= 5 && hcp >= 6  { return .contract(.two, openStrain) }
        if eval.length(openSuit) >= 5 && hcp >= 13 { return .contract(.three, openStrain) }

        // Other minor
        let otherMinor: Strain = openStrain == .clubs ? .diamonds : .clubs
        if eval.length(otherMinor.suit!) >= 4 && hcp >= 10 { return .contract(.two, otherMinor) }

        return .contract(.one, .notrump)
    }

    private static func respondToWeakTwo(open: Bid, openStrain: Strain, eval: HandEvaluation) -> Bid {
        let hcp = eval.hcp
        guard let openSuit = openStrain.suit else { return .pass }
        let fit = eval.length(openSuit)

        // With strong hand and fit, raise to game
        if hcp >= 14 && fit >= 3 { return .contract(.four, openStrain) }
        if hcp >= 12 && fit >= 3 { return .contract(.three, openStrain) }
        // Competitive raise (preemptive)
        if hcp < 12 && fit >= 3 { return .contract(.three, openStrain) }
        // New suit forcing (12+ HCP, natural)
        if hcp >= 14 {
            for suit in [Suit.spades, .hearts, .diamonds, .clubs] {
                if eval.length(suit) >= 5 && suit != openSuit {
                    return .contract(.three, suit.strain)
                }
            }
            return .contract(.two, .notrump) // Ogust / artificial enquiry
        }
        return .pass
    }

    // MARK: - Rebids (opener's second bid)

    private static func rebid(
        myOpen: Bid,
        partnerResp: Bid,
        eval: HandEvaluation,
        hand: [Card],
        ctx: AuctionContext
    ) -> Bid {
        guard let openLevel = myOpen.level, let openStrain = myOpen.strain else { return .pass }
        guard let respLevel = partnerResp.level, let respStrain = partnerResp.strain else {
            // Partner doubled etc - competitive
            return competitiveBid(eval: eval, hand: hand, ctx: ctx)
        }

        let hcp = eval.hcp
        let highest = ctx.highestCurrentBid ?? myOpen

        // Handle 1NT rebid sequences (Stayman / Transfers)
        if openStrain == .notrump && openLevel == .one {
            return rebidAfterOneNT(partnerResp: partnerResp, eval: eval, hand: hand)
        }

        if openStrain == .clubs && openLevel == .two {
            // Strong 2♣ rebid
            return rebidAfterTwoClubs(partnerResp: partnerResp, eval: eval, hand: hand)
        }

        // After major open
        if openStrain.isMajor {
            return rebidAfterMajorOpen(
                openStrain: openStrain, partnerResp: partnerResp,
                eval: eval, hand: hand, ctx: ctx
            )
        }

        // After minor open
        return rebidAfterMinorOpen(
            openStrain: openStrain, partnerResp: partnerResp,
            eval: eval, hand: hand, ctx: ctx
        )
    }

    private static func rebidAfterOneNT(partnerResp: Bid, eval: HandEvaluation, hand: [Card]) -> Bid {
        guard let respStrain = partnerResp.strain, let respLevel = partnerResp.level else { return .pass }

        // Stayman response (2♣): show 4-card major or deny
        if respLevel == .two && respStrain == .clubs {
            if eval.length(.spades) >= 4 { return .contract(.two, .spades) }
            if eval.length(.hearts) >= 4 { return .contract(.two, .hearts) }
            return .contract(.two, .diamonds) // No 4-card major
        }

        // Jacoby transfer (2♦ → accept into 2♥)
        if respLevel == .two && respStrain == .diamonds {
            let h = eval.length(.hearts)
            if h >= 3 && eval.hcp >= 16 { return .contract(.three, .hearts) } // Super-accept
            return .contract(.two, .hearts)
        }

        // Jacoby transfer (2♥ → accept into 2♠)
        if respLevel == .two && respStrain == .hearts {
            let s = eval.length(.spades)
            if s >= 3 && eval.hcp >= 16 { return .contract(.three, .spades) } // Super-accept
            return .contract(.two, .spades)
        }

        // 2NT invite → accept or decline
        if respLevel == .two && respStrain == .notrump {
            return eval.hcp >= 17 ? .contract(.three, .notrump) : .pass
        }

        // Quantitative 4NT
        if respLevel == .four && respStrain == .notrump {
            return eval.hcp >= 17 ? .contract(.six, .notrump) : .pass
        }

        return .pass
    }

    private static func rebidAfterTwoClubs(partnerResp: Bid, eval: HandEvaluation, hand: [Card]) -> Bid {
        guard let respStrain = partnerResp.strain, let respLevel = partnerResp.level else { return .pass }

        // Partner bid 2♦ (waiting) — show hand
        if respLevel == .two && respStrain == .diamonds {
            if eval.length(.spades) >= 5  { return .contract(.two, .spades)  }
            if eval.length(.hearts) >= 5  { return .contract(.two, .hearts)  }
            if eval.length(.diamonds) >= 5 { return .contract(.three, .diamonds) }
            if eval.length(.clubs) >= 5   { return .contract(.three, .clubs)  }
            if eval.isBalanced            { return .contract(.two, .notrump)  }
            return .contract(.three, .clubs)
        }

        // Partner showed positive — set contract
        if eval.hcp >= 24 && eval.isBalanced { return .contract(.six, .notrump) }
        if respStrain.isMajor && eval.length(respStrain.suit!) >= 3 {
            return .contract(.four, respStrain)
        }
        return .contract(.three, .notrump)
    }

    private static func rebidAfterMajorOpen(
        openStrain: Strain,
        partnerResp: Bid,
        eval: HandEvaluation,
        hand: [Card],
        ctx: AuctionContext
    ) -> Bid {
        guard let respStrain = partnerResp.strain, let respLevel = partnerResp.level else { return .pass }
        let hcp = eval.hcp
        let openSuit = openStrain.suit!

        // Partner bid Jacoby 2NT (4+ fit, game force)
        if respLevel == .two && respStrain == .notrump {
            // Show short suit (singleton/void) with extras, or NT/4M minimum
            for suit in Suit.allCases {
                if suit != openSuit && eval.length(suit) <= 1 && hcp >= 15 {
                    return .contract(.three, suit.strain) // Short suit cue
                }
            }
            if hcp >= 15 { return .contract(.three, openStrain) } // Extra trump length
            return .contract(.four, openStrain)  // Minimum
        }

        // Partner made simple raise
        if respStrain == openStrain {
            if hcp >= 17 { return .contract(.four, openStrain) } // Game
            if hcp >= 16 { return .contract(.three, openStrain) } // Invite
            return .pass
        }

        // Partner bid 1NT (6-11)
        if respLevel == .one && respStrain == .notrump {
            if hcp >= 18 { return .contract(.three, openStrain) }
            if hcp >= 15 { return .contract(.two, openStrain) }
            return .pass
        }

        // Partner bid new suit at 2-level (game force)
        if respLevel == .two {
            if eval.length(respStrain.suit ?? .clubs) >= 4 {
                return .contract(.three, respStrain)
            }
            if hcp >= 15 { return .contract(.two, openStrain) }
            if eval.isBalanced { return .contract(.two, .notrump) }
            return .contract(.two, openStrain)
        }

        // Partner bid 1♠ over 1♥
        if openStrain == .hearts && respStrain == .spades && respLevel == .one {
            if eval.length(.spades) >= 4 { return .contract(.three, .spades) } // Spade fit
            if hcp >= 19 { return .contract(.three, .hearts) }
            if hcp >= 16 { return .contract(.two, .hearts) }
            return .pass
        }

        return highestSafeBid(eval: eval, above: ctx.highestCurrentBid)
    }

    private static func rebidAfterMinorOpen(
        openStrain: Strain,
        partnerResp: Bid,
        eval: HandEvaluation,
        hand: [Card],
        ctx: AuctionContext
    ) -> Bid {
        guard let respStrain = partnerResp.strain, let respLevel = partnerResp.level else { return .pass }
        let hcp = eval.hcp

        // Partner responded with a major
        if respStrain.isMajor && respLevel == .one {
            let fit = eval.length(respStrain.suit!)
            if fit >= 4 && hcp >= 16 { return .contract(.three, respStrain) } // Strong raise
            if fit >= 4 && hcp >= 12 { return .contract(.two, respStrain)  } // Normal raise
            // No fit: show balanced hand in NT
            if eval.isBalanced {
                if hcp >= 18 { return .contract(.two, .notrump) }
                if hcp >= 12 { return .contract(.one, .notrump) }
            }
            // New suit (reverse) with 4+ cards
            let otherMajor: Suit = respStrain == .hearts ? .spades : .hearts
            if eval.length(otherMajor) >= 4 && hcp >= 17 {
                return .contract(.one, otherMajor.strain)
            }
            return .contract(.one, .notrump)
        }

        // Partner bid 1NT
        if respStrain == .notrump && respLevel == .one {
            if eval.isBalanced {
                if hcp >= 18 { return .contract(.two, .notrump) }
                return .pass
            }
            if hcp >= 17 { return .contract(.two, openStrain) }
            return .pass
        }

        // Partner raised minor
        if respStrain == openStrain {
            if hcp >= 19 { return .contract(.five, openStrain) }
            if hcp >= 17 { return .contract(.four, openStrain) }
            return .pass
        }

        return .pass
    }

    // MARK: - Responder Rebid

    private static func responderRebid(eval: HandEvaluation, hand: [Card], ctx: AuctionContext) -> Bid {
        let hcp = eval.hcp
        guard let partnerRebidBid = ctx.partnerLastContractBid else { return .pass }
        guard let myResp = ctx.myLastContractBid else { return .pass }

        // After Stayman sequence
        if myResp == .contract(.two, .clubs) {
            // Partner showed 2♥ or 2♠ (4-card major)
            if let level = partnerRebidBid.level, let strain = partnerRebidBid.strain,
               level == .two && strain.isMajor {
                let fit = eval.length(strain.suit!)
                if fit >= 4 && hcp >= 8  { return .contract(.four, strain) } // Game
                if fit >= 4 && hcp >= 6  { return .contract(.three, strain) } // Invite
                if hcp >= 10 { return .contract(.three, .notrump) }
                if hcp >= 8  { return .contract(.two, .notrump) }
                return .pass
            }
            // Partner denied (2♦)
            if hcp >= 10 { return .contract(.three, .notrump) }
            if hcp >= 8  { return .contract(.two, .notrump) }
            return .pass
        }

        // After Jacoby transfer to hearts accepted at 2♥
        if myResp == .contract(.two, .diamonds) {
            if hcp >= 10 { return .contract(.four, .hearts) }
            if hcp >= 8  { return .contract(.three, .hearts) }  // Invite
            return .pass // 5 hearts, weak
        }

        // After Jacoby transfer to spades accepted at 2♠
        if myResp == .contract(.two, .hearts) {
            if hcp >= 10 { return .contract(.four, .spades) }
            if hcp >= 8  { return .contract(.three, .spades) }  // Invite
            return .pass
        }

        // After Blackwood - respond to ace ask
        if ctx.iAskedForAces || ctx.partnerAskedForAces {
            return blackwoodResponse(eval: eval, hand: hand)
        }

        // General: if game not yet bid, try to reach game
        if hcp >= 12 {
            if eval.length(.spades) >= 5  { return .contract(.four, .spades)  }
            if eval.length(.hearts) >= 5  { return .contract(.four, .hearts)  }
            if eval.isBalanced            { return .contract(.three, .notrump) }
        }

        return .pass
    }

    // MARK: - Blackwood

    private static func blackwoodResponse(eval: HandEvaluation, hand: [Card]) -> Bid {
        // Count aces and respond
        let aces = hand.filter { $0.rank == .ace }.count
        switch aces {
        case 0, 4: return .contract(.five, .clubs)
        case 1:    return .contract(.five, .diamonds)
        case 2:    return .contract(.five, .hearts)
        case 3:    return .contract(.five, .spades)
        default:   return .contract(.five, .clubs)
        }
    }

    // MARK: - Competitive Bidding

    private static func competitiveBid(eval: HandEvaluation, hand: [Card], ctx: AuctionContext) -> Bid {
        let hcp = eval.hcp
        guard let highest = ctx.highestCurrentBid else {
            return openingBid(eval: eval, hand: hand, vulnerability: .neither)
        }

        // Takeout double (13+ HCP, shortage in opponent's suit, 3 other suits)
        if ctx.myBids.isEmpty {
            if let oppSuit = highest.strain?.suit, eval.length(oppSuit) <= 2 && hcp >= 12 {
                return .double
            }
        }

        // Simple overcall with good 5-card suit
        if ctx.myBids.isEmpty && hcp >= 8 {
            for suit in [Suit.spades, .hearts, .diamonds, .clubs] {
                if eval.length(suit) >= 5 {
                    let overcallBid = Bid.contract(.one, suit.strain)
                    if overcallBid.isHigherThan(highest) {
                        return overcallBid
                    }
                    let overcall2 = Bid.contract(.two, suit.strain)
                    if hcp >= 11 && overcall2.isHigherThan(highest) {
                        return overcall2
                    }
                }
            }
        }

        // Negative double (partner opened, opponent overcalled)
        if let partnerOpen = ctx.partnerLastContractBid,
           let oppOvercall = (ctx.leftOpponentBids + ctx.rightOpponentBids).last?.bid,
           ctx.myBids.isEmpty && hcp >= 7 {
            return .double
        }

        // Competitive raise of partner's suit
        if let partnerSuit = ctx.partnerLastContractBid?.strain {
            let fit = eval.length(partnerSuit.suit ?? .clubs)
            if fit >= 3 && hcp >= 6 {
                let raiseBid = Bid.contract(.three, partnerSuit)
                if raiseBid.isHigherThan(highest) {
                    return raiseBid
                }
            }
        }

        return .pass
    }

    private static func lateBid(eval: HandEvaluation, hand: [Card], ctx: AuctionContext) -> Bid {
        let hcp = eval.hcp
        // 4NT Blackwood if we have a suit agreement and enough points for slam
        if hcp >= 15, let partnerBid = ctx.partnerLastContractBid {
            if partnerBid.strain?.isMajor == true {
                let fit = eval.length(partnerBid.strain!.suit!)
                if fit >= 3 && eval.hcp >= 16 {
                    return .contract(.four, .notrump)
                }
            }
        }
        return .pass
    }

    private static func highestSafeBid(eval: HandEvaluation, above: Bid?) -> Bid {
        let above = above ?? .contract(.one, .clubs)
        for level in BidLevel.allCases {
            for strain in Strain.allCases {
                let b = Bid.contract(level, strain)
                if b.isHigherThan(above) { return b }
            }
        }
        return .pass
    }
}
