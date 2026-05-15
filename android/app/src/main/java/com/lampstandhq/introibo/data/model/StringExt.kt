package com.lampstandhq.introibo.data.model

/**
 * Light-weight markup cleaner: the source data uses <em>...</em> around a
 * few single words. Until we wire up styled rendering we just strip
 * the tags for plain display. All other characters pass through.
 */
val String.strippingEm: String
    get() {
        var out = this
        out = out.replace("<br>", "\n")
        out = out.replace("<br/>", "\n")
        out = out.replace("<br />", "\n")
        out = out.replace(Regex("<[^>]+>"), "")
        out = out.replace("&amp;", "&")
        out = out.replace("&nbsp;", " ")
        return out
    }
