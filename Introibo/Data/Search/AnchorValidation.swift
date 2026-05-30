import Foundation

// MARK: - anchorExists (Phase 4: link validation)
//
// Mirror of:
//   android/app/src/main/java/com/lampstandhq/introibo/ui/navigation/AnchorValidation.kt
//
// Companion to DeepLinkRouter.resolve. Where `resolve` confirms the CONTENT id
// exists, `anchorExists` additionally confirms the position ANCHOR is one the
// destination detail view can actually scroll to — catching links like
// `missal:foo#kyrei` (typo'd element) or `office:lauds#part:999` (out of range)
// that resolve to a document but land on a dead anchor.
//
// The anchor vocabulary here MUST stay in lock-step with the positions the search
// extractors emit (SearchExtractors.swift):
//   - missal proper → one of the 12 element names, or "feast"; Ordinary sections
//     (store.missal) carry no position.
//   - office        → "part:N" where N < the hour's parts.count.
//   - reference / prayer / saint / calendar → whole-document (position == nil).
//
// Used by the DEBUG assertion in LinkGraph.build and by the offline validator
// (scripts/validate_links.py mirrors these exact rules).

enum AnchorValidation {

    /// The 12 Mass-proper element anchor names emitted per formulary, plus the
    /// title-only "feast" anchor. Mirrors the element list in
    /// SearchExtractors.proper(_:).
    static let missalProperAnchors: Set<String> = [
        "introit", "collect", "epistle", "gradual", "alleluia", "tract",
        "sequence", "gospel", "offertory", "secret", "communion", "postcommunion",
        "feast",
    ]

    /// Confirms that `target.position` is a real, scrollable anchor on the
    /// destination the target resolves to. Returns `true` for a nil position
    /// (document home is always valid). Returns `false` only when a non-nil
    /// position is invalid for the resolved content.
    ///
    /// Precondition for a meaningful result: `target.id` resolves via
    /// DeepLinkRouter.resolve. (A missing id makes the anchor moot; callers
    /// check resolution separately.)
    static func anchorExists(_ target: DeepLinkTarget, store: ContentStore) -> Bool {
        guard let position = target.position else { return true } // document home

        switch target.type {
        case .missal:
            // Proper element / feast anchors. Ordinary sections (store.missal)
            // never carry a position, so any position here must be a proper one.
            return missalProperAnchors.contains(position)

        case .office:
            // "part:N" with 0 <= N < the hour's parts.count.
            guard let hour = store.hour(slug: target.id) else { return false }
            guard let n = parsePartIndex(position) else { return false }
            return n >= 0 && n < hour.parts.count

        case .reference, .calendar, .prayer, .saint:
            // Whole-document content: a non-nil position is never expected.
            return false
        }
    }

    /// Parses the integer N out of a "part:N" anchor; nil if the shape is wrong.
    private static func parsePartIndex(_ position: String) -> Int? {
        let prefix = "part:"
        guard position.hasPrefix(prefix) else { return nil }
        return Int(position.dropFirst(prefix.count))
    }
}
