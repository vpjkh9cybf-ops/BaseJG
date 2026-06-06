import Foundation

struct HandEvaluation {
    let hcp: Int
    let lengths: [Suit: Int]

    // Distribution (lengths sorted descending)
    var distribution: [Int] { lengths.values.sorted(by: >) }

    var isBalanced: Bool {
        let d = distribution
        return d == [4,3,3,3] || d == [4,4,3,2] || d == [5,3,3,2]
    }

    var isSemiBalanced: Bool {
        if isBalanced { return true }
        let d = distribution
        return d == [5,4,2,2] || d == [6,3,2,2]
    }

    func length(_ suit: Suit) -> Int { lengths[suit] ?? 0 }

    var longestSuit: Suit {
        Suit.allCases.max(by: { length($0) < length($1) }) ?? .spades
    }

    var longestLength: Int { distribution.first ?? 0 }

    var fiveCardMajors: [Suit] {
        [.spades, .hearts].filter { length($0) >= 5 }
    }

    var fourCardMajors: [Suit] {
        [.spades, .hearts].filter { length($0) >= 4 }
    }

    // Shortness points (for suit contracts)
    var shortPoints: Int {
        var pts = 0
        for suit in Suit.allCases {
            switch length(suit) {
            case 0: pts += 3
            case 1: pts += 2
            case 2: pts += 1
            default: break
            }
        }
        return pts
    }

    var totalPoints: Int { hcp + shortPoints }

    // Quality of a suit (top honors count)
    func suitQuality(_ suit: Suit, in cards: [Card]) -> Int {
        let suitCards = cards.filter { $0.suit == suit }
        return suitCards.reduce(0) { $0 + $1.rank.hcp }
    }

    // Is a suit "good" for opening leads / overcalls
    func isSolidOrSemi(_ suit: Suit, in cards: [Card]) -> Bool {
        let suitCards = cards.filter { $0.suit == suit }
        guard suitCards.count >= 4 else { return false }
        let ranks = suitCards.map { $0.rank }.sorted(by: >)
        // Has AKQ, AKJ, AQJ, KQJ, etc.
        return suitQuality(suit, in: cards) >= 5
    }
}

struct HandEvaluator {
    static func evaluate(_ cards: [Card]) -> HandEvaluation {
        var hcp = 0
        var lengths: [Suit: Int] = [:]
        for suit in Suit.allCases { lengths[suit] = 0 }
        for card in cards {
            hcp += card.rank.hcp
            lengths[card.suit, default: 0] += 1
        }
        return HandEvaluation(hcp: hcp, lengths: lengths)
    }
}
