import Foundation
import SwiftData

@Model
class Prayer {
    var id: UUID
    var slug: String
    var latinName: String
    var englishName: String
    var latinText: String
    var phoneticText: String
    var englishText: String
    var audioFileName: String
    var sortOrder: Int
    var category: PrayerCategory

    init(
        id: UUID = UUID(),
        slug: String,
        latinName: String,
        englishName: String,
        latinText: String = "",
        phoneticText: String = "",
        englishText: String = "",
        audioFileName: String = "",
        sortOrder: Int = 0,
        category: PrayerCategory = .rosary
    ) {
        self.id = id
        self.slug = slug
        self.latinName = latinName
        self.englishName = englishName
        self.latinText = latinText
        self.phoneticText = phoneticText
        self.englishText = englishText
        self.audioFileName = audioFileName
        self.sortOrder = sortOrder
        self.category = category
    }
}

enum PrayerCategory: String, Codable, CaseIterable, Identifiable {
    case rosary
    case litany
    case mass
    case devotional

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .rosary: return "Rosary"
        case .litany: return "Litany"
        case .mass: return "Mass"
        case .devotional: return "Devotional"
        }
    }

    var latinName: String {
        switch self {
        case .rosary: return "Rosarium"
        case .litany: return "Litaniae"
        case .mass: return "Missa"
        case .devotional: return "Devotiones"
        }
    }
}
