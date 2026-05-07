import SwiftUI
import Foundation

// Per-user progress tracking — what the user has done across the app.
// All values live in UserDefaults so they survive app restarts without
// requiring iCloud or an account. Everything is local, matching the
// "no accounts, no tracking" product principle.

enum ProgressKey {
    // Saints
    static let followedSaint = "saints.followed"
    static let saintStreak = "saints.streak"        // prefix: saints.streak.<slug>
    static let saintStreakLast = "saints.streakLast" // prefix: saints.streakLast.<slug>
    static let saintChecklist = "saints.checklist"   // prefix: saints.checklist.<date>

    // Prayer Rule
    static let prayerRule = "prayers.rule"           // JSON-encoded {morning: [slug], midday: [slug], evening: [slug]}
    static let prayerChecklist = "prayers.checklist"  // prefix: prayers.checklist.<date>
    static let rosaryLastDate = "rosary.lastDate"   // ISO date of last completion
    static let rosaryLastSet = "rosary.lastSet"     // mystery set key

    // Schola
    static let learnMastered = "learn.mastered"     // JSON-encoded [String]
}

/// A tiny facade over UserDefaults so views can query and mutate user
/// progress without each one reimplementing the key names.
enum UserProgress {
    private static var defaults: UserDefaults { .standard }

    // MARK: - Followed saint

    static func followedSaint() -> String? {
        defaults.string(forKey: ProgressKey.followedSaint)
    }

    static func setFollowedSaint(_ slug: String?) {
        if let slug {
            defaults.set(slug, forKey: ProgressKey.followedSaint)
            bumpSaintStreak(slug: slug)
        } else {
            defaults.removeObject(forKey: ProgressKey.followedSaint)
        }
    }

    static func saintStreak(slug: String) -> Int {
        defaults.integer(forKey: "\(ProgressKey.saintStreak).\(slug)")
    }

    /// Bumps the streak for this saint if the last bump was yesterday
    /// (continuation) or never (start). Same-day calls are idempotent;
    /// calls after a skipped day reset the streak to 1.
    static func bumpSaintStreak(slug: String) {
        let cal = Calendar.liturgical
        let today = cal.startOfDay(for: Date())
        let lastKey = "\(ProgressKey.saintStreakLast).\(slug)"
        let streakKey = "\(ProgressKey.saintStreak).\(slug)"

        let lastStr = defaults.string(forKey: lastKey)
        let current = defaults.integer(forKey: streakKey)

        if let lastStr, let last = ISO8601DateFormatter.dayOnly.date(from: lastStr) {
            let lastDay = cal.startOfDay(for: last)
            if cal.isDate(lastDay, inSameDayAs: today) {
                return // already bumped today
            }
            let daysBetween = cal.dateComponents([.day], from: lastDay, to: today).day ?? 0
            if daysBetween == 1 {
                defaults.set(current + 1, forKey: streakKey)
            } else {
                defaults.set(1, forKey: streakKey)
            }
        } else {
            defaults.set(1, forKey: streakKey)
        }
        defaults.set(ISO8601DateFormatter.dayOnly.string(from: today), forKey: lastKey)
    }

    // MARK: - Rosary

    static func rosaryLastDate() -> Date? {
        guard let str = defaults.string(forKey: ProgressKey.rosaryLastDate) else { return nil }
        return ISO8601DateFormatter.dayOnly.date(from: str)
    }

    static func rosaryLastSet() -> String? {
        defaults.string(forKey: ProgressKey.rosaryLastSet)
    }

    static func markRosaryPrayed(set: String, date: Date = Date()) {
        defaults.set(ISO8601DateFormatter.dayOnly.string(from: date), forKey: ProgressKey.rosaryLastDate)
        defaults.set(set, forKey: ProgressKey.rosaryLastSet)
    }

    // MARK: - Schola

    static func masteredLessons() -> Set<String> {
        guard let data = defaults.data(forKey: ProgressKey.learnMastered),
              let arr = try? JSONDecoder().decode([String].self, from: data) else {
            return []
        }
        return Set(arr)
    }

    static func setMastered(_ slug: String, mastered: Bool) {
        var current = masteredLessons()
        if mastered { current.insert(slug) } else { current.remove(slug) }
        if let data = try? JSONEncoder().encode(Array(current).sorted()) {
            defaults.set(data, forKey: ProgressKey.learnMastered)
        }
    }

    // MARK: - Prayer Rule

    struct PrayerRule: Codable {
        var morning: [String]
        var midday: [String]
        var evening: [String]

        var allSlugs: [String] { morning + midday + evening }
        var totalCount: Int { allSlugs.count }
        var isEmpty: Bool { morning.isEmpty && midday.isEmpty && evening.isEmpty }
    }

    static func prayerRule() -> PrayerRule {
        guard let data = defaults.data(forKey: ProgressKey.prayerRule),
              let rule = try? JSONDecoder().decode(PrayerRule.self, from: data) else {
            return PrayerRule(morning: [], midday: [], evening: [])
        }
        return rule
    }

    static func savePrayerRule(_ rule: PrayerRule) {
        if let data = try? JSONEncoder().encode(rule) {
            defaults.set(data, forKey: ProgressKey.prayerRule)
        }
    }

    static func addToRule(_ slug: String, period: String) {
        var rule = prayerRule()
        switch period {
        case "morning": if !rule.morning.contains(slug) { rule.morning.append(slug) }
        case "midday": if !rule.midday.contains(slug) { rule.midday.append(slug) }
        case "evening": if !rule.evening.contains(slug) { rule.evening.append(slug) }
        default: break
        }
        savePrayerRule(rule)
    }

    static func removeFromRule(_ slug: String) {
        var rule = prayerRule()
        rule.morning.removeAll { $0 == slug }
        rule.midday.removeAll { $0 == slug }
        rule.evening.removeAll { $0 == slug }
        savePrayerRule(rule)
    }

    private static func prayerChecklistKey(for date: Date = Date()) -> String {
        let day = ISO8601DateFormatter.dayOnly.string(from: date)
        return "\(ProgressKey.prayerChecklist).\(day)"
    }

    static func completedPrayers(for date: Date = Date()) -> Set<String> {
        guard let data = defaults.data(forKey: prayerChecklistKey(for: date)),
              let arr = try? JSONDecoder().decode([String].self, from: data) else {
            return []
        }
        return Set(arr)
    }

    static func togglePrayer(_ slug: String, for date: Date = Date()) {
        var current = completedPrayers(for: date)
        if current.contains(slug) {
            current.remove(slug)
        } else {
            current.insert(slug)
        }
        if let data = try? JSONEncoder().encode(Array(current).sorted()) {
            defaults.set(data, forKey: prayerChecklistKey(for: date))
        }
    }

    // MARK: - Saint Daily Checklist

    private static func checklistKey(for date: Date = Date()) -> String {
        let day = ISO8601DateFormatter.dayOnly.string(from: date)
        return "\(ProgressKey.saintChecklist).\(day)"
    }

    static func completedPractices(for date: Date = Date()) -> Set<String> {
        guard let data = defaults.data(forKey: checklistKey(for: date)),
              let arr = try? JSONDecoder().decode([String].self, from: data) else {
            return []
        }
        return Set(arr)
    }

    static func togglePractice(_ id: String, for date: Date = Date()) {
        var current = completedPractices(for: date)
        if current.contains(id) {
            current.remove(id)
        } else {
            current.insert(id)
        }
        if let data = try? JSONEncoder().encode(Array(current).sorted()) {
            defaults.set(data, forKey: checklistKey(for: date))
        }
    }

    static func practiceCompleted(_ id: String, for date: Date = Date()) -> Bool {
        completedPractices(for: date).contains(id)
    }

    static func dailyProgress(totalPractices: Int, for date: Date = Date()) -> Double {
        let done = completedPractices(for: date).count
        guard totalPractices > 0 else { return 0 }
        return Double(done) / Double(totalPractices)
    }

    // MARK: - Reset

    /// Wipes every Introibo-managed key. Used by the "Reset all progress"
    /// button in Settings. Does not touch system keys.
    static func resetAll() {
        for key in defaults.dictionaryRepresentation().keys {
            if key.hasPrefix("saints.") || key.hasPrefix("rosary.") || key.hasPrefix("learn.") || key.hasPrefix("saints.checklist") {
                defaults.removeObject(forKey: key)
            }
        }
    }
}

// Day-granularity ISO formatter used across the module. Pulled out so
// callers don't create a new instance on every call.
extension ISO8601DateFormatter {
    static let dayOnly: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withFullDate]
        return f
    }()
}
