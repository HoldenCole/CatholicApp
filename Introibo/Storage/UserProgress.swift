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

    // Rosary
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

    // MARK: - Reset

    /// Wipes every Introibo-managed key. Used by the "Reset all progress"
    /// button in Settings. Does not touch system keys.
    static func resetAll() {
        for key in defaults.dictionaryRepresentation().keys {
            if key.hasPrefix("saints.") || key.hasPrefix("rosary.") || key.hasPrefix("learn.") {
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
