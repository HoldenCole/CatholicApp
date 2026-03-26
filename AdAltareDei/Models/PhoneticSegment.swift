import Foundation

struct PhoneticWord: Identifiable {
    let id = UUID()
    let syllables: [PhoneticSyllable]

    var fullText: String {
        syllables.map(\.text).joined(separator: "·")
    }
}

struct PhoneticSyllable: Identifiable {
    let id = UUID()
    let text: String
    let isStressed: Bool
}
