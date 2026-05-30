import Foundation

// MARK: - Inline-link markup parser
//
// Scans a body string for `<link target="...">...</link>` boundaries and
// produces an array of TextRun values. NO regex — pure string scanning.
//
// Mirror of:
//   android/app/src/main/java/com/lampstandhq/introibo/data/links/LinkMarkup.kt

/// A run of either plain text or a link with display text and target.
enum TextRun: Hashable {
    case text(String)
    case link(text: String, target: DeepLinkTarget)
}

enum LinkMarkup {

    /// Parse inline `<link target="...">...</link>` markup into runs.
    ///
    /// - Text outside links is passed through `strippingEm`.
    /// - A body with NO `<link>` tags produces exactly one `.text` run
    ///   equal to `body.strippingEm`.
    /// - If a link's target fails to parse, the inner text becomes a
    ///   plain `.text` run (graceful degradation).
    static func runs(_ body: String) -> [TextRun] {
        var result: [TextRun] = []
        var cursor = body.startIndex

        while cursor < body.endIndex {
            // Find next "<link " tag
            guard let openStart = body.range(of: "<link ", range: cursor..<body.endIndex) else {
                break
            }

            // Emit text before the tag
            if cursor < openStart.lowerBound {
                let before = String(body[cursor..<openStart.lowerBound]).strippingEm
                if !before.isEmpty {
                    result.append(.text(before))
                }
            }

            // Extract target="..." — find 'target="' after "<link "
            guard let targetAttrStart = body.range(of: "target=\"", range: openStart.upperBound..<body.endIndex) else {
                // Malformed: no target attribute. Treat rest as text.
                break
            }
            guard let targetAttrEnd = body.firstIndex(of: "\"", after: targetAttrStart.upperBound) else {
                break
            }
            let targetStr = String(body[targetAttrStart.upperBound..<targetAttrEnd])

            // Find the closing '>' of the opening tag
            guard let tagClose = body.firstIndex(of: ">", after: targetAttrEnd) else {
                break
            }
            let innerStart = body.index(after: tagClose)

            // Find </link>
            guard let closeTag = body.range(of: "</link>", range: innerStart..<body.endIndex) else {
                break
            }
            let innerText = String(body[innerStart..<closeTag.lowerBound])

            // Parse the target
            if let target = LinkTarget.parse(targetStr) {
                result.append(.link(text: innerText, target: target))
            } else {
                // Graceful degradation: emit inner text as plain text
                if !innerText.isEmpty {
                    result.append(.text(innerText))
                }
            }

            cursor = closeTag.upperBound
        }

        // Emit any remaining text after the last link
        if cursor < body.endIndex {
            let tail = String(body[cursor...]).strippingEm
            if !tail.isEmpty {
                result.append(.text(tail))
            }
        }

        // If no runs were produced (empty body), return empty array
        return result
    }
}

// MARK: - String helper: find character after a given index

private extension String {
    func firstIndex(of ch: Character, after start: String.Index) -> String.Index? {
        guard start < endIndex else { return nil }
        var i = start
        while i < endIndex {
            if self[i] == ch { return i }
            i = index(after: i)
        }
        return nil
    }
}
