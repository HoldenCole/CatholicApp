import Foundation

/// Generates styled HTML documents from Mass proper data, matching the
/// parchment + sanctuary-red visual identity of the app. The resulting
/// HTML is a self-contained document suitable for PDF rendering via
/// ``PDFExporter`` or direct sharing.
enum MassHTMLExporter {

    // MARK: - Public API

    /// Returns a complete HTML5 document string for the given Mass proper.
    /// All CSS is inlined so the document renders correctly anywhere.
    static func properHTML(_ proper: MassProper) -> String {
        var sections = ""

        // Required sections
        sections += sectionHTML(label: "Introitus  ·  Introit", lat: proper.introit.lat, eng: proper.introit.eng, ref: proper.introit.ref)
        sections += sectionHTML(label: "Orátio  ·  Collect", lat: proper.collect.lat, eng: proper.collect.eng, ref: proper.collect.ref)
        sections += sectionHTML(label: "Léctio  ·  Epistle", lat: proper.epistle.lat, eng: proper.epistle.eng, ref: proper.epistle.ref)

        // Optional chant sections
        if let gradual = proper.gradual {
            sections += sectionHTML(label: "Graduále  ·  Gradual", lat: gradual.lat, eng: gradual.eng, ref: gradual.ref)
        }
        if let alleluia = proper.alleluia {
            sections += sectionHTML(label: "Allelúja  ·  Alleluia", lat: alleluia.lat, eng: alleluia.eng, ref: alleluia.ref)
        }
        if let tract = proper.tract {
            sections += sectionHTML(label: "Tractus  ·  Tract", lat: tract.lat, eng: tract.eng, ref: tract.ref)
        }
        if let sequence = proper.sequence {
            sections += sectionHTML(label: "Sequéntia  ·  Sequence", lat: sequence.lat, eng: sequence.eng, ref: sequence.ref)
        }

        // Required sections (continued)
        sections += sectionHTML(label: "Evangélium  ·  Gospel", lat: proper.gospel.lat, eng: proper.gospel.eng, ref: proper.gospel.ref)
        sections += sectionHTML(label: "Offertórium  ·  Offertory", lat: proper.offertory.lat, eng: proper.offertory.eng, ref: proper.offertory.ref)
        sections += sectionHTML(label: "Secréta  ·  Secret", lat: proper.secret.lat, eng: proper.secret.eng, ref: proper.secret.ref)

        // Preface note (between Secret and Communion)
        var prefaceHTML = ""
        if let preface = proper.preface {
            prefaceHTML = "<p class=\"preface-note\">Præfátio: \(escapeHTML(preface.capitalized))</p>"
            prefaceHTML += "<div class=\"divider\"></div>"
        }

        sections += prefaceHTML
        sections += sectionHTML(label: "Commúnio  ·  Communion", lat: proper.communion.lat, eng: proper.communion.eng, ref: proper.communion.ref)
        sections += sectionHTML(label: "Postcommúnio  ·  Postcommunion", lat: proper.postcommunion.lat, eng: proper.postcommunion.eng, ref: proper.postcommunion.ref)

        return document(
            title: proper.title,
            englishTitle: proper.englishTitle,
            body: sections
        )
    }

    /// Returns a styled HTML document for a calendar day detail — feast name,
    /// liturgical colour, season, special-day flags, and penance/fasting info.
    static func calendarDayHTML(
        latinTitle: String,
        englishTitle: String?,
        longDate: String,
        colour: String?,
        colourHex: String?,
        season: String,
        flags: [String],
        penanceTitle: String,
        penanceDesc: String,
        penanceStrict: Bool,
        discipline: String
    ) -> String {
        var body = ""

        // Info rows
        if let colour {
            var row = "<div class=\"info-row\">"
            row += "<span class=\"info-label\">LITURGICAL COLOUR</span>"
            if let hex = colourHex {
                row += "<span style=\"display:inline-block;width:10px;height:10px;border-radius:50%;background:\(hex);margin-right:6px;vertical-align:middle;\"></span>"
            }
            row += "<span class=\"info-value\">\(escapeHTML(colour))</span>"
            row += "</div>"
            body += row
        }

        body += "<div class=\"info-row\">"
        body += "<span class=\"info-label\">SEASON</span>"
        body += "<span class=\"info-value\">\(escapeHTML(season))</span>"
        body += "</div>"

        // Special-day flags
        for flag in flags {
            body += "<p class=\"flag\">\(escapeHTML(flag))</p>"
        }

        // Penance card
        body += "<div class=\"penance-card\(penanceStrict ? " strict" : "")\">"
        body += "<div class=\"penance-header\">"
        body += "<span class=\"info-label\">FASTING &amp; ABSTINENCE</span>"
        body += "<span class=\"discipline\">\(escapeHTML(discipline))</span>"
        body += "</div>"
        body += "<p class=\"penance-title\">"
        body += "<span class=\"penance-dot\(penanceStrict ? " strict" : "")\"></span>"
        body += escapeHTML(penanceTitle)
        body += "</p>"
        body += "<p class=\"penance-desc\">\(escapeHTML(penanceDesc))</p>"
        body += "</div>"

        body += "<div class=\"footer\">Introibo — app.introibo</div>"

        return calendarDocument(
            latinTitle: latinTitle,
            englishTitle: englishTitle,
            longDate: longDate,
            body: body
        )
    }

    /// Wraps calendar-day content in a full HTML5 document with inline CSS.
    private static func calendarDocument(latinTitle: String, englishTitle: String?, longDate: String, body: String) -> String {
        """
        <!DOCTYPE html>
        <html lang="la">
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <title>\(escapeHTML(latinTitle))</title>
        <style>
        * { margin: 0; padding: 0; box-sizing: border-box; }
        body {
            background: #F2E8D0;
            font-family: Palatino, "Palatino Linotype", Georgia, "Times New Roman", serif;
            color: #1C1410;
            padding: 32px;
            max-width: 520px;
            margin: 0 auto;
            -webkit-print-color-adjust: exact;
            print-color-adjust: exact;
        }
        .header {
            background: linear-gradient(to bottom, #1A130C, #2C2015);
            color: #E8DFC9;
            text-align: center;
            padding: 28px 24px;
            border-radius: 8px;
            margin-bottom: 28px;
        }
        .header h1 {
            font-size: 22px;
            font-style: italic;
            margin: 0;
            line-height: 1.3;
        }
        .header .english {
            font-size: 14px;
            color: #B8960C;
            margin-top: 8px;
            font-style: italic;
        }
        .header .date {
            font-size: 12px;
            color: #9A8670;
            margin-top: 6px;
            font-style: italic;
        }
        .info-row {
            margin-bottom: 16px;
        }
        .info-label {
            display: block;
            font-size: 10px;
            text-transform: uppercase;
            letter-spacing: 1.5px;
            color: #9A8670;
            margin-bottom: 4px;
        }
        .info-value {
            font-size: 15px;
            color: #1C1410;
        }
        .flag {
            font-size: 13px;
            font-style: italic;
            color: #8B1A1A;
            margin-bottom: 6px;
        }
        .penance-card {
            border: 1px solid rgba(184, 150, 12, 0.3);
            border-radius: 6px;
            padding: 14px;
            margin-top: 20px;
        }
        .penance-card.strict {
            border-color: rgba(139, 26, 26, 0.3);
        }
        .penance-header {
            display: flex;
            justify-content: space-between;
            align-items: center;
            margin-bottom: 10px;
        }
        .discipline {
            font-size: 9px;
            color: #B8960C;
        }
        .penance-title {
            font-size: 15px;
            font-weight: 500;
            color: #1C1410;
            margin-bottom: 8px;
        }
        .penance-dot {
            display: inline-block;
            width: 8px; height: 8px;
            border-radius: 50%;
            background: #B8960C;
            margin-right: 8px;
            vertical-align: middle;
        }
        .penance-dot.strict { background: #8B1A1A; }
        .penance-desc {
            font-size: 13px;
            color: #5A4A3A;
            line-height: 1.5;
        }
        .footer {
            text-align: center;
            color: #9A8670;
            font-size: 11px;
            margin-top: 32px;
            padding-top: 16px;
            border-top: 1px solid rgba(184, 150, 12, 0.2);
        }
        @media print {
            body { padding: 20px; }
        }
        </style>
        </head>
        <body>
        <div class="header">
            <h1>\(escapeHTML(latinTitle))</h1>
            \(englishTitle.map { "<p class=\"english\">\(escapeHTML($0))</p>" } ?? "")
            <p class="date">\(escapeHTML(longDate))</p>
        </div>
        \(body)
        </body>
        </html>
        """
    }

    // MARK: - Private helpers

    /// Wraps one proper section (label + optional ref + bilingual text) in HTML.
    /// Full interleaved Mass (Ordinary + Propers) as a styled HTML document.
    /// Each section is (label, latin, english, optional scripture ref) —
    /// built by MissalView's fullMassItems walk so the PDF can never drift
    /// from the text share.
    static func massHTML(
        title: String,
        englishTitle: String,
        sections: [(label: String, lat: String, eng: String, ref: String?)]
    ) -> String {
        var body = ""
        for section in sections {
            body += sectionHTML(label: section.label, lat: section.lat,
                                eng: section.eng, ref: section.ref)
        }
        return document(title: title, englishTitle: englishTitle, body: body)
    }

    private static func sectionHTML(label: String, lat: String, eng: String, ref: String?) -> String {
        var html = "<div class=\"section\">"
        html += "<div class=\"section-label\">\(escapeHTML(label))</div>"

        if let ref, !ref.isEmpty {
            html += "<p class=\"ref\">\(escapeHTML(ref))</p>"
        }

        html += "<div class=\"bilingual\">"
        html += "<p class=\"latin\">\(prepareBodyHTML(lat))</p>"
        // Some propers have no approved English upstream; omit the empty
        // paragraph rather than print a blank line under the Latin.
        if !eng.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            html += "<p class=\"english-text\">\(prepareBodyHTML(eng))</p>"
        }
        html += "</div>"
        html += "</div>"
        html += "<div class=\"divider\"></div>"
        return html
    }

    /// Prepares body text for HTML display. Keeps `<em>` tags (rendered as
    /// italic) and converts `<br>` variants to `<br>`. Strips any other tags
    /// and decodes common HTML entities.
    private static func prepareBodyHTML(_ text: String) -> String {
        var out = text
        // Normalise <br> variants
        out = out.replacingOccurrences(of: "<br/>", with: "<br>")
        out = out.replacingOccurrences(of: "<br />", with: "<br>")
        // Decode entities that would otherwise double-encode
        out = out.replacingOccurrences(of: "&amp;", with: "&")
        out = out.replacingOccurrences(of: "&nbsp;", with: " ")
        // Preserve <em>, </em>, <br> — strip everything else
        out = out.replacingOccurrences(
            of: #"<(?!/?(em|br)\b)[^>]+>"#,
            with: "",
            options: .regularExpression
        )
        // Now escape any raw & or < that are NOT part of our kept tags/entities
        // We do a targeted escape: & → &amp; only if not already part of an entity
        // Actually, since we already decoded &amp; above, any remaining & is literal
        // and should be escaped for valid HTML.
        out = out.replacingOccurrences(of: "&", with: "&amp;")
        // Restore our kept tags that we may have broken
        out = out.replacingOccurrences(of: "<em>", with: "<em>")
        out = out.replacingOccurrences(of: "</em>", with: "</em>")
        out = out.replacingOccurrences(of: "<br>", with: "<br>")
        return out
    }

    /// Minimal HTML entity escaping for plain-text values (titles, labels, refs).
    private static func escapeHTML(_ text: String) -> String {
        text.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }

    /// Wraps body content in a full HTML5 document with inline CSS.
    private static func document(title: String, englishTitle: String, body: String) -> String {
        """
        <!DOCTYPE html>
        <html lang="la">
        <head>
        <meta charset="utf-8">
        <meta name="viewport" content="width=device-width, initial-scale=1">
        <title>\(escapeHTML(title))</title>
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
            <h1>\(escapeHTML(title))</h1>
            <div class="english">\(escapeHTML(englishTitle))</div>
        </div>
        \(body)
        <div class="footer">Introibo &mdash; app.introibo</div>
        </body>
        </html>
        """
    }
}
