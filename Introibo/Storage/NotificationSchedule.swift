import Foundation

struct NotificationSchedule: Codable, Identifiable, Equatable {
    let id: String
    var days: Set<Int>
    var hour: Int
    var minute: Int
    var isEnabled: Bool
}

enum NotificationStore {
    private static let key = "notifications.schedules"
    private static var defaults: UserDefaults { .standard }

    static func all() -> [NotificationSchedule] {
        guard let data = defaults.data(forKey: key),
              let arr = try? JSONDecoder().decode([NotificationSchedule].self, from: data) else {
            return []
        }
        return arr
    }

    static func schedule(for id: String) -> NotificationSchedule? {
        all().first { $0.id == id }
    }

    static func upsert(_ schedule: NotificationSchedule) {
        var schedules = all()
        if let idx = schedules.firstIndex(where: { $0.id == schedule.id }) {
            schedules[idx] = schedule
        } else {
            schedules.append(schedule)
        }
        save(schedules)
    }

    static func remove(id: String) {
        var schedules = all()
        schedules.removeAll { $0.id == id }
        save(schedules)
    }

    static func removeAll() {
        defaults.removeObject(forKey: key)
    }

    private static func save(_ schedules: [NotificationSchedule]) {
        if let data = try? JSONEncoder().encode(schedules) {
            defaults.set(data, forKey: key)
        }
    }
}
