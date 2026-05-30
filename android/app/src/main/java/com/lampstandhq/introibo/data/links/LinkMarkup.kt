package com.lampstandhq.introibo.data.links

import com.lampstandhq.introibo.data.model.strippingEm
import com.lampstandhq.introibo.data.search.DeepLinkTarget

// MARK: - Inline-link markup parser
//
// Scans a body string for `<link target="...">...</link>` boundaries and
// produces a list of TextRun values. NO regex — pure string scanning.
//
// Mirror of:
//   Introibo/Data/Links/LinkMarkup.swift

/** A run of either plain text or a link with display text and target. */
sealed class TextRun {
    data class Text(val text: String) : TextRun()
    data class Link(val text: String, val target: DeepLinkTarget) : TextRun()
}

object LinkMarkup {

    /**
     * Parse inline `<link target="...">...</link>` markup into runs.
     *
     * - Text outside links is passed through [strippingEm].
     * - A body with NO `<link>` tags produces exactly one [TextRun.Text] run
     *   equal to `body.strippingEm`.
     * - If a link's target fails to parse, the inner text becomes a
     *   plain [TextRun.Text] run (graceful degradation).
     */
    fun runs(body: String): List<TextRun> {
        val result = mutableListOf<TextRun>()
        var cursor = 0

        while (cursor < body.length) {
            // Find next "<link " tag
            val openStart = body.indexOf("<link ", cursor)
            if (openStart < 0) break

            // Emit text before the tag
            if (cursor < openStart) {
                val before = body.substring(cursor, openStart).strippingEm
                if (before.isNotEmpty()) {
                    result.add(TextRun.Text(before))
                }
            }

            // Extract target="..." — find 'target="' after "<link "
            val targetAttrStart = body.indexOf("target=\"", openStart + 6)
            if (targetAttrStart < 0) break
            val targetValueStart = targetAttrStart + 8 // length of 'target="'
            val targetAttrEnd = body.indexOf('"', targetValueStart)
            if (targetAttrEnd < 0) break
            val targetStr = body.substring(targetValueStart, targetAttrEnd)

            // Find the closing '>' of the opening tag
            val tagClose = body.indexOf('>', targetAttrEnd)
            if (tagClose < 0) break
            val innerStart = tagClose + 1

            // Find </link>
            val closeTagStart = body.indexOf("</link>", innerStart)
            if (closeTagStart < 0) break
            val innerText = body.substring(innerStart, closeTagStart)

            // Parse the target
            val target = LinkTarget.parse(targetStr)
            if (target != null) {
                result.add(TextRun.Link(text = innerText, target = target))
            } else {
                // Graceful degradation: emit inner text as plain text
                if (innerText.isNotEmpty()) {
                    result.add(TextRun.Text(innerText))
                }
            }

            cursor = closeTagStart + 7 // length of "</link>"
        }

        // Emit any remaining text after the last link
        if (cursor < body.length) {
            val tail = body.substring(cursor).strippingEm
            if (tail.isNotEmpty()) {
                result.add(TextRun.Text(tail))
            }
        }

        return result
    }
}
