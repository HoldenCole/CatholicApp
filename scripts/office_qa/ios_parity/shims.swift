import Foundation
// Design/Palette.swift's enum without its SwiftUI colours.
enum LiturgicalColour: String {
    case violet, rose, white, red, green, black
    static func from(ordoColor raw: String) -> LiturgicalColour { LiturgicalColour(rawValue: raw) ?? .green }
}
