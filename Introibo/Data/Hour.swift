import Foundation

// Matches Introibo/Resources/hours.json — the 8 canonical hours of the
// 1962 Roman Breviary.

struct Hour: Identifiable, Decodable, Hashable, ScheduledHour {
    let slug: String
    let name: String        // Latin name (Matutínum, Laudes, ...)
    // Vernacular metadata is `var` so the Spanish overlay can rewrite it
    // (ContentStore.applyVernacularOverlay). The parts stay Latin/English.
    var eng: String         // Vernacular name
    var time: String        // "at midnight", "at dawn", ...
    let hour: Int           // 0-23
    let minute: Int
    let glyph: String       // Single-letter dial glyph (M, L, I, III...)
    let order: Int          // Roman order for Hora I/II/...
    var intro: String       // Short prose introduction
    var parts: [Part]
    var related: [RelatedLink]? = nil

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
        var antiphonLat: String? = nil
        var antiphonEng: String? = nil

        struct Verse: Decodable, Hashable {
            let lat: String
            var eng: String
        }
    }
}

// Matches Introibo/Resources/marian_antiphons.json.
struct MarianAntiphonData: Identifiable, Decodable, Hashable {
    let slug: String
    let title: String
    var eng: String
    let season: String
    let lat: String
    var engBody: String
    // The ℣/℟ and Orémus that follow the antiphon at Compline.
    var versicleLat: String?
    var versicleEng: String?
    var collectLat: String?
    var collectEng: String?
    // Alma Redemptóris only: the forms used from Christmas to Feb 1.
    var versicleLatChristmas: String?
    var versicleEngChristmas: String?
    var collectLatChristmas: String?
    var collectEngChristmas: String?

    var id: String { slug }

    enum CodingKeys: String, CodingKey {
        case slug, title, eng, season, lat, engBody
        case versicleLat = "versicle_lat"
        case versicleEng = "versicle_eng"
        case collectLat = "collect_lat"
        case collectEng = "collect_eng"
        case versicleLatChristmas = "versicle_lat_christmas"
        case versicleEngChristmas = "versicle_eng_christmas"
        case collectLatChristmas = "collect_lat_christmas"
        case collectEngChristmas = "collect_eng_christmas"
    }
}
