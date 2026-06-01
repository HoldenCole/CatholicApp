package com.lampstandhq.introibo.export

import com.lampstandhq.introibo.data.model.MassProper
import com.lampstandhq.introibo.data.model.ProperText
import java.util.Locale

/**
 * Generates styled HTML documents from Mass proper data, matching the
 * parchment + sanctuary-red visual identity of the app. The resulting
 * HTML is a self-contained document suitable for sharing or printing
 * to PDF from any browser.
 */
object MassHTMLExporter {

    // MARK: - Public API

    /**
     * Returns a complete HTML5 document string for the given Mass proper.
     * All CSS is inlined so the document renders correctly anywhere.
     */
    fun properHTML(proper: MassProper): String {
        val sections = buildString {
            // Required sections
            append(sectionHTML("Introitus  ·  Introit", proper.introit.lat, proper.introit.eng, proper.introit.ref))
            append(sectionHTML("Orátio  ·  Collect", proper.collect.lat, proper.collect.eng, proper.collect.ref))
            append(sectionHTML("Léctio  ·  Epistle", proper.epistle.lat, proper.epistle.eng, proper.epistle.ref))

            // Optional chant sections
            proper.gradual?.let {
                append(sectionHTML("Graduále  ·  Gradual", it.lat, it.eng, it.ref))
            }
            proper.alleluia?.let {
                append(sectionHTML("Allelúja  ·  Alleluia", it.lat, it.eng, it.ref))
            }
            proper.tract?.let {
                append(sectionHTML("Tractus  ·  Tract", it.lat, it.eng, it.ref))
            }
            proper.sequence?.let {
                append(sectionHTML("Sequéntia  ·  Sequence", it.lat, it.eng, it.ref))
            }

            // Required sections (continued)
            append(sectionHTML("Evangélium  ·  Gospel", proper.gospel.lat, proper.gospel.eng, proper.gospel.ref))
            append(sectionHTML("Offertórium  ·  Offertory", proper.offertory.lat, proper.offertory.eng, proper.offertory.ref))
            append(sectionHTML("Secréta  ·  Secret", proper.secret.lat, proper.secret.eng, proper.secret.ref))

            // Preface note (between Secret and Communion)
            proper.preface?.let { preface ->
                val capitalized = preface.replaceFirstChar {
                    if (it.isLowerCase()) it.titlecase(Locale.ROOT) else it.toString()
                }
                append("""<p class="preface-note">Præfátio: ${escapeHTML(capitalized)}</p>""")
                append("""<div class="divider"></div>""")
            }

            append(sectionHTML("Commúnio  ·  Communion", proper.communion.lat, proper.communion.eng, proper.communion.ref))
            append(sectionHTML("Postcommúnio  ·  Postcommunion", proper.postcommunion.lat, proper.postcommunion.eng, proper.postcommunion.ref))
        }

        return document(
            title = proper.title,
            englishTitle = proper.englishTitle,
            body = sections,
        )
    }

    /** Returns a styled HTML document for a calendar day detail. */
    fun calendarDayHTML(
        latinTitle: String,
        englishTitle: String?,
        longDate: String,
        colour: String?,
        colourHex: String?,
        season: String,
        flags: List<String>,
        penanceTitle: String,
        penanceDesc: String,
        penanceStrict: Boolean,
        discipline: String,
    ): String {
        val body = buildString {
            if (colour != null) {
                append("""<div class="info-row"><span class="info-label">LITURGICAL COLOUR</span>""")
                if (colourHex != null) {
                    append("""<span style="display:inline-block;width:10px;height:10px;border-radius:50%;background:$colourHex;margin-right:6px;vertical-align:middle;"></span>""")
                }
                append("""<span class="info-value">${escapeHTML(colour)}</span></div>""")
            }
            append("""<div class="info-row"><span class="info-label">SEASON</span><span class="info-value">${escapeHTML(season)}</span></div>""")
            flags.forEach { append("""<p class="flag">${escapeHTML(it)}</p>""") }
            val strictClass = if (penanceStrict) " strict" else ""
            append("""<div class="penance-card$strictClass">""")
            append("""<div class="penance-header"><span class="info-label">FASTING &amp; ABSTINENCE</span><span class="discipline">${escapeHTML(discipline)}</span></div>""")
            append("""<p class="penance-title"><span class="penance-dot$strictClass"></span>${escapeHTML(penanceTitle)}</p>""")
            append("""<p class="penance-desc">${escapeHTML(penanceDesc)}</p>""")
            append("</div>")
            append("""<div class="footer">Introibo — app.introibo</div>""")
        }
        return calendarDocument(latinTitle, englishTitle, longDate, body)
    }

    // MARK: - Private helpers

    /** Wraps one proper section (label + optional ref + bilingual text) in HTML. */
    private fun sectionHTML(label: String, lat: String, eng: String, ref: String?): String {
        return buildString {
            append("""<div class="section">""")
            append("""<div class="section-label">${escapeHTML(label)}</div>""")

            if (!ref.isNullOrEmpty()) {
                append("""<p class="ref">${escapeHTML(ref)}</p>""")
            }

            // Keep <em> tags — they render correctly in HTML as italics.
            // Convert <br> variants to <br> for consistency, strip other tags.
            append("""<div class="bilingual">""")
            append("""<p class="latin">${prepareBodyHTML(lat)}</p>""")
            append("""<p class="english-text">${prepareBodyHTML(eng)}</p>""")
            append("</div>")
            append("</div>")
            append("""<div class="divider"></div>""")
        }
    }

    /**
     * Prepares body text for HTML display. Keeps `<em>` tags (rendered as
     * italic) and converts `<br>` variants to `<br>`. Strips any other tags
     * and decodes common HTML entities.
     */
    private fun prepareBodyHTML(text: String): String {
        var out = text
        // Normalise <br> variants
        out = out.replace("<br/>", "<br>")
        out = out.replace("<br />", "<br>")
        // Decode entities that would otherwise double-encode
        out = out.replace("&amp;", "&")
        out = out.replace("&nbsp;", " ")
        // Preserve <em>, </em>, <br> — strip everything else
        out = out.replace(Regex("<(?!/?(em|br)\\b)[^>]+>"), "")
        // Escape remaining literal & for valid HTML
        out = out.replace("&", "&amp;")
        // Restore our kept tags that we may have broken
        out = out.replace("<em>", "<em>")
        out = out.replace("</em>", "</em>")
        out = out.replace("<br>", "<br>")
        return out
    }

    /** Minimal HTML entity escaping for plain-text values (titles, labels, refs). */
    private fun escapeHTML(text: String): String {
        return text
            .replace("&", "&amp;")
            .replace("<", "&lt;")
            .replace(">", "&gt;")
            .replace("\"", "&quot;")
    }

    private fun calendarDocument(latinTitle: String, englishTitle: String?, longDate: String, body: String): String {
        val engLine = if (englishTitle != null) """<p class="english">${escapeHTML(englishTitle)}</p>""" else ""
        return """<!DOCTYPE html>
<html lang="la"><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1">
<title>${escapeHTML(latinTitle)}</title>
<style>
*{margin:0;padding:0;box-sizing:border-box}
body{background:#F2E8D0;font-family:Palatino,"Palatino Linotype",Georgia,serif;color:#1C1410;padding:32px;max-width:520px;margin:0 auto;-webkit-print-color-adjust:exact;print-color-adjust:exact}
.header{background:linear-gradient(to bottom,#1A130C,#2C2015);color:#E8DFC9;text-align:center;padding:28px 24px;border-radius:8px;margin-bottom:28px}
.header h1{font-size:22px;font-style:italic;margin:0;line-height:1.3}
.header .english{font-size:14px;color:#B8960C;margin-top:8px;font-style:italic}
.header .date{font-size:12px;color:#9A8670;margin-top:6px;font-style:italic}
.info-row{margin-bottom:16px}
.info-label{display:block;font-size:10px;text-transform:uppercase;letter-spacing:1.5px;color:#9A8670;margin-bottom:4px}
.info-value{font-size:15px;color:#1C1410}
.flag{font-size:13px;font-style:italic;color:#8B1A1A;margin-bottom:6px}
.penance-card{border:1px solid rgba(184,150,12,0.3);border-radius:6px;padding:14px;margin-top:20px}
.penance-card.strict{border-color:rgba(139,26,26,0.3)}
.penance-header{display:flex;justify-content:space-between;align-items:center;margin-bottom:10px}
.discipline{font-size:9px;color:#B8960C}
.penance-title{font-size:15px;font-weight:500;color:#1C1410;margin-bottom:8px}
.penance-dot{display:inline-block;width:8px;height:8px;border-radius:50%;background:#B8960C;margin-right:8px;vertical-align:middle}
.penance-dot.strict{background:#8B1A1A}
.penance-desc{font-size:13px;color:#5A4A3A;line-height:1.5}
.footer{text-align:center;color:#9A8670;font-size:11px;margin-top:32px;padding-top:16px;border-top:1px solid rgba(184,150,12,0.2)}
@media print{body{padding:20px}}
</style></head><body>
<div class="header"><h1>${escapeHTML(latinTitle)}</h1>$engLine<p class="date">${escapeHTML(longDate)}</p></div>
$body
</body></html>"""
    }

    /** Wraps body content in a full HTML5 document with inline CSS. */
    private fun document(title: String, englishTitle: String, body: String): String {
        return """<!DOCTYPE html>
<html lang="la">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>${escapeHTML(title)}</title>
<style>
* { margin: 0; padding: 0; box-sizing: border-box; }
body {
    background: #F2E8D0;
    font-family: Palatino, "Palatino Linotype", Georgia, "Times New Roman", serif;
    color: #1C1410;
    padding: 32px;
    max-width: 680px;
    margin: 0 auto;
    -webkit-print-color-adjust: exact;
    print-color-adjust: exact;
}
.header {
    background: linear-gradient(to bottom, #1A130C, #2C2015);
    color: #E8DFC9;
    text-align: center;
    padding: 24px;
    border-radius: 8px;
    margin-bottom: 24px;
}
.header h1 {
    font-size: 22px;
    font-style: italic;
    margin: 0;
    line-height: 1.3;
}
.header .english {
    font-size: 13px;
    letter-spacing: 2px;
    text-transform: uppercase;
    color: #B8960C;
    margin-top: 6px;
    font-style: normal;
}
.section {
    margin-bottom: 20px;
    border-left: 3px solid #8B1A1A;
    padding-left: 14px;
}
.section-label {
    font-size: 11px;
    text-transform: uppercase;
    letter-spacing: 2px;
    color: #8B1A1A;
    font-weight: 600;
    margin-bottom: 8px;
}
.bilingual {
    display: flex;
    gap: 20px;
}
.bilingual .latin {
    flex: 1;
    color: #1C1410;
    line-height: 1.6;
}
.bilingual .english-text {
    flex: 1;
    color: #5A4A3A;
    font-style: italic;
    line-height: 1.6;
}
.ref {
    font-size: 12px;
    color: #B8960C;
    font-style: italic;
    margin-bottom: 6px;
}
.preface-note {
    text-align: center;
    color: #9A8670;
    font-style: italic;
    font-size: 13px;
}
.footer {
    text-align: center;
    color: #9A8670;
    font-size: 11px;
    margin-top: 32px;
    padding-top: 16px;
    border-top: 1px solid rgba(184, 150, 12, 0.2);
}
.divider {
    height: 1px;
    background: rgba(184, 150, 12, 0.25);
    margin: 16px 0;
}
@media print {
    body { padding: 20px; }
    .section { break-inside: avoid; }
}
</style>
</head>
<body>
<div class="header">
    <h1>${escapeHTML(title)}</h1>
    <div class="english">${escapeHTML(englishTitle)}</div>
</div>
$body
<div class="footer">Introibo &mdash; app.introibo</div>
</body>
</html>"""
    }
}
