import Foundation

/// The vernacular form of the English headings the Office assembly gives some
/// of its parts ("Versicle", "Blessing before Léctio I", "Marian Antiphon;
/// Salve Regína"). The parts keep their English label, which the rubrics and
/// the versicle marks key on; only the heading drawn on screen is translated
/// (ui_strings office.label.*). Latin headings pass through untouched.
///
/// Android mirror: data/content/OfficeLabels.kt
enum OfficeLabels {
    private static let exact: [String: String] = [
        "Versicle": "versicle", "Hymn": "hymn", "Opening": "opening", "Conclusion": "conclusion",
        "Benediction": "benediction", "Antiphon": "antiphon", "Collect": "collect", "Doxology": "doxology",
        "Antiphon ad Benedictus": "ad_benedictus", "Antiphon ad Magnificat": "ad_magnificat",
        "Versicle & Response": "versicle_response", "Blessing": "blessing", "Supplication": "supplication",
        "Invitatory Antiphon": "invitatory", "Concluding Versicles": "concluding_versicles",
    ]
    // "Blessing before Léctio I" · "Marian Antiphon; Salve Regína" · "Short Reading (1 Peter 5:8-9)" · "Psalm 94; Venite"
    private static let patterns: [(NSRegularExpression, String)] = [
        ("^Blessing before (.+)$", "blessing_before"),
        ("^Marian Antiphon; (.+)$", "marian"),
        ("^Short Reading \\((.+)\\)$", "short_reading"),
        ("^Psalm (\\d+); (.+)$", "psalm"),
    ].map { (try! NSRegularExpression(pattern: $0.0), $0.1) }

    /// `label` as the reader's vernacular names it; the label itself when there is no translation.
    static func display(_ label: String?) -> String? {
        guard let label else { return nil }
        if let key = exact[label] { return ContentStore.shared.uiString("office.label.\(key)", label) }
        let range = NSRange(label.startIndex..., in: label)
        for (re, key) in patterns {
            guard let m = re.firstMatch(in: label, range: range), m.range.length == range.length else { continue }
            var t = ContentStore.shared.uiString("office.label.\(key)", "")
            if t.isEmpty { return label }
            for i in 1..<m.numberOfRanges {
                if let r = Range(m.range(at: i), in: label) { t = t.replacingOccurrences(of: "{\(i - 1)}", with: String(label[r])) }
            }
            return t
        }
        return label
    }
}
