// BRIDGE APP — Built 2026-06-07
import Foundation

// MARK: - Analysis result

struct BidAnalysis {
    let recommendedBid: Bid
    let convention: String
    let rationale: String           // one sentence shown in the banner
    let detailedExplanation: String // 2-4 sentences shown when "Why?" expanded
    let isForcingPass: Bool         // true if human passed a game-forcing auction
}

// MARK: - Coach

enum ConventionCoach {

    // Main entry: call BEFORE appending the chosen bid to the auction.
    // auction = the bids so far (not including chosenBid).
    static func analyze(
        hand: [Card],
        chosenBid: Bid,
        auction: [AuctionEntry],
        settings: ConventionSettings
    ) -> BidAnalysis? {

        // 1. Forcing-pass check — highest priority
        if chosenBid == .pass, let w = checkForcingPass(auction: auction) { return w }

        let eval = HandEvaluator.evaluate(hand)

        // 2. Convention checks (only when human is in the right seat / context)
        if settings.staymanEnabled,
           let w = checkStayman(eval: eval, chosenBid: chosenBid, auction: auction, settings: settings) { return w }

        if settings.jacobyTransfersEnabled,
           let w = checkTransfer(eval: eval, chosenBid: chosenBid, auction: auction) { return w }

        if settings.jacoby2NTEnabled,
           let w = checkJacoby2NT(eval: eval, chosenBid: chosenBid, auction: auction, settings: settings) { return w }

        if settings.splinterEnabled,
           let w = checkSplinter(eval: eval, hand: hand, chosenBid: chosenBid, auction: auction, settings: settings) { return w }

        if settings.takeoutDoubleEnabled,
           let w = checkTakeoutDouble(eval: eval, hand: hand, chosenBid: chosenBid, auction: auction, settings: settings) { return w }

        return nil
    }

    // MARK: - Forcing pass

    // Convention: Game Force obligations
    // SAYC rule: a game-forcing auction cannot be passed below game.
    private static func checkForcingPass(auction: [AuctionEntry]) -> BidAnalysis? {
        guard !auction.isEmpty else { return nil }
        let bids = auction.map { $0.bid }

        // 2♣ opening → all bids game-forcing until 3NT / 4M
        let has2COpen = auction.first?.bid == .contract(.two, .clubs)
        if has2COpen {
            let highestLevel = bids.compactMap { $0.level?.rawValue }.max() ?? 0
            if highestLevel < 4 { // below game
                return BidAnalysis(
                    recommendedBid: .pass,
                    convention: "2\u{2663} Game Force",
                    rationale: "Passing a game-forcing auction \u{2014} the 2\u{2663} opener requires reaching at least 3NT or 4\u{2665}/4\u{2660}.",
                    detailedExplanation: "After a strong 2\u{2663} opening, the partnership is committed to game. Neither player may pass below game unless opener rebids 2NT (22-24 HCP) and responder passes, or the auction reaches 3NT/4M/5m. Continue bidding naturally.",
                    isForcingPass: true
                )
            }
        }

        // 2/1 game force: responder bid new suit at 2-level after 1M
        // Detect: 1M opener, pass, 2X response (X ≠ trump, not 2NT raise)
        if auction.count >= 2 {
            let openEntry = auction[0]
            let respEntry = auction.count > 2 ? auction[2] : nil
            if let openStrain = openEntry.bid.strain, openStrain.isMajor,
               openEntry.bid.level == .one,
               let resp = respEntry,
               let rLevel = resp.bid.level, rLevel == .two,
               let rStrain = resp.bid.strain, rStrain != openStrain, rStrain != .notrump {
                // We are now in a 2/1 GF sequence; check if still below game
                let highest = bids.compactMap { $0.level?.rawValue }.max() ?? 0
                if highest < 4 {
                    return BidAnalysis(
                        recommendedBid: .pass,
                        convention: "2/1 Game Force",
                        rationale: "The 2/1 response established a game force \u{2014} passing below game is not allowed.",
                        detailedExplanation: "A new suit at the 2-level in response to partner's 1M opening (2/1 Game Force) obligates both players to reach game. Keep bidding naturally \u{2014} describe your hand with shape and stoppers until you reach 3NT, 4\u{2665}, 4\u{2660}, or a minor-suit game.",
                        isForcingPass: true
                    )
                }
            }
        }

        return nil
    }

    // MARK: - Stayman
    // Convention: Stayman (2♣ over 1NT)
    // SAYC rule: responder with 4+ cards in a major and 8+ HCP should bid 2♣ to find a major fit.
    private static func checkStayman(
        eval: HandEvaluation,
        chosenBid: Bid,
        auction: [AuctionEntry],
        settings: ConventionSettings
    ) -> BidAnalysis? {
        // Context: partner opened 1NT cleanly (no interference)
        guard partnerOpened1NT(auction: auction) else { return nil }
        guard eval.hcp >= 8 else { return nil }
        let has4Major = eval.length(.spades) >= 4 || eval.length(.hearts) >= 4
        guard has4Major else { return nil }
        guard chosenBid != .contract(.two, .clubs) else { return nil }

        let majorStr = eval.length(.spades) >= 4 ? "\u{2660}" : "\u{2665}"
        return BidAnalysis(
            recommendedBid: .contract(.two, .clubs),
            convention: "Stayman",
            rationale: "Better: 2\u{2663} Stayman \u{2014} you hold a 4-card \(majorStr) and \(eval.hcp) HCP.",
            detailedExplanation: "Stayman (2\u{2663}) asks opener to name a 4-card major. If they respond 2\(majorStr) matching yours, you have an 8-card fit \u{2014} usually better than NT. With \(eval.hcp) HCP you have the values to invite or force game. Bid 2\u{2663}, then raise to 3\(majorStr) (invite) or 4\(majorStr) (game) based on opener's response.",
            isForcingPass: false
        )
    }

    // MARK: - Jacoby Transfer
    // Convention: Jacoby Transfer (2♦ = hearts, 2♥ = spades) over 1NT
    // SAYC rule: with 5+ cards in a major, transfer rather than bidding the suit directly.
    private static func checkTransfer(
        eval: HandEvaluation,
        chosenBid: Bid,
        auction: [AuctionEntry]
    ) -> BidAnalysis? {
        guard partnerOpened1NT(auction: auction) else { return nil }

        // Transfer to hearts
        if eval.length(.hearts) >= 5 && chosenBid != .contract(.two, .diamonds) {
            return BidAnalysis(
                recommendedBid: .contract(.two, .diamonds),
                convention: "Jacoby Transfer",
                rationale: "Better: 2\u{2666} Transfer \u{2192} \u{2665} \u{2014} you hold \(eval.length(.hearts)) hearts.",
                detailedExplanation: "Bid 2\u{2666} to transfer partner to 2\u{2665}. This keeps the strong NT hand as declarer (harder to lead against) and lets you show extra values by rebidding: pass = weak, 2NT/3\u{2665} = invite, 3NT/4\u{2665} = game. Bidding 2\u{2665} directly gives up these options.",
                isForcingPass: false
            )
        }

        // Transfer to spades
        if eval.length(.spades) >= 5 && chosenBid != .contract(.two, .hearts) {
            return BidAnalysis(
                recommendedBid: .contract(.two, .hearts),
                convention: "Jacoby Transfer",
                rationale: "Better: 2\u{2665} Transfer \u{2192} \u{2660} \u{2014} you hold \(eval.length(.spades)) spades.",
                detailedExplanation: "Bid 2\u{2665} to transfer partner to 2\u{2660}. Partner completes the transfer, then you describe your hand: pass = weak, 2NT = 5-4 invite, 3\u{2660} = invite, 4\u{2660} = game. A super-accept (bidding 3\u{2660} directly) shows extra values (17+ HCP).",
                isForcingPass: false
            )
        }

        return nil
    }

    // MARK: - Jacoby 2NT
    // Convention: Jacoby 2NT (over partner's 1M opening)
    // SAYC rule: with 4+ trump support and 13+ HCP (game force), bid 2NT to describe the hand further.
    private static func checkJacoby2NT(
        eval: HandEvaluation,
        chosenBid: Bid,
        auction: [AuctionEntry],
        settings: ConventionSettings
    ) -> BidAnalysis? {
        guard let openStrain = partnerOpenedMajorCleanly(auction: auction) else { return nil }
        guard eval.hcp >= settings.splinterMinHCP else { return nil }  // reuse splinter HCP floor
        guard let openSuit = openStrain.suit else { return nil }
        guard eval.length(openSuit) >= 4 else { return nil }
        guard chosenBid != .contract(.two, .notrump) else { return nil }
        // Don't warn if they bid a splinter (4+ support, void/singleton in new suit)
        if eval.hcp >= settings.splinterMinHCP { /* proceed */ }

        return BidAnalysis(
            recommendedBid: .contract(.two, .notrump),
            convention: "Jacoby 2NT",
            rationale: "Better: 2NT Jacoby \u{2014} 4+ \(openStrain.display) support with \(eval.hcp) HCP is a game force.",
            detailedExplanation: "Jacoby 2NT shows a game-forcing raise with 4+ trump support. Opener then describes their hand: 4M = minimum balanced, 3 of a new suit = singleton/void shortness, 4 of a new suit = 5-card side suit, 3M = extra trump length. This pinpoints slam potential.",
            isForcingPass: false
        )
    }

    // MARK: - Splinter
    // Convention: Splinter bids (jump to game in new suit showing 4+ support + shortness)
    // SAYC rule: with 4+ support, a singleton/void, and 13+ HCP, make a jump to game in short suit.
    private static func checkSplinter(
        eval: HandEvaluation,
        hand: [Card],
        chosenBid: Bid,
        auction: [AuctionEntry],
        settings: ConventionSettings
    ) -> BidAnalysis? {
        guard let openStrain = partnerOpenedMajorCleanly(auction: auction) else { return nil }
        guard eval.hcp >= settings.splinterMinHCP else { return nil }
        guard let openSuit = openStrain.suit else { return nil }
        guard eval.length(openSuit) >= 4 else { return nil }

        // Find singleton or void in a side suit
        var shortSuit: Suit? = nil
        for suit in [Suit.clubs, .diamonds, .hearts, .spades] {
            if suit != openSuit && eval.length(suit) <= 1 {
                shortSuit = suit
                break
            }
        }
        guard let short = shortSuit else { return nil }

        // Determine the splinter bid
        let splinterBid: Bid
        if openSuit == .hearts {
            // Splinters over 1♥: 3♠, 4♣, 4♦
            switch short {
            case .spades:   splinterBid = .contract(.three, .spades)
            case .clubs:    splinterBid = .contract(.four, .clubs)
            case .diamonds: splinterBid = .contract(.four, .diamonds)
            default: return nil
            }
        } else { // openSuit == .spades
            // Splinters over 1♠: 4♥, 4♣, 4♦
            switch short {
            case .hearts:   splinterBid = .contract(.four, .hearts)
            case .clubs:    splinterBid = .contract(.four, .clubs)
            case .diamonds: splinterBid = .contract(.four, .diamonds)
            default: return nil
            }
        }

        // Only warn if they didn't already bid the splinter or Jacoby 2NT
        guard chosenBid != splinterBid && chosenBid != .contract(.two, .notrump) else { return nil }

        let voidOrSingleton = eval.length(short) == 0 ? "void" : "singleton"
        return BidAnalysis(
            recommendedBid: splinterBid,
            convention: "Splinter",
            rationale: "Better: \(splinterBid.display) Splinter \u{2014} shows 4+ \(openSuit.symbol) and a \(voidOrSingleton) in \(short.symbol).",
            detailedExplanation: "A splinter (jump to game in a new suit) shows 4+ card trump support, a singleton or void in the bid suit, and \(settings.splinterMinHCP)+ HCP \u{2014} a game force with slam interest. Partner can evaluate: good controls in your short suit \u{2192} slam unlikely; wasted values there \u{2192} proceed to game only.",
            isForcingPass: false
        )
    }

    // MARK: - Takeout Double
    // Convention: Takeout Double
    // SAYC rule: with 12+ HCP, short in opponent's suit, and 3-card support for all unbid suits → double.
    private static func checkTakeoutDouble(
        eval: HandEvaluation,
        hand: [Card],
        chosenBid: Bid,
        auction: [AuctionEntry],
        settings: ConventionSettings
    ) -> BidAnalysis? {
        // Context: RHO opened a suit at the 1-level, partner has not yet bid
        guard auction.count == 1,
              let oppBid = auction.first?.bid,
              oppBid.level == .one,
              let oppStrain = oppBid.strain,
              oppStrain != .notrump else { return nil }
        guard chosenBid == .pass else { return nil }
        guard eval.hcp >= settings.takeoutDoubleMinHCP else { return nil }

        // Short in opponent's suit (0-2 cards)
        guard let oppSuit = oppStrain.suit, eval.length(oppSuit) <= 2 else { return nil }

        // 3+ in each of the other three suits (classic takeout shape)
        let unbidSuits = [Suit.clubs, .diamonds, .hearts, .spades].filter { $0 != oppSuit }
        guard unbidSuits.allSatisfy({ eval.length($0) >= 3 }) else { return nil }

        return BidAnalysis(
            recommendedBid: .double,
            convention: "Takeout Double",
            rationale: "Better: X (Takeout) \u{2014} \(eval.hcp) HCP, short in \(oppSuit.symbol), support for all unbid suits.",
            detailedExplanation: "A takeout double shows 12+ HCP, typically 0-2 cards in the opponent's suit, and at least 3 cards in each unbid suit. Partner picks their best suit. If you double and RHO bids again, partner need not jump unless they have extra values. A minimum response to your double is usually not punished.",
            isForcingPass: false
        )
    }

    // MARK: - Context helpers

    /// Returns true when the last relevant bid by partner was 1NT and RHO passed cleanly
    private static func partnerOpened1NT(auction: [AuctionEntry]) -> Bool {
        // Need: [P's 1NT, RHO pass, (optional others...)] and it's our turn
        guard auction.count >= 2,
              auction[0].seat == .north,       // humanSeat is always .south, partner is .north
              auction[0].bid == .contract(.one, .notrump),
              auction[1].seat == .east,
              auction[1].bid == .pass else { return false }
        // West not yet bid (auction.count == 2) or west also passed (auction.count == 3 + west pass)
        if auction.count == 2 { return true }
        if auction.count == 3 && auction[2].seat == .west && auction[2].bid == .pass { return true }
        return false
    }

    /// Returns the strain of partner's 1M opening if RHO passed cleanly
    private static func partnerOpenedMajorCleanly(auction: [AuctionEntry]) -> Strain? {
        guard auction.count >= 2,
              auction[0].seat == .north,
              auction[0].bid.level == .one,
              let strain = auction[0].bid.strain,
              strain.isMajor,
              auction[1].seat == .east,
              auction[1].bid == .pass else { return nil }
        if auction.count == 2 { return strain }
        if auction.count == 3 && auction[2].seat == .west && auction[2].bid == .pass { return strain }
        return nil
    }
}
