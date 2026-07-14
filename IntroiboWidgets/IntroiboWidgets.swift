import WidgetKit
import SwiftUI

// MARK: - IntroiboWidgets
//
// The home-screen / lock-screen widget: an INVITATION to pray, never a
// tracker. It shows the right prayer content for the current part of the day
// and opens directly into it, ready to pray. Content is computed from config
// + clock + the SAME OfficeSchedule logic the Office tab uses (the file is
// compiled into both targets), so widget and app can never disagree about
// the current hour.
//
// WELLBEING CUT LINE (non-negotiable): no completion state, counts, streaks,
// progress, history, or missed-day framing — here or in any later addition.
//
// Refresh: a computed timeline with one entry per content boundary (Office
// hour times, or slot starts), extended ~36h ahead; WidgetKit re-renders at
// each boundary without waking the app. Tap-through carries a
// "resolve at tap time" URL (introibo://widget?m=…) so a stale render can
// never open the wrong content.
//
// Android mirror: android/.../widget/IntroiboWidgetProvider.kt

// MARK: - Lean hour model

/// The widget's lean decode of the SAME bundled hours.json the app reads
/// (the resource is copied into the extension bundle at build time).
struct WidgetHour: Decodable, ScheduledHour {
    let slug: String
    let name: String   // Latin name (Matutínum, Laudes, ...)
    let eng: String    // English name
    let hour: Int      // 0-23
    let minute: Int
}

enum WidgetContent {

    static func loadHours() -> [WidgetHour] {
        guard let url = Bundle.main.url(forResource: "hours", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let hours = try? JSONDecoder().decode([WidgetHour].self, from: data)
        else { return [] }
        // hours.json also carries the devotional Office of the Dead at the
        // same time as Matins — the widget (like the Office tab's dial) only
        // surfaces the canonical cursus.
        return hours.filter { $0.slug != "office-of-the-dead" }
    }

    /// Prayer titles for the chosen-prayer mode, keyed by slug. Denormalized
    /// from the app's prayer corpus so the extension does not carry the full
    /// prayers.json. Must cover WidgetConfigStore.defaultSlotPrayers.
    /// The config screen stores the chosen prayer's display titles alongside
    /// the slug precisely so this table only backs the defaults.
    static let defaultPrayerTitles: [String: (title: String, eng: String)] = [
        "morning": ("Oblátio Matutína", "Morning Offering"),
        "angelus": ("Angelus Dómini", "The Angelus"),
        "actusContr": ("Actus Contritiónis", "Act of Contrition"),
    ]

    static func prayerDisplay(slug: String) -> (title: String, eng: String) {
        if let stored = WidgetConfigStore.defaults.string(forKey: "widget.title.\(slug)") {
            let engStored = WidgetConfigStore.defaults.string(forKey: "widget.eng.\(slug)") ?? ""
            return (stored, engStored)
        }
        return defaultPrayerTitles[slug] ?? ("Oratio", "Tap to pray")
    }
}

// MARK: - Timeline

struct PrayerEntry: TimelineEntry {
    let date: Date
    let label: String      // "DIVINE OFFICE" / "MORNING" ...
    let title: String      // "Laudes" / "Angelus Dómini"
    let subtitle: String   // "Lauds" / "The Angelus"
    let mode: WidgetMode
}

struct PrayerProvider: TimelineProvider {

    func placeholder(in context: Context) -> PrayerEntry {
        PrayerEntry(date: Date(), label: "Divine Office", title: "Laudes",
                    subtitle: "Lauds", mode: .office)
    }

    func getSnapshot(in context: Context, completion: @escaping (PrayerEntry) -> Void) {
        completion(entry(for: Date()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<PrayerEntry>) -> Void) {
        let now = Date()
        let cal = Calendar(identifier: .gregorian)
        let startOfDay = cal.startOfDay(for: now)

        // Boundary minutes for the active mode.
        let boundaries: [Int]
        switch WidgetConfigStore.mode {
        case .office:
            boundaries = WidgetContent.loadHours().map { $0.hour * 60 + $0.minute }.sorted()
        case .prayer:
            boundaries = WidgetSlot.allCases.map { WidgetConfigStore.slotStart($0) }.sorted()
        }

        // One entry now, plus one at each boundary over today and tomorrow.
        // Boundaries are WALL-CLOCK times, so build them with
        // date(bySettingHour:) — minute-adding from midnight drifts by an
        // hour on DST-transition days.
        var dates: [Date] = [now]
        for dayOffset in 0...1 {
            guard let day = cal.date(byAdding: .day, value: dayOffset, to: startOfDay) else { continue }
            for minutes in boundaries {
                if let d = cal.date(bySettingHour: minutes / 60, minute: minutes % 60,
                                    second: 0, of: day),
                   d > now {
                    dates.append(d)
                }
            }
        }

        let entries = dates.sorted().map { entry(for: $0) }
        completion(Timeline(entries: entries, policy: .atEnd))
    }

    private func entry(for date: Date) -> PrayerEntry {
        switch WidgetConfigStore.mode {
        case .office:
            let hours = WidgetContent.loadHours()
            let slug = OfficeSchedule.currentHourSlug(in: hours, at: date)
            let hour = hours.first { $0.slug == slug }
            return PrayerEntry(
                date: date,
                label: "Divine Office",
                title: hour?.name ?? "Divine Office",
                subtitle: hour?.eng ?? "Tap to pray",
                mode: .office
            )
        case .prayer:
            let slot = WidgetConfigStore.currentSlot(at: date)
            let slug = WidgetConfigStore.slotPrayer(slot)
            let display = WidgetContent.prayerDisplay(slug: slug)
            return PrayerEntry(
                date: date,
                label: slot.label,
                title: display.title,
                subtitle: display.eng,
                mode: .prayer
            )
        }
    }
}

// MARK: - Views

private extension Color {
    static let wParchment = Color(red: 0xF2 / 255, green: 0xE8 / 255, blue: 0xD0 / 255)
    static let wWalnut = Color(red: 0x1A / 255, green: 0x13 / 255, blue: 0x0C / 255)
    static let wRed = Color(red: 0x8B / 255, green: 0x1A / 255, blue: 0x1A / 255)
    static let wGold = Color(red: 0xC9 / 255, green: 0xA2 / 255, blue: 0x27 / 255)
    static let wInkSoft = Color(red: 0x4C / 255, green: 0x3E / 255, blue: 0x31 / 255)
}

struct IntroiboWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: PrayerEntry

    private var tapURL: URL? {
        URL(string: "introibo://widget?m=\(entry.mode.rawValue)")
    }

    var body: some View {
        Group {
            switch family {
            case .accessoryRectangular:
                // Lock screen: monochrome, compact.
                VStack(alignment: .leading, spacing: 1) {
                    Text(entry.label.uppercased())
                        .font(.system(size: 10, weight: .semibold, design: .serif))
                        .tracking(1.2)
                    Text(entry.title)
                        .font(.system(size: 16, weight: .medium, design: .serif))
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
                    Text(entry.subtitle)
                        .font(.system(size: 11, design: .serif))
                        .italic()
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            default:
                // Home screen: the parchment card.
                VStack(alignment: .leading, spacing: 3) {
                    Text(entry.label.uppercased())
                        .font(.system(size: 10, weight: .semibold, design: .serif))
                        .tracking(1.6)
                        .foregroundStyle(Color.wRed)
                        .lineLimit(1)
                    Rectangle()
                        .fill(Color.wGold)
                        .frame(width: 28, height: 1)
                        .padding(.vertical, 2)
                    Text(entry.title)
                        .font(.system(size: family == .systemSmall ? 19 : 22,
                                      weight: .medium, design: .serif))
                        .foregroundStyle(Color.wWalnut)
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
                    Text(entry.subtitle)
                        .font(.system(size: 13, design: .serif))
                        .italic()
                        .foregroundStyle(Color.wInkSoft)
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            }
        }
        .widgetURL(tapURL)
        .containerBackground(for: .widget) {
            if family == .accessoryRectangular {
                Color.clear
            } else {
                Color.wParchment
            }
        }
    }
}

// MARK: - Widget declaration

struct IntroiboWidget: Widget {
    let kind = "IntroiboWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: PrayerProvider()) { entry in
            IntroiboWidgetView(entry: entry)
        }
        .configurationDisplayName("Introibo")
        .description("The current canonical hour, or your chosen prayer for this part of the day. Tap to pray.")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryRectangular])
    }
}

@main
struct IntroiboWidgetsBundle: WidgetBundle {
    var body: some Widget {
        IntroiboWidget()
    }
}
