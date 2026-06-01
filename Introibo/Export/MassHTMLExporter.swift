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

    // MARK: - Private helpers

    /// Wraps one proper section (label + optional ref + bilingual text) in HTML.
    private static func sectionHTML(label: String, lat: String, eng: String, ref: String?) -> String {
        var html = "<div class=\"section\">"
        html += "<div class=\"section-label\">\(escapeHTML(label))</div>"

        if let ref, !ref.isEmpty {
            html += "<p class=\"ref\">\(escapeHTML(ref))</p>"
        }

        // Keep <em> tags — they render correctly in HTML as italics.
        // Convert <br> variants to <br> for consistency, strip other tags.
        html += "<p class=\"latin\">\(prepareBodyHTML(lat))</p>"
        html += "<p class=\"english-text\">\(prepareBodyHTML(eng))</p>"
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
        .latin {
            color: #1C1410;
            line-height: 1.6;
            margin-bottom: 8px;
        }
        .english-text {
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
