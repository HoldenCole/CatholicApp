import Foundation
import SwiftData

@MainActor
class TodayViewModel: ObservableObject {
    @Published var todaysMysteries: [Mystery] = []
    @Published var todaysSetTypes: [MysterySetType] = []
    @Published var isSaturday = false

    let today = Date()

    var latinFeria: String { today.latinFeriaName }
    var englishDay: String { today.englishWeekdayName }
    var dateString: String { today.liturgicalDateString }

    func loadMysteries(context: ModelContext) {
        todaysSetTypes = MysteryScheduleService.mysterySetTypes(for: today)
        isSaturday = MysteryScheduleService.isSaturdayAmbiguous(for: today)

        let setTypeStrings = todaysSetTypes.map(\.rawValue)
        let descriptor = FetchDescriptor<Mystery>(
            predicate: #Predicate<Mystery> { mystery in
                setTypeStrings.contains(mystery.setType.rawValue)
            },
            sortBy: [SortDescriptor(\.sortOrder)]
        )

        todaysMysteries = (try? context.fetch(descriptor)) ?? []
    }
}
