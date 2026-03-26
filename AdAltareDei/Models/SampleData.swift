import Foundation
import SwiftData

struct SampleData {
    /// Loads prayers from the bundled prayers.json file.
    static func loadPrayers() -> [PrayerData] {
        guard let url = Bundle.main.url(forResource: "prayers", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let prayers = try? JSONDecoder().decode([PrayerData].self, from: data) else {
            return []
        }
        return prayers
    }

    /// Loads mysteries from the bundled mysteries.json file.
    static func loadMysteries() -> [MysteryData] {
        guard let url = Bundle.main.url(forResource: "mysteries", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let mysteries = try? JSONDecoder().decode([MysteryData].self, from: data) else {
            return []
        }
        return mysteries
    }

    /// Seeds the SwiftData model context with prayers and mysteries if empty.
    @MainActor
    static func seedIfNeeded(context: ModelContext) {
        let prayerDescriptor = FetchDescriptor<Prayer>()
        let existingPrayers = (try? context.fetchCount(prayerDescriptor)) ?? 0

        if existingPrayers == 0 {
            for prayerData in loadPrayers() {
                let prayer = Prayer(
                    slug: prayerData.slug,
                    latinName: prayerData.latinName,
                    englishName: prayerData.englishName,
                    latinText: prayerData.latinText,
                    phoneticText: prayerData.phoneticText,
                    englishText: prayerData.englishText,
                    audioFileName: prayerData.audioFileName,
                    sortOrder: prayerData.sortOrder,
                    category: PrayerCategory(rawValue: prayerData.category) ?? .rosary
                )
                context.insert(prayer)
            }
        }

        let mysteryDescriptor = FetchDescriptor<Mystery>()
        let existingMysteries = (try? context.fetchCount(mysteryDescriptor)) ?? 0

        if existingMysteries == 0 {
            for mysteryData in loadMysteries() {
                let mystery = Mystery(
                    sortOrder: mysteryData.sortOrder,
                    setType: MysterySetType(rawValue: mysteryData.setType) ?? .joyful,
                    latinSetName: mysteryData.latinSetName,
                    englishSetName: mysteryData.englishSetName,
                    latinTitle: mysteryData.latinTitle,
                    englishTitle: mysteryData.englishTitle,
                    mysteryNumber: mysteryData.mysteryNumber,
                    scriptureRef: mysteryData.scriptureRef,
                    meditationText: mysteryData.meditationText
                )
                context.insert(mystery)
            }
        }
    }
}

// MARK: - Decodable DTOs

struct PrayerData: Decodable {
    let slug: String
    let latinName: String
    let englishName: String
    let category: String
    let sortOrder: Int
    let audioFileName: String
    let englishText: String
    let latinText: String
    let phoneticText: String
}

struct MysteryData: Decodable {
    let sortOrder: Int
    let setType: String
    let latinSetName: String
    let englishSetName: String
    let latinTitle: String
    let englishTitle: String
    let mysteryNumber: Int
    let scriptureRef: String
    let meditationText: String
}
