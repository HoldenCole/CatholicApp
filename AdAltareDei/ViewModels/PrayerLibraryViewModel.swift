import Foundation
import SwiftData

@MainActor
class PrayerLibraryViewModel: ObservableObject {
    @Published var prayers: [Prayer] = []
    @Published var searchText = ""

    var filteredPrayers: [Prayer] {
        if searchText.isEmpty {
            return prayers
        }
        return prayers.filter { prayer in
            prayer.englishName.localizedCaseInsensitiveContains(searchText) ||
            prayer.latinName.localizedCaseInsensitiveContains(searchText)
        }
    }

    var groupedPrayers: [(PrayerCategory, [Prayer])] {
        let grouped = Dictionary(grouping: filteredPrayers) { $0.category }
        return PrayerCategory.allCases.compactMap { category in
            guard let prayers = grouped[category], !prayers.isEmpty else { return nil }
            return (category, prayers.sorted { $0.sortOrder < $1.sortOrder })
        }
    }

    func loadPrayers(context: ModelContext) {
        let descriptor = FetchDescriptor<Prayer>(sortBy: [SortDescriptor(\.sortOrder)])
        prayers = (try? context.fetch(descriptor)) ?? []
    }
}
