import WidgetKit
import SwiftUI

// MARK: - SaintsWidget (Sanctorale)
//
// The large widget's "saints" content: today's feast, how far the current
// season has run, and the saints coming up — rendered from the same
// WidgetDaySnapshot window as the other day widgets. The upcoming list is
// derived inside the window (each snapshot carries rank/sanctoral/notable),
// so it stays correct for a month without waking the app.
//
// WELLBEING CUT LINE: the "season progress" bar is the CHURCH'S calendar —
// day N of M in the season — never the user's behaviour. No completion,
// streaks, or personal progress of any kind, here or in any later addition.
//
// Android mirror: IntroiboSaintsWidgetProvider in android/.../widget/DayWidgets.kt

struct SaintsWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: DayEntry

    var body: some View {
        Group {
            if let snap = entry.snapshot {
                content(snap)
            } else {
                stalePrompt
            }
        }
        .widgetURL(URL(string: "introibo://widget?m=day"))
        .containerBackground(for: .widget) { ParchmentBackground() }
    }

    private func content(_ snap: WidgetDaySnapshot) -> some View {
        let latin = WidgetSnapshotStore.prefersLatin
        let ahead = WidgetSnapshotStore.upcoming(
            after: snap, limit: family == .systemLarge ? 5 : 2)

        return VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 6) {
                Text("Sanctorale".uppercased())
                    .font(.system(size: 9, weight: .semibold, design: .serif))
                    .tracking(1.8)
                    .foregroundStyle(Color.wGold)
                    .lineLimit(1)
                Spacer(minLength: 0)
                Text(snap.season.uppercased())
                    .font(.system(size: 9, weight: .semibold, design: .serif))
                    .tracking(1.6)
                    .foregroundStyle(Color.wRed)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }

            Text(latin ? snap.name : (snap.english ?? snap.name))
                .font(.system(size: family == .systemLarge ? 19 : 16,
                              weight: .medium, design: .serif))
                .foregroundStyle(Color.wWalnut)
                .lineLimit(2)
                .minimumScaleFactor(0.75)

            seasonPosition(snap)

            OrnamentRule()
                .padding(.vertical, family == .systemLarge ? 3 : 1)

            if !ahead.isEmpty {
                Text("Ventura \u{00B7} Upcoming".uppercased())
                    .font(.system(size: 8, weight: .semibold, design: .serif))
                    .tracking(1.4)
                    .foregroundStyle(Color.wGold)
                ForEach(ahead, id: \.date) { day in
                    upcomingRow(day, latin: latin)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 13)
        .padding(.horizontal, 16)
        .missalCard(ribbon: liturgicalColor(snap.color))
    }

    /// "Day N of M" through the current season, as a thin gold rule filling
    /// left to right — the ribbon's progress through the missal, so to speak.
    @ViewBuilder
    private func seasonPosition(_ snap: WidgetDaySnapshot) -> some View {
        if let day = snap.seasonDay, let length = snap.seasonLength, length > 0 {
            HStack(spacing: 8) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.wWalnut.opacity(0.14))
                        Capsule()
                            .fill(Color.wGold)
                            .frame(width: max(3, geo.size.width * CGFloat(day) / CGFloat(length)))
                    }
                }
                .frame(height: 3)
                Text("Day \(day) of \(length)")
                    .font(.system(size: 9, design: .serif))
                    .italic()
                    .foregroundStyle(Color.wInkSoft)
                    .lineLimit(1)
                    .fixedSize()
            }
            .padding(.top, 1)
        }
    }

    private func upcomingRow(_ day: WidgetDaySnapshot, latin: Bool) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(latin ? day.name : (day.english ?? day.name))
                .font(.system(size: family == .systemLarge ? 12 : 11, design: .serif))
                .foregroundStyle(Color.wWalnut)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Spacer(minLength: 0)
            Text(Self.displayDate(day.date))
                .font(.system(size: 10, design: .serif))
                .italic()
                .foregroundStyle(Color.wInkSoft)
                .lineLimit(1)
                .fixedSize()
        }
        .padding(.top, 1)
    }

    /// "yyyy-MM-dd" → "24 Jul" without a DateFormatter round-trip.
    private static let monthAbbrev = ["", "Jan", "Feb", "Mar", "Apr", "May", "Jun",
                                      "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
    private static func displayDate(_ key: String) -> String {
        let parts = key.split(separator: "-")
        guard parts.count == 3,
              let month = Int(parts[1]), (1...12).contains(month),
              let day = Int(parts[2])
        else { return key }
        return "\(day) \(monthAbbrev[month])"
    }
}

struct SaintsWidget: Widget {
    let kind = "IntroiboSaintsWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: DayProvider()) { entry in
            SaintsWidgetView(entry: entry)
        }
        .configurationDisplayName("Sanctorale")
        .description("Today's feast, your place in the season, and the saints ahead.")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}
