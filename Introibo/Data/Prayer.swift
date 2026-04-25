import Foundation

// A single prayer. Matches the shape of Introibo/Resources/prayers.json
// which is a faithful port of prototype/prayers.html's PRAYERS object.

struct Prayer: Identifiable, Decodable, Hashable {
    let slug: String
    let title: String       // Latin title, may contain diacritics
    let eng: String         // English name
    let category: String    // Rosárium | Missa | Devotiónes | Ante Crucifíxum
    let note: String?       // Optional liturgical note / indulgence info
    let lines: [Line]

    var id: String { slug }

    struct Line: Decodable, Hashable {
        let lat: String
        let eng: String
    }
}

// Light-weight markup cleaner: the source data uses <em>…</em> around a
// few single words. Until we wire up attributed rendering we just strip
// the tags for plain display. All other characters pass through.
extension String {
    var strippingEm: String {
        var out = self
        out = out.replacingOccurrences(of: "<br>", with: "\n")
        out = out.replacingOccurrences(of: "<br/>", with: "\n")
        out = out.replacingOccurrences(of: "<br />", with: "\n")
        out = out.replacingOccurrences(of: #"<[^>]+>"#, with: "", options: .regularExpression)
        out = out.replacingOccurrences(of: "&amp;", with: "&")
        out = out.replacingOccurrences(of: "&nbsp;", with: " ")
        return out
    }
}
