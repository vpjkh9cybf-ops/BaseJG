// BRIDGE APP — Built 2026-06-07
import SwiftUI

struct AuctionView: View {
    let auction: [AuctionEntry]
    let dealer: Seat
    let contract: Contract?

    // Seat column order: W  N  E  S (clockwise from dealer)
    private let columns: [Seat] = [.west, .north, .east, .south]

    // Pad auction to start on dealer's column
    private var rows: [[Bid?]] {
        let offset = columns.firstIndex(of: dealer)!
        var flat: [Bid?] = Array(repeating: nil, count: offset) + auction.map { $0.bid }
        // Fill to complete rows
        let remainder = flat.count % 4
        if remainder != 0 { flat += Array(repeating: nil, count: 4 - remainder) }
        return stride(from: 0, to: flat.count, by: 4).map { Array(flat[$0..<$0+4]) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(spacing: 0) {
                ForEach(columns, id: \.self) { seat in
                    Text(seat.abbreviation)
                        .font(.callout.bold())
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.vertical, 4)
            .background(Color.blue.opacity(0.15))

            Divider()

            // Rows
            ScrollView {
                VStack(spacing: 0) {
                    ForEach(rows.indices, id: \.self) { rowIdx in
                        HStack(spacing: 0) {
                            ForEach(0..<4) { col in
                                if let bid = rows[rowIdx][col] {
                                    bidCell(bid)
                                } else {
                                    Text("").frame(maxWidth: .infinity)
                                }
                            }
                        }
                        .background(rowIdx % 2 == 0 ? Color.clear : Color.gray.opacity(0.05))
                        Divider()
                    }
                }
            }

            if let c = contract {
                Divider()
                Text("\(c.display) by \(c.declarer.name)")
                    .font(.callout.bold())
                    .padding(6)
            }
        }
        .background(Color(.systemBackground))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.gray.opacity(0.3), lineWidth: 0.5)
        )
    }

    private func bidCell(_ bid: Bid) -> some View {
        let text: String
        let color: Color

        switch bid {
        case .pass:
            text  = "P"
            color = .secondary
        case .double:
            text  = "X"
            color = .red
        case .redouble:
            text  = "XX"
            color = .purple
        case .contract(let level, let strain):
            text  = "\(level.rawValue)\(strain.display)"
            color = strain.color
        }

        return Text(text)
            .font(.callout)
            .foregroundColor(color)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
    }
}
