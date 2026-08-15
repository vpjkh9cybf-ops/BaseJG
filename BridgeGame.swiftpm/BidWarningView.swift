// Conventional Wisdom — modified 2026-06-27 15:12 UTC
import SwiftUI

struct BidWarningView: View {
    let analysis: BidAnalysis
    @State private var expanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top, spacing: 6) {
                Image(systemName: analysis.isForcingPass ? "exclamationmark.triangle.fill" : "lightbulb.fill")
                    .foregroundColor(analysis.isForcingPass ? .red : .yellow)
                    .font(.caption)
                VStack(alignment: .leading, spacing: 2) {
                    Text(analysis.isForcingPass ? "\u{26A0} Forcing Bid" : analysis.convention)
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(analysis.isForcingPass ? .red : .yellow)
                    Text(analysis.rationale)
                        .font(.system(size: 10))
                        .foregroundColor(.white.opacity(0.9))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                Button(expanded ? "\u{25B2}" : "Why?") { expanded.toggle() }
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(.yellow.opacity(0.8))
            }
            if expanded {
                Text(analysis.detailedExplanation)
                    .font(.system(size: 9))
                    .foregroundColor(.white.opacity(0.75))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 2)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(analysis.isForcingPass ? Color.red.opacity(0.18) : Color.yellow.opacity(0.12))
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(analysis.isForcingPass ? Color.red.opacity(0.4) : Color.yellow.opacity(0.3), lineWidth: 0.5)
        )
    }
}
