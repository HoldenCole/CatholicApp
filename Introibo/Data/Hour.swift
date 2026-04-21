import Foundation

// Matches Introibo/Resources/hours.json — the 8 canonical hours of the
// 1962 Roman Breviary.

struct Hour: Identifiable, Decodable, Hashable {
    let slug: String
    let name: String        // Latin name (Matutínum, Laudes, ...)
    let eng: String         // English name
    let time: String        // "at midnight", "at dawn", ...
    let hour: Int           // 0-23
    let minute: Int
    let glyph: String       // Single-letter dial glyph (M, L, I, III...)
    let order: Int          // Roman order for Hora I/II/...
    let intro: String       // Short prose introduction
    let parts: [Part]

    var id: String { slug }

    // Heterogeneous parts. We decode into a sum-type-ish struct that
    // carries whichever fields are present; views switch on `type`.
    struct Part: Decodable, Hashable {
        let type: String    // vr|hymn|antiphon|psalm|capitulum|canticle|pater|
                            // collect|closing|confiteor|responsory|marian
        let label: String?
        let title: String?
        let ref: String?
        let lat: String?
        let eng: String?
        let latR: String?   // response pair for vr / responsory
        let engR: String?
        let v1Lat: String?
        let v1Eng: String?
        let r1Lat: String?
        let r1Eng: String?
        let v2Lat: String?
        let v2Eng: String?
        let r2Lat: String?
        let r2Eng: String?
        let verses: [Verse]?
        // marian antiphon
        let season: String?
        let engBody: String?

        struct Verse: Decodable, Hashable {
            let lat: String
            let eng: String
        }
    }
}

// Matches Introibo/Resources/marian_antiphons.json.
struct MarianAntiphonData: Identifiable, Decodable, Hashable {
    let slug: String
    let title: String
    let eng: String
    let season: String
    let lat: String
    let engBody: String

    var id: String { slug }
}
