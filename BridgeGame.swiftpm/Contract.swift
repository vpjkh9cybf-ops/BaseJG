// Conventional Wisdom — modified 2026-06-07 03:07 UTC
import Foundation

enum Doubled: Int {
    case undoubled = 1
    case doubled   = 2
    case redoubled = 4
}

struct Contract: Equatable {
    let level: BidLevel
    let strain: Strain
    let declarer: Seat
    let doubled: Doubled

    var tricksRequired: Int { level.rawValue + 6 }

    var isGame: Bool {
        switch strain {
        case .notrump:         return level.rawValue >= 3
        case .hearts, .spades: return level.rawValue >= 4
        default:               return level.rawValue >= 5
        }
    }

    var isSmallSlam: Bool { level == .six }
    var isGrandSlam: Bool { level == .seven }

    var display: String {
        var d = "\(level.rawValue)\(strain.display)"
        switch doubled {
        case .doubled:   d += "X"
        case .redoubled: d += "XX"
        case .undoubled: break
        }
        return d
    }
}
