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
        let type: String
        var label: String? = nil
        var title: String? = nil
        var ref: String? = nil
        var lat: String? = nil
        var eng: String? = nil
        var latR: String? = nil
        var engR: String? = nil
        var v1Lat: String? = nil
        var v1Eng: String? = nil
        var r1Lat: String? = nil
        var r1Eng: String? = nil
        var v2Lat: String? = nil
        var v2Eng: String? = nil
        var r2Lat: String? = nil
        var r2Eng: String? = nil
        var verses: [Verse]? = nil
        var season: String? = nil
        var engBody: String? = nil
        var variationKey: String? = nil

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
