package com.lampstandhq.introibo.ui.navigation

import com.lampstandhq.introibo.data.content.ContentStore
import com.lampstandhq.introibo.data.search.ContentType
import com.lampstandhq.introibo.data.search.DeepLinkTarget

// MARK: - anchorExists (Phase 4: link validation)
//
// Mirror of:
//   Introibo/Data/Search/AnchorValidation.swift
//
// Companion to DeepLinkRouter.resolve. Where `resolve` confirms the CONTENT id
// exists, [anchorExists] additionally confirms the position ANCHOR is one the
// destination detail screen can actually scroll to — catching links like
// `missal:foo#kyrei` (typo'd element) or `office:lauds#part:999` (out of range)
// that resolve to a document but land on a dead anchor.
//
// The anchor vocabulary here MUST stay in lock-step with the positions the
// search extractors emit:
//   - missal proper -> one of the 12 element names, or "feast"; Ordinary
//     sections (ContentStore.missal) carry no position.
//   - office        -> "part:N" where N < the hour's parts.count.
//   - reference / prayer / saint / calendar -> whole-document (position null).
//
// Used by the debug assertion in LinkGraph.build and by the offline validator
// (scripts/validate_links.py mirrors these exact rules).

object AnchorValidation {

    /**
     * The 12 Mass-proper element anchor names emitted per formulary, plus the
     * title-only "feast" anchor. Mirrors the element list in the search proper
     * extractor.
     */
    val missalProperAnchors: Set<String> = setOf(
        "introit", "collect", "epistle", "gradual", "alleluia", "tract",
        "sequence", "gospel", "offertory", "secret", "communion", "postcommunion",
        "feast",
    )

    /**
     * Confirms that [target].position is a real, scrollable anchor on the
     * destination the target resolves to. Returns true for a null position
     * (document home is always valid). Returns false only when a non-null
     * position is invalid for the resolved content.
     *
     * Precondition for a meaningful result: [target].id resolves via
     * DeepLinkRouter.resolve (a missing id makes the anchor moot; callers check
     * resolution separately).
     */
    fun anchorExists(target: DeepLinkTarget): Boolean {
        val position = target.position ?: return true // document home

        return when (target.type) {
            ContentType.MISSAL ->
                // Proper element / feast anchors. Ordinary sections never carry a
                // position, so any position here must be a proper one.
                position in missalProperAnchors

            ContentType.OFFICE -> {
                // "part:N" with 0 <= N < the hour's parts.count.
                val hour = ContentStore.hour(target.id) ?: return false
                val n = parsePartIndex(position) ?: return false
                n in 0 until hour.parts.size
            }

            ContentType.REFERENCE, ContentType.CALENDAR,
            ContentType.PRAYER, ContentType.SAINT ->
                // Whole-document content: a non-null position is never expected.
                false
        }
    }

    /** Parses the integer N out of a "part:N" anchor; null if the shape is wrong. */
    private fun parsePartIndex(position: String): Int? {
        val prefix = "part:"
        if (!position.startsWith(prefix)) return null
        return position.removePrefix(prefix).toIntOrNull()
    }
}
