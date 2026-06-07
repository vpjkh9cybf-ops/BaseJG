import SwiftUI

struct HandResult {
    let contract: Contract
    let declarer: Seat
    let tricksWon: Int
    let vulnerability: Vulnerability

    var made: Bool { tricksWon >= contract.tricksRequired }
    var overtricks: Int { made ? tricksWon - contract.tricksRequired : 0 }
    var undertricks: Int { made ? 0 : contract.tricksRequired - tricksWon }
    var isVulnerable: Bool { vulnerability.isVulnerable(declarer) }

    var declarerIsNS: Bool { declarer.isNorthSouth }

    // Returns the net score (positive = declarer's side scored)
    var netScore: Int {
        if made {
            return madeScore()
        } else {
            return -penaltyScore()
        }
    }

    // Score that goes below the line (trick score only)
    var belowLineScore: Int {
        guard made else { return 0 }
        let raw: Int
        switch contract.strain {
        case .clubs, .diamonds: raw = 20 * contract.level.rawValue
        case .hearts, .spades:  raw = 30 * contract.level.rawValue
        case .notrump:          raw = 40 + 30 * (contract.level.rawValue - 1)
        }
        return raw * contract.doubled.rawValue
    }

    private func madeScore() -> Int {
        var score = belowLineScore

        // Overtricks
        if overtricks > 0 {
            switch contract.doubled {
            case .undoubled:
                let perTrick = contract.strain.isMinor ? 20 : 30
                score += perTrick * overtricks
            case .doubled:
                score += (isVulnerable ? 200 : 100) * overtricks
            case .redoubled:
                score += (isVulnerable ? 400 : 200) * overtricks
            }
        }

        // Insult bonus
        if contract.doubled == .doubled   { score += 50  }
        if contract.doubled == .redoubled { score += 100 }

        // Slam bonuses
        if contract.isGrandSlam { score += isVulnerable ? 1500 : 1000 }
        else if contract.isSmallSlam { score += isVulnerable ? 750 : 500 }

        return score
    }

    private func penaltyScore() -> Int {
        switch contract.doubled {
        case .undoubled:
            return (isVulnerable ? 100 : 50) * undertricks

        case .doubled:
            if isVulnerable {
                return 200 * undertricks
            } else {
                // 100 first, 200 each after
                if undertricks == 1 { return 100 }
                return 100 + 200 * (undertricks - 1)
            }

        case .redoubled:
            if isVulnerable {
                return 400 * undertricks
            } else {
                if undertricks == 1 { return 200 }
                return 200 + 400 * (undertricks - 1)
            }
        }
    }
}

@MainActor
class RubberScore: ObservableObject {
    // Running below-the-line partial scores (reset on game)
    @Published var nsBelow: Int = 0
    @Published var ewBelow: Int = 0

    // Cumulative above-the-line bonuses/penalties
    @Published var nsAbove: Int = 0
    @Published var ewAbove: Int = 0

    @Published var nsGames: Int = 0
    @Published var ewGames: Int = 0

    @Published var handHistory: [HandResult] = []

    var rubberOver: Bool { nsGames >= 2 || ewGames >= 2 }

    var nsTotal: Int { nsAbove + nsBelow + (nsGames >= 2 ? rubberBonus(winner: .north) : 0) }
    var ewTotal: Int { ewAbove + ewBelow + (ewGames >= 2 ? rubberBonus(winner: .east)  : 0) }

    var currentVulnerability: Vulnerability {
        switch (nsGames > 0, ewGames > 0) {
        case (false, false): return .neither
        case (true,  false): return .northSouth
        case (false, true):  return .eastWest
        case (true,  true):  return .both
        }
    }

    func recordHand(_ result: HandResult) {
        handHistory.append(result)
        let net = result.netScore

        if result.made {
            let below = result.belowLineScore
            let above = abs(net) - below

            if result.declarerIsNS {
                nsBelow += below
                nsAbove += above
            } else {
                ewBelow += below
                ewAbove += above
            }

            // Check for game
            if nsBelow >= 100 {
                nsGames += 1
                nsBelow = 0
                ewBelow = 0
            } else if ewBelow >= 100 {
                ewGames += 1
                nsBelow = 0
                ewBelow = 0
            }
        } else {
            let penalty = abs(net)
            if result.declarerIsNS {
                ewAbove += penalty
            } else {
                nsAbove += penalty
            }
        }
    }

    private func rubberBonus(winner: Seat) -> Int {
        let loserGames = winner.isNorthSouth ? ewGames : nsGames
        return loserGames == 0 ? 700 : 500
    }

    func reset() {
        nsBelow = 0; ewBelow = 0
        nsAbove = 0; ewAbove = 0
        nsGames = 0; ewGames = 0
        handHistory = []
    }
}
