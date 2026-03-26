import Foundation
import SwiftData

@Model
class PracticeSession {
    var id: UUID
    var prayerId: UUID
    var date: Date
    var recordingFileName: String?
    var comfortRating: ComfortLevel
    var durationSeconds: Double?

    init(
        id: UUID = UUID(),
        prayerId: UUID,
        date: Date = Date(),
        recordingFileName: String? = nil,
        comfortRating: ComfortLevel = .notStarted,
        durationSeconds: Double? = nil
    ) {
        self.id = id
        self.prayerId = prayerId
        self.date = date
        self.recordingFileName = recordingFileName
        self.comfortRating = comfortRating
        self.durationSeconds = durationSeconds
    }
}

enum ComfortLevel: Int, Codable, CaseIterable, Identifiable {
    case notStarted = 0
    case learning = 1
    case familiar = 2
    case mastered = 3

    var id: Int { rawValue }

    var label: String {
        switch self {
        case .notStarted: return "Not Started"
        case .learning: return "Learning"
        case .familiar: return "Familiar"
        case .mastered: return "Mastered"
        }
    }

    var latinLabel: String {
        switch self {
        case .notStarted: return "Non Inceptum"
        case .learning: return "Discens"
        case .familiar: return "Notum"
        case .mastered: return "Perfectum"
        }
    }

    var sfSymbol: String {
        switch self {
        case .notStarted: return "circle.dashed"
        case .learning: return "circle.bottomhalf.filled"
        case .familiar: return "circle.inset.filled"
        case .mastered: return "checkmark.circle.fill"
        }
    }
}
