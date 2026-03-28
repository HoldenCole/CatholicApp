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

        let descriptor = FetchDescriptor<Mystery>(
            sortBy: [SortDescriptor(\.sortOrder)]
        )
        let allMysteries = (try? context.fetch(descriptor)) ?? []

        let setTypeStrings = Set(todaysSetTypes.map(\.rawValue))
        todaysMysteries = allMysteries.filter { setTypeStrings.contains($0.setType.rawValue) }
    }
}
