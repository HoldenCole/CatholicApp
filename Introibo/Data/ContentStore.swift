import Foundation
import SwiftUI

// Loads bundled JSON content on first access and keeps it in memory.
// Exposed via @Observable so views can inject a single shared instance
// through @Environment; per-view ContentStore() is also fine since the
// load is cheap and the payload is small.

@Observable
final class ContentStore {
    static let shared = ContentStore()

    private(set) var prayers: [Prayer] = []

    init() {
        loadPrayers()
    }

    // MARK: - Loaders

    private func loadPrayers() {
        guard let url = Bundle.main.url(forResource: "prayers", withExtension: "json") else {
            assertionFailure("prayers.json missing from bundle")
            return
        }
        do {
            let data = try Data(contentsOf: url)
            self.prayers = try JSONDecoder().decode([Prayer].self, from: data)
        } catch {
            assertionFailure("Failed to decode prayers.json: \(error)")
        }
    }

    // MARK: - Convenience lookups

    func prayer(slug: String) -> Prayer? {
        prayers.first { $0.slug == slug }
    }

    func prayers(in category: String) -> [Prayer] {
        prayers.filter { $0.category == category }
    }

    /// Returns prayers grouped by category, preserving the order in which
    /// categories first appear in the source file (liturgically meaningful).
    func prayersByCategory() -> [(category: String, items: [Prayer])] {
        var seen: [String] = []
        var buckets: [String: [Prayer]] = [:]
        for p in prayers {
            if buckets[p.category] == nil {
                seen.append(p.category)
                buckets[p.category] = []
            }
            buckets[p.category]?.append(p)
        }
        return seen.map { ($0, buckets[$0] ?? []) }
    }
}
