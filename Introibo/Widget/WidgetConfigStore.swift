import Foundation
#if canImport(WidgetKit)
import WidgetKit
#endif

// MARK: - WidgetConfigStore
//
// The home-screen widget's small persistent configuration, deliberately
// independent of the Prayer Rule data model (the Rule is being reworked; the
// widget must not couple to it). Stored in the shared App Group defaults so
// the widget extension reads the same values the app writes; falls back to
// standard defaults when the group container is unavailable (e.g. unsigned
// CI builds), in which case the widget renders its sensible defaults.
//
// The mode set is EXTENSIBLE (string raw values, exhaustive switches at
// render sites) so the planned "Follow my Life Rule" mode can be added later
// additively.
//
// WELLBEING CUT LINE: this config carries what the widget SHOWS, never any
// completion/progress/streak state. Do not add tracking fields of any kind.
//
// This FILE is compiled into BOTH the app target and the IntroiboWidgets
// extension target (see project.yml).
//
// Android mirror: android/.../data/widget/WidgetConfig.kt

/// Widget display mode. Extensible set — do not collapse to a Boolean.
enum WidgetMode: String, CaseIterable {
    case office   // current canonical hour, from OfficeSchedule
    case prayer   // user-chosen prayer per time slot
}

/// The three chosen-prayer time slots.
enum WidgetSlot: String, CaseIterable {
    case morning, midday, evening

    var label: String {
        switch self {
        case .morning: return "Morning"
        case .midday: return "Midday"
        case .evening: return "Evening"
        }
    }
}

enum WidgetConfigStore {

    static let appGroup = "group.app.introibo.shared"

    /// App Group defaults when provisioned; standard defaults otherwise so
    /// nothing crashes in unsigned/simulator contexts.
    static var defaults: UserDefaults {
        UserDefaults(suiteName: appGroup) ?? .standard
    }

    // Slot boundaries as minutes since midnight. Defaults align with the
    // Office's own sense of the day: Laudes in the early morning, Sext at
    // midday, Vespers in the evening. Mirrors Android WidgetConfig.
    static let defaultSlotStarts: [WidgetSlot: Int] = [
        .morning: 4 * 60,    // 04:00
        .midday: 12 * 60,    // 12:00
        .evening: 17 * 60,   // 17:00
    ]

    // Default slot prayers: Morning Offering / Angelus / Act of Contrition —
    // the widget renders something prayable before any configuration.
    static let defaultSlotPrayers: [WidgetSlot: String] = [
        .morning: "morning",
        .midday: "angelus",
        .evening: "actusContr",
    ]

    static var mode: WidgetMode {
        get { WidgetMode(rawValue: defaults.string(forKey: "widget.mode") ?? "") ?? .office }
        set {
            defaults.set(newValue.rawValue, forKey: "widget.mode")
            reloadWidgets()
        }
    }

    static func slotPrayer(_ slot: WidgetSlot) -> String {
        defaults.string(forKey: "widget.slot.\(slot.rawValue)")
            ?? defaultSlotPrayers[slot]!
    }

    static func setSlotPrayer(_ slot: WidgetSlot, slug: String) {
        defaults.set(slug, forKey: "widget.slot.\(slot.rawValue)")
        reloadWidgets()
    }

    /// Start of `slot` in minutes since midnight.
    static func slotStart(_ slot: WidgetSlot) -> Int {
        let v = defaults.object(forKey: "widget.start.\(slot.rawValue)") as? Int
        return v ?? defaultSlotStarts[slot]!
    }

    static func setSlotStart(_ slot: WidgetSlot, minutes: Int) {
        defaults.set(minutes, forKey: "widget.start.\(slot.rawValue)")
        reloadWidgets()
    }

    /// The slot in effect at `minutes` since midnight: the slot whose start is
    /// at or before now; before the morning start, the previous evening's slot
    /// is still in effect (mirrors OfficeSchedule's roll-back).
    static func currentSlot(atMinutes minutes: Int) -> WidgetSlot {
        let starts = WidgetSlot.allCases.map { ($0, slotStart($0)) }
        return starts.filter { $0.1 <= minutes }.max(by: { $0.1 < $1.1 })?.0 ?? .evening
    }

    static func currentSlot(at date: Date = Date()) -> WidgetSlot {
        let cal = Calendar(identifier: .gregorian)
        let m = cal.component(.hour, from: date) * 60 + cal.component(.minute, from: date)
        return currentSlot(atMinutes: m)
    }

    /// Ask WidgetKit to re-render after a config change. No-op where
    /// WidgetKit is unavailable.
    private static func reloadWidgets() {
        #if canImport(WidgetKit)
        WidgetCenter.shared.reloadAllTimelines()
        #endif
    }
}
