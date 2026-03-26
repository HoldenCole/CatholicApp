import SwiftUI

struct PhoneticTextView: View {
    let phoneticText: String

    private var words: [PhoneticWord] {
        PhoneticParser.parse(phoneticText)
    }

    var body: some View {
        WrappingHStack(words: words)
    }
}

/// A custom wrapping layout that renders phonetic words with styled syllables.
struct WrappingHStack: View {
    let words: [PhoneticWord]

    var body: some View {
        // Use a FlowLayout-style approach with Text concatenation
        VStack(alignment: .leading, spacing: 8) {
            ForEach(lineGroups(), id: \.self) { line in
                HStack(spacing: 0) {
                    Text(attributedLine(line))
                        .font(.phoneticBody)
                        .lineSpacing(6)
                }
            }
        }
    }

    private func lineGroups() -> [String] {
        // Split phonetic text by newlines for multi-line prayers
        let fullText = words.map(\.fullText).joined(separator: " ")
        return fullText.components(separatedBy: "\n").filter { !$0.isEmpty }
    }

    private func attributedLine(_ line: String) -> AttributedString {
        let lineWords = PhoneticParser.parse(line)
        var result = AttributedString()

        for (wordIndex, word) in lineWords.enumerated() {
            for (syllableIndex, syllable) in word.syllables.enumerated() {
                var syllableText = AttributedString(syllable.text)

                if syllable.isStressed {
                    syllableText.foregroundColor = .sanctuaryRed
                    syllableText.font = .custom("Palatino-BoldItalic", size: 18)
                } else {
                    syllableText.foregroundColor = .ink
                    syllableText.font = .custom("Palatino-Italic", size: 18)
                }

                result.append(syllableText)

                // Add syllable separator (centered dot) between syllables
                if syllableIndex < word.syllables.count - 1 {
                    var dot = AttributedString("·")
                    dot.foregroundColor = .goldLeaf
                    dot.font = .custom("Palatino-Italic", size: 18)
                    result.append(dot)
                }
            }

            // Add space between words
            if wordIndex < lineWords.count - 1 {
                result.append(AttributedString(" "))
            }
        }

        return result
    }
}

#Preview {
    PhoneticTextView(phoneticText: "A·ve Ma·RÍ·a, GRÁ·ti·a PLÉ·na, DÓ·mi·nus TÉ·cum.")
        .padding()
}
