package com.lampstandhq.introibo.data.search

import kotlinx.serialization.SerialName
import kotlinx.serialization.Serializable

// MARK: - Search models (Phase 1: index core)
//
// Mirror of:
//   Introibo/Data/Search/SearchModels.swift

/**
 * The kind of content a search hit points at. Adding a new content type =
 * add one entry here + one extractor in SearchExtractors.
 *
 * [wire] is the lowercase token used in document ids / deep links and MUST
 * match the iOS `ContentType.rawValue` (the Swift enum's String raw value).
 */
@Serializable
enum class ContentType(val wire: String) {
    @SerialName("prayer") PRAYER("prayer"),
    @SerialName("missal") MISSAL("missal"),
    @SerialName("office") OFFICE("office"),
    @SerialName("reference") REFERENCE("reference"),
    @SerialName("saint") SAINT("saint"),
    @SerialName("calendar") CALENDAR("calendar"),
}

/**
 * A stable, opaque pointer into the app's content used for deep linking
 * (navigation is Phase 3; for now this is just data carried by documents).
 */
@Serializable
data class DeepLinkTarget(
    val type: ContentType,
    val id: String,          // slug / section id
    val position: String? = null, // opaque stable anchor; null = document home
) {
    /**
     * Serializes back to the `type:id` / `type:id#position` string form — the
     * inverse of `LinkTarget.parse`. Used as the stable tag for an inline link
     * annotation. Mirrors iOS `DeepLinkTarget.wireString`. (Phase 2)
     */
    val wireString: String
        get() = "${type.wire}:$id" + (position?.let { "#$it" } ?: "")
}

/**
 * One indexed unit. [searchText] is the folded match target; [title] and
 * [displayText] keep diacritics for display/snippets.
 */
data class SearchDocument(
    val id: String,          // "<type>:<contentId>[#<position>]"
    val type: ContentType,
    val title: String,       // display title WITH diacritics
    val subtitle: String?,
    val displayText: String, // snippet source WITH diacritics
    val searchText: String,  // folded / normalized — the match target
    val target: DeepLinkTarget,
)
