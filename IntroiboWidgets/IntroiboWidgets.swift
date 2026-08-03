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
                label: WidgetConfigStore.chrome("widget.label.office", "Divine Office"),
                title: hour?.name ?? "Divine Office",
                subtitle: hour.map { WidgetConfigStore.chrome("hour.\($0.slug)", $0.eng) }
                    ?? WidgetConfigStore.chrome("widget.tap_to_pray", "Tap to pray"),
                mode: .office
            )
        case .prayer:
            let slot = WidgetConfigStore.currentSlot(at: date)
            let slug = WidgetConfigStore.slotPrayer(slot)
            let display = WidgetContent.prayerDisplay(slug: slug)
            return PrayerEntry(
                date: date,
                label: WidgetConfigStore.chrome("widget.label.\(slot.rawValue)", slot.label),
                title: display.title,
                subtitle: display.eng,
                mode: .prayer
            )
        }
    }
}

// MARK: - Views

extension Color {
    static let wParchment = Color(red: 0xF2 / 255, green: 0xE8 / 255, blue: 0xD0 / 255)
    static let wIvory = Color(red: 0xF8 / 255, green: 0xF2 / 255, blue: 0xE2 / 255)
    static let wParchDeep = Color(red: 0xE7 / 255, green: 0xD9 / 255, blue: 0xBB / 255)
    static let wWalnut = Color(red: 0x1A / 255, green: 0x13 / 255, blue: 0x0C / 255)
    static let wRed = Color(red: 0x8B / 255, green: 0x1A / 255, blue: 0x1A / 255)
    static let wGold = Color(red: 0xC9 / 255, green: 0xA2 / 255, blue: 0x27 / 255)
    static let wInkSoft = Color(red: 0x4C / 255, green: 0x3E / 255, blue: 0x31 / 255)
}

// MARK: Missal chrome (shared by every home-screen family)
//
// The widgets read as a small missal page: warm parchment gradient, a double
// hairline frame (walnut outside, gold leaf inside), and a ribbon marker in
// the day's liturgical colour hanging from the top edge — the bookmark of a
// hand missal. Lock-screen accessory families stay plain.

/// Warm top-lit parchment.
struct ParchmentBackground: View {
    var body: some View {
        LinearGradient(
            colors: [.wIvory, .wParchment, .wParchDeep],
            startPoint: .top, endPoint: .bottom
        )
    }
}

/// A bookmark ribbon with a swallow-tail notch, hanging from the top.
struct RibbonShape: Shape {
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: 0, y: 0))
        p.addLine(to: CGPoint(x: rect.width, y: 0))
        p.addLine(to: CGPoint(x: rect.width, y: rect.height))
        p.addLine(to: CGPoint(x: rect.width / 2, y: rect.height - rect.width * 0.8))
        p.addLine(to: CGPoint(x: 0, y: rect.height))
        p.closeSubpath()
        return p
    }
}

/// A centred gold rule broken by a small cross: ─── ✠ ───
struct OrnamentRule: View {
    var body: some View {
        HStack(spacing: 6) {
            Rectangle().fill(Color.wGold.opacity(0.75)).frame(height: 0.7)
            Text("\u{2720}")
                .font(.system(size: 8))
                .foregroundStyle(Color.wGold)
            Rectangle().fill(Color.wGold.opacity(0.75)).frame(height: 0.7)
        }
    }
}

/// Double hairline page frame + optional ribbon marker over the content.
struct MissalCard: ViewModifier {
    var ribbon: Color?

    func body(content: Content) -> some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .overlay(
                RoundedRectangle(cornerRadius: 3)
                    .strokeBorder(Color.wWalnut.opacity(0.28), lineWidth: 0.8)
                    .padding(4)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 2)
                    .strokeBorder(Color.wGold.opacity(0.55), lineWidth: 0.5)
                    .padding(6.5)
            )
            .overlay(alignment: .topLeading) {
                if let ribbon {
                    RibbonShape()
                        .fill(ribbon.opacity(0.92))
                        .frame(width: 6, height: 34)
                        .shadow(color: .black.opacity(0.18), radius: 0.8, x: 0.5, y: 0.8)
                        .padding(.leading, 14)
                }
            }
    }
}

extension View {
    func missalCard(ribbon: Color?) -> some View {
        modifier(MissalCard(ribbon: ribbon))
    }
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
                // Home screen: a small missal page, sanctuary-red ribbon.
                VStack(spacing: family == .systemSmall ? 3 : 4) {
                    Text(entry.label.uppercased())
                        .font(.system(size: 10, weight: .semibold, design: .serif))
                        .tracking(2.2)
                        .foregroundStyle(Color.wRed)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    OrnamentRule()
                        .frame(width: family == .systemSmall ? 84 : 110)
                    Spacer(minLength: 0)
                    Text(entry.title)
                        .font(.system(size: family == .systemSmall ? 22 : 26,
                                      weight: .medium, design: .serif))
                        .foregroundStyle(Color.wWalnut)
                        .minimumScaleFactor(0.6)
                        .lineLimit(1)
                        .multilineTextAlignment(.center)
                    Text(entry.subtitle)
                        .font(.system(size: 13, design: .serif))
                        .italic()
                        .foregroundStyle(Color.wInkSoft)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Spacer(minLength: 0)
                    Text("\u{2766}")   // ❦ fleuron foot ornament
                        .font(.system(size: 9))
                        .foregroundStyle(Color.wGold.opacity(0.85))
                }
                .padding(.vertical, 14)
                .padding(.horizontal, 16)
                .missalCard(ribbon: .wRed)
            }
        }
        .widgetURL(tapURL)
        .containerBackground(for: .widget) {
            if family == .accessoryRectangular {
                Color.clear
            } else {
                ParchmentBackground()
            }
        }
    }
}

// MARK: - Liturgical-day + Daily-reading widgets
//
// Both render from the WidgetDaySnapshot window the APP precomputes into the
// App Group (the extension can't load the missal corpus). Content changes at
// local midnight; the timeline carries entries for the next week and refreshes
// .atEnd. If the window has gone stale (app unopened for >30 days) the views
// degrade to an invitation to open the app.

struct DayEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetDaySnapshot?
}

private func midnightTimeline(completion: @escaping (Timeline<DayEntry>) -> Void) {
    let cal = Calendar(identifier: .gregorian)
    let now = Date()
    var dates: [Date] = [now]
    for offset in 1...7 {
        if let day = cal.date(byAdding: .day, value: offset, to: cal.startOfDay(for: now)) {
            dates.append(day)
        }
    }
    let entries = dates.map { DayEntry(date: $0, snapshot: WidgetSnapshotStore.snapshot(for: $0)) }
    completion(Timeline(entries: entries, policy: .atEnd))
}

struct DayProvider: TimelineProvider {
    func placeholder(in context: Context) -> DayEntry {
        DayEntry(date: Date(), snapshot: nil)
    }
    func getSnapshot(in context: Context, completion: @escaping (DayEntry) -> Void) {
        completion(DayEntry(date: Date(), snapshot: WidgetSnapshotStore.snapshot()))
    }
    func getTimeline(in context: Context, completion: @escaping (Timeline<DayEntry>) -> Void) {
        midnightTimeline(completion: completion)
    }
}

func liturgicalColor(_ key: String) -> Color {
    switch key {
    case "violet": return Color(red: 0.42, green: 0.21, blue: 0.60)
    case "rose": return Color(red: 0.63, green: 0.28, blue: 0.38)
    case "red": return .wRed
    case "green": return Color(red: 0.23, green: 0.36, blue: 0.16)
    case "black": return Color(red: 0.16, green: 0.15, blue: 0.13)
    default: return .wGold   // white feasts render as gold on parchment
    }
}

/// Small square: the day of the liturgical calendar you are on.
struct LiturgicalDayWidgetView: View {
    let entry: DayEntry

    private static let dayFormatter: DateFormatter = {
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.dateFormat = "EEEE d MMMM"
        return df
    }()

    var body: some View {
        Group {
            if let snap = entry.snapshot {
                VStack(spacing: 3) {
                    Text(snap.season.uppercased())
                        .font(.system(size: 9, weight: .semibold, design: .serif))
                        .tracking(1.8)
                        .foregroundStyle(Color.wRed)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    OrnamentRule()
                        .frame(width: 84)
                    Spacer(minLength: 0)
                    Text(WidgetSnapshotStore.prefersLatin
                         ? snap.name
                         : (snap.english ?? snap.name))
                        .font(.system(size: 16, weight: .medium, design: .serif))
                        .foregroundStyle(Color.wWalnut)
                        .multilineTextAlignment(.center)
                        .lineLimit(4)
                        .minimumScaleFactor(0.7)
                    Spacer(minLength: 0)
                    Text(Self.dayFormatter.string(from: entry.date))
                        .font(.system(size: 10, design: .serif))
                        .italic()
                        .foregroundStyle(Color.wInkSoft)
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
                .padding(.vertical, 14)
                .padding(.horizontal, 15)
                .missalCard(ribbon: liturgicalColor(snap.color))
            } else {
                stalePrompt
            }
        }
        .widgetURL(URL(string: "introibo://widget?m=day"))
        .containerBackground(for: .widget) { ParchmentBackground() }
    }
}

/// Medium/large rectangle: a quote from the day's Mass propers.
struct DailyReadingWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: DayEntry

    var body: some View {
        Group {
            if let snap = entry.snapshot {
                readingBody(snap)
            } else {
                stalePrompt
            }
        }
        .widgetURL(URL(string: "introibo://widget?m=reading"))
        .containerBackground(for: .widget) { ParchmentBackground() }
    }

    private func readingBody(_ snap: WidgetDaySnapshot) -> some View {
        let latin = WidgetSnapshotStore.prefersLatin
        let choice = WidgetSnapshotStore.readingText
        let primary = text(choice, from: snap, latin: latin)

        return VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text((latin ? snap.name : (snap.english ?? snap.name)).uppercased())
                    .font(.system(size: 10, weight: .semibold, design: .serif))
                    .tracking(1.6)
                    .foregroundStyle(Color.wRed)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Spacer(minLength: 0)
                Text(WidgetConfigStore.chrome("widget.reading.\(choice.rawValue)", choice.label).uppercased())
                    .font(.system(size: 8, weight: .semibold, design: .serif))
                    .tracking(1.4)
                    .foregroundStyle(Color.wGold)
                    .lineLimit(1)
                if let ref = primary.ref {
                    Text("\u{00B7} \(ref)")
                        .font(.system(size: 9, design: .serif))
                        .italic()
                        .foregroundStyle(Color.wInkSoft)
                        .lineLimit(1)
                }
            }
            OrnamentRule()
                .padding(.vertical, 1)

            // Illuminated drop cap: the quote opens with an oversized
            // sanctuary-red initial, as in a hand missal. The large family
            // gives the quote the whole page — no truncation; the Collect
            // addendum yields whatever space the full quote leaves.
            dropCapText(primary.body,
                        bodySize: family == .systemLarge ? 14 : 12,
                        lines: family == .systemLarge ? nil : 4)
                .layoutPriority(1)

            if family == .systemLarge, choice != .collect {
                Text("COLLECT")
                    .font(.system(size: 8, weight: .semibold, design: .serif))
                    .tracking(1.4)
                    .foregroundStyle(Color.wGold)
                    .padding(.top, 4)
                Text(latin ? snap.collectLat : snap.collectEng)
                    .font(.system(size: 12, design: .serif))
                    .italic()
                    .foregroundStyle(Color.wWalnut)
                    .lineSpacing(2)
                    .lineLimit(6)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 13)
        .padding(.horizontal, 16)
        .missalCard(ribbon: liturgicalColor(snap.color))
    }

    /// First letter oversized in Sanctuary Red beside the flowing text.
    /// `lines` nil = untruncated (the large family's full quote).
    @ViewBuilder
    private func dropCapText(_ body: String, bodySize: CGFloat, lines: Int?) -> some View {
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        if let first = trimmed.first, first.isLetter {
            HStack(alignment: .top, spacing: 5) {
                Text(String(first))
                    .font(.system(size: bodySize * 2.6, weight: .medium, design: .serif))
                    .foregroundStyle(Color.wRed)
                    .padding(.top, -4)
                Text(String(trimmed.dropFirst()))
                    .font(.system(size: bodySize, design: .serif))
                    .foregroundStyle(Color.wWalnut)
                    .lineSpacing(2)
                    .lineLimit(lines)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        } else {
            Text(trimmed)
                .font(.system(size: bodySize, design: .serif))
                .foregroundStyle(Color.wWalnut)
                .lineSpacing(2)
                .lineLimit(lines)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func text(_ choice: WidgetReadingText, from snap: WidgetDaySnapshot,
                      latin: Bool) -> (body: String, ref: String?) {
        switch choice {
        case .introit: return (latin ? snap.introitLat : snap.introitEng, snap.introitRef)
        case .collect: return (latin ? snap.collectLat : snap.collectEng, nil)
        case .epistle: return (latin ? snap.epistleLat : snap.epistleEng, snap.epistleRef)
        case .gospel: return (latin ? snap.gospelLat : snap.gospelEng, snap.gospelRef)
        }
    }
}

/// Rendered when the snapshot window doesn't cover the entry date (the app
/// hasn't been opened in over a month). An invitation, never an error.
var stalePrompt: some View {
    VStack(spacing: 5) {
        Text("INTROIBO")
            .font(.system(size: 10, weight: .semibold, design: .serif))
            .tracking(2.2)
            .foregroundStyle(Color.wRed)
        OrnamentRule()
            .frame(width: 84)
        Text(WidgetConfigStore.chrome("widget.stale", "Open the app to refresh today's liturgy."))
            .font(.system(size: 12, design: .serif))
            .italic()
            .foregroundStyle(Color.wInkSoft)
            .multilineTextAlignment(.center)
    }
    .padding(14)
    .missalCard(ribbon: nil)
}

struct LiturgicalDayWidget: Widget {
    let kind = "IntroiboDayWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: DayProvider()) { entry in
            LiturgicalDayWidgetView(entry: entry)
        }
        .configurationDisplayName("Today's Feast")
        .description("The day of the liturgical calendar you are on — feast, season, and colour.")
        .supportedFamilies([.systemSmall])
    }
}

struct DailyReadingWidget: Widget {
    let kind = "IntroiboReadingWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: DayProvider()) { entry in
            DailyReadingWidgetView(entry: entry)
        }
        .configurationDisplayName("Daily Reading")
        .description("A quote from today's Mass propers — choose the text in the app's widget settings.")
        .supportedFamilies([.systemMedium, .systemLarge])
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
        LiturgicalDayWidget()
        DailyReadingWidget()
        SaintsWidget()
    }
}
