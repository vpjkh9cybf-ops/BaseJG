// Conventional Wisdom — modified 2026-09-18 14:07 UTC
import SwiftUI

enum PracticeConvention: String, CaseIterable, Identifiable {
    case stayman           = "Stayman"
    case jacobyToHearts    = "Jacoby Transfer (→ ♥)"
    case jacobyToSpades    = "Jacoby Transfer (→ ♠)"
    case jacoby2NT         = "Jacoby 2NT"
    case weakTwo           = "Weak Two Opening"
    case twoOverOne        = "2/1 Game Force"
    case splinter          = "Splinter Bid"
    case negativeDouble    = "Negative Double"
    case takeoutDouble     = "Takeout Double"
    case michaelsCueBid    = "Michaels Cue Bid"
    case unusual2NT        = "Unusual 2NT"
    case invertedMinorRaise = "Inverted Minor Raise"
    case weakTwoResponse   = "Weak Two Response"

    var id: String { rawValue }

    var subtitle: String {
        switch self {
        case .stayman:        return "Bid 2♣ after 1NT to find a 4-card major fit (8+ HCP)"
        case .jacobyToHearts: return "Bid 2♦ after 1NT to transfer partner to hearts (5+ ♥)"
        case .jacobyToSpades: return "Bid 2♥ after 1NT to transfer partner to spades (5+ ♠)"
        case .jacoby2NT:      return "Bid 2NT after partner's 1M with 4+ fit and 13+ HCP — game force"
        case .weakTwo:        return "Open 2♥ or 2♠ with 5-10 HCP and a good 6-card suit"
        case .twoOverOne:     return "Bid a new suit at the 2-level after partner's 1M — game force (13+ HCP)"
        case .splinter:       return "Jump to game in a new suit after partner's 1M opening — shows 4+ support and a singleton/void (13-16 HCP)"
        case .negativeDouble: return "Double after partner's minor opening and an opposing overcall — shows the unbid major(s), 6-11 HCP"
        case .takeoutDouble:  return "Double an opening bid with 12-16 HCP, short in their suit, 3+ support for the other three"
        case .michaelsCueBid: return "Cue-bid the opponent's minor opening with 5-5 in the majors (6-11 HCP)"
        case .unusual2NT:     return "Bid 2NT over an opposing major opening with 5-5 in the minors (6-11 HCP) — not a notrump hand"
        case .invertedMinorRaise: return "Raise partner's 1♦ opening to 2♦ with 5+ support and 10-12 HCP — forcing under Inverted Minors"
        case .weakTwoResponse:    return "Ask with 2NT after partner's weak two — 14+ HCP with no fit, opener describes suit and strength"
        }
    }

    // Dealer seat that creates the right auction setup
    var dealerSeat: Seat {
        switch self {
        case .weakTwo, .takeoutDouble, .michaelsCueBid, .unusual2NT:
            return .east
        default:
            return .north
        }
    }

    // Does North's hand set up the right opening bid?
    func northQualifies(_ north: [Card]) -> Bool {
        let e = HandEvaluator.evaluate(north)
        switch self {
        case .stayman, .jacobyToHearts, .jacobyToSpades:
            return e.hcp >= 15 && e.hcp <= 17 && e.isBalanced
        case .jacoby2NT, .twoOverOne, .splinter:
            guard e.hcp >= 12 && e.hcp <= 21 else { return false }
            guard !(e.hcp >= 15 && e.hcp <= 17 && e.isBalanced) else { return false }
            guard e.hcp < 20 else { return false }
            return e.length(.spades) >= 5 || e.length(.hearts) >= 5
        case .weakTwo, .takeoutDouble, .michaelsCueBid, .unusual2NT:
            return true  // north hasn't acted yet at the drill's critical moment
        case .negativeDouble:
            // North must open a minor so at least one major is left unbid.
            guard e.hcp >= 12 && e.hcp <= 19 else { return false }
            if e.hcp >= 15 && e.hcp <= 17 && e.isBalanced { return false }
            return e.length(.spades) < 5 && e.length(.hearts) < 5
        case .invertedMinorRaise:
            // Force a 1♦ opening specifically, so South's shape is deterministic.
            guard e.hcp >= 12 && e.hcp <= 19 else { return false }
            if e.hcp >= 15 && e.hcp <= 17 && e.isBalanced { return false }
            guard e.length(.spades) < 5 && e.length(.hearts) < 5 else { return false }
            return e.length(.diamonds) > e.length(.clubs)
        case .weakTwoResponse:
            return (e.hcp >= 6 && e.hcp <= 10) &&
                   (e.length(.hearts) >= 6 || e.length(.spades) >= 6)
        }
    }

    // The convention only actually comes up if the opponents' hands produce
    // the auction this drill needs — either staying quiet, or (for the
    // opponent-driven drills) actually making the specific opening bid the
    // drill is built around.
    func opponentsQualify(east: [Card], west: [Card]) -> Bool {
        switch self {
        case .weakTwo:
            // South is dealer, so the drill bid is made before anyone else acts.
            return true

        case .takeoutDouble:
            // East (dealer) must open a natural 1♦ — forced by shape so South's
            // takeout shape can be fixed in advance.
            let ee = HandEvaluator.evaluate(east)
            guard ee.hcp >= 12 && ee.hcp <= 19 else { return false }
            if ee.hcp >= 15 && ee.hcp <= 17 && ee.isBalanced { return false }
            guard ee.length(.spades) < 5 && ee.length(.hearts) < 5 else { return false }
            return ee.length(.diamonds) > ee.length(.clubs)

        case .michaelsCueBid:
            // East (dealer) must open a natural 1♣, forced the same way.
            let ee = HandEvaluator.evaluate(east)
            guard ee.hcp >= 12 && ee.hcp <= 19 else { return false }
            if ee.hcp >= 15 && ee.hcp <= 17 && ee.isBalanced { return false }
            guard ee.length(.spades) < 5 && ee.length(.hearts) < 5 else { return false }
            return ee.length(.clubs) > ee.length(.diamonds)

        case .unusual2NT:
            // East (dealer) must open a natural 1♠.
            let ee = HandEvaluator.evaluate(east)
            guard ee.hcp >= 12 && ee.hcp <= 19 else { return false }
            if ee.hcp >= 15 && ee.hcp <= 17 && ee.isBalanced { return false }
            return ee.length(.spades) >= 5 && ee.length(.spades) >= ee.length(.hearts)

        case .negativeDouble:
            // East must hold a real overcall — a decent 5+ card suit to act on.
            let ee = HandEvaluator.evaluate(east)
            guard ee.hcp >= 10 && ee.hcp <= 17 else { return false }
            return Suit.allCases.contains { ee.length($0) >= 5 }

        default:
            let ee = HandEvaluator.evaluate(east)
            guard ee.hcp <= 11 else { return false }
            // Values plus a long suit is an overcall waiting to happen.
            if ee.hcp >= 8 && Suit.allCases.contains(where: { ee.length($0) >= 6 }) {
                return false
            }
            return true
        }
    }

    // Does South's hand qualify to use the convention given North's hand?
    func southQualifies(_ south: [Card], north: [Card]) -> Bool {
        let se = HandEvaluator.evaluate(south)
        let ne = HandEvaluator.evaluate(north)
        switch self {
        case .stayman:
            return se.hcp >= 8 && (se.length(.spades) >= 4 || se.length(.hearts) >= 4)
        case .jacobyToHearts:
            return se.length(.hearts) >= 5
        case .jacobyToSpades:
            return se.length(.spades) >= 5
        case .jacoby2NT:
            let northMajor: Suit = ne.length(.spades) >= 5 ? .spades : .hearts
            return se.length(northMajor) >= 4 && se.hcp >= 13
        case .weakTwo:
            return (se.hcp >= 5 && se.hcp <= 10) &&
                   (se.length(.hearts) >= 6 || se.length(.spades) >= 6)
        case .twoOverOne:
            let northMajor: Suit = ne.length(.spades) >= 5 ? .spades : .hearts
            let fit = se.length(northMajor)
            let hasFiveSuit = se.length(.clubs) >= 5 || se.length(.diamonds) >= 5 ||
                              (northMajor != .hearts && se.length(.hearts) >= 5)
            return fit < 4 && se.hcp >= 13 && hasFiveSuit
        case .splinter:
            let northMajor: Suit = ne.length(.spades) >= 5 ? .spades : .hearts
            guard se.length(northMajor) >= 4 else { return false }
            guard se.hcp >= 13 && se.hcp <= 16 else { return false }
            let shortSuits = Suit.allCases.filter { $0 != northMajor && se.length($0) <= 1 }
            return !shortSuits.isEmpty
        case .negativeDouble:
            return se.hcp >= 6 && se.hcp <= 11 &&
                   se.length(.spades) >= 4 && se.length(.hearts) >= 4
        case .takeoutDouble:
            return se.hcp >= 12 && se.hcp <= 16 &&
                   se.length(.diamonds) <= 2 &&
                   se.length(.clubs) >= 3 && se.length(.hearts) >= 3 && se.length(.spades) >= 3
        case .michaelsCueBid:
            return se.hcp >= 6 && se.hcp <= 11 &&
                   se.length(.spades) >= 5 && se.length(.hearts) >= 5
        case .unusual2NT:
            return se.hcp >= 6 && se.hcp <= 11 &&
                   se.length(.clubs) >= 5 && se.length(.diamonds) >= 5
        case .invertedMinorRaise:
            return se.hcp >= 10 && se.hcp <= 12 && se.length(.diamonds) >= 5
        case .weakTwoResponse:
            let northMajor: Suit = ne.length(.spades) >= 6 ? .spades : .hearts
            guard se.length(northMajor) < 3 else { return false }   // no fit — forces the ask, not a raise
            guard se.hcp >= 14 && se.hcp <= 17 else { return false }
            let noNaturalSuit = Suit.allCases.allSatisfy { $0 == northMajor || se.length($0) < 5 }
            return noNaturalSuit
        }
    }

    // The bid South MUST make at the critical moment.
    // Returns nil if we are not yet at the critical decision point.
    func expectedBid(auction: [AuctionEntry], southHand: [Card]) -> Bid? {
        let se = HandEvaluator.evaluate(southHand)

        switch self {
        // ── 1NT opening sequences ─────────────────────────────────────────────
        case .stayman, .jacobyToHearts, .jacobyToSpades:
            guard auction.count == 2,
                  auction[0].seat == .north,
                  auction[0].bid  == .contract(.one, .notrump),
                  auction[1].seat == .east,
                  auction[1].bid  == .pass else { return nil }
            switch self {
            case .stayman:        return .contract(.two, .clubs)
            case .jacobyToHearts: return .contract(.two, .diamonds)
            case .jacobyToSpades: return .contract(.two, .hearts)
            default: return nil
            }

        // ── Jacoby 2NT ────────────────────────────────────────────────────────
        case .jacoby2NT:
            guard auction.count == 2,
                  auction[0].seat == .north,
                  auction[0].bid.level == .one,
                  auction[0].bid.strain?.isMajor == true,
                  auction[1].seat == .east,
                  auction[1].bid  == .pass,
                  let openSuit = auction[0].bid.strain?.suit,
                  se.length(openSuit) >= 4,
                  se.hcp >= 13 else { return nil }
            return .contract(.two, .notrump)

        // ── Weak Two Opening ──────────────────────────────────────────────────
        case .weakTwo:
            // South is dealer; critical moment is when auction is empty
            guard auction.isEmpty else { return nil }
            if se.length(.spades) >= 6 && se.hcp >= 5 && se.hcp <= 10 { return .contract(.two, .spades) }
            if se.length(.hearts) >= 6 && se.hcp >= 5 && se.hcp <= 10 { return .contract(.two, .hearts) }
            return nil

        // ── 2/1 Game Force ────────────────────────────────────────────────────
        case .twoOverOne:
            guard auction.count == 2,
                  auction[0].seat == .north,
                  auction[0].bid.level == .one,
                  auction[0].bid.strain?.isMajor == true,
                  auction[1].seat == .east,
                  auction[1].bid  == .pass,
                  let openSuit = auction[0].bid.strain?.suit,
                  se.length(openSuit) < 4,
                  se.hcp >= 13 else { return nil }
            if se.length(.hearts) >= 5 && openSuit != .hearts { return .contract(.two, .hearts) }
            if se.length(.clubs)  >= 5                        { return .contract(.two, .clubs)  }
            if se.length(.diamonds) >= 5                      { return .contract(.two, .diamonds) }
            return nil

        // ── Splinter Bid ─────────────────────────────────────────────────────
        case .splinter:
            guard auction.count == 2,
                  auction[0].seat == .north,
                  auction[0].bid.level == .one,
                  auction[0].bid.strain?.isMajor == true,
                  auction[1].seat == .east,
                  auction[1].bid  == .pass,
                  let openSuit = auction[0].bid.strain?.suit,
                  se.length(openSuit) >= 4,
                  se.hcp >= 13 && se.hcp <= 16 else { return nil }
            let shortSuits = Suit.allCases.filter { $0 != openSuit && se.length($0) <= 1 }
            guard let shortSuit = shortSuits.first else { return nil }
            switch (openSuit, shortSuit) {
            case (.hearts, .spades):   return .contract(.three, .spades)
            case (.hearts, .clubs):    return .contract(.four, .clubs)
            case (.hearts, .diamonds): return .contract(.four, .diamonds)
            case (.spades, .hearts):   return .contract(.four, .hearts)
            case (.spades, .clubs):    return .contract(.four, .clubs)
            case (.spades, .diamonds): return .contract(.four, .diamonds)
            default: return nil
            }

        // ── Negative Double ───────────────────────────────────────────────────
        case .negativeDouble:
            guard auction.count == 2,
                  auction[0].seat == .north,
                  auction[0].bid.level == .one,
                  auction[0].bid.strain?.isMinor == true,
                  auction[1].seat == .east,
                  auction[1].bid.isSuitBid,
                  se.hcp >= 6 && se.hcp <= 11,
                  se.length(.spades) >= 4, se.length(.hearts) >= 4 else { return nil }
            return .double

        // ── Takeout Double ───────────────────────────────────────────────────
        case .takeoutDouble:
            guard auction.count == 1,
                  auction[0].seat == .east,
                  auction[0].bid  == .contract(.one, .diamonds),
                  se.hcp >= 12 && se.hcp <= 16,
                  se.length(.diamonds) <= 2,
                  se.length(.clubs) >= 3, se.length(.hearts) >= 3, se.length(.spades) >= 3
            else { return nil }
            return .double

        // ── Michaels Cue Bid ─────────────────────────────────────────────────
        case .michaelsCueBid:
            guard auction.count == 1,
                  auction[0].seat == .east,
                  auction[0].bid  == .contract(.one, .clubs),
                  se.hcp >= 6 && se.hcp <= 11,
                  se.length(.spades) >= 5, se.length(.hearts) >= 5
            else { return nil }
            return .contract(.two, .clubs)

        // ── Unusual 2NT ───────────────────────────────────────────────────────
        case .unusual2NT:
            guard auction.count == 1,
                  auction[0].seat == .east,
                  auction[0].bid  == .contract(.one, .spades),
                  se.hcp >= 6 && se.hcp <= 11,
                  se.length(.clubs) >= 5, se.length(.diamonds) >= 5
            else { return nil }
            return .contract(.two, .notrump)

        // ── Inverted Minor Raise ─────────────────────────────────────────────
        case .invertedMinorRaise:
            guard auction.count == 2,
                  auction[0].seat == .north,
                  auction[0].bid  == .contract(.one, .diamonds),
                  auction[1].seat == .east,
                  auction[1].bid  == .pass,
                  se.hcp >= 10 && se.hcp <= 12,
                  se.length(.diamonds) >= 5
            else { return nil }
            return .contract(.two, .diamonds)

        // ── Weak Two Response (Ogust / Feature) ─────────────────────────────
        case .weakTwoResponse:
            guard auction.count == 2,
                  auction[0].seat == .north,
                  auction[0].bid.level == .two,
                  auction[0].bid.strain?.isMajor == true,
                  auction[1].seat == .east,
                  auction[1].bid  == .pass,
                  let northSuit = auction[0].bid.strain?.suit,
                  se.length(northSuit) < 3,
                  se.hcp >= 14 && se.hcp <= 17,
                  Suit.allCases.allSatisfy({ $0 == northSuit || se.length($0) < 5 })
            else { return nil }
            return .contract(.two, .notrump)
        }
    }

    // Explanation shown when South bids incorrectly at the critical moment
    func correctionText(expected: Bid, southHand: [Card], auction: [AuctionEntry]) -> String {
        let se = HandEvaluator.evaluate(southHand)
        switch self {
        case .stayman:
            let majors = [Suit.spades, .hearts]
                .filter { se.length($0) >= 4 }
                .map { $0.name }
                .joined(separator: " and ")
            return "Bid 2♣ (Stayman) with \(se.hcp) HCP and 4-card \(majors). Stayman asks partner to name a 4-card major so you can find an 8-card fit."

        case .jacobyToHearts:
            return "Bid 2♦ (Jacoby Transfer → ♥) with \(se.length(.hearts)) hearts. Partner will bid 2♥, placing the strong hand as declarer and keeping your hand hidden."

        case .jacobyToSpades:
            return "Bid 2♥ (Jacoby Transfer → ♠) with \(se.length(.spades)) spades. Partner will bid 2♠, then you describe your hand (pass, invite, or bid game)."

        case .jacoby2NT:
            let major = auction.first?.bid.strain?.display ?? "major"
            return "Bid 2NT (Jacoby 2NT) with 4-card \(major) support and \(se.hcp) HCP. It's game-forcing and asks opener to describe their hand — a singleton, 6-card suit, or balanced minimum."

        case .weakTwo:
            let suit: Suit = se.length(.spades) >= 6 ? .spades : .hearts
            return "Open 2\(suit.symbol) with \(se.length(suit)) \(suit.name.lowercased()) and \(se.hcp) HCP. A weak two preempts opponents, shows your long suit, and helps partner judge the auction."

        case .twoOverOne:
            return "Bid \(expected.display) (2/1 Game Force). With \(se.hcp) HCP and no 4-card fit in partner's major, bidding a new suit at the 2-level is game-forcing. It promises 13+ HCP and 5+ cards in the bid suit."

        case .splinter:
            let major = auction.first?.bid.strain?.display ?? "major"
            return "Bid \(expected.display) (Splinter) with 4+ \(major) support, \(se.hcp) HCP, and a singleton/void outside trumps. A splinter jumps to game showing shortness, so partner can judge slam chances from how well their high cards work with your shortage."

        case .negativeDouble:
            let rhoSuit = auction.count > 1 ? (auction[1].bid.strain?.display ?? "their suit") : "their suit"
            return "Double (Negative) with \(se.hcp) HCP and 4+ cards in both majors. After partner opens a minor and RHO overcalls \(rhoSuit), a double shows the unbid major(s) without enough to bid a new suit at the 2-level."

        case .takeoutDouble:
            return "Double (Takeout) with \(se.hcp) HCP, only \(se.length(.diamonds)) diamond(s), and 3+ cards in each other suit. A takeout double asks partner to bid their best suit rather than showing a diamond stack of your own."

        case .michaelsCueBid:
            return "Bid 2♣ (Michaels Cue Bid) with 5-5 in the majors and \(se.hcp) HCP. Cueing the opponent's suit shows both majors in one bid, so partner can pick the fit at a low level."

        case .unusual2NT:
            return "Bid 2NT (Unusual NT) with 5-5 in the minors and \(se.hcp) HCP. 2NT here doesn't show notrump values — it shows the two lowest unbid suits, clubs and diamonds, in one bid."

        case .invertedMinorRaise:
            return "Bid 2♦ (Inverted Minor Raise) with \(se.length(.diamonds)) diamonds and \(se.hcp) HCP. Playing Inverted Minors, the single raise shows 10+ points and is forcing — it describes a hand too good for a direct preemptive raise."

        case .weakTwoResponse:
            return "Bid 2NT with \(se.hcp) HCP and no fit for partner's weak two. 2NT here is the ask, not a notrump hand — it asks opener to describe their hand (suit quality and overall strength, or an outside feature, per your agreement)."
        }
    }

    // Short hint shown to South at the critical decision point
    func hintText(southHand: [Card], auction: [AuctionEntry]) -> String {
        switch self {
        case .stayman:        return "💡 You have a 4-card major — consider Stayman (2♣)"
        case .jacobyToHearts: return "💡 Use Jacoby Transfer: bid 2♦ to show 5+ hearts"
        case .jacobyToSpades: return "💡 Use Jacoby Transfer: bid 2♥ to show 5+ spades"
        case .jacoby2NT:
            let major = auction.first?.bid.strain?.display ?? "partner's major"
            return "💡 You have 4+ \(major) and 13+ HCP — try Jacoby 2NT"
        case .weakTwo:        return "💡 Consider opening a Weak Two with your 6-card suit"
        case .twoOverOne:     return "💡 With 13+ HCP and no fit, bid your suit at the 2-level (2/1 Game Force)"
        case .splinter:       return "💡 4+ card support, a singleton/void, and game-going values — consider a Splinter"
        case .negativeDouble: return "💡 You have both majors and opening-range values — consider a Negative Double"
        case .takeoutDouble:  return "💡 Short in their suit with support for the other three and opening values — consider a Takeout Double"
        case .michaelsCueBid: return "💡 5-5 in the majors after their minor opening — consider a Michaels Cue Bid"
        case .unusual2NT:     return "💡 5-5 in the minors after their major opening — consider the Unusual 2NT"
        case .invertedMinorRaise: return "💡 5+ card support and 10+ HCP — with Inverted Minors, raise to 2 of partner's minor (forcing)"
        case .weakTwoResponse:    return "💡 14+ HCP with no fit — 2NT asks opener to describe the weak two further"
        }
    }
}
