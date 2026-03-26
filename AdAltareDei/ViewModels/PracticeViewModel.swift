import Foundation
import SwiftData

@MainActor
class PracticeViewModel: ObservableObject {
    @Published var prayer: Prayer
    @Published var isRecording = false
    @Published var hasRecording = false
    @Published var comfortRating: ComfortLevel = .notStarted

    init(prayer: Prayer) {
        self.prayer = prayer
    }

    func saveSession(context: ModelContext) {
        let session = PracticeSession(
            prayerId: prayer.id,
            comfortRating: comfortRating
        )
        context.insert(session)
    }
}
