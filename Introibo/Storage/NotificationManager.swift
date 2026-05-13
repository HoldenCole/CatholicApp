import UserNotifications
import SwiftUI

enum PrayerNotificationManager {

    static func requestPermission(completion: @escaping (Bool) -> Void) {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            DispatchQueue.main.async { completion(granted) }
        }
    }

    static func checkStatus(completion: @escaping (UNAuthorizationStatus) -> Void) {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async { completion(settings.authorizationStatus) }
        }
    }

    static func scheduleAll() {
        let center = UNUserNotificationCenter.current()
        let schedules = NotificationStore.all().filter { $0.isEnabled }

        var prayerCache: [String: Prayer] = [:]
        let store = ContentStore.shared
        for s in schedules {
            if s.id.hasPrefix("prayer.") {
                let slug = String(s.id.dropFirst(7))
                prayerCache[slug] = store.prayer(slug: slug)
            }
        }

        center.getPendingNotificationRequests { existing in
            let introiboIds = existing.map(\.identifier).filter { $0.hasPrefix("introibo.") }
            center.removePendingNotificationRequests(withIdentifiers: introiboIds)

            for schedule in schedules {
                let prayerSlug = schedule.id.hasPrefix("prayer.") ? String(schedule.id.dropFirst(7)) : nil
                let prayer = prayerSlug.flatMap { prayerCache[$0] }

                let rulePeriod = schedule.id.hasPrefix("rule.") ? String(schedule.id.dropFirst(5)) : nil
                let ruleTitle = rulePeriod.map { period -> String in
                    switch period {
                    case "morning": return "Morning Prayer Rule"
                    case "midday":  return "Midday Prayer Rule"
                    case "evening": return "Evening Prayer Rule"
                    case "daily":   return "Daily Prayer Rule"
                    default:        return "Prayer Rule"
                    }
                }

                let devotionTitle: String? = {
                    if schedule.id.hasPrefix("devotion.") {
                        let key = String(schedule.id.dropFirst(9))
                        switch key {
                        case "office":     return "Divine Office"
                        case "rosary":     return "The Holy Rosary"
                        case "stations":   return "Stations of the Cross"
                        case "confession": return "Confession"
                        default:           return "Devotion"
                        }
                    } else if schedule.id.hasPrefix("office.") {
                        let slug = String(schedule.id.dropFirst(7))
                        let hourNames: [String: String] = [
                            "matutinum": "Matins", "laudes": "Lauds", "prima": "Prime",
                            "tertia": "Terce", "sexta": "Sext", "nona": "None",
                            "vesperae": "Vespers", "completorium": "Compline"
                        ]
                        return hourNames[slug] ?? "Divine Office"
                    }
                    return nil
                }()

                let content = UNMutableNotificationContent()
                if let prayer = prayer {
                    content.title = prayer.title.strippingEm
                    content.body = String(prayer.lines.first?.lat.strippingEm.prefix(80) ?? "")
                } else if let ruleTitle = ruleTitle {
                    content.title = ruleTitle
                    content.body = "Time for your prayers."
                } else if let devotionTitle = devotionTitle {
                    content.title = devotionTitle
                    content.body = "Time for your devotion."
                }
                content.sound = .default

                for day in schedule.days {
                    var comps = DateComponents()
                    comps.weekday = day
                    comps.hour = schedule.hour
                    comps.minute = schedule.minute

                    let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: true)
                    let id = "introibo.\(schedule.id).day\(day)"
                    let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
                    center.add(request)
                }
            }
        }
    }

    static func cancel(id: String) {
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { existing in
            let toRemove = existing.map(\.identifier).filter { $0.hasPrefix("introibo.\(id).") }
            center.removePendingNotificationRequests(withIdentifiers: toRemove)
        }
    }

    static func cancelAll() {
        let center = UNUserNotificationCenter.current()
        center.getPendingNotificationRequests { existing in
            let toRemove = existing.map(\.identifier).filter { $0.hasPrefix("introibo.") }
            center.removePendingNotificationRequests(withIdentifiers: toRemove)
        }
    }
}
