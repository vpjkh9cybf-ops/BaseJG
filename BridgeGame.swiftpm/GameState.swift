// Conventional Wisdom — modified 2026-08-15 01:52 UTC
import SwiftUI

enum RKCBFlavor: String, CaseIterable {
    case f1430 = "1430"   // 5♣ = 1 or 4 key cards, 5♦ = 0 or 3
    case f0314 = "0314"   // 5♣ = 0 or 3 key cards, 5♦ = 1 or 4
}

enum ScoringMode: String, CaseIterable {
    case rubber  = "Rubber"
    case chicago = "Chicago"
}

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

    // MARK: - Published State

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
    @Published var claimDenied: Bool = false
    @Published var scoringMode: ScoringMode = .rubber
    @Published var biddingNote: String = ""
    /// Every convention the user selected to drill. Empty = ordinary play.
    @Published var practiceConventions: Set<PracticeConvention> = []
    /// The convention the *current* deal was constructed for.
    @Published var practiceConvention: PracticeConvention? = nil
    @Published var showCorrectPractice: Bool = false
    @Published var showIncorrectPractice: Bool = false
    @Published var practiceFeedbackMessage: String = ""
    @Published var practiceHint: String = ""

    /// Bumped whenever the board changes underneath a pending timer. Each
    /// delayed Task captures the value at spawn and abandons its work if it has
    /// moved on — otherwise an AI bid or card lands seconds after the user has
    /// already left for the menu or restarted the hand.
    private var boardGeneration: Int = 0

    // Replay snapshots
    private var dealtHands: [Seat: [Card]] = [:]
    private var dealerAtDeal: Seat = .north
    private var auctionSnapshot: [AuctionEntry] = []
    private var contractSnapshot: Contract? = nil
    private var dummySnapshot: Seat? = nil
    private var pendingPracticeBid: Bid? = nil

    let humanSeat: Seat = .south
    /// Defaults on: when the human would be dummy, they play the declarer's hand instead.
    @Published var switchSeatsForDeclarer: Bool = true
    /// The partnership's convention card. The bidding engine reads it directly,
    /// so changing a setting changes how the AI bids on the very next call.
    @Published var conventionSettings: ConventionSettings = ConventionSettings.load() {
        didSet { conventionSettings.save() }
    }
    @Published var bidWarning: BidAnalysis? = nil

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
        if lastContractBid != nil {
            let last3 = auction.suffix(3).map { $0.bid }
            if last3.allSatisfy({ $0 == .pass }) { return true }
        }
        return false
    }

    var legalBids: [Bid] {
        var bids: [Bid] = [.pass]
        if canDouble   { bids.append(.double)   }
        if canRedouble { bids.append(.redouble) }
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

    var isHumanTurn: Bool {
        switch phase {
        case .bidding:
            return currentBidder == humanSeat && !aiThinking
        case .playing:
            guard let trick = currentTrick, let c = contract else { return false }
            let cp = trick.currentPlayer
            if c.declarer == humanSeat {
                return (cp == humanSeat || cp == dummy) && !aiThinking
            }
            if switchSeatsForDeclarer && c.declarer == humanSeat.partner {
                return (cp == c.declarer || cp == dummy) && !aiThinking
            }
            // North is declarer, South is dummy — AI handles both; human watches
            if c.declarer == humanSeat.partner { return false }
            return cp == humanSeat && !aiThinking
        default:
            return false
        }
    }

    var tappableSeat: Seat? {
        guard case .playing = phase, !aiThinking, let trick = currentTrick else { return nil }
        let cp = trick.currentPlayer
        guard let c = contract else { return nil }
        if c.declarer == humanSeat {
            if cp == humanSeat || cp == dummy { return cp }
            return nil
        }
        if switchSeatsForDeclarer && c.declarer == humanSeat.partner {
            if cp == c.declarer || cp == dummy { return cp }
            return nil
        }
        // North is declarer, South is dummy — AI handles both; human watches
        if c.declarer == humanSeat.partner { return nil }
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

    // MARK: - Public Actions

    func startNewRubber() {
        practiceConventions = []
        practiceConvention = nil
        practiceHint = ""
        showCorrectPractice = false
        showIncorrectPractice = false
        rubberScore.reset(mode: scoringMode)
        dealer = .north
        vulnerability = .neither
        startNewHand()
    }

    /// Abandon the current game and go back to the start screen.
    func returnToMenu() {
        boardGeneration += 1

        phase                 = .menu
        hands                 = [:]
        auction               = []
        completedTricks       = []
        currentTrick          = nil
        contract              = nil
        dummy                 = nil
        nsTricks              = 0
        ewTricks              = 0
        aiThinking            = false
        statusMessage         = ""
        biddingNote           = ""
        practiceHint          = ""
        bidWarning            = nil
        pendingPracticeBid    = nil
        practiceConvention    = nil
        practiceConventions   = []
        claimDenied           = false
        showCorrectPractice   = false
        showIncorrectPractice = false
    }

    func startNewHand() {
        boardGeneration += 1

        // A random deal is not built around any convention, so no drill applies
        // to it — clearing this stops a stale hint firing on an unrelated hand.
        practiceConvention = nil

        let deck = Card.fullDeck
        hands[.north] = Array(deck[0..<13]).sorted(by: sortCards)
        hands[.east]  = Array(deck[13..<26]).sorted(by: sortCards)
        hands[.south] = Array(deck[26..<39]).sorted(by: sortCards)
        hands[.west]  = Array(deck[39..<52]).sorted(by: sortCards)
        dealtHands = hands
        dealerAtDeal = dealer

        auction         = []
        completedTricks = []
        currentTrick    = nil
        contract        = nil
        dummy           = nil
        nsTricks        = 0
        ewTricks        = 0
        aiThinking          = false
        biddingNote         = ""
        practiceHint        = ""
        bidWarning          = nil
        pendingPracticeBid  = nil
        showCorrectPractice = false
        showIncorrectPractice = false

        statusMessage = "\(dealer.name) deals — \(vulnerability.rawValue) vulnerable"
        phase = .bidding
        triggerAIIfNeeded()
    }

    func placeBid(_ bid: Bid) {
        guard phase == .bidding, !aiThinking, legalBids.contains(bid) else { return }
        biddingNote = ""

        // Convention practice: hold bid pending user acknowledgement
        if currentBidder == humanSeat, let convention = practiceConvention {
            if let expected = convention.expectedBid(auction: auction, southHand: hands[humanSeat] ?? []) {
                practiceHint = ""
                pendingPracticeBid = bid
                if bid == expected {
                    practiceFeedbackMessage = "✓ Correct! \(bid.display) — \(convention.rawValue) bid confirmed."
                    showCorrectPractice = true
                } else {
                    practiceFeedbackMessage = convention.correctionText(expected: expected,
                                                                       southHand: hands[humanSeat] ?? [],
                                                                       auction: auction)
                    showIncorrectPractice = true
                }
                return  // don't commit until user taps Continue or Rebid
            }
            practiceHint = ""
        }

        commitBid(bid)
    }

    // Commit the human's chosen bid (or pending practice bid) to the auction.
    func continuePracticeBid() {
        if let bid = pendingPracticeBid {
            pendingPracticeBid = nil
            commitBid(bid)
        }
    }

    // Discard the pending practice bid so the human can retry.
    func rebidPracticeHand() {
        pendingPracticeBid = nil
        updatePracticeHint()
    }

    private func commitBid(_ bid: Bid) {
        if currentBidder == humanSeat {
            bidWarning = ConventionCoach.analyze(
                hand: hands[humanSeat] ?? [],
                chosenBid: bid,
                auction: auction,
                settings: conventionSettings
            )
        } else {
            bidWarning = nil
        }
        auction.append(AuctionEntry(seat: currentBidder, bid: bid))
        if biddingIsComplete { finalizeBidding() }
        else { triggerAIIfNeeded() }
    }

    func playCard(_ card: Card, from seat: Seat) {
        guard case .playing = phase, !aiThinking,
              tappableSeat == seat, legalCards.contains(card) else { return }
        applyCard(card, from: seat)
    }

    func canClaim() -> Bool {
        guard case .playing = phase, let c = contract else { return false }
        let remaining = 13 - completedTricks.count
        guard remaining > 0 else { return false }
        let declarerSeats: [Seat] = c.declarer.isNorthSouth ? [.north, .south] : [.east, .west]
        let opponentSeats: [Seat] = Seat.allCases.filter { !declarerSeats.contains($0) }
        let ourCards   = declarerSeats.compactMap { hands[$0] }.flatMap { $0 }
        let theirCards = opponentSeats.compactMap { hands[$0] }.flatMap { $0 }
        var winners = 0
        for suit in Suit.allCases {
            let ours   = ourCards.filter   { $0.suit == suit }.sorted { $0.rank > $1.rank }
            let theirs = theirCards.filter { $0.suit == suit }.sorted { $0.rank > $1.rank }
            if theirs.isEmpty { winners += ours.count }
            else { winners += ours.filter { $0.rank > theirs[0].rank }.count }
        }
        return winners >= remaining
    }

    func claimTricks() {
        guard case .playing = phase, let c = contract else { return }
        guard canClaim() else { claimDenied = true; return }
        let remaining = 13 - completedTricks.count
        if c.declarer.isNorthSouth { nsTricks += remaining } else { ewTricks += remaining }
        finishHand()
    }

    func acknowledgeResult() {
        guard case .handResult = phase else { return }
        dealer = dealer.next
        if rubberScore.rubberOver {
            phase = .rubberComplete
        } else {
            vulnerability = rubberScore.currentVulnerability
            if practiceConventions.isEmpty {
                startNewHand()
            } else {
                dealForConvention()
            }
        }
    }

    func startNewRubberAfterCompletion() {
        if practiceConventions.isEmpty {
            startNewRubber()
        } else {
            startPractice(conventions: practiceConventions)
        }
    }

    func startPractice(conventions: Set<PracticeConvention>) {
        guard !conventions.isEmpty else { startNewRubber(); return }
        practiceConventions = conventions
        rubberScore.reset(mode: .rubber)
        vulnerability = .neither
        dealForConvention()
    }

    func nextPracticeHand() {
        guard !practiceConventions.isEmpty else { return }
        pendingPracticeBid = nil
        dealForConvention()
    }

    func replayFromBidding() {
        guard !dealtHands.isEmpty else { return }
        boardGeneration += 1
        hands   = dealtHands
        dealer  = dealerAtDeal
        auction = []; completedTricks = []; currentTrick = nil
        contract = nil; dummy = nil; nsTricks = 0; ewTricks = 0
        aiThinking = false; biddingNote = ""; practiceHint = ""
        bidWarning = nil; pendingPracticeBid = nil
        showCorrectPractice = false; showIncorrectPractice = false
        statusMessage = "\(dealer.name) deals — \(vulnerability.rawValue) vulnerable"
        phase = .bidding
        triggerAIIfNeeded()
    }

    func replayFromPlay() {
        guard let c = contractSnapshot, !dealtHands.isEmpty else { return }
        boardGeneration += 1
        hands            = dealtHands
        auction          = auctionSnapshot
        contract         = c
        dummy            = dummySnapshot
        completedTricks  = []
        currentTrick     = Trick(leader: c.declarer.next, plays: [], trump: c.strain.suit)
        nsTricks         = 0; ewTricks = 0
        aiThinking       = false
        bidWarning       = nil; pendingPracticeBid = nil
        showCorrectPractice = false; showIncorrectPractice = false
        statusMessage = "\(c.declarer.name) plays \(c.display) — \(c.declarer.next.name) leads"
        phase = .playing
        triggerAIIfNeeded()
    }

    /// Deal until the layout fits one of the selected conventions, then set the
    /// dealer that produces the auction where that convention actually comes up.
    /// Conventions are tried in a shuffled order so a multi-convention drill
    /// does not always resolve to the same (easiest to satisfy) one.
    private func dealForConvention() {
        guard !practiceConventions.isEmpty else { startNewHand(); return }
        let pool = practiceConventions.shuffled()

        for _ in 0..<200 {
            let deck  = Card.fullDeck
            let north = Array(deck[0..<13]).sorted(by: sortCards)
            let east  = Array(deck[13..<26]).sorted(by: sortCards)
            let south = Array(deck[26..<39]).sorted(by: sortCards)
            let west  = Array(deck[39..<52]).sorted(by: sortCards)

            for convention in pool
            where convention.northQualifies(north)
               && convention.southQualifies(south, north: north)
               && convention.opponentsQualify(east: east, west: west) {
                practiceConvention = convention
                dealer = convention.dealerSeat
                applyPracticeDeal(north: north, east: east, south: south, west: west)
                return
            }
        }

        // Could not construct a qualifying layout — play a normal deal rather
        // than looping forever, and clear the per-hand convention so no hint or
        // grading fires on a hand that does not actually contain the auction.
        practiceConvention = nil
        startNewHand()
    }

    private func applyPracticeDeal(north: [Card], east: [Card], south: [Card], west: [Card]) {
        boardGeneration += 1
        hands[.north] = north
        hands[.east]  = east
        hands[.south] = south
        hands[.west]  = west
        dealtHands   = hands
        dealerAtDeal = dealer

        auction = []; completedTricks = []; currentTrick = nil
        contract = nil; dummy = nil; nsTricks = 0; ewTricks = 0
        aiThinking = false; biddingNote = ""; practiceHint = ""
        bidWarning = nil; pendingPracticeBid = nil
        showCorrectPractice = false; showIncorrectPractice = false

        statusMessage = "\(dealer.name) deals — \(vulnerability.rawValue) vulnerable"
        phase = .bidding
        updatePracticeHint()
        triggerAIIfNeeded()
    }

    // MARK: - Private

    private func triggerAIIfNeeded() {
        switch phase {
        case .bidding:
            guard currentBidder != humanSeat else { return }
            triggerAIBid()
        case .playing:
            guard tappableSeat == nil else { return }
            triggerAIPlay()
        default:
            break
        }
    }

    private func triggerAIBid() {
        guard !aiThinking else { return }
        aiThinking = true

        let bidder   = currentBidder
        let hand     = hands[bidder] ?? []
        let snapshot = auction.map { (seat: $0.seat, bid: $0.bid) }
        let vul      = vulnerability
        // The engine bids the partnership's actual convention card.
        let ai       = BiddingAI(settings: conventionSettings)
        let gen      = boardGeneration

        Task {
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            guard self.boardGeneration == gen else { return }
            let bid = ai.selectBid(hand: hand, seat: bidder,
                                   auction: snapshot, vulnerability: vul)
            self.aiThinking = false
            let safeBid = self.legalBids.contains(bid) ? bid : .pass
            self.biddingNote = ai.bidNote(bid: safeBid, seat: bidder, auction: snapshot)
            self.auction.append(AuctionEntry(seat: bidder, bid: safeBid))
            self.updatePracticeHint()
            if self.biddingIsComplete { self.finalizeBidding() }
            else { self.triggerAIIfNeeded() }
        }
    }

    private func updatePracticeHint() {
        guard let convention = practiceConvention else { practiceHint = ""; return }
        // Only show hint when it's South's turn in the bidding phase
        if phase == .bidding && currentBidder == humanSeat {
            if let _ = convention.expectedBid(auction: auction, southHand: hands[humanSeat] ?? []) {
                practiceHint = convention.hintText(southHand: hands[humanSeat] ?? [], auction: auction)
            } else {
                practiceHint = ""
            }
        } else {
            practiceHint = ""
        }
    }

    private func finalizeBidding() {
        bidWarning = nil
        if auction.allSatisfy({ $0.bid == .pass }) {
            statusMessage = "Passed out — no hand played"
            dealer = dealer.next
            let gen = boardGeneration
            Task {
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                guard self.boardGeneration == gen else { return }
                if self.practiceConventions.isEmpty {
                    self.startNewHand()
                } else {
                    self.dealForConvention()   // stay in the drill
                }
            }
            return
        }

        guard let c = buildContract() else { return }
        contract = c
        dummy    = c.declarer.partner
        auctionSnapshot  = auction
        contractSnapshot = c
        dummySnapshot    = dummy
        statusMessage = "\(c.declarer.name) plays \(c.display) — \(c.declarer.next.name) leads"

        phase = .playing
        currentTrick = Trick(leader: c.declarer.next, plays: [], trump: c.strain.suit)
        triggerAIIfNeeded()
    }

    private func buildContract() -> Contract? {
        guard let (lastBid, lastSeat) = lastContractBid,
              let level = lastBid.level, let strain = lastBid.strain else { return nil }

        let winningSide = lastSeat.isNorthSouth
        var declarerSeat = lastSeat
        for entry in auction {
            if entry.seat.isNorthSouth == winningSide && entry.bid.strain == strain {
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
            let gen = boardGeneration
            Task {
                try? await Task.sleep(nanoseconds: 600_000_000)
                guard self.boardGeneration == gen else { return }
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

        currentTrick  = Trick(leader: winner, plays: [], trump: contract?.strain.suit)
        statusMessage = "\(winner.name) wins the trick"
        triggerAIIfNeeded()
    }

    func finishHand() {
        guard let c = contract else { return }
        let tricks = c.declarer.isNorthSouth ? nsTricks : ewTricks
        let result = HandResult(contract: c, declarer: c.declarer,
                                tricksWon: tricks, vulnerability: vulnerability,
                                scoringMode: scoringMode)
        rubberScore.recordHand(result)
        phase = .handResult(made: result.made, tricks: tricks, score: abs(result.netScore))
    }

    private func triggerAIPlay() {
        guard !aiThinking,
              let trick = currentTrick,
              let c = contract else { return }
        aiThinking = true

        let cp = trick.currentPlayer
        let playingSeat: Seat = (c.declarer != humanSeat && cp == dummy) ? dummy! : cp

        let hand          = hands[playingSeat] ?? []
        let isDec         = c.declarer == playingSeat || (c.declarer != humanSeat && playingSeat == dummy)
        let isDum         = playingSeat == dummy
        let trickCopy     = trick
        let completedCopy = completedTricks
        let cCopy         = c
        let gen           = boardGeneration

        Task {
            try? await Task.sleep(nanoseconds: 600_000_000)
            guard self.boardGeneration == gen else { return }
            let card = PlayAI.selectCard(hand: hand, trick: trickCopy, contract: cCopy,
                                         seat: playingSeat, isDeclarer: isDec, isDummy: isDum,
                                         completedTricks: completedCopy)
            self.aiThinking = false
            self.applyCard(card, from: playingSeat)
        }
    }
}
