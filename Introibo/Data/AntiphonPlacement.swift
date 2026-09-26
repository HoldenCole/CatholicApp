import Foundation

// MARK: - AntiphonPlacement
//
// Where the antiphon goes around its psalm(s), after Divinum Officium's
// `antetpsalm`: an antiphon is said before its psalm — or before the first of
// the psalms it covers — and repeated whole (the asterisk dropped) after the
// last of them. Whether the first saying is the whole antiphon or only its
// incipit (up to the asterisk) depends on the books and the rank:
//
//  - Rubrics 1960: every antiphon is doubled (said whole both times).
//  - Older books: doubled at Matins, Lauds and Vespers on doubles (not in the
//    Office of the Dead, nor when the rule says "Matins simplex"); the
//    Benedictus/Magnificat antiphon on doubles and the Advent O antiphons at
//    Vespers (Dec 17-23); never at Prime, the little hours and Compline.
//
// The hour model keeps the antiphon once (on the psalm, or as its own part);
// `runs` finds the psalm runs each antiphon covers and `repeats` gives the
// views the antiphon to print after each run's last psalm. The invitatory is
// not an antiphon of this kind (it is woven into the Venite), and the Special
// scripts of the Triduum and Holy Saturday spell their repeats out
// themselves — those are left alone.
//
// Kotlin mirror: android/.../data/content/AntiphonPlacement.kt

enum AntiphonPlacement {

    private static let psalmTypes: Set<String> = ["psalm", "canticle"]
    private static let canticleKeys: Set<String> = ["ant_laudes", "ant_vespera"]

    /// The antiphon as it is intoned before the psalm: up to the asterisk, a final comma made a period.
    static func intoned(_ text: String) -> String {
        var head = text
        if let r = text.range(of: #"\s+\*"#, options: .regularExpression) {
            head = String(text[..<r.lowerBound])
        }
        head = head.trimmingCharacters(in: .whitespacesAndNewlines)
        if head.isEmpty { return text.trimmingCharacters(in: .whitespacesAndNewlines) }
        if head.hasSuffix(",") { return String(head.dropLast()) + "." }
        return head
    }

    /// The whole antiphon as it is repeated after the psalm(s): the asterisk dropped.
    static func whole(_ text: String) -> String {
        text.replacingOccurrences(of: #"\s*\*\s*"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #" {2,}"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// A standalone antiphon part as intoned: its texts cut at the asterisk.
    static func intonedPart(_ p: Hour.Part) -> Hour.Part {
        var q = p
        q.lat = p.lat.map(intoned)
        q.eng = p.eng.map(intoned)
        return q
    }

    /// One antiphon and the consecutive psalm parts it covers.
    struct Run {
        /// Index of the part that carries the antiphon (a psalm with its own, or a standalone antiphon part).
        let head: Int
        /// Index of the last psalm/canticle under the antiphon.
        let last: Int
        let lat: String
        let eng: String?
        /// The next part already prints this antiphon (a Special script): nothing to repeat.
        let literalAfter: Bool
    }

    struct Repeat {
        let lat: String
        let eng: String?
    }

    static func runs(_ parts: [Hour.Part]) -> [Run] {
        var out: [Run] = []
        var head = -1
        var lat: String? = nil
        var eng: String? = nil
        for i in parts.indices {
            let p = parts[i]
            let next: Hour.Part? = i + 1 < parts.count ? parts[i + 1] : nil
            if p.type == "antiphon" {
                head = -1; lat = nil
                let opensRun = next != nil && psalmTypes.contains(next!.type) && (next!.antiphonLat ?? "").isEmpty
                if opensRun, p.variationKey != "invit", let l = p.lat, !l.trimmingCharacters(in: .whitespaces).isEmpty {
                    head = i; lat = l; eng = p.eng
                }
            } else if psalmTypes.contains(p.type) {
                if let a = p.antiphonLat, !a.isEmpty { head = i; lat = a; eng = p.antiphonEng }
                if let l = lat {
                    let continues = next != nil && psalmTypes.contains(next!.type) && (next!.antiphonLat ?? "").isEmpty
                    if !continues {
                        let literal = next != nil && next!.type == "antiphon" && fold(next!.lat) == fold(l)
                        out.append(Run(head: head, last: i, lat: l, eng: eng, literalAfter: literal))
                        head = -1; lat = nil
                    }
                }
            } else {
                head = -1; lat = nil
            }
        }
        return out
    }

    /// For each part index, the antiphon (Latin, vernacular) to print after that part.
    static func repeats(_ parts: [Hour.Part]) -> [Int: Repeat] {
        var out: [Int: Repeat] = [:]
        for r in runs(parts) where !r.literalAfter {
            out[r.last] = Repeat(lat: whole(r.lat), eng: r.eng.map(whole))
        }
        return out
    }

    /// Marks the antiphons the older books intone only (DO's `$duplexf`). The
    /// 1960 books double every antiphon; parts without a variation key come
    /// from DO's literal scripts and are left as written.
    static func markIntonation(_ parts: [Hour.Part], hourSlug: String, office: OfficeRubrics.Office, rite: MissalRite) -> [Hour.Part] {
        if rite == .rite1962 { return parts }
        let dead = office.communeKey == "C12"
        let doubledPsalms: Bool
        switch hourSlug {
        case "matutinum": doubledPsalms = office.duplex > 2 && !dead && !office.ruleHas("Matins simplex")
        case "laudes", "vesperae": doubledPsalms = office.duplex > 2 && !dead
        default: doubledPsalms = false
        }
        let oAntiphon = hourSlug == "vesperae" && office.temporal && office.date.month == 12 && (17...23).contains(office.date.day)
        let doubledCanticle = office.duplex > 2 || oAntiphon
        let heads = Set(runs(parts).map { $0.head })
        if heads.isEmpty { return parts }
        var out = parts
        for i in heads where i >= 0 {
            let p = parts[i]
            guard p.variationKey != nil else { continue }
            let doubled = (p.type == "antiphon" && canticleKeys.contains(p.variationKey ?? "")) ? doubledCanticle : doubledPsalms
            if !doubled { out[i].antiphonIntoned = true }
        }
        return out
    }

    private static func fold(_ s: String?) -> String {
        (s ?? "").lowercased()
            .replacingOccurrences(of: "*", with: "")
            .replacingOccurrences(of: #"[\s.,:;!?]+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespaces)
    }
}
