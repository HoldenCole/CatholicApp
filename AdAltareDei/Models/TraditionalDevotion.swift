import Foundation

/// Represents a traditional Catholic devotional practice.
struct TraditionalDevotion: Identifiable, Codable {
    var id: String { slug }
    let slug: String
    let title: String
    let latinTitle: String
    let description: String
    let category: DevotionCategory
    let applicableDays: [Int]?        // 1=Sun...7=Sat, nil = daily
    let seasonalNote: String?
    let isAbstinence: Bool
    let isFasting: Bool
}

enum DevotionCategory: String, Codable, CaseIterable, Identifiable {
    case fasting = "fasting"
    case dailyDevotion = "daily_devotion"
    case weeklyDevotion = "weekly_devotion"
    case seasonalPractice = "seasonal_practice"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .fasting: return "Fasting & Abstinence"
        case .dailyDevotion: return "Daily Devotions"
        case .weeklyDevotion: return "Weekly Devotions"
        case .seasonalPractice: return "Seasonal Practices"
        }
    }

    var latinName: String {
        switch self {
        case .fasting: return "Ieiunium et Abstinentia"
        case .dailyDevotion: return "Devotiones Quotidianae"
        case .weeklyDevotion: return "Devotiones Hebdomadales"
        case .seasonalPractice: return "Praxes Temporales"
        }
    }

    var icon: String {
        switch self {
        case .fasting: return "fork.knife"
        case .dailyDevotion: return "sun.max"
        case .weeklyDevotion: return "calendar"
        case .seasonalPractice: return "leaf"
        }
    }
}
