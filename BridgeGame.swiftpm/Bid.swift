// Conventional Wisdom — modified 2026-06-27 15:12 UTC
import SwiftUI

enum BidLevel: Int, CaseIterable, Comparable {
    case one = 1, two, three, four, five, six, seven

    static func < (lhs: BidLevel, rhs: BidLevel) -> Bool { lhs.rawValue < rhs.rawValue }
}

enum Strain: Int, CaseIterable, Comparable, Hashable {
    case clubs = 0, diamonds = 1, hearts = 2, spades = 3, notrump = 4

    static func < (lhs: Strain, rhs: Strain) -> Bool { lhs.rawValue < rhs.rawValue }

    var display: String {
        switch self {
        case .clubs:   return "♣"
        case .diamonds:return "♦"
        case .hearts:  return "♥"
        case .spades:  return "♠"
        case .notrump: return "NT"
        }
    }

    var color: Color { suit?.color ?? .primary }

    func color(alternate: Bool) -> Color { suit?.color(alternate: alternate) ?? .primary }

    var isMajor: Bool  { self == .hearts || self == .spades }
    var isMinor: Bool  { self == .clubs  || self == .diamonds }

    var suit: Suit? {
        switch self {
        case .clubs:    return .clubs
        case .diamonds: return .diamonds
        case .hearts:   return .hearts
        case .spades:   return .spades
        case .notrump:  return nil
        }
    }
}

enum Bid: Equatable {
    case pass
    case double
    case redouble
    case contract(BidLevel, Strain)

    var level: BidLevel? {
        guard case .contract(let l, _) = self else { return nil }
        return l
    }

    var strain: Strain? {
        guard case .contract(_, let s) = self else { return nil }
        return s
    }

    var isSuitBid: Bool {
        if case .contract = self { return true }
        return false
    }

    func isHigherThan(_ other: Bid) -> Bool {
        guard case .contract(let myL, let myS) = self,
              case .contract(let otherL, let otherS) = other else { return false }
        if myL != otherL { return myL > otherL }
        return myS > otherS
    }

    var display: String {
        switch self {
        case .pass:               return "Pass"
        case .double:             return "X"
        case .redouble:           return "XX"
        case .contract(let l, let s): return "\(l.rawValue)\(s.display)"
        }
    }
}
