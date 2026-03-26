import Foundation

/// Parses phonetic strings into structured PhoneticWord arrays.
///
/// Format: Uppercase syllable = stressed. · = syllable break. Space = word break.
/// Example: "SÍG·num CRÚ·cis" → [PhoneticWord(syllables: [stressed("SÍG"), normal("num")]), ...]
struct PhoneticParser {
    static func parse(_ phoneticString: String) -> [PhoneticWord] {
        let words = phoneticString.components(separatedBy: " ")
        return words.compactMap { wordString -> PhoneticWord? in
            let trimmed = wordString.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return nil }

            let syllableStrings = trimmed.components(separatedBy: "·")
            let syllables = syllableStrings.map { syllable -> PhoneticSyllable in
                let isStressed = isUppercaseSyllable(syllable)
                return PhoneticSyllable(text: syllable, isStressed: isStressed)
            }
            return PhoneticWord(syllables: syllables)
        }
    }

    /// A syllable is stressed if its alphabetic characters are predominantly uppercase.
    private static func isUppercaseSyllable(_ text: String) -> Bool {
        let letters = text.unicodeScalars.filter { CharacterSet.letters.contains($0) }
        guard !letters.isEmpty else { return false }
        let uppercaseCount = letters.filter { CharacterSet.uppercaseLetters.contains($0) }.count
        return uppercaseCount > letters.count / 2
    }
}
