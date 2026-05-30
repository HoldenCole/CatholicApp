import Foundation

// MARK: - Related-link model
//
// A label + link-target string that content models carry as an optional
// `related` array. The target is a raw string parsed via LinkTarget.parse
// at read time (Phase 2 rendering will resolve it).
//
// Mirror of:
//   android/app/src/main/java/com/lampstandhq/introibo/data/links/RelatedLink.kt

struct RelatedLink: Decodable, Hashable {
    let label: String
    let target: String  // link-target string, parsed via LinkTarget.parse
}
