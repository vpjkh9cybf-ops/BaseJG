// BRIDGE APP — Built 2026-06-07
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

    var opponentIntervened: Bool {
        let opBids = (leftOpponentBids + rightOpponentBids)
        return opBids.contains(where: { $0.bid.isSuitBid || $0.bid == .double })
    }

    var isOpeningPosition: Bool {
        auction.allSatisfy { $0.bid == .pass }
    }

    var partnerOpenedCleanly: Bool {
        guard myBids.isEmpty,
              let _ = partnerLastContractBid,
              (leftOpponentBids + rightOpponentBids).allSatisfy({ $0.bid == .pass })
        else { return false }
        return true
    }

    var iRebidding: Bool {
        myBids.count == 1 && partnerBids.count == 1 && myBids[0].bid.isSuitBid
    }

    var partnerRebid: Bool {
        partnerBids.count == 2 && myBids.count == 1
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

struct BiddingAI {

    static func selectBid(
        hand: [Card],
        seat: Seat,
        auction: [(seat: Seat, bid: Bid)],
        vulnerability: Vulnerability,
        rkcbFlavor: RKCBFlavor = .f1430
    ) -> Bid {
        let eval = HandEvaluator.evaluate(hand)
        let ctx  = AuctionContext(seat: seat, auction: auction)

        if ctx.isOpeningPosition { return openingBid(eval: eval, hand: hand, vulnerability: vulnerability) }

        if ctx.partnerOpenedCleanly, let partnerOpen = ctx.partnerLastContractBid {
            return respond(to: partnerOpen, eval: eval, hand: hand, ctx: ctx)
        }

        if ctx.iRebidding, let myOpen = ctx.myLastContractBid, let partnerResp = ctx.partnerLastContractBid {
            return rebid(myOpen: myOpen, partnerResp: partnerResp, eval: eval, hand: hand, ctx: ctx)
        }

        if ctx.partnerRebid {
            return responderRebid(eval: eval, hand: hand, ctx: ctx, rkcbFlavor: rkcbFlavor)
        }

        // Respond to partner's RKCB ask (regardless of auction round)
        if ctx.partnerAskedForAces {
            return rkcbResponse(eval: eval, hand: hand, ctx: ctx, flavor: rkcbFlavor)
        }

        // I asked RKCB; partner just answered — place the contract
        if ctx.justReceivedBlackwoodResponse, let bwResp = ctx.partnerLastContractBid {
            return rkcbFollowup(response: bwResp, eval: eval, hand: hand, ctx: ctx, flavor: rkcbFlavor)
        }

        if ctx.opponentIntervened {
            return competitiveBid(eval: eval, hand: hand, ctx: ctx)
        }

        return lateBid(eval: eval, hand: hand, ctx: ctx)
    }

    // MARK: - Opening Bids

    private static func openingBid(eval: HandEvaluation, hand: [Card], vulnerability: Vulnerability) -> Bid {
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

    private static func preemptBid(eval: HandEvaluation, hand: [Card], vulnerability: Vulnerability) -> Bid {
        let hcp = eval.hcp
        // Weak 2s (5–10 HCP, good 6-card suit, not clubs)
        if hcp >= 5 && hcp <= 10 {
            for suit in [Suit.spades, .hearts, .diamonds] {
                if eval.length(suit) >= 6 && eval.isSolidOrSemi(suit, in: hand) {
                    return .contract(.two, suit.strain)
                }
            }
            // Allow weaker 6-card suit at lower vulnerability
            if vulnerability == .neither || vulnerability == .northSouth {
                for suit in [Suit.spades, .hearts, .diamonds] {
                    if eval.length(suit) >= 6 { return .contract(.two, suit.strain) }
                }
            }
        }
        // 3-level preempt (4–9 HCP, 7-card suit)
        if hcp >= 4 && hcp <= 9 {
            for suit in Suit.allCases.reversed() {
                if eval.length(suit) >= 7 { return .contract(.three, suit.strain) }
            }
        }
        return .pass
    }

    // MARK: - Responses

    private static func respond(to open: Bid, eval: HandEvaluation, hand: [Card], ctx: AuctionContext) -> Bid {
        guard let level = open.level, let strain = open.strain else { return .pass }

        switch (level, strain) {
        case (.one, .notrump):  return respondToOneNT(eval: eval, hand: hand)
        case (.two, .notrump):  return respondToTwoNT(eval: eval, hand: hand)
        case (.two, .clubs):    return respondToTwoClubs(eval: eval)
        case (.one, .hearts), (.one, .spades):
            return respondToOneMajor(open: open, openStrain: strain, eval: eval, hand: hand)
        case (.one, .clubs), (.one, .diamonds):
            return respondToOneMinor(open: open, openStrain: strain, eval: eval, hand: hand)
        case (.two, .hearts), (.two, .spades), (.two, .diamonds):
            return respondToWeakTwo(open: open, openStrain: strain, eval: eval)
        default:
            return .pass
        }
    }

    // Response to 1NT (15–17)
    private static func respondToOneNT(eval: HandEvaluation, hand: [Card]) -> Bid {
        let hcp = eval.hcp
        let sp = eval.length(.spades)
        let h  = eval.length(.hearts)

        // Game in long major when combined points are enough
        if sp >= 6 && hcp >= 9  { return .contract(.four, .spades)   } // Game with 6+ spades
        if h  >= 6 && hcp >= 9  { return .contract(.four, .hearts)   } // Game with 6+ hearts
        if sp >= 6              { return .contract(.two, .hearts)     } // Transfer weak 6-spader
        if h  >= 6              { return .contract(.two, .diamonds)   } // Transfer weak 6-hearter

        if hcp < 8 {
            if sp >= 5 { return .contract(.two, .hearts)   } // Jacoby transfer to spades
            if h  >= 5 { return .contract(.two, .diamonds) } // Jacoby transfer to hearts
            return .pass
        }

        // 8+ HCP
        if sp >= 5 && sp >= h { return .contract(.two, .hearts)   } // Transfer → 2♠
        if h  >= 5            { return .contract(.two, .diamonds) } // Transfer → 2♥
        if sp >= 4 || h >= 4  { return .contract(.two, .clubs)    } // Stayman
        if hcp >= 15          { return .contract(.four, .notrump)  } // Quantitative slam invite
        if hcp >= 10          { return .contract(.three, .notrump) }
        if hcp >= 8           { return .contract(.two, .notrump)   }
        return .contract(.three, .notrump)
    }

    // Response to 2NT (20–21)
    private static func respondToTwoNT(eval: HandEvaluation, hand: [Card]) -> Bid {
        let hcp = eval.hcp
        let sp = eval.length(.spades)
        let h  = eval.length(.hearts)
        if hcp == 0 && sp < 5 && h < 5 { return .pass }
        if sp >= 5 { return .contract(.three, .hearts)   } // Jacoby transfer
        if h  >= 5 { return .contract(.three, .diamonds) } // Jacoby transfer
        if sp >= 4 || h >= 4 { return .contract(.three, .clubs) } // Puppet Stayman
        if hcp >= 10 { return .contract(.six, .notrump) }
        if hcp >= 4  { return .contract(.three, .notrump) }
        return .pass
    }

    // Response to 2♣ (strong)
    private static func respondToTwoClubs(eval: HandEvaluation) -> Bid {
        let hcp = eval.hcp
        if hcp < 8 { return .contract(.two, .diamonds) } // Waiting
        if eval.length(.spades) >= 5   { return .contract(.two, .spades)      }
        if eval.length(.hearts) >= 5   { return .contract(.two, .hearts)      }
        if eval.length(.diamonds) >= 5 { return .contract(.three, .diamonds)  }
        if eval.length(.clubs) >= 5    { return .contract(.three, .clubs)     }
        return .contract(.two, .notrump) // Balanced positive
    }

    // Response to 1♥ or 1♠
    private static func respondToOneMajor(open: Bid, openStrain: Strain, eval: HandEvaluation, hand: [Card]) -> Bid {
        let hcp = eval.hcp
        let tp  = eval.totalPoints
        guard let openSuit = openStrain.suit else { return .pass }
        let fit = eval.length(openSuit)

        if hcp < 6 { return .pass }

        // Jacoby 2NT: 4+ fit, 13+ HCP, game-forcing
        if fit >= 4 && hcp >= 13 {
            return .contract(.two, .notrump)
        }

        // Splinter: 4+ fit, 10–12 HCP, singleton/void in side suit
        if fit >= 4 && hcp >= 10 && hcp <= 12 {
            let side = Suit.allCases.filter { $0 != openSuit }.sorted { eval.length($0) < eval.length($1) }
            if let short = side.first, eval.length(short) <= 1,
               let spl = splinterBid(openSuit: openSuit, singletonSuit: short) {
                return spl
            }
        }

        // Reverse Drury: 2♣ = limit raise (3+ fit, 10–11 TP)
        if fit >= 3 && tp >= 10 && tp <= 12 && hcp <= 11 {
            return .contract(.two, .clubs)
        }

        // Game raise with fit (12+ TP)
        if fit >= 3 && tp >= 13 {
            return .contract(.four, openStrain)
        }

        // Simple raise (6–9 HCP, 3+ fit)
        if fit >= 3 && hcp >= 6 {
            return .contract(.two, openStrain)
        }

        // After 1♥: show 4-card spades regardless of strength
        if openStrain == .hearts && eval.length(.spades) >= 4 {
            return .contract(.one, .spades)
        }

        // 2/1 Game Force (13+ HCP, 5-card suit, no fit)
        if hcp >= 13 {
            if openStrain == .spades {
                if eval.length(.hearts) >= 5   { return .contract(.two, .hearts)   }
                if eval.length(.clubs) >= 5    { return .contract(.two, .clubs)    }
                if eval.length(.diamonds) >= 5 { return .contract(.two, .diamonds) }
            } else { // after 1♥: spades shown above for 4+
                if eval.length(.clubs) >= 5    { return .contract(.two, .clubs)    }
                if eval.length(.diamonds) >= 5 { return .contract(.two, .diamonds) }
                // 5+ spades: can't bid 1♠ (already past it), use game force 2♠
                if eval.length(.spades) >= 5   { return .contract(.two, .spades)   }
            }
            if eval.isBalanced { return .contract(.three, .notrump) }
            // Semi-balanced game force: rebid as 2NT (Jacoby-like)
            return .contract(.two, .notrump)
        }

        // 1NT (6–12 HCP, semi-forcing — no fit, no other bid)
        return .contract(.one, .notrump)
    }

    // Response to 1♣ or 1♦
    private static func respondToOneMinor(open: Bid, openStrain: Strain, eval: HandEvaluation, hand: [Card]) -> Bid {
        let hcp = eval.hcp
        if hcp < 6 { return .pass }

        // Majors first
        if eval.length(.spades) >= 4 { return .contract(.one, .spades) }
        if eval.length(.hearts) >= 4 { return .contract(.one, .hearts) }

        let openSuit = openStrain.suit!

        // NT responses (balanced, no 4-card major)
        if hcp >= 13 && hcp <= 15 && eval.isBalanced { return .contract(.three, .notrump) }
        if hcp >= 10 && hcp <= 12 && eval.isBalanced { return .contract(.two, .notrump)   }
        if hcp >= 6  && hcp <= 9  && eval.isBalanced { return .contract(.one, .notrump)   }

        // Minor raises — check HIGHER level first
        if eval.length(openSuit) >= 5 && hcp >= 13 { return .contract(.three, openStrain) }
        if eval.length(openSuit) >= 5               { return .contract(.two, openStrain)   }

        // Show other minor
        let otherMinor: Strain = (openStrain == .clubs) ? .diamonds : .clubs
        if eval.length(otherMinor.suit!) >= 4 && hcp >= 10 { return .contract(.two, otherMinor) }

        return .contract(.one, .notrump)
    }

    private static func respondToWeakTwo(open: Bid, openStrain: Strain, eval: HandEvaluation) -> Bid {
        let hcp = eval.hcp
        guard let openSuit = openStrain.suit else { return .pass }
        let fit = eval.length(openSuit)

        if hcp >= 14 && fit >= 3 { return .contract(.four, openStrain) }
        if hcp >= 12 && fit >= 3 { return .contract(.three, openStrain) }
        if hcp < 12  && fit >= 3 { return .contract(.three, openStrain) } // Preemptive raise
        if hcp >= 14 {
            for suit in [Suit.spades, .hearts, .diamonds, .clubs] {
                if eval.length(suit) >= 5 && suit != openSuit {
                    return .contract(.three, suit.strain)
                }
            }
            return .contract(.two, .notrump) // Ogust enquiry
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
        guard let openStrain = myOpen.strain else { return .pass }

        if openStrain == .notrump && myOpen.level == .one {
            return rebidAfterOneNT(partnerResp: partnerResp, eval: eval, hand: hand)
        }
        if openStrain == .clubs && myOpen.level == .two {
            return rebidAfterTwoClubs(partnerResp: partnerResp, eval: eval, hand: hand)
        }
        if openStrain.isMajor {
            return rebidAfterMajorOpen(openStrain: openStrain, partnerResp: partnerResp,
                                       eval: eval, hand: hand, ctx: ctx)
        }
        return rebidAfterMinorOpen(openStrain: openStrain, partnerResp: partnerResp,
                                   eval: eval, hand: hand, ctx: ctx)
    }

    private static func rebidAfterOneNT(partnerResp: Bid, eval: HandEvaluation, hand: [Card]) -> Bid {
        guard let respStrain = partnerResp.strain, let respLevel = partnerResp.level else { return .pass }

        if respLevel == .two && respStrain == .clubs {
            if eval.length(.spades) >= 4 { return .contract(.two, .spades) }
            if eval.length(.hearts) >= 4 { return .contract(.two, .hearts) }
            return .contract(.two, .diamonds)
        }
        if respLevel == .two && respStrain == .diamonds {
            return eval.hcp >= 16 && eval.length(.hearts) >= 3
                ? .contract(.three, .hearts)
                : .contract(.two, .hearts)
        }
        if respLevel == .two && respStrain == .hearts {
            return eval.hcp >= 16 && eval.length(.spades) >= 3
                ? .contract(.three, .spades)
                : .contract(.two, .spades)
        }
        if respLevel == .two && respStrain == .notrump {
            return eval.hcp >= 17 ? .contract(.three, .notrump) : .pass
        }
        if respLevel == .four && respStrain == .notrump {
            return eval.hcp >= 17 ? .contract(.six, .notrump) : .pass
        }
        return .pass
    }

    private static func rebidAfterTwoClubs(partnerResp: Bid, eval: HandEvaluation, hand: [Card]) -> Bid {
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

        // ── Support Double ────────────────────────────────────────────────────
        if ctx.opponentIntervened, respLevel == .one, respStrain != openStrain,
           let respSuit = respStrain.suit, eval.length(respSuit) == 3 {
            return .double
        }

        // ── Jacoby 2NT (4+ fit, game force) ──────────────────────────────────
        if respLevel == .two && respStrain == .notrump {
            for suit in Suit.allCases {
                if suit != openSuit && eval.length(suit) <= 1 && hcp >= 15 {
                    return .contract(.three, suit.strain)
                }
            }
            if eval.length(openSuit) >= 6 && hcp >= 14 { return .contract(.three, openStrain) }
            return .contract(.four, openStrain)
        }

        // ── Simple raise ──────────────────────────────────────────────────────
        if respStrain == openStrain {
            if hcp >= 17 { return .contract(.four, openStrain) }
            if hcp >= 15 { return .contract(.three, openStrain) }
            return .pass
        }

        // ── 1NT response (6–11 HCP) ───────────────────────────────────────────
        if respLevel == .one && respStrain == .notrump {
            if hcp >= 19 { return .contract(.three, openStrain) }     // Strong jump
            if hcp >= 17 { return .contract(.two, openStrain) }       // Extra values
            // 15–16: show second suit or rebid 6-card major
            if hcp >= 15 || eval.length(openSuit) >= 6 {
                if eval.length(openSuit) >= 6 { return .contract(.two, openStrain) }
                // Show 4-card lower suit (non-reverse)
                let lowers: [Suit] = openStrain == .spades
                    ? [.diamonds, .clubs]
                    : [.diamonds, .clubs]
                for suit in lowers {
                    if eval.length(suit) >= 4 { return .contract(.two, suit.strain) }
                }
                return .contract(.two, openStrain)
            }
            // 12–14: rebid 6-card suit, or show 4-card suit, or pass
            if eval.length(openSuit) >= 6 { return .contract(.two, openStrain) }
            let lowers2: [Suit] = openStrain == .spades
                ? [.hearts, .diamonds, .clubs]
                : [.diamonds, .clubs]
            for suit in lowers2 {
                if eval.length(suit) >= 4 { return .contract(.two, suit.strain) }
            }
            return .pass
        }

        // ── Reverse Drury: 2♣ = limit raise ──────────────────────────────────
        if respLevel == .two && respStrain == .clubs {
            if hcp >= 16 { return .contract(.four, openStrain)  }
            if hcp >= 14 { return .contract(.two, openStrain)   }
            return .contract(.two, .diamonds)                     // Minimum: responder signs off
        }

        // ── 2/1 game-force response ───────────────────────────────────────────
        if respLevel == .two {
            let fit2 = (respStrain.suit.map { eval.length($0) } ?? 0)
            if fit2 >= 4 { return .contract(.three, respStrain) }
            if hcp >= 15 || eval.length(openSuit) >= 6 { return .contract(.two, openStrain) }
            if eval.isBalanced { return .contract(.two, .notrump) }
            return .contract(.two, openStrain)
        }

        // ── 1♠ over 1♥ ───────────────────────────────────────────────────────
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

    private static func rebidAfterMinorOpen(
        openStrain: Strain,
        partnerResp: Bid,
        eval: HandEvaluation,
        hand: [Card],
        ctx: AuctionContext
    ) -> Bid {
        guard let respStrain = partnerResp.strain, let respLevel = partnerResp.level else { return .pass }
        let hcp = eval.hcp
        let openSuit = openStrain.suit!

        // ── Partner bid a major at 1-level ───────────────────────────────────
        if respStrain.isMajor && respLevel == .one {
            let respSuit = respStrain.suit!
            let fit = eval.length(respSuit)
            if fit >= 4 && hcp >= 17 { return .contract(.three, respStrain) }
            if fit >= 4 && hcp >= 12 { return .contract(.two,   respStrain) }
            if fit >= 4              { return .contract(.two,   respStrain) } // minimum raise
            // No fit: show balanced range in NT or show second suit
            if eval.isBalanced {
                if hcp >= 18 { return .contract(.three, .notrump) }
                if hcp >= 15 { return .contract(.two,   .notrump) }
                return .contract(.one, .notrump)
            }
            // Reverse: show other major if strong enough (e.g., 1♣-1♥-1♠ shows 4+♠, 17+)
            let otherMajor: Suit = (respSuit == .hearts) ? .spades : .hearts
            if eval.length(otherMajor) >= 4 && hcp >= 17 {
                return .contract(.one, otherMajor.strain)
            }
            // Rebid own minor
            if eval.length(openSuit) >= 5 && hcp >= 15 { return .contract(.two, openStrain) }
            return .contract(.one, .notrump)
        }

        // ── Partner bid 1NT ───────────────────────────────────────────────────
        if respStrain == .notrump && respLevel == .one {
            if eval.isBalanced {
                if hcp >= 18 { return .contract(.three, .notrump) }
                if hcp >= 15 { return .contract(.two,   .notrump) }
                return .pass
            }
            // Unbalanced: rebid suit or show second suit
            if eval.length(openSuit) >= 6 { return .contract(.two, openStrain) }
            if hcp >= 17                  { return .contract(.two, openStrain) }
            return .pass
        }

        // ── Partner raised minor ──────────────────────────────────────────────
        if respStrain == openStrain {
            if hcp >= 19 { return .contract(.five, openStrain) }
            if hcp >= 17 { return .contract(.four, openStrain) }
            if hcp >= 14 { return .contract(.three, openStrain) }
            return .pass
        }

        // ── Partner bid 2NT (10–12 balanced) ─────────────────────────────────
        if respStrain == .notrump && respLevel == .two {
            if hcp >= 15 { return .contract(.three, .notrump) }
            return .pass
        }

        // ── Partner bid 3NT (13–15 balanced) ─────────────────────────────────
        if respStrain == .notrump && respLevel == .three {
            if hcp >= 16 { return .contract(.six, .notrump) }
            return .pass
        }

        return .pass
    }

    // MARK: - Responder Rebid

    private static func responderRebid(eval: HandEvaluation, hand: [Card], ctx: AuctionContext, rkcbFlavor: RKCBFlavor) -> Bid {
        let hcp = eval.hcp
        guard let partnerRebidBid = ctx.partnerLastContractBid else { return .pass }
        guard let myResp = ctx.myLastContractBid else { return .pass }
        let partnerFirstBid = ctx.partnerFirstContractBid

        // ── After RKCB ────────────────────────────────────────────────────────
        if ctx.partnerAskedForAces { return rkcbResponse(eval: eval, hand: hand, ctx: ctx, flavor: rkcbFlavor) }
        if ctx.iAskedForAces       { return rkcbFollowup(response: partnerRebidBid, eval: eval, hand: hand, ctx: ctx, flavor: rkcbFlavor) }

        // ── After Drury 2♣ (partner opened 1M, I bid 2♣ = limit raise) ───────
        if myResp == .contract(.two, .clubs) {
            let isDrury = partnerFirstBid?.strain?.isMajor == true && partnerFirstBid?.level == .one

            if isDrury {
                guard let openMajor = partnerFirstBid?.strain else { return .pass }
                if let level = partnerRebidBid.level, let strain = partnerRebidBid.strain {
                    if level == .two && strain == .diamonds {
                        return .contract(.two, openMajor) // Sign off: opener showed minimum
                    }
                    if level == .two && strain.isMajor   { return .contract(.four, strain) }
                    if level == .four                    { return .pass }
                }
                return .pass
            }

            // Stayman: partner showed major
            if let level = partnerRebidBid.level, let strain = partnerRebidBid.strain,
               level == .two && strain.isMajor {
                let fit = eval.length(strain.suit!)
                if fit >= 4 && hcp >= 8  { return .contract(.four, strain) }
                if fit >= 4              { return .contract(.three, strain) }
                if hcp >= 10             { return .contract(.three, .notrump) }
                if hcp >= 8              { return .contract(.two,   .notrump) }
                return .pass
            }
            // Partner denied major (2♦)
            if hcp >= 10 { return .contract(.three, .notrump) }
            if hcp >= 8  { return .contract(.two,   .notrump) }
            return .pass
        }

        // ── After Jacoby transfer to hearts (I bid 2♦) ───────────────────────
        if myResp == .contract(.two, .diamonds) {
            // Partner super-accepted (3♥)
            if partnerRebidBid == .contract(.three, .hearts) {
                return hcp >= 8 ? .contract(.four, .hearts) : .pass
            }
            if hcp >= 10 { return .contract(.four, .hearts)  }
            if hcp >= 8  { return .contract(.three, .hearts) }
            return .pass
        }

        // ── After Jacoby transfer to spades (I bid 2♥) ───────────────────────
        if myResp == .contract(.two, .hearts) {
            if partnerRebidBid == .contract(.three, .spades) {
                return hcp >= 8 ? .contract(.four, .spades) : .pass
            }
            if hcp >= 10 { return .contract(.four, .spades)  }
            if hcp >= 8  { return .contract(.three, .spades) }
            return .pass
        }

        // ── After 2/1 game force (my first bid was at 2-level) ───────────────
        if let myLevel = myResp.level, myLevel == .two, let mySuit = myResp.strain?.suit {
            let prLevel = partnerRebidBid.level
            let prStrain = partnerRebidBid.strain

            // Partner raised my 2/1 suit
            if prStrain == myResp.strain {
                if eval.length(mySuit) >= 5 {
                    let game4 = Bid.contract(.four, myResp.strain!)
                    return game4
                }
                return .contract(.three, .notrump)
            }
            // Partner rebid own major at 3-level
            if prStrain?.isMajor == true, let prSuit = prStrain?.suit, let prLvl = prLevel,
               prLvl == .three {
                if eval.length(prSuit) >= 3 { return .contract(.four, prStrain!) }
                if eval.length(mySuit) >= 5 { return .contract(.four, myResp.strain!) }
                return .contract(.three, .notrump)
            }
            // Partner bid 2NT (balanced minimum after 2/1)
            if prStrain == .notrump && prLevel == .two {
                if eval.length(mySuit) >= 6 { return .contract(.four, myResp.strain!) }
                return .contract(.three, .notrump)
            }
            // Generic: drive to game
            if hcp >= 13 {
                if eval.length(mySuit) >= 5 {
                    let game4 = Bid.contract(.four, myResp.strain!)
                    if game4.isHigherThan(partnerRebidBid) { return game4 }
                }
                return .contract(.three, .notrump)
            }
        }

        // ── After simple raise of my major (partner opened 1M, I raised 2M) ──
        if let partnerOpenMajor = partnerFirstBid?.strain, partnerOpenMajor.isMajor,
           myResp.strain == partnerOpenMajor {
            if hcp >= 10 { return .contract(.four, partnerOpenMajor) }
            return .pass
        }

        // ── General late-game push ────────────────────────────────────────────
        if hcp >= 12 {
            if eval.length(.spades) >= 5 { return .contract(.four, .spades) }
            if eval.length(.hearts) >= 5 { return .contract(.four, .hearts) }
            if eval.isBalanced           { return .contract(.three, .notrump) }
        }

        return .pass
    }

    // MARK: - RKCB (Roman Key Card Blackwood)

    // Determine the agreed trump suit from the auction context
    private static func agreedTrumpSuit(ctx: AuctionContext) -> Suit? {
        // Prefer the most recently agreed major (both sides bid it)
        let allSuitBids = ctx.auction.filter { $0.bid.isSuitBid && $0.bid.strain != .notrump }
        let suitCounts = Dictionary(grouping: allSuitBids, by: { $0.bid.strain! })
            .mapValues { $0.count }
        // Both sides agreed on a major
        for suit in [Suit.spades, .hearts] {
            if (ctx.myBids.contains   { $0.bid.strain == suit.strain }) &&
               (ctx.partnerBids.contains { $0.bid.strain == suit.strain }) {
                return suit
            }
        }
        // Partner bid a major
        if let s = ctx.partnerBids.last(where: { $0.bid.strain?.isMajor == true })?.bid.strain?.suit { return s }
        // I bid a major
        if let s = ctx.myBids.last(where: { $0.bid.strain?.isMajor == true })?.bid.strain?.suit { return s }
        // Any suit from auction
        return allSuitBids.last?.bid.strain?.suit
    }

    // Count RKCB key cards: 4 aces + king of agreed trump suit (max 5)
    private static func keyCardCount(hand: [Card], trumpSuit: Suit?) -> Int {
        let aces = hand.filter { $0.rank == .ace }.count
        let trumpKing: Int = trumpSuit.map { suit in
            hand.contains { $0.suit == suit && $0.rank == .king } ? 1 : 0
        } ?? 0
        return min(aces + trumpKing, 5)
    }

    // Respond to partner's 4NT RKCB ask
    private static func rkcbResponse(eval: HandEvaluation, hand: [Card], ctx: AuctionContext, flavor: RKCBFlavor) -> Bid {
        let trump = agreedTrumpSuit(ctx: ctx)
        let keyCards = keyCardCount(hand: hand, trumpSuit: trump)
        let hasQueenOfTrump = trump.map { suit in
            hand.contains { $0.suit == suit && $0.rank == .queen }
        } ?? false

        switch flavor {
        case .f1430:
            switch keyCards {
            case 1, 4: return .contract(.five, .clubs)     // 1 or 4
            case 0, 3: return .contract(.five, .diamonds)  // 0 or 3
            default:   // 2 or 5
                return hasQueenOfTrump ? .contract(.five, .spades) : .contract(.five, .hearts)
            }
        case .f0314:
            switch keyCards {
            case 0, 3: return .contract(.five, .clubs)     // 0 or 3
            case 1, 4: return .contract(.five, .diamonds)  // 1 or 4
            default:   // 2 or 5
                return hasQueenOfTrump ? .contract(.five, .spades) : .contract(.five, .hearts)
            }
        }
    }

    // After I bid 4NT (RKCB) and partner responded, place the contract
    private static func rkcbFollowup(
        response: Bid,
        eval: HandEvaluation,
        hand: [Card],
        ctx: AuctionContext,
        flavor: RKCBFlavor
    ) -> Bid {
        let trump = agreedTrumpSuit(ctx: ctx)
        let myKeyCards = keyCardCount(hand: hand, trumpSuit: trump)

        // Decode partner's key card count (use the lower ambiguous value — conservative)
        let partnerKeyCards: Int = {
            switch (flavor, response) {
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
        let myHcp = eval.hcp

        let agreedStrain: Strain = trump.map { $0.strain } ?? .notrump

        // Missing 2+ key cards → sign off at the five-level
        if totalKeyCards < 4 {
            return .contract(.five, agreedStrain)
        }

        // Check for grand slam: all 5 key cards + trump queen present
        let hasQueenOfTrump = trump.map { suit in
            hand.contains { $0.suit == suit && $0.rank == .queen }
        } ?? false
        let trumpQueenAccounted = hasQueenOfTrump || hasPartnerQueenOfTrump || (totalKeyCards == 5)

        if totalKeyCards == 5 && trumpQueenAccounted && myHcp >= 13 {
            return .contract(.seven, agreedStrain)
        }

        // Small slam
        return .contract(.six, agreedStrain)
    }

    // MARK: - Competitive Bidding

    private static func competitiveBid(eval: HandEvaluation, hand: [Card], ctx: AuctionContext) -> Bid {
        let hcp = eval.hcp
        guard let highest = ctx.highestCurrentBid else {
            return openingBid(eval: eval, hand: hand, vulnerability: .neither)
        }

        // ── Negative Double ───────────────────────────────────────────────────
        // Partner opened 1-level, RHO overcalled, I haven't bid: shows unbid major(s), 6+ HCP
        if ctx.myBids.isEmpty,
           let partnerOpen = ctx.partnerLastContractBid,
           partnerOpen.level == .one,
           let partnerOpenSuit = partnerOpen.strain?.suit,
           let rhoLast = ctx.rightOpponentBids.last?.bid,
           rhoLast.isSuitBid,
           let rhoBidSuit = rhoLast.strain?.suit,
           hcp >= 6 {
            let hasUnbidMajor = [Suit.hearts, .spades].contains { suit in
                suit != partnerOpenSuit && suit != rhoBidSuit && eval.length(suit) >= 4
            }
            if hasUnbidMajor { return .double }
        }

        // ── Takeout Double ────────────────────────────────────────────────────
        if ctx.myBids.isEmpty,
           ctx.partnerBids.allSatisfy({ $0.bid == .pass }),
           let oppSuit = highest.strain?.suit,
           hcp >= 12 {
            let otherSuits = Suit.allCases.filter { $0 != oppSuit }
            let supportCount = otherSuits.filter { eval.length($0) >= 3 }.count
            let shortage = eval.length(oppSuit) <= 1
            if shortage && supportCount == 3 { return .double }
            if eval.length(oppSuit) <= 2 && supportCount == 3 && hcp >= 13 { return .double }
            if eval.length(oppSuit) <= 2 && supportCount >= 2 && hcp >= 16 { return .double }
        }

        // ── 1NT Overcall (15–18 HCP, balanced) ───────────────────────────────
        if ctx.myBids.isEmpty && hcp >= 15 && hcp <= 18 && eval.isBalanced {
            let nt1 = Bid.contract(.one, .notrump)
            if nt1.isHigherThan(highest) { return nt1 }
        }

        // ── Simple Overcall (8–16 HCP, 5-card suit) ──────────────────────────
        if ctx.myBids.isEmpty {
            for suit in [Suit.spades, .hearts, .diamonds, .clubs] {
                if eval.length(suit) >= 5 {
                    let lvl1 = Bid.contract(.one, suit.strain)
                    if lvl1.isHigherThan(highest) && hcp >= 8  { return lvl1 }
                    let lvl2 = Bid.contract(.two, suit.strain)
                    if lvl2.isHigherThan(highest) && hcp >= 11 { return lvl2 }
                }
            }
            // Preemptive jump overcall (weak hand, 6-card suit)
            if hcp >= 5 && hcp <= 10 {
                for suit in [Suit.spades, .hearts, .diamonds, .clubs] {
                    if eval.length(suit) >= 6 {
                        let jmp = Bid.contract(.two, suit.strain)
                        if jmp.isHigherThan(highest) { return jmp }
                    }
                }
            }
        }

        // ── Raise Partner's Suit ──────────────────────────────────────────────
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

    private static func lateBid(eval: HandEvaluation, hand: [Card], ctx: AuctionContext) -> Bid {
        let hcp = eval.hcp
        guard let highest = ctx.highestCurrentBid else { return .pass }

        // Blackwood if we have a major fit and slam-zone values
        if let partnerBid = ctx.partnerLastContractBid,
           partnerBid.strain?.isMajor == true,
           let suit = partnerBid.strain?.suit {
            let fit = eval.length(suit)
            if fit >= 3 && hcp >= 17 {
                let bw = Bid.contract(.four, .notrump)
                if bw.isHigherThan(highest) { return bw }
            }
            // Drive to game if fit established
            if fit >= 3 && hcp >= 10 {
                let game4M = Bid.contract(.four, partnerBid.strain!)
                if game4M.isHigherThan(highest) { return game4M }
            }
        }

        // Drive to 3NT with balanced hand and enough HCP
        if eval.isBalanced && hcp >= 13 {
            let threeNT = Bid.contract(.three, .notrump)
            if threeNT.isHigherThan(highest) { return threeNT }
        }

        // Bid own suit if strong enough
        if hcp >= 14 {
            for suit in [Suit.spades, .hearts, .diamonds, .clubs] {
                if eval.length(suit) >= 5 {
                    let b = Bid.contract(.three, suit.strain)
                    if b.isHigherThan(highest) { return b }
                }
            }
        }

        return .pass
    }

    // MARK: - Helpers

    private static func splinterBid(openSuit: Suit, singletonSuit: Suit) -> Bid? {
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
