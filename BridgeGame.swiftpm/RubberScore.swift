// BRIDGE APP — Built 2026-06-07
import SwiftUI

struct HandResult {
    let contract: Contract
    let declarer: Seat
    let tricksWon: Int
    let vulnerability: Vulnerability
    let scoringMode: ScoringMode

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

        // Chicago: game/partial bonus per hand
        if scoringMode == .chicago {
            if contract.isGame { score += isVulnerable ? 500 : 300 }
            else               { score += 50 }
        }

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
    // Accumulated below-the-line totals (never reset in rubber)
    @Published var nsBelow: Int = 0
    @Published var ewBelow: Int = 0

    // Cumulative above-the-line bonuses/penalties
    @Published var nsAbove: Int = 0
    @Published var ewAbove: Int = 0

    @Published var nsGames: Int = 0
    @Published var ewGames: Int = 0

    // Current partial toward next game (resets on game)
    @Published var nsPartial: Int = 0
    @Published var ewPartial: Int = 0

    @Published var handHistory: [HandResult] = []

    var scoringMode: ScoringMode = .rubber

    var rubberOver: Bool {
        if scoringMode == .chicago { return handHistory.count >= 4 }
        return nsGames >= 2 || ewGames >= 2
    }

    var nsTotal: Int {
        if scoringMode == .chicago { return nsBelow }
        return nsAbove + nsBelow + (nsGames >= 2 ? rubberBonus(winner: .north) : 0)
    }
    var ewTotal: Int {
        if scoringMode == .chicago { return ewBelow }
        return ewAbove + ewBelow + (ewGames >= 2 ? rubberBonus(winner: .east) : 0)
    }

    var currentVulnerability: Vulnerability {
        if scoringMode == .chicago {
            switch handHistory.count % 4 {
            case 0: return .neither
            case 1: return .northSouth
            case 2: return .eastWest
            default: return .both
            }
        }
        switch (nsGames > 0, ewGames > 0) {
        case (false, false): return .neither
        case (true,  false): return .northSouth
        case (false, true):  return .eastWest
        case (true,  true):  return .both
        }
    }

    func recordHand(_ result: HandResult) {
        handHistory.append(result)

        if scoringMode == .chicago {
            let pts = abs(result.netScore)
            if result.made {
                if result.declarerIsNS { nsBelow += pts } else { ewBelow += pts }
            } else {
                // penalty goes to defending side
                if result.declarerIsNS { ewBelow += pts } else { nsBelow += pts }
            }
            return
        }

        // Rubber mode
        if result.made {
            let below = result.belowLineScore
            let above = abs(result.netScore) - below
            if result.declarerIsNS {
                nsPartial += below
                nsBelow += below
                nsAbove += above
            } else {
                ewPartial += below
                ewBelow += below
                ewAbove += above
            }
            // game check uses nsPartial/ewPartial
            if nsPartial >= 100 {
                nsGames += 1
                nsPartial = 0
                ewPartial = 0
            } else if ewPartial >= 100 {
                ewGames += 1
                nsPartial = 0
                ewPartial = 0
            }
        } else {
            let penalty = abs(result.netScore)
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

    func reset(mode: ScoringMode = .rubber) {
        scoringMode = mode
        nsBelow = 0; ewBelow = 0
        nsAbove = 0; ewAbove = 0
        nsGames = 0; ewGames = 0
        nsPartial = 0; ewPartial = 0
        handHistory = []
    }
}
