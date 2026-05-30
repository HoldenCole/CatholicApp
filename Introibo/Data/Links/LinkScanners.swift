import Foundation

// MARK: - LinkScanners (Phase 3: contextual-links reverse index)
//
// Mirror of:
//   android/app/src/main/java/com/lampstandhq/introibo/data/links/LinkScanners.kt
//
// One scanner per content type. Each computes an entry's OWN DeepLinkTarget +
// display label (the LinkSource that will be shown under "Referenced By"), then
// finds every OUTBOUND link from that entry and records the inverse edge into the
// LinkGraph.Builder.
//
// Outbound links come from two places, exactly mirroring what a detail view +
// RelatedLinksSection render:
//   1. Inline `<link>` markup in the same text fields BilingualLine renders —
//      collected by running `LinkMarkup.runs` over each field and keeping every
//      `.link` run's target.
//   2. The entry's optional `related: [RelatedLink]` array — each `target`
//      string parsed via `LinkTarget.parse`.
//
// Scanners are registered in LinkGraph.build so adding a content type is one
// scanner + one registration line (mirrors SearchExtractors / SearchIndex.build).

enum LinkScanners {

    // MARK: - Inline-link target collection

    /// Every `.link` run target found across the given (optional) text fields.
    /// Fields with no `<link>` markup contribute nothing. The single choke point
    /// for inline-link extraction.
    private static func inlineTargets(_ fields: [String?]) -> [DeepLinkTarget] {
        var out: [DeepLinkTarget] = []
        for field in fields {
            guard let field, !field.isEmpty else { continue }
            for run in LinkMarkup.runs(field) {
                if case let .link(_, target) = run {
                    out.append(target)
                }
            }
        }
        return out
    }

    /// Parsed targets from an entry's `related[]` array (nil/malformed dropped).
    private static func relatedTargets(_ related: [RelatedLink]?) -> [DeepLinkTarget] {
        (related ?? []).compactMap { LinkTarget.parse($0.target) }
    }

    /// Records one source's outbound edges (inline + related) into the builder.
    private static func record(
        source: LinkSource,
        inlineFields: [String?],
        related: [RelatedLink]?,
        into builder: inout LinkGraph.Builder
    ) {
        for target in inlineTargets(inlineFields) {
            builder.record(source: source, linksTo: target)
        }
        for target in relatedTargets(related) {
            builder.record(source: source, linksTo: target)
        }
    }

    // MARK: - Prayer

    static func prayers(_ items: [Prayer], into builder: inout LinkGraph.Builder) {
        for p in items {
            let source = LinkSource(
                target: DeepLinkTarget(type: .prayer, id: p.slug, position: nil),
                label: p.title
            )
            var fields: [String?] = [p.note]
            for line in p.lines { fields.append(line.lat); fields.append(line.eng) }
            record(source: source, inlineFields: fields, related: p.related, into: &builder)
        }
    }

    // MARK: - MissalSection (Ordinary)

    static func missalSections(_ items: [MissalSection], into builder: inout LinkGraph.Builder) {
        for s in items {
            let source = LinkSource(
                target: DeepLinkTarget(type: .missal, id: s.slug, position: nil),
                label: s.title
            )
            var fields: [String?] = []
            for line in s.body { fields.append(line.lat); fields.append(line.eng) }
            record(source: source, inlineFields: fields, related: nil, into: &builder)
        }
    }

    // MARK: - MassProper

    static func propers(_ items: [MassProper], into builder: inout LinkGraph.Builder) {
        for mp in items {
            let source = LinkSource(
                target: DeepLinkTarget(type: .missal, id: mp.slug, position: nil),
                label: mp.title
            )
            let fields: [String?] = [
                mp.introit.lat, mp.introit.eng,
                mp.collect.lat, mp.collect.eng,
                mp.epistle.lat, mp.epistle.eng,
                mp.gradual?.lat, mp.gradual?.eng,
                mp.alleluia?.lat, mp.alleluia?.eng,
                mp.tract?.lat, mp.tract?.eng,
                mp.sequence?.lat, mp.sequence?.eng,
                mp.gospel.lat, mp.gospel.eng,
                mp.offertory.lat, mp.offertory.eng,
                mp.secret.lat, mp.secret.eng,
                mp.communion.lat, mp.communion.eng,
                mp.postcommunion.lat, mp.postcommunion.eng,
            ]
            record(source: source, inlineFields: fields, related: mp.related, into: &builder)
        }
    }

    // MARK: - Hour

    static func hours(_ items: [Hour], into builder: inout LinkGraph.Builder) {
        for hour in items {
            let source = LinkSource(
                target: DeepLinkTarget(type: .office, id: hour.slug, position: nil),
                label: hour.eng
            )
            var fields: [String?] = []
            for part in hour.parts {
                fields.append(part.lat);  fields.append(part.eng)
                fields.append(part.latR); fields.append(part.engR)
                fields.append(part.v1Lat); fields.append(part.v1Eng)
                fields.append(part.r1Lat); fields.append(part.r1Eng)
                fields.append(part.v2Lat); fields.append(part.v2Eng)
                fields.append(part.r2Lat); fields.append(part.r2Eng)
                fields.append(part.engBody)
                fields.append(part.antiphonLat); fields.append(part.antiphonEng)
                if let verses = part.verses {
                    for v in verses { fields.append(v.lat); fields.append(v.eng) }
                }
            }
            record(source: source, inlineFields: fields, related: hour.related, into: &builder)
        }
    }

    // MARK: - ReferenceEntry (reference + calendar)

    static func reference(_ items: [ReferenceEntry], into builder: inout LinkGraph.Builder) {
        for e in items {
            // Calendar entries (cat == "Calendarium") deep-link as .calendar; all
            // others as .reference — matching the search extractor split.
            let type: ContentType = (e.cat == "Calendarium") ? .calendar : .reference
            let source = LinkSource(
                target: DeepLinkTarget(type: type, id: e.slug, position: nil),
                label: e.title
            )
            var fields: [String?] = [e.summary, e.history, e.practice, e.notes]
            if let scripture = e.scripture { fields.append(scripture.lat); fields.append(scripture.eng) }
            record(source: source, inlineFields: fields, related: e.related, into: &builder)
        }
    }

    // MARK: - Saint

    static func saints(_ items: [Saint], into builder: inout LinkGraph.Builder) {
        for s in items {
            let source = LinkSource(
                target: DeepLinkTarget(type: .saint, id: s.slug, position: nil),
                label: s.name
            )
            var fields: [String?] = [s.quote]
            for section in s.sections { fields.append(section.lat); fields.append(section.eng) }
            for pr in (s.prayers ?? []) {
                fields.append(pr.latin); fields.append(pr.eng); fields.append(pr.note)
            }
            record(source: source, inlineFields: fields, related: s.related, into: &builder)
        }
    }
}
