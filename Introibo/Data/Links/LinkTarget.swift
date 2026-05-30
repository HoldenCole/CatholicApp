import Foundation

// MARK: - Link-target string parser
//
// Grammar: "type:id" or "type:id#position"
//   - Split on FIRST ":" for type vs rest
//   - Split rest on FIRST "#" for id vs position
//   - type must be a valid ContentType rawValue
//   - Returns nil on parse failure
//
// Mirror of:
//   android/app/src/main/java/com/lampstandhq/introibo/data/links/LinkTarget.kt

enum LinkTarget {

    /// Parse a link-target string into a `DeepLinkTarget`.
    /// Returns `nil` if the string is malformed or the type is unknown.
    static func parse(_ raw: String) -> DeepLinkTarget? {
        // Find the first ':'
        guard let colonIdx = raw.firstIndex(of: ":") else { return nil }

        let typeStr = String(raw[raw.startIndex..<colonIdx])
        guard !typeStr.isEmpty, let type = ContentType(rawValue: typeStr) else { return nil }

        let afterColon = raw[raw.index(after: colonIdx)...]
        guard !afterColon.isEmpty else { return nil }

        // Split rest on first '#' for optional position
        if let hashIdx = afterColon.firstIndex(of: "#") {
            let id = String(afterColon[afterColon.startIndex..<hashIdx])
            let position = String(afterColon[afterColon.index(after: hashIdx)...])
            guard !id.isEmpty else { return nil }
            return DeepLinkTarget(type: type, id: id, position: position.isEmpty ? nil : position)
        } else {
            return DeepLinkTarget(type: type, id: String(afterColon), position: nil)
        }
    }
}
