package com.lampstandhq.introibo.data.links

import com.lampstandhq.introibo.data.content.ContentStore
import com.lampstandhq.introibo.data.search.DeepLinkTarget

// MARK: - LinkGraph (Phase 3: contextual-links reverse index)
//
// Mirror of:
//   Introibo/Data/Links/LinkGraph.swift
//
// An automatic reverse-index of every OUTBOUND link in the content corpus, keyed
// so a detail screen can ask "who references me?" and render a bidirectional
// "Citatur In · Referenced By" block.
//
// Built once off the main thread on first access via ContentStore, exactly like
// SearchIndex. Adding a content type = add one scanner + one registration line in
// [build], mirroring SearchExtractors / SearchIndex.build.
//
// Outbound links come from two places per entry:
//   1. Inline `<link>` markup in the SAME text fields BilingualLine renders
//      (parsed via LinkMarkup.runs → every Link run's DeepLinkTarget).
//   2. The entry's optional `related: List<RelatedLink>` array (each target
//      string parsed via LinkTarget.parse).
//
// Edges are recorded under the DOCUMENT-HOME canonical key ("type:id", WITHOUT
// the #position) so an article matches links pointing at it with or without a
// specific anchor.

/**
 * A single inbound edge: the SOURCE entry that links to some target, carrying
 * its own deep-link target (to navigate back) plus a display label (its title).
 */
data class LinkSource(
    val target: DeepLinkTarget,   // the SOURCE entry's own target (navigate back to it)
    val label: String,            // display label (source entry's title)
)

class LinkGraph private constructor(
    private val inbound: Map<String, List<LinkSource>>,
) {
    constructor() : this(emptyMap())

    /**
     * The sources that reference [target] (matched at document-home granularity).
     * Already deduplicated by [LinkSource] equality at build time. Returns an
     * empty list when nothing references it.
     */
    fun referencedBy(target: DeepLinkTarget): List<LinkSource> =
        inbound[canonicalKey(target)] ?: emptyList()

    companion object {
        /**
         * Document-home form of a target: "type:id" WITHOUT the `#position`. A
         * link to `reference:confiteor#section-2` and one to `reference:confiteor`
         * both canonicalize to `reference:confiteor`, so the article collects both.
         */
        fun canonicalKey(target: DeepLinkTarget): String =
            "${target.type.wire}:${target.id}"

        /**
         * Scans every content entry, collects its outbound links, and inverts
         * them into the inbound index. Pure function of its inputs — safe off the
         * main thread. Empty corpus / no links → empty index ([referencedBy]
         * returns []).
         */
        fun build(store: ContentStore): LinkGraph {
            val builder = Builder()

            // Registration list: adding a content type = adding one line here
            // (mirrors SearchIndex.build / SearchExtractors).
            LinkScanners.prayers(store.prayers, builder)
            LinkScanners.missalSections(store.missal, builder)
            LinkScanners.propers(store.allPropers, builder)
            LinkScanners.hours(store.hours, builder)
            LinkScanners.reference(store.reference, builder)
            LinkScanners.saints(store.saints, builder)

            return LinkGraph(builder.finish())
        }
    }

    /**
     * Accumulates inbound edges while scanners run, deduping per key so the same
     * source linking to the same target multiple times is recorded once.
     */
    class Builder {
        private val inbound = linkedMapOf<String, MutableList<LinkSource>>()
        private val seen = linkedMapOf<String, MutableSet<LinkSource>>()

        /**
         * Record that [source] links to [outbound]. The edge is filed under the
         * outbound target's document-home canonical key.
         */
        fun record(source: LinkSource, outbound: DeepLinkTarget) {
            val key = canonicalKey(outbound)
            val seenForKey = seen.getOrPut(key) { mutableSetOf() }
            if (!seenForKey.add(source)) return
            inbound.getOrPut(key) { mutableListOf() }.add(source)
        }

        fun finish(): Map<String, List<LinkSource>> = inbound
    }
}
