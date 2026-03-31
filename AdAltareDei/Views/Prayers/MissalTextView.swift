import SwiftUI

/// Side-by-side Latin/English display like a traditional hand missal.
/// Latin on the left, English on the right, separated by a gold rule.
struct MissalTextView: View {
    let latinText: String
    let englishText: String

    private var latinLines: [String] {
        splitIntoSentences(latinText)
    }

    private var englishLines: [String] {
        splitIntoSentences(englishText)
    }

    var body: some View {
        VStack(spacing: 0) {
            // Column headers
            HStack(spacing: 0) {
                Text("LATINA")
                    .font(.sectionHeader)
                    .foregroundStyle(.sanctuaryRed)
                    .tracking(1.5)
                    .frame(maxWidth: .infinity)

                Rectangle()
                    .fill(Color.goldLeaf.opacity(0.4))
                    .frame(width: 1)

                Text("ENGLISH")
                    .font(.sectionHeader)
                    .foregroundStyle(.secondary)
                    .tracking(1.5)
                    .frame(maxWidth: .infinity)
            }
            .padding(.bottom, 12)

            Rectangle()
                .fill(Color.goldLeaf.opacity(0.3))
                .frame(height: 1)
                .padding(.bottom, 12)

            // Side-by-side lines
            let lineCount = max(latinLines.count, englishLines.count)
            ForEach(0..<lineCount, id: \.self) { index in
                HStack(alignment: .top, spacing: 0) {
                    // Latin column
                    Text(index < latinLines.count ? latinLines[index] : "")
                        .font(.latinBody)
                        .foregroundStyle(.ink)
                        .lineSpacing(5)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.trailing, 10)

                    // Gold divider
                    Rectangle()
                        .fill(Color.goldLeaf.opacity(0.25))
                        .frame(width: 1)

                    // English column
                    Text(index < englishLines.count ? englishLines[index] : "")
                        .font(.englishBody)
                        .foregroundStyle(.secondary)
                        .lineSpacing(5)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading, 10)
                }
                .padding(.vertical, 6)

                if index < lineCount - 1 {
                    Rectangle()
                        .fill(Color.goldLeaf.opacity(0.08))
                        .frame(height: 1)
                }
            }
        }
        .padding(.vertical, 4)
    }

    /// Splits prayer text into sentences for line-by-line alignment.
    private func splitIntoSentences(_ text: String) -> [String] {
        // First split by explicit newlines
        let paragraphs = text.components(separatedBy: "\n").filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        var result: [String] = []
        for paragraph in paragraphs {
            // Split long paragraphs by sentence-ending punctuation
            let sentences = paragraph
                .replacingOccurrences(of: ". ", with: ".\n")
                .replacingOccurrences(of: "? ", with: "?\n")
                .replacingOccurrences(of: "! ", with: "!\n")
                .components(separatedBy: "\n")
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
            result.append(contentsOf: sentences)
        }
        return result
    }
}

#Preview {
    ScrollView {
        MissalTextView(
            latinText: "Ave María, grátia plena, Dóminus tecum. Benedícta tu in muliéribus, et benedíctus fructus ventris tui, Iesus. Sancta María, Mater Dei, ora pro nobis peccatóribus, nunc et in hora mortis nostræ. Amen.",
            englishText: "Hail Mary, full of grace, the Lord is with thee. Blessed art thou amongst women, and blessed is the fruit of thy womb, Jesus. Holy Mary, Mother of God, pray for us sinners, now and at the hour of our death. Amen."
        )
        .padding()
    }
    .background(Color.parchment)
}
