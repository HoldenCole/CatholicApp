import Foundation

// MARK: - Search models (Phase 1: index core)
//
// Mirror of:
//   android/app/src/main/java/com/lampstandhq/introibo/data/search/SearchModels.kt

/// The kind of content a search hit points at. Adding a new content type =
/// add one case here + one extractor in SearchExtractors.
enum ContentType: String, Codable, Hashable {
    case prayer
    case missal
    case office
    case reference
    case saint
    case calendar
}

/// A stable, opaque pointer into the app's content used for deep linking
/// (navigation is Phase 3; for now this is just data carried by documents).
struct DeepLinkTarget: Codable, Hashable {
    let type: ContentType
    let id: String          // slug / section id
    let position: String?   // opaque stable anchor; nil = document home
}

/// One indexed unit. `searchText` is the folded match target; `title` and
/// `displayText` keep diacritics for display/snippets.
struct SearchDocument: Identifiable, Hashable {
    let id: String          // "<type>:<contentId>[#<position>]"
    let type: ContentType
    let title: String       // display title WITH diacritics
    let subtitle: String?
    let displayText: String // snippet source WITH diacritics
    let searchText: String  // folded / normalized — the match target
    let target: DeepLinkTarget
}
