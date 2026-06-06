import Foundation
import Combine

enum GamePhase: Equatable {
    case menu
    case bidding
    case playing
    case handResult(made: Bool, tricks: Int, score: Int)
    case rubberComplete
}

struct AuctionEntry: Identifiable {
    let id = UUID()
    let seat: Seat
    let bid: Bid
}

@MainActor
class GameState: ObservableObject {

    // MARK: - State

    @Published var phase: GamePhase = .menu
    @Published var hands: [Seat: [Card]] = [:]
    @Published var dealer: Seat = .north
    @Published var vulnerability: Vulnerability = .neither
    @Published var auction: [AuctionEntry] = []
    @Published var contract: Contract?
    @Published var dummy: Seat?
    @Published var completedTricks: [Trick] = []
    @Published var currentTrick: Trick?
    @Published var nsTricks: Int = 0
    @Published var ewTricks: Int = 0
    @Published var rubberScore = RubberScore()
    @Published var statusMessage: String = ""
    @Published var aiThinking: Bool = false

    // MARK: - Computed

    var currentBidder: Seat {
        var s = dealer
        for _ in 0..<auction.count { s = s.next }
        return s
    }

    var lastContractBid: (bid: Bid, seat: Seat)? {
        auction.reversed().first(where: { $0.bid.isSuitBid }).map { ($0.bid, $0.seat) }
    }

    var doubleStatus: Doubled {
        guard let idx = auction.lastIndex(where: { $0.bid.isSuitBid }) else { return .undoubled }
        var status = Doubled.undoubled
        for entry in auction[(idx + 1)...] {
            if entry.bid == .double   { status = .doubled   }
            if entry.bid == .redouble { status = .redoubled }
        }
        return status
    }

    var biddingIsComplete: Bool {
        guard auction.count >= 4 else { return false }
        let last4 = auction.suffix(4).map { $0.bid }
        if last4.allSatisfy({ $0 == .pass }) { return true }
        if auction.count >= 4, lastContractBid != nil {
            let last3 = auction.suffix(3).map { $0.bid }
            if last3.allSatisfy({ $0 == .pass }) { return true }
        }
        return false
    }

    var legalBids: [Bid] {
        var bids: [Bid] = [.pass]
        if canDouble    { bids.append(.double) }
        if canRedouble  { bids.append(.redouble) }
        for level in BidLevel.allCases {
            for strain in Strain.allCases {
                let b = Bid.contract(level, strain)
                if let highest = lastContractBid?.bid {
                    if b.isHigherThan(highest) { bids.append(b) }
                } else {
                    bids.append(b)
                }
            }
        }
        return bids
    }

    var canDouble: Bool {
        guard let last = lastContractBid, doubleStatus == .undoubled else { return false }
        return last.seat.isNorthSouth != currentBidder.isNorthSouth
    }

    var canRedouble: Bool {
        guard doubleStatus == .doubled else { return false }
        guard let last = lastContractBid else { return false }
        return last.seat.isNorthSouth == currentBidder.isNorthSouth
    }

    var humanSeat: Seat { .south }

    var isHumanTurn: Bool {
        switch phase {
        case .bidding:
            return currentBidder == humanSeat
        case .playing:
            guard let trick = currentTrick else { return false }
            let cp = trick.currentPlayer
            if let c = contract, c.declarer == humanSeat {
                return cp == humanSeat || cp == dummy
            }
            return cp == humanSeat
        default:
            return false
        }
    }

    var tappableSeat: Seat? {
        guard case .playing = phase, let trick = currentTrick else { return nil }
        let cp = trick.currentPlayer
        if let c = contract, c.declarer == humanSeat, cp == dummy {
            return dummy
        }
        return cp == humanSeat ? humanSeat : nil
    }

    var legalCards: Set<Card> {
        guard case .playing = phase,
              let trick = currentTrick,
              let seat = tappableSeat,
              let hand = hands[seat] else { return [] }

        if let ledSuit = trick.ledSuit {
            let followers = hand.filter { $0.suit == ledSuit }
            return Set(followers.isEmpty ? hand : followers)
        }
        return Set(hand)
    }

    // MARK: - Actions

    func startNewRubber() {
        rubberScore.reset()
        dealer = .north
        vulnerability = .neither
        startNewHand()
    }

    func startNewHand() {
        let deck = Card.fullDeck
        hands[.north] = Array(deck[0..<13]).sorted(by: sortCards)
        hands[.east]  = Array(deck[13..<26]).sorted(by: sortCards)
        hands[.south] = Array(deck[26..<39]).sorted(by: sortCards)
        hands[.west]  = Array(deck[39..<52]).sorted(by: sortCards)

        auction = []
        completedTricks = []
        currentTrick = nil
        contract = nil
        dummy = nil
        nsTricks = 0
        ewTricks = 0
        aiThinking = false

        statusMessage = "\(dealer.name) deals — \(vulnerability.rawValue) vulnerable"
        phase = .bidding

        triggerAIIfNeeded()
    }

    func placeBid(_ bid: Bid) {
        guard phase == .bidding, !aiThinking else { return }
        guard legalBids.contains(bid) else { return }

        auction.append(AuctionEntry(seat: currentBidder, bid: bid))

        if biddingIsComplete {
            finalizeBidding()
        } else {
            triggerAIIfNeeded()
        }
    }

    func playCard(_ card: Card, from seat: Seat) {
        guard case .playing = phase, !aiThinking else { return }
        guard legalCards.contains(card), tappableSeat == seat else { return }

        applyCard(card, from: seat)
    }

    func acknowledgeResult() {
        guard case .handResult = phase else { return }

        // Advance dealer and vulnerability
        dealer = dealer.next

        // Vulnerability cycles: Neither → NS → EW → Both → Neither per game
        // (Handled inside RubberScore via currentVulnerability)

        if rubberScore.rubberOver {
            phase = .rubberComplete
        } else {
            vulnerability = rubberScore.currentVulnerability
            startNewHand()
        }
    }

    func startNewRubberAfterCompletion() {
        startNewRubber()
    }

    // MARK: - Private

    private func triggerAIIfNeeded() {
        switch phase {
        case .bidding:
            guard currentBidder != humanSeat else { return }
            triggerAIBid()
        case .playing:
            guard let seat = currentTrick?.currentPlayer else { return }
            guard seat != tappableSeat else { return }
            triggerAIPlay()
        default:
            break
        }
    }

    private func triggerAIBid() {
        aiThinking = true
        Task {
            try? await Task.sleep(nanoseconds: 700_000_000)
            let bidder = self.currentBidder
            guard let hand = self.hands[bidder] else { return }
            let auctionSnapshot = self.auction.map { (seat: $0.seat, bid: $0.bid) }
            let bid = BiddingAI.selectBid(
                hand: hand,
                seat: bidder,
                auction: auctionSnapshot,
                vulnerability: self.vulnerability
            )
            self.aiThinking = false
            self.auction.append(AuctionEntry(seat: bidder, bid: bid))
            if self.biddingIsComplete {
                self.finalizeBidding()
            } else {
                self.triggerAIIfNeeded()
            }
        }
    }

    private func finalizeBidding() {
        // Passed out
        if auction.allSatisfy({ $0.bid == .pass }) {
            statusMessage = "Passed out — no hand played"
            dealer = dealer.next
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                self.startNewHand()
            }
            return
        }

        guard let c = buildContract() else { return }
        contract = c
        dummy = c.declarer.partner
        statusMessage = "\(c.declarer.name) plays \(c.display) — \(c.declarer.next.name) leads"

        phase = .playing
        let leader = c.declarer.next
        currentTrick = Trick(leader: leader, plays: [], trump: c.strain.suit)

        triggerAIIfNeeded()
    }

    private func buildContract() -> Contract? {
        guard let (lastBid, lastSeat) = lastContractBid else { return nil }
        guard let level = lastBid.level, let strain = lastBid.strain else { return nil }

        let winningSide = lastSeat.isNorthSouth
        // Declarer: first player on winning side to bid this strain
        var declarerSeat = lastSeat
        for entry in auction {
            if entry.seat.isNorthSouth == winningSide, entry.bid.strain == strain {
                declarerSeat = entry.seat
                break
            }
        }

        return Contract(level: level, strain: strain, declarer: declarerSeat, doubled: doubleStatus)
    }

    private func applyCard(_ card: Card, from seat: Seat) {
        hands[seat]?.removeAll { $0 == card }
        currentTrick?.plays.append(TrickCard(seat: seat, card: card))

        if currentTrick?.isComplete == true {
            let trick = currentTrick!
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 500_000_000)
                self.processTrickEnd(trick)
            }
        } else {
            triggerAIIfNeeded()
        }
    }

    private func processTrickEnd(_ trick: Trick) {
        completedTricks.append(trick)

        guard let winner = trick.winner else { return }
        if winner.isNorthSouth { nsTricks += 1 } else { ewTricks += 1 }

        if completedTricks.count == 13 {
            finishHand()
            return
        }

        // New trick led by winner
        currentTrick = Trick(leader: winner, plays: [], trump: contract?.strain.suit)
        statusMessage = "\(winner.name) wins the trick"

        triggerAIIfNeeded()
    }

    private func finishHand() {
        guard let c = contract else { return }
        let isNS = c.declarer.isNorthSouth
        let tricks = isNS ? nsTricks : ewTricks
        let made = tricks >= c.tricksRequired

        let result = HandResult(
            contract: c,
            declarer: c.declarer,
            tricksWon: tricks,
            vulnerability: vulnerability
        )
        rubberScore.recordHand(result)

        let net = result.netScore
        let scoreStr = made
            ? "+\(net) (\(tricks - c.tricksRequired >= 0 ? "+\(tricks - c.tricksRequired)" : "="))"
            : "\(net) (\(tricks - c.tricksRequired))"

        phase = .handResult(made: made, tricks: tricks, score: made ? net : -result.netScore)
    }

    private func triggerAIPlay() {
        aiThinking = true
        Task {
            try? await Task.sleep(nanoseconds: 600_000_000)
            guard let trick = self.currentTrick,
                  let c = self.contract else { return }

            let cp = trick.currentPlayer
            // Declarer plays both declarer and dummy's cards
            let playingSeat: Seat
            if c.declarer != self.humanSeat && cp == self.dummy {
                playingSeat = self.dummy!
            } else {
                playingSeat = cp
            }

            guard let hand = self.hands[playingSeat] else { return }
            let isDeclarer = (c.declarer == playingSeat) || (c.declarer != self.humanSeat && playingSeat == self.dummy)
            let isDummy    = playingSeat == self.dummy

            let card = PlayAI.selectCard(
                hand: hand,
                trick: trick,
                contract: c,
                seat: playingSeat,
                isDeclarer: isDeclarer,
                isDummy: isDummy,
                completedTricks: self.completedTricks
            )

            self.aiThinking = false
            self.applyCard(card, from: playingSeat)
        }
    }
}
