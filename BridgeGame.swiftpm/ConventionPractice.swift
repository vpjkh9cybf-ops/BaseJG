// BRIDGE APP — Built 2026-06-07
import SwiftUI

enum PracticeConvention: String, CaseIterable, Identifiable {
    case stayman           = "Stayman"
    case jacobyToHearts    = "Jacoby Transfer (→ ♥)"
    case jacobyToSpades    = "Jacoby Transfer (→ ♠)"
    case jacoby2NT         = "Jacoby 2NT"
    case weakTwo           = "Weak Two Opening"
    case twoOverOne        = "2/1 Game Force"

    var id: String { rawValue }

    var subtitle: String {
        switch self {
        case .stayman:        return "Bid 2♣ after 1NT to find a 4-card major fit (8+ HCP)"
        case .jacobyToHearts: return "Bid 2♦ after 1NT to transfer partner to hearts (5+ ♥)"
        case .jacobyToSpades: return "Bid 2♥ after 1NT to transfer partner to spades (5+ ♠)"
        case .jacoby2NT:      return "Bid 2NT after partner's 1M with 4+ fit and 13+ HCP — game force"
        case .weakTwo:        return "Open 2♥ or 2♠ with 5-10 HCP and a good 6-card suit"
        case .twoOverOne:     return "Bid a new suit at the 2-level after partner's 1M — game force (13+ HCP)"
        }
    }

    // Dealer seat that creates the right auction setup
    var dealerSeat: Seat {
        self == .weakTwo ? .south : .north
    }

    // Does North's hand set up the right opening bid?
    func northQualifies(_ north: [Card]) -> Bool {
        let e = HandEvaluator.evaluate(north)
        switch self {
        case .stayman, .jacobyToHearts, .jacobyToSpades:
            return e.hcp >= 15 && e.hcp <= 17 && e.isBalanced
        case .jacoby2NT, .twoOverOne:
            guard e.hcp >= 12 && e.hcp <= 21 else { return false }
            guard !(e.hcp >= 15 && e.hcp <= 17 && e.isBalanced) else { return false }
            guard e.hcp < 20 else { return false }
            return e.length(.spades) >= 5 || e.length(.hearts) >= 5
        case .weakTwo:
            return true  // north unimportant
        }
    }

    // The convention only actually comes up if the opponents stay out of the
    // auction — an overcall from East diverts the sequence and wastes the deal.
    func opponentsQualify(east: [Card], west: [Card]) -> Bool {
        switch self {
        case .weakTwo:
            // South is dealer, so the drill bid is made before anyone else acts.
            return true
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
        }
    }
}
