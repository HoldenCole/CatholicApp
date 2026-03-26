import Foundation
import SwiftData

@MainActor
class PrayerDetailViewModel: ObservableObject {
    @Published var prayer: Prayer
    @Published var textMode: TextMode = .english
    @Published var latestSession: PracticeSession?

    init(prayer: Prayer) {
        self.prayer = prayer
    }

    var displayText: String {
        switch textMode {
        case .english: return prayer.englishText
        case .latin: return prayer.latinText
        case .phonetic: return prayer.phoneticText
        }
    }

    var phoneticWords: [PhoneticWord] {
        PhoneticParser.parse(prayer.phoneticText)
    }

    var hasLatinText: Bool {
        !prayer.latinText.isEmpty
    }

    var hasPhoneticText: Bool {
        !prayer.phoneticText.isEmpty
    }

    func loadLatestSession(context: ModelContext) {
        let prayerId = prayer.id
        var descriptor = FetchDescriptor<PracticeSession>(
            predicate: #Predicate<PracticeSession> { session in
                session.prayerId == prayerId
            },
            sortBy: [SortDescriptor(\.date, order: .reverse)]
        )
        descriptor.fetchLimit = 1
        latestSession = try? context.fetch(descriptor).first
    }
}
