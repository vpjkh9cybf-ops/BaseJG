import Foundation

struct TrickCard: Identifiable {
    let id = UUID()
    let seat: Seat
    let card: Card
}

struct Trick {
    let leader: Seat
    var plays: [TrickCard] = []
    let trump: Suit?

    var ledSuit: Suit? { plays.first?.card.suit }
    var isComplete: Bool { plays.count == 4 }

    var currentPlayer: Seat {
        if plays.isEmpty { return leader }
        return plays.last!.seat.next
    }

    var winner: Seat? {
        guard isComplete else { return nil }
        var best = plays[0]
        for p in plays.dropFirst() {
            if let t = trump {
                if p.card.suit == t && best.card.suit != t {
                    best = p
                } else if p.card.suit == best.card.suit && p.card.rank > best.card.rank {
                    best = p
                }
            } else {
                if p.card.suit == best.card.suit && p.card.rank > best.card.rank {
                    best = p
                }
            }
        }
        return best.seat
    }

    func card(for seat: Seat) -> Card? {
        plays.first(where: { $0.seat == seat })?.card
    }
}
