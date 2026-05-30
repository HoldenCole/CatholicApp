package com.lampstandhq.introibo.data.links

import kotlinx.serialization.Serializable

// MARK: - Related-link model
//
// A label + link-target string that content models carry as an optional
// `related` list. The target is a raw string parsed via LinkTarget.parse
// at read time (Phase 2 rendering will resolve it).
//
// Mirror of:
//   Introibo/Data/Links/RelatedLink.swift

@Serializable
data class RelatedLink(
    val label: String,
    val target: String,  // link-target string, parsed via LinkTarget.parse
)
