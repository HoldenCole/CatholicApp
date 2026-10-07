import Foundation

// MARK: - VersicleMarks
//
// The ℣./℟. marks of the template's versicle parts, added at render time:
// the templates carry "Dómine, exáudi oratiónem meam." / "Et clamor meus ad
// te véniat." without marks while the parts the rubrics assemble from
// Divinum Officium carry them, so the hours showed both forms. The labels say
// which part is a versicle, a blessing ("Benedíctio.") or the absolution; the
// marks are language-neutral and the Latin labels stay Latin in every
// vernacular. Kotlin mirror: android/.../data/content/VersicleMarks.kt

enum VersicleMarks {
    struct Marked {
        let lat: String?
        let eng: String?
        let latR: String?
        let engR: String?
    }

    private static let marked = try! NSRegularExpression(pattern: "^(℣\\.|℟\\.|℟\\.br\\.|V\\.|R\\.|Ant\\.|Benedíctio\\.|Benedictio\\.|Absolútio\\.|Absolutio\\.)")
    private static let versicleLabels: Set<String> = [
        "Versicle", "Versus", "Versiculus", "Versicle & Response", "Opening", "Supplication", "Tu autem",
        "Conclusio", "Conclusio (continued)", "Benediction", "Versicle after Nocturn I", "Versicle after Nocturn II", "Versicle after Nocturn III",
    ]

    private static func prefix(_ t: String?, _ mark: String) -> String? {
        guard let t, !t.trimmingCharacters(in: .whitespaces).isEmpty else { return t }
        let s = t.trimmingCharacters(in: .whitespaces)
        if marked.firstMatch(in: s, range: NSRange(s.startIndex..., in: s)) != nil { return t }
        return "\(mark) \(t)"
    }

    /// The response of a short reading: "Tu autem, Dómine... Deo grátias." as ℣./℟. lines.
    private static func tuAutem(_ t: String?) -> String? {
        guard let t else { return nil }
        let cuts = [" Deo grátias", " Thanks be to God", " Demos gracias"].compactMap { t.range(of: $0)?.lowerBound }
        guard let cut = cuts.min() else { return prefix(t, "℣.") }
        return "℣. " + t[..<cut].trimmingCharacters(in: .whitespaces) + "\n℟. " + t[cut...].trimmingCharacters(in: .whitespaces)
    }

    static func of(_ p: Hour.Part) -> Marked {
        guard p.type == "vr" else { return Marked(lat: p.lat, eng: p.eng, latR: p.latR, engR: p.engR) }
        let label = p.label ?? ""
        if label == "Absolutio" {
            return Marked(lat: prefix(p.lat, "Absolútio."), eng: prefix(p.eng, "Absolútio."), latR: prefix(p.latR, "℟."), engR: prefix(p.engR, "℟."))
        }
        if label.hasPrefix("Blessing before") {
            return Marked(lat: prefix(p.lat, "Benedíctio."), eng: prefix(p.eng, "Benedíctio."), latR: prefix(p.latR, "℟."), engR: prefix(p.engR, "℟."))
        }
        if label == "Blessing" {
            return Marked(lat: prefix(p.lat, "℣."), eng: prefix(p.eng, "℣."), latR: prefix(p.latR, "Benedíctio."), engR: prefix(p.engR, "Benedíctio."))
        }
        if label.hasPrefix("Short Reading") {
            return Marked(lat: p.lat, eng: p.eng, latR: tuAutem(p.latR), engR: tuAutem(p.engR))
        }
        if versicleLabels.contains(label) {
            return Marked(lat: prefix(p.lat, "℣."), eng: prefix(p.eng, "℣."), latR: prefix(p.latR, "℟."), engR: prefix(p.engR, "℟."))
        }
        return Marked(lat: p.lat, eng: p.eng, latR: p.latR, engR: p.engR)
    }
}
