import Foundation

// MARK: - SearchExtractors (Phase 1: index core)
//
// Mirror of:
//   android/app/src/main/java/com/lampstandhq/introibo/data/search/SearchExtractors.kt
//
// One extractor per content type. Each turns a slice of ContentStore's
// in-memory content into [SearchDocument]. Extractors are registered in
// SearchIndex.build so adding a content type is:
//   1. add a ContentType case,
//   2. add an extractor,
//   3. register it in SearchIndex.build.
//
// LANGUAGE MODEL (read SearchVernacular.swift for the full story):
//   Content is Latin (`lat`, constant) + ONE user-selected vernacular shown at
//   a time, but the INDEX collects Latin + EVERY available vernacular field so
//   search works for any current/future selection. Extractors NEVER hardcode
//   ".eng" as the only vernacular: structured fragments conform to
//   `Translatable` and expose `translatableFields` (lat + each vernacular in
//   `SearchVernacular.keys`); prose-only English fields are collected through
//   `vernacularProse(...)` which is likewise keyed off `SearchVernacular.keys`.
//   Adding a language is a one-line edit in SearchVernacular.keys plus teaching
//   each model's `vernaculars` map — no extractor edits.

enum SearchExtractors {

    // MARK: Generic translation-text collector

    /// Concatenates an arbitrary list of (optional) translation/text fields
    /// into one whitespace-joined blob, dropping nils/empties. The single
    /// choke point that flattens `lat` + every vernacular field into one
    /// folded blob.
    static func collectText(_ fields: [String?]) -> String {
        fields
            .compactMap { $0 }
            .map { $0.strippingEm }
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            .joined(separator: " ")
    }

    /// Convenience overload for variadic call sites (used for Latin-only or
    /// already-flat field groups).
    static func collectText(_ fields: String?...) -> String {
        collectText(fields)
    }

    /// Collects a per-language prose field that is NOT part of a structured
    /// `Translatable` — e.g. a Saint identity quote or a Reference summary that
    /// today exists only in English. Caller supplies a closure mapping a
    /// vernacular key to that language's value; we iterate `SearchVernacular`
    /// so when an `es`/`fr` prose field is added the same call picks it up.
    static func vernacularProse(_ value: (String) -> String?) -> [String?] {
        SearchVernacular.keys.map { value($0) }
    }

    /// Builds the canonical document id string.
    private static func docID(_ type: ContentType, _ contentID: String, _ position: String? = nil) -> String {
        if let position { return "\(type.rawValue):\(contentID)#\(position)" }
        return "\(type.rawValue):\(contentID)"
    }

    // MARK: - Prayer → 1 doc per prayer

    static func prayers(_ items: [Prayer]) -> [SearchDocument] {
        items.map { p in
            var fields: [String?] = [p.title, p.note]
            fields += vernacularProse { p.vernacular($0) }   // prayer-level body
            for line in p.lines { fields += line.translatableFields }
            // Snippet uses the currently-shipping vernacular (eng) for display.
            let display = collectText([p.eng] + p.lines.map { $0.eng })
            return SearchDocument(
                id: docID(.prayer, p.slug),
                type: .prayer,
                title: p.title,
                subtitle: p.category,
                displayText: display,
                searchText: SearchNormalizer.fold(collectText(fields)),
                target: DeepLinkTarget(type: .prayer, id: p.slug, position: nil)
            )
        }
    }

    // MARK: - MissalSection (Ordinary) → 1 doc per section

    static func missalSections(_ items: [MissalSection]) -> [SearchDocument] {
        items.map { s in
            var fields: [String?] = [s.title, s.label]
            fields += vernacularProse { s.vernacular($0) }   // section heading text
            for line in s.body {
                fields += line.translatableFields
                fields.append(line.rubric)
            }
            let display = collectText([s.english] + s.body.map { $0.eng })
            return SearchDocument(
                id: docID(.missal, s.slug),
                type: .missal,
                title: s.title,
                subtitle: s.label ?? s.english,
                displayText: display,
                searchText: SearchNormalizer.fold(collectText(fields)),
                target: DeepLinkTarget(type: .missal, id: s.slug, position: nil)
            )
        }
    }

    // MARK: - MassProper → 1 doc per element + 1 "feast" title doc

    /// The ordered list of named proper-element fragments on a MassProper.
    /// Each fragment is `Translatable`, so its `translatableFields` already
    /// covers lat + every vernacular. Adding a proper element = add a row here.
    private static func properElements(_ mp: MassProper) -> [(name: String, fields: [String?])] {
        func fields(_ t: Translatable?) -> [String?] { t?.translatableFields ?? [] }
        return [
            ("introit",       fields(mp.introit)),
            ("collect",       fields(mp.collect)),
            ("epistle",       fields(mp.epistle)),
            ("gradual",       fields(mp.gradual)),
            ("alleluia",      fields(mp.alleluia)),
            ("tract",         fields(mp.tract)),
            ("sequence",      fields(mp.sequence)),
            ("gospel",        fields(mp.gospel)),
            ("offertory",     fields(mp.offertory)),
            ("secret",        fields(mp.secret)),
            ("communion",     fields(mp.communion)),
            ("postcommunion", fields(mp.postcommunion)),
        ]
    }

    static func propers(_ items: [MassProper]) -> [SearchDocument] {
        var docs: [SearchDocument] = []
        for mp in items {
            // 1 title-only "feast" doc for calendar findability. Title is Latin,
            // english is the vernacular; collected generically.
            var feastFields: [String?] = [mp.title]
            feastFields += vernacularProse { mp.vernacular($0) }
            let feastSearch = SearchNormalizer.fold(collectText(feastFields))
            if !feastSearch.isEmpty {
                docs.append(SearchDocument(
                    id: docID(.missal, mp.slug, "feast"),
                    type: .missal,
                    title: mp.title,
                    subtitle: mp.english,
                    displayText: collectText(mp.english),
                    searchText: feastSearch,
                    target: DeepLinkTarget(type: .missal, id: mp.slug, position: "feast")
                ))
            }
            // 1 doc per element that has text.
            for element in properElements(mp) {
                let folded = SearchNormalizer.fold(collectText(element.fields))
                if folded.isEmpty { continue }
                docs.append(SearchDocument(
                    id: docID(.missal, mp.slug, element.name),
                    type: .missal,
                    title: mp.title,
                    subtitle: element.name,
                    displayText: collectText(element.fields),
                    searchText: folded,
                    target: DeepLinkTarget(type: .missal, id: mp.slug, position: element.name)
                ))
            }
        }
        return docs
    }

    // MARK: - Hour (template hours) → 1 doc per Part that has text

    /// Every translatable field on an Hour.Part, collected lat + vernacular via
    /// the part's own `translatableFields` plus its flattened verses.
    private static func partFields(_ part: Hour.Part) -> [String?] {
        var f: [String?] = [part.label, part.title]
        f += part.translatableFields
        if let verses = part.verses {
            for v in verses { f += v.translatableFields }
        }
        return f
    }

    static func hours(_ items: [Hour]) -> [SearchDocument] {
        var docs: [SearchDocument] = []
        for hour in items {
            for (i, part) in hour.parts.enumerated() {
                let fields = partFields(part)
                let folded = SearchNormalizer.fold(collectText(fields))
                if folded.isEmpty { continue }
                let partTitle = part.title ?? part.label ?? hour.eng
                docs.append(SearchDocument(
                    id: docID(.office, hour.slug, "part:\(i)"),
                    type: .office,
                    title: hour.eng,
                    subtitle: partTitle,
                    displayText: collectText(fields),
                    searchText: folded,
                    target: DeepLinkTarget(type: .office, id: hour.slug, position: "part:\(i)")
                ))
            }
        }
        return docs
    }

    // MARK: - ReferenceEntry → reference (1/entry) or calendar (1/season)

    private static let calendarCategory = "Calendarium"

    static func reference(_ items: [ReferenceEntry]) -> [SearchDocument] {
        items
            .filter { $0.cat != calendarCategory }
            .map { e in
                var fields: [String?] = [e.title, e.latin]
                // Prose body (summary/history/practice/notes) is per-vernacular.
                fields += vernacularProse { e.vernacularProse($0) }
                fields += (e.scripture?.translatableFields ?? [])
                return SearchDocument(
                    id: docID(.reference, e.slug),
                    type: .reference,
                    title: e.title,
                    subtitle: e.cat,
                    displayText: collectText(e.summary),
                    searchText: SearchNormalizer.fold(collectText(fields)),
                    target: DeepLinkTarget(type: .reference, id: e.slug, position: nil)
                )
            }
    }

    static func calendar(_ items: [ReferenceEntry]) -> [SearchDocument] {
        items
            .filter { $0.cat == calendarCategory }
            .map { e in
                var fields: [String?] = [e.title, e.latin]
                fields += vernacularProse { e.vernacularProse($0) }
                return SearchDocument(
                    id: docID(.calendar, e.slug),
                    type: .calendar,
                    title: e.title,
                    subtitle: e.latin ?? e.cat,
                    displayText: collectText(e.summary),
                    searchText: SearchNormalizer.fold(collectText(fields)),
                    target: DeepLinkTarget(type: .calendar, id: e.slug, position: nil)
                )
            }
    }

    // MARK: - Saint → 1 identity + 1 per section + 1 per prayer

    static func saints(_ items: [Saint]) -> [SearchDocument] {
        var docs: [SearchDocument] = []
        for s in items {
            // Identity doc. Name is language-neutral; quote/penance are prose.
            var idFields: [String?] = [s.name, s.title, s.penanceLatin]
            idFields += vernacularProse { s.vernacularProse($0) }
            docs.append(SearchDocument(
                id: docID(.saint, s.slug),
                type: .saint,
                title: s.name,
                subtitle: s.title,
                displayText: collectText(s.quote),
                searchText: SearchNormalizer.fold(collectText(idFields)),
                target: DeepLinkTarget(type: .saint, id: s.slug, position: nil)
            ))
            // Section docs.
            for (i, section) in s.sections.enumerated() {
                var fields: [String?] = section.translatableFields
                for pr in section.practices { fields.append(pr.t); fields.append(pr.d) }
                let folded = SearchNormalizer.fold(collectText(fields))
                if folded.isEmpty { continue }
                docs.append(SearchDocument(
                    id: docID(.saint, s.slug, "section:\(i)"),
                    type: .saint,
                    title: s.name,
                    subtitle: s.title,
                    displayText: collectText(section.eng),
                    searchText: folded,
                    target: DeepLinkTarget(type: .saint, id: s.slug, position: "section:\(i)")
                ))
            }
            // Prayer docs.
            for (i, pr) in (s.prayers ?? []).enumerated() {
                var fields: [String?] = [pr.title, pr.latin, pr.note]
                fields += vernacularProse { pr.vernacular($0) }
                let folded = SearchNormalizer.fold(collectText(fields))
                if folded.isEmpty { continue }
                docs.append(SearchDocument(
                    id: docID(.saint, s.slug, "prayer:\(i)"),
                    type: .saint,
                    title: pr.title,
                    subtitle: s.name,
                    displayText: collectText(pr.eng),
                    searchText: folded,
                    target: DeepLinkTarget(type: .saint, id: s.slug, position: "prayer:\(i)")
                ))
            }
        }
        return docs
    }
}

// MARK: - Translatable conformances
//
// The ONLY place a vernacular field name appears. When the content model gains
// `es`/`fr`/… fields, add them to `vernaculars` (and the prose accessors) here
// and to `SearchVernacular.keys`; nothing in the extractors above changes.

extension ProperText: Translatable {
    var latText: String? { lat }
    var vernaculars: [String: String?] { ["eng": eng] }
}

extension ProperReading: Translatable {
    var latText: String? { lat }
    var vernaculars: [String: String?] { ["eng": eng] }
}

extension Prayer.Line: Translatable {
    var latText: String? { lat }
    var vernaculars: [String: String?] { ["eng": eng] }
}

extension MissalSection.Line: Translatable {
    var latText: String? { lat }
    var vernaculars: [String: String?] { ["eng": eng] }
}

extension Hour.Part.Verse: Translatable {
    var latText: String? { lat }
    var vernaculars: [String: String?] { ["eng": eng] }
}

extension ReferenceEntry.Scripture: Translatable {
    var latText: String? { lat }
    var vernaculars: [String: String?] { ["eng": eng] }
}

extension Saint.Section: Translatable {
    var latText: String? { lat }
    var vernaculars: [String: String?] { ["eng": eng] }
}

// Hour.Part carries many parallel lat/eng pairs; expose them all so a single
// `translatableFields` yields every paired field for both languages.
extension Hour.Part: Translatable {
    var latText: String? {
        SearchExtractors.collectText(lat, latR, v1Lat, r1Lat, v2Lat, r2Lat, antiphonLat)
    }
    var vernaculars: [String: String?] {
        ["eng": SearchExtractors.collectText(eng, engR, v1Eng, r1Eng, v2Eng, r2Eng, engBody, antiphonEng)]
    }
}

// MARK: - Prose-only vernacular accessors
//
// These models currently hold their vernacular as flat English prose (no Latin
// counterpart per field). Each returns the value for a given vernacular key so
// the extractor stays generic; add `es`/`fr` cases here alongside the model
// fields when those languages land.

extension Prayer {
    func vernacular(_ key: String) -> String? {
        switch key {
        case "eng": return eng
        default: return nil
        }
    }
}

extension MissalSection {
    func vernacular(_ key: String) -> String? {
        switch key {
        case "eng": return english
        default: return nil
        }
    }
}

extension MassProper {
    /// The feast's vernacular display name (`english` today).
    func vernacular(_ key: String) -> String? {
        switch key {
        case "eng": return english
        default: return nil
        }
    }
}

extension ReferenceEntry {
    /// All prose body fields for a vernacular, joined. English-only today.
    func vernacularProse(_ key: String) -> String? {
        switch key {
        case "eng": return SearchExtractors.collectText(summary, history, practice, notes)
        default: return nil
        }
    }
}

extension Saint {
    /// Identity-level prose (quote + penance) for a vernacular. English today.
    func vernacularProse(_ key: String) -> String? {
        switch key {
        case "eng": return SearchExtractors.collectText(quote, penance)
        default: return nil
        }
    }
}

extension Saint.SaintPrayer {
    func vernacular(_ key: String) -> String? {
        switch key {
        case "eng": return eng
        default: return nil
        }
    }
}
