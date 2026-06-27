// BRIDGE APP — Built 2026-06-07
import SwiftUI

enum Suit: Int, CaseIterable, Comparable, Hashable {
    case clubs = 0, diamonds = 1, hearts = 2, spades = 3

    static func < (lhs: Suit, rhs: Suit) -> Bool { lhs.rawValue < rhs.rawValue }

    var symbol: String {
        switch self {
        case .clubs:    return "♣"
        case .diamonds: return "♦"
        case .hearts:   return "♥"
        case .spades:   return "♠"
        }
    }

    var name: String {
        switch self {
        case .clubs:    return "Clubs"
        case .diamonds: return "Diamonds"
        case .hearts:   return "Hearts"
        case .spades:   return "Spades"
        }
    }

    var color: Color { color(alternate: false) }

    func color(alternate: Bool = false) -> Color {
        if alternate {
            switch self {
            case .clubs:    return .blue
            case .diamonds: return Color(red: 1.0, green: 0.5, blue: 0.0)
            case .hearts:   return .red
            case .spades:   return .primary
            }
        }
        return (self == .hearts || self == .diamonds) ? .red : .primary
    }

    var strain: Strain {
        Strain(rawValue: rawValue)!
    }
}

enum Rank: Int, CaseIterable, Comparable, Hashable {
    case two = 2, three, four, five, six, seven, eight, nine, ten
    case jack = 11, queen = 12, king = 13, ace = 14

    static func < (lhs: Rank, rhs: Rank) -> Bool { lhs.rawValue < rhs.rawValue }

    var display: String {
        switch self {
        case .jack:  return "J"
        case .queen: return "Q"
        case .king:  return "K"
        case .ace:   return "A"
        case .ten:   return "10"
        default:     return "\(rawValue)"
        }
    }

    var hcp: Int {
        switch self {
        case .ace:   return 4
        case .king:  return 3
        case .queen: return 2
        case .jack:  return 1
        default:     return 0
        }
    }
}

struct Card: Hashable, Identifiable {
    let suit: Suit
    let rank: Rank

    var id: String { "\(rank.rawValue)-\(suit.rawValue)" }

    static var fullDeck: [Card] {
        var deck: [Card] = []
        for suit in Suit.allCases {
            for rank in Rank.allCases {
                deck.append(Card(suit: suit, rank: rank))
            }
        }
        return deck.shuffled()
    }
}

func sortCards(_ a: Card, _ b: Card) -> Bool {
    if a.suit != b.suit { return a.suit > b.suit }
    return a.rank > b.rank
}
