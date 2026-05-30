package com.lampstandhq.introibo.data.links

import com.lampstandhq.introibo.data.search.ContentType
import com.lampstandhq.introibo.data.search.DeepLinkTarget

// MARK: - Link-target string parser
//
// Grammar: "type:id" or "type:id#position"
//   - Split on FIRST ":" for type vs rest
//   - Split rest on FIRST "#" for id vs position
//   - type must be a valid ContentType wire value
//   - Returns null on parse failure
//
// Mirror of:
//   Introibo/Data/Links/LinkTarget.swift

object LinkTarget {

    /** Parse a link-target string into a [DeepLinkTarget].
     *  Returns `null` if the string is malformed or the type is unknown. */
    fun parse(raw: String): DeepLinkTarget? {
        val colonIdx = raw.indexOf(':')
        if (colonIdx < 0) return null

        val typeStr = raw.substring(0, colonIdx)
        if (typeStr.isEmpty()) return null
        val type = ContentType.entries.firstOrNull { it.wire == typeStr } ?: return null

        val afterColon = raw.substring(colonIdx + 1)
        if (afterColon.isEmpty()) return null

        val hashIdx = afterColon.indexOf('#')
        return if (hashIdx >= 0) {
            val id = afterColon.substring(0, hashIdx)
            val position = afterColon.substring(hashIdx + 1)
            if (id.isEmpty()) return null
            DeepLinkTarget(type = type, id = id, position = position.ifEmpty { null })
        } else {
            DeepLinkTarget(type = type, id = afterColon, position = null)
        }
    }
}
