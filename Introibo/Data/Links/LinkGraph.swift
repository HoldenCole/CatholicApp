import Foundation

// MARK: - LinkGraph (Phase 3: contextual-links reverse index)
//
// Mirror of:
//   android/app/src/main/java/com/lampstandhq/introibo/data/links/LinkGraph.kt
//
// An automatic reverse-index of every OUTBOUND link in the content corpus,
// keyed so a detail view can ask "who references me?" and render a bidirectional
// "Citatur In · Referenced By" block.
//
// Built once off the main thread on first access via ContentStore, exactly like
// SearchIndex. Adding a content type = add one scanner + one registration line
// in `build`, mirroring SearchExtractors / SearchIndex.build.
//
// Outbound links come from two places per entry:
//   1. Inline `<link>` markup in the SAME text fields BilingualLine renders
//      (parsed via LinkMarkup.runs → every `.link` run's DeepLinkTarget).
//   2. The entry's optional `related: [RelatedLink]` array (each target string
//      parsed via LinkTarget.parse).
//
// Edges are recorded under the DOCUMENT-HOME canonical key ("type:id", WITHOUT
// the #position) so an article matches links pointing at it with or without a
// specific anchor.

/// A single inbound edge: the SOURCE entry that links to some target, carrying
/// its own deep-link target (to navigate back) plus a display label (its title).
struct LinkSource: Hashable {
    let target: DeepLinkTarget   // the SOURCE entry's own target (navigate back to it)
    let label: String            // display label (source entry's title)
}

struct LinkGraph {

    /// inbound: canonical target wireString (document-home form "type:id", no
    /// #position) → the sources that link to it.
    private let inbound: [String: [LinkSource]]

    init() {
        inbound = [:]
    }

    private init(inbound: [String: [LinkSource]]) {
        self.inbound = inbound
    }

    // MARK: - Canonical key

    /// Document-home form of a target: "type:id" WITHOUT the `#position`. A link
    /// to `reference:confiteor#section-2` and one to `reference:confiteor` both
    /// canonicalize to `reference:confiteor`, so the article collects both.
    static func canonicalKey(_ target: DeepLinkTarget) -> String {
        "\(target.type.rawValue):\(target.id)"
    }

    // MARK: - Query

    /// The sources that reference `target` (matched at document-home granularity).
    /// Deduplicated by `LinkSource` equality so an entry linking to the same
    /// target multiple times appears once. Returns [] when nothing references it.
    func referencedBy(_ target: DeepLinkTarget) -> [LinkSource] {
        inbound[Self.canonicalKey(target)] ?? []
    }

    // MARK: - Build

    /// Scans every content entry, collects its outbound links, and inverts them
    /// into the inbound index. Pure function of its inputs — safe off the main
    /// thread.
    static func build(from store: ContentStore) -> LinkGraph {
        var builder = Builder()

        // Registration list: adding a content type = adding one line here.
        LinkScanners.prayers(store.prayers, into: &builder)
        LinkScanners.reference(store.reference, into: &builder)
        LinkScanners.propers(store.allPropers, into: &builder)
        LinkScanners.saints(store.saints, into: &builder)
        LinkScanners.hours(store.hours, into: &builder)
        LinkScanners.missalSections(store.missal, into: &builder)

        return LinkGraph(inbound: builder.finish())
    }

    // MARK: - Builder

    /// Accumulates inbound edges while scanners run, deduping per key so the same
    /// source linking to the same target multiple times is recorded once.
    struct Builder {
        private var inbound: [String: [LinkSource]] = [:]
        private var seen: [String: Set<LinkSource>] = [:]

        /// Record that `source` links to `outbound`. The edge is filed under the
        /// outbound target's document-home canonical key.
        mutating func record(source: LinkSource, linksTo outbound: DeepLinkTarget) {
            let key = LinkGraph.canonicalKey(outbound)
            if seen[key]?.contains(source) == true { return }
            seen[key, default: []].insert(source)
            inbound[key, default: []].append(source)
        }

        func finish() -> [String: [LinkSource]] { inbound }
    }
}
