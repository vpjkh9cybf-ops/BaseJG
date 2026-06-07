// BRIDGE APP — Built 2026-06-07
import Foundation

enum Seat: Int, CaseIterable, Hashable {
    case north = 0, east = 1, south = 2, west = 3

    var name: String {
        switch self {
        case .north: return "North"
        case .east:  return "East"
        case .south: return "South"
        case .west:  return "West"
        }
    }

    var abbreviation: String { String(name.prefix(1)) }

    var next: Seat    { Seat(rawValue: (rawValue + 1) % 4)! }
    var partner: Seat { Seat(rawValue: (rawValue + 2) % 4)! }
    var prev: Seat    { Seat(rawValue: (rawValue + 3) % 4)! }

    var isNorthSouth: Bool { self == .north || self == .south }
    var isEastWest: Bool   { self == .east  || self == .west  }
}
