import Foundation
import SwiftData

@Model
class Mystery {
    var id: UUID
    var sortOrder: Int
    var setType: MysterySetType
    var latinSetName: String
    var englishSetName: String
    var latinTitle: String
    var englishTitle: String
    var mysteryNumber: Int
    var scriptureRef: String
    var meditationText: String

    init(
        id: UUID = UUID(),
        sortOrder: Int,
        setType: MysterySetType,
        latinSetName: String,
        englishSetName: String,
        latinTitle: String,
        englishTitle: String,
        mysteryNumber: Int,
        scriptureRef: String,
        meditationText: String
    ) {
        self.id = id
        self.sortOrder = sortOrder
        self.setType = setType
        self.latinSetName = latinSetName
        self.englishSetName = englishSetName
        self.latinTitle = latinTitle
        self.englishTitle = englishTitle
        self.mysteryNumber = mysteryNumber
        self.scriptureRef = scriptureRef
        self.meditationText = meditationText
    }
}

enum MysterySetType: String, Codable, CaseIterable, Identifiable {
    case joyful
    case sorrowful
    case glorious

    var id: String { rawValue }

    var latinName: String {
        switch self {
        case .joyful: return "Mysteria Gaudiosa"
        case .sorrowful: return "Mysteria Dolorosa"
        case .glorious: return "Mysteria Gloriosa"
        }
    }

    var englishName: String {
        switch self {
        case .joyful: return "Joyful Mysteries"
        case .sorrowful: return "Sorrowful Mysteries"
        case .glorious: return "Glorious Mysteries"
        }
    }

    var traditionalDays: String {
        switch self {
        case .joyful: return "Monday, Thursday"
        case .sorrowful: return "Tuesday, Friday"
        case .glorious: return "Wednesday, Sunday"
        }
    }
}
