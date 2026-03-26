import Foundation
import SwiftData

@MainActor
class ProgressViewModel: ObservableObject {
    @Published var prayers: [Prayer] = []
    @Published var sessions: [PracticeSession] = []
    @Published var prayerComfortLevels: [UUID: ComfortLevel] = [:]

    var totalPrayers: Int { prayers.count }

    var masteredCount: Int {
        prayerComfortLevels.values.filter { $0 == .mastered }.count
    }

    var familiarCount: Int {
        prayerComfortLevels.values.filter { $0 == .familiar }.count
    }

    var learningCount: Int {
        prayerComfortLevels.values.filter { $0 == .learning }.count
    }

    var masteryPercentage: Double {
        guard totalPrayers > 0 else { return 0 }
        let weightedSum = Double(masteredCount) * 1.0 +
                          Double(familiarCount) * 0.66 +
                          Double(learningCount) * 0.33
        return weightedSum / Double(totalPrayers)
    }

    func loadData(context: ModelContext) {
        let prayerDescriptor = FetchDescriptor<Prayer>(sortBy: [SortDescriptor(\.sortOrder)])
        prayers = (try? context.fetch(prayerDescriptor)) ?? []

        let sessionDescriptor = FetchDescriptor<PracticeSession>(
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        sessions = (try? context.fetch(sessionDescriptor)) ?? []

        // Build comfort level map — latest session per prayer
        prayerComfortLevels = [:]
        for prayer in prayers {
            if let latestSession = sessions.first(where: { $0.prayerId == prayer.id }) {
                prayerComfortLevels[prayer.id] = latestSession.comfortRating
            } else {
                prayerComfortLevels[prayer.id] = .notStarted
            }
        }
    }

    func comfortLevel(for prayer: Prayer) -> ComfortLevel {
        prayerComfortLevels[prayer.id] ?? .notStarted
    }

    func updateComfortLevel(for prayer: Prayer, to level: ComfortLevel, context: ModelContext) {
        let session = PracticeSession(
            prayerId: prayer.id,
            comfortRating: level
        )
        context.insert(session)
        prayerComfortLevels[prayer.id] = level
    }
}
