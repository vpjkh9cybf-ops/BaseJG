// BRIDGE APP — Built 2026-06-07
import SwiftUI

struct BiddingBoxView: View {
    @EnvironmentObject var game: GameState
    @State private var selectedLevel: BidLevel? = nil

    private let strains: [Strain] = [.clubs, .diamonds, .hearts, .spades, .notrump]
    private let levels: [BidLevel] = BidLevel.allCases

    var body: some View {
        VStack(spacing: 8) {
            Text("Your Bid")
                .font(.headline)
                .padding(.top, 4)

            // Level selector row
            HStack(spacing: 6) {
                ForEach(levels, id: \.rawValue) { level in
                    Button("\(level.rawValue)") {
                        selectedLevel = level
                    }
                    .buttonStyle(LevelButtonStyle(isSelected: selectedLevel == level))
                }
            }

            // Strain grid (only shown if level selected)
            if let lvl = selectedLevel {
                HStack(spacing: 6) {
                    ForEach(strains, id: \.rawValue) { strain in
                        let bid = Bid.contract(lvl, strain)
                        let legal = game.legalBids.contains(bid)
                        Button {
                            game.placeBid(bid)
                            selectedLevel = nil
                        } label: {
                            Text(strain.display)
                                .foregroundColor(strain.color)
                                .font(.callout.bold())
                                .frame(width: 40, height: 36)
                                .background(Color(.secondarySystemBackground))
                                .cornerRadius(8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(Color.gray.opacity(0.4), lineWidth: 0.5)
                                )
                        }
                        .disabled(!legal)
                        .opacity(legal ? 1 : 0.3)
                    }
                }
            }

            // Pass / Double / Redouble
            HStack(spacing: 10) {
                BidActionButton(label: "Pass", color: .green) {
                    game.placeBid(.pass)
                    selectedLevel = nil
                }

                if game.legalBids.contains(.double) {
                    BidActionButton(label: "X", color: .red) {
                        game.placeBid(.double)
                        selectedLevel = nil
                    }
                }

                if game.legalBids.contains(.redouble) {
                    BidActionButton(label: "XX", color: .purple) {
                        game.placeBid(.redouble)
                        selectedLevel = nil
                    }
                }
            }
        }
        .padding(10)
        .background(Color(.systemBackground).opacity(0.95))
        .cornerRadius(12)
        .shadow(radius: 4)
    }
}

struct LevelButtonStyle: ButtonStyle {
    var isSelected: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(width: 34, height: 34)
            .background(isSelected ? Color.blue : Color(.secondarySystemBackground))
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(8)
            .font(.callout.bold())
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.gray.opacity(0.3), lineWidth: 0.5)
            )
            .scaleEffect(configuration.isPressed ? 0.92 : 1)
    }
}

struct BidActionButton: View {
    let label: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(.callout.bold())
                .foregroundColor(.white)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(color)
                .cornerRadius(8)
        }
    }
}
