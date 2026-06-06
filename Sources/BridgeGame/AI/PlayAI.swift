import Foundation

struct PlayAI {

    // Select a card to play for the given seat
    static func selectCard(
        hand: [Card],
        trick: Trick,
        contract: Contract,
        seat: Seat,
        isDeclarer: Bool,
        isDummy: Bool,
        completedTricks: [Trick]
    ) -> Card {
        guard !hand.isEmpty else { fatalError("PlayAI: empty hand") }

        let ledSuit = trick.ledSuit
        let trump = contract.strain.suit

        // Must follow suit if possible
        let followers = ledSuit.map { s in hand.filter { $0.suit == s } } ?? []
        let legalCards = followers.isEmpty ? hand : followers

        if trick.plays.isEmpty {
            // Opening lead or leading to a new trick
            return selectLead(hand: hand, contract: contract, seat: seat, isDeclarer: isDeclarer, completedTricks: completedTricks)
        } else {
            return selectFollow(
                legal: legalCards,
                trick: trick,
                contract: contract,
                seat: seat,
                isDeclarer: isDeclarer,
                completedTricks: completedTricks
            )
        }
    }

    // MARK: - Lead Selection

    private static func selectLead(
        hand: [Card],
        contract: Contract,
        seat: Seat,
        isDeclarer: Bool,
        completedTricks: [Trick]
    ) -> Card {
        let trump = contract.strain.suit

        if isDeclarer {
            return declarerLead(hand: hand, contract: contract, completedTricks: completedTricks)
        } else {
            return defenderLead(hand: hand, contract: contract, completedTricks: completedTricks)
        }
    }

    private static func declarerLead(hand: [Card], contract: Contract, completedTricks: [Trick]) -> Card {
        let trump = contract.strain.suit
        let eval  = HandEvaluator.evaluate(hand)

        // Draw trumps first (if any remain in hand)
        if let t = trump, let trumpCard = hand.filter({ $0.suit == t }).max(by: { $0.rank < $1.rank }) {
            // Lead high trump to draw opponents' trumps
            return trumpCard
        }

        // Lead from longest established suit
        for suit in Suit.allCases.reversed() {
            if suit == trump { continue }
            let suitCards = hand.filter { $0.suit == suit }
            if suitCards.count >= 4 {
                return topOfSequence(suitCards) ?? suitCards.max(by: { $0.rank < $1.rank })!
            }
        }

        // Lead from suit with top honors (AK, KQ etc.)
        for suit in Suit.allCases.reversed() {
            if suit == trump { continue }
            let suitCards = hand.filter { $0.suit == suit }.sorted(by: { $0.rank > $1.rank })
            if suitCards.count >= 2 && suitCards[0].rank >= .king && suitCards[1].rank >= .queen {
                return suitCards[0]
            }
        }

        // Fourth-best from longest suit
        return fourthBest(from: hand, excluding: trump)
    }

    private static func defenderLead(hand: [Card], contract: Contract, completedTricks: [Trick]) -> Card {
        let trump = contract.strain.suit
        let isNT  = (trump == nil)

        // Against NT: lead fourth-best from longest/strongest suit
        if isNT {
            return fourthBest(from: hand, excluding: nil)
        }

        // Against suit contract:
        // Top of a sequence (AK, KQ, QJ, JT)
        for suit in Suit.allCases.reversed() {
            if suit == trump { continue }
            let suitCards = hand.filter { $0.suit == suit }.sorted(by: { $0.rank > $1.rank })
            if suitCards.count >= 2 {
                if let seq = topOfSequence(suitCards) {
                    if suitCards[0].rank >= .king {
                        return seq
                    }
                }
            }
        }

        // Singleton in side suit (for ruff)
        for suit in Suit.allCases {
            if suit == trump { continue }
            if hand.filter({ $0.suit == suit }).count == 1 {
                return hand.first(where: { $0.suit == suit })!
            }
        }

        return fourthBest(from: hand, excluding: trump)
    }

    // MARK: - Follow-suit Selection

    private static func selectFollow(
        legal: [Card],
        trick: Trick,
        contract: Contract,
        seat: Seat,
        isDeclarer: Bool,
        completedTricks: [Trick]
    ) -> Card {
        let trump = contract.strain.suit
        let isPartnerWinning = partnerIsWinning(trick: trick, seat: seat, trump: trump)
        let position = trick.plays.count // 1 = second, 2 = third, 3 = fourth

        if isDeclarer {
            return declarerFollow(legal: legal, trick: trick, trump: trump, isPartnerWinning: isPartnerWinning, position: position)
        } else {
            return defenderFollow(legal: legal, trick: trick, trump: trump, isPartnerWinning: isPartnerWinning, position: position)
        }
    }

    private static func declarerFollow(legal: [Card], trick: Trick, trump: Suit?, isPartnerWinning: Bool, position: Int) -> Card {
        if isPartnerWinning {
            // Partner (dummy or declarer partner) winning — play low
            return legal.min(by: { $0.rank < $1.rank }) ?? legal[0]
        }

        // Try to win the trick
        if let winner = winningCard(from: legal, against: trick, trump: trump) {
            return winner
        }

        // Can't win — discard lowest
        return legal.min(by: { $0.rank < $1.rank }) ?? legal[0]
    }

    private static func defenderFollow(legal: [Card], trick: Trick, trump: Suit?, isPartnerWinning: Bool, position: Int) -> Card {
        // Second hand low
        if position == 1 {
            return legal.min(by: { $0.rank < $1.rank }) ?? legal[0]
        }

        // Third hand high
        if position == 2 {
            if !isPartnerWinning {
                return legal.max(by: { $0.rank < $1.rank }) ?? legal[0]
            }
            return legal.min(by: { $0.rank < $1.rank }) ?? legal[0]
        }

        // Fourth hand: win cheaply or discard
        if !isPartnerWinning {
            if let winner = winningCard(from: legal, against: trick, trump: trump) {
                return winner
            }
        }

        return legal.min(by: { $0.rank < $1.rank }) ?? legal[0]
    }

    // MARK: - Helpers

    private static func partnerIsWinning(trick: Trick, seat: Seat, trump: Suit?) -> Bool {
        guard let currentWinner = currentWinner(of: trick, trump: trump) else { return false }
        return currentWinner == seat.partner
    }

    private static func currentWinner(of trick: Trick, trump: Suit?) -> Seat? {
        guard !trick.plays.isEmpty else { return nil }
        var best = trick.plays[0]
        for p in trick.plays.dropFirst() {
            if let t = trump {
                if p.card.suit == t && best.card.suit != t { best = p }
                else if p.card.suit == best.card.suit && p.card.rank > best.card.rank { best = p }
            } else {
                if p.card.suit == best.card.suit && p.card.rank > best.card.rank { best = p }
            }
        }
        return best.seat
    }

    private static func winningCard(from legal: [Card], against trick: Trick, trump: Suit?) -> Card? {
        guard let curWinner = currentWinner(of: trick, trump: trump) else { return legal.first }
        let winningCard = trick.plays.first(where: { $0.seat == curWinner })!.card

        // Try to beat it
        let beaters = legal.filter { card in
            if let t = trump {
                if card.suit == t && winningCard.suit != t { return true }
                if card.suit == winningCard.suit && card.rank > winningCard.rank { return true }
            } else {
                if card.suit == winningCard.suit && card.rank > winningCard.rank { return true }
            }
            return false
        }

        // Return cheapest winner
        return beaters.min(by: { $0.rank < $1.rank })
    }

    private static func topOfSequence(_ sorted: [Card]) -> Card? {
        guard sorted.count >= 2 else { return nil }
        // Check for sequence from top (AK, KQ, QJ, JT, T9)
        let top = sorted[0].rank
        let next = sorted[1].rank
        if top.rawValue - next.rawValue == 1 { return sorted[0] }
        return nil
    }

    private static func fourthBest(from hand: [Card], excluding trump: Suit?) -> Card {
        // Find longest suit, play fourth-highest card
        var bestSuit: Suit = .spades
        var bestCount = 0
        for suit in Suit.allCases {
            if suit == trump { continue }
            let count = hand.filter { $0.suit == suit }.count
            if count > bestCount {
                bestCount = count
                bestSuit = suit
            }
        }

        let suitCards = hand.filter { $0.suit == bestSuit }.sorted(by: { $0.rank > $1.rank })
        if suitCards.count >= 4 { return suitCards[3] }       // True fourth-best
        return suitCards.last ?? hand.last ?? hand[0]
    }
}
