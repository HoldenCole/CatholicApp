import SwiftUI

// MARK: - CalendarView (v1.2 feature 3: liturgical calendar)
//
// A browsable month list of the traditional calendar, presented full-screen
// from the Today header. Each day gets a full row showing the liturgical colour
// bar, day-of-week, day number, feast/feria name, and Sunday-obligation badge.
// Tapping a row opens a detail sheet with season, colour, special-day flags,
// and a link to that day's Mass.
//
// Android mirror: android/.../ui/calendar/CalendarScreen.kt

struct CalendarView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(SettingsKey.rite) private var riteRaw = MissalRite.rite1962.rawValue

    @State private var year: Int
    @State private var month: Int
    @State private var selectedDay: CalendarDay?
    @State private var pendingProper: MassProper?
    @State private var properToShow: MassProper?

    private var rite: MissalRite { MissalRite(rawValue: riteRaw) ?? .rite1962 }
    private var store: ContentStore { .shared }

    init(initial: Date = Date()) {
        let cal = Calendar.liturgical
        _year = State(initialValue: cal.component(.year, from: initial))
        _month = State(initialValue: cal.component(.month, from: initial))
    }

    private var yearRange: ClosedRange<Int> { store.ordoYearRange(rite: rite) }
    private var model: CalendarMonth {
        CalendarMonth.build(year: year, month: month, rite: rite, store: store)
    }
    private var canGoPrev: Bool { !(year == yearRange.lowerBound && month == 1) }
    private var canGoNext: Bool { !(year == yearRange.upperBound && month == 12) }

    var body: some View {
        VStack(spacing: 0) {
            chrome
            navRow
            Divider().overlay(Color.frameLine)
            dayList
        }
        .background(Color.pageBackground.ignoresSafeArea())
        .sheet(item: $selectedDay, onDismiss: presentPendingProper) { day in
            DayDetailView(day: day, rite: rite) { proper in
                pendingProper = proper
                selectedDay = nil
            }
        }
        .sheet(item: $properToShow) { proper in
            ProperView(proper: proper)
        }
    }

    private func presentPendingProper() {
        guard let proper = pendingProper else { return }
        pendingProper = nil
        DispatchQueue.main.async { properToShow = proper }
    }

    // MARK: Chrome

    private var chrome: some View {
        HStack {
            Text("Kalendárium")
                .smallLabel(color: Color.sanctuaryRed)
            Spacer()
            if !isCurrentMonth {
                Button { jumpToToday() } label: {
                    Text("Today")
                        .font(.captionSm)
                        .foregroundStyle(Color.sanctuaryRed)
                }
            }
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Color.tertiaryText)
            }
            .padding(.leading, 14)
        }
        .padding(.horizontal, 24)
        .padding(.top, 20)
        .padding(.bottom, 8)
    }

    // MARK: Month / year navigation

    private var navRow: some View {
        HStack(spacing: 16) {
            navButton("\u{2039}", enabled: canGoPrev) { step(months: -1) }
            Spacer()
            VStack(spacing: 2) {
                Text(monthName)
                    .font(.titleM)
                    .foregroundStyle(Color.primaryText)
                Text("\(String(year))")
                    .font(.captionSm)
                    .foregroundStyle(Color.tertiaryText)
            }
            Spacer()
            navButton("\u{203A}", enabled: canGoNext) { step(months: 1) }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 10)
    }

    private var monthName: String {
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.dateFormat = "LLLL"
        var comps = DateComponents()
        comps.year = year; comps.month = month; comps.day = 1
        guard let d = Calendar.liturgical.date(from: comps) else { return "" }
        return df.string(from: d)
    }

    private func navButton(_ glyph: String, enabled: Bool, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(glyph)
                .font(.system(size: 22, weight: .medium))
                .foregroundStyle(enabled ? Color.goldLeaf : Color.frameLine)
                .frame(width: 44, height: 44)
                .background(
                    Circle()
                        .fill(enabled ? Color.goldLeaf.opacity(0.08) : Color.clear)
                )
        }
        .disabled(!enabled)
    }

    // MARK: Day list

    private var dayList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(model.days) { day in
                        DayRow(day: day) { selectedDay = day }
                        Divider()
                            .overlay(Color.frameLine.opacity(0.5))
                            .padding(.leading, 60)
                    }
                }
                .padding(.bottom, 20)
            }
            .onAppear {
                if let todayDay = model.days.first(where: { $0.isToday }) {
                    proxy.scrollTo(todayDay.id, anchor: .center)
                }
            }
        }
    }

    // MARK: Navigation logic

    private var isCurrentMonth: Bool {
        let cal = Calendar.liturgical; let now = Date()
        return year == cal.component(.year, from: now) && month == cal.component(.month, from: now)
    }

    private func jumpToToday() {
        let cal = Calendar.liturgical; let now = Date()
        year = cal.component(.year, from: now)
        month = cal.component(.month, from: now)
    }

    private func step(months: Int) {
        var m = month + months; var y = year
        while m > 12 { m -= 12; y += 1 }
        while m < 1  { m += 12; y -= 1 }
        y = min(max(y, yearRange.lowerBound), yearRange.upperBound)
        year = y; month = m
    }
}

// MARK: - Day row

private struct DayRow: View {
    let day: CalendarDay
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 0) {
                // Liturgical colour bar
                Rectangle()
                    .fill(day.colour?.swiftUIColor ?? Color.clear)
                    .frame(width: 3)

                // Day number + weekday
                VStack(spacing: 1) {
                    Text(day.weekdayAbbrev)
                        .font(.system(size: 10, weight: .medium))
                        .tracking(0.5)
                        .foregroundStyle(Color.tertiaryText)
                    Text("\(day.day)")
                        .font(.system(size: 24, weight: day.isMajor ? .semibold : .regular))
                        .foregroundStyle(day.isToday ? Color.sanctuaryRed : Color.primaryText)
                }
                .frame(width: 52)
                .padding(.leading, 4)

                // Feast / feria name + badges
                VStack(alignment: .leading, spacing: 4) {
                    Text(day.label ?? "Feria")
                        .font(.body)
                        .fontWeight(day.isMajor ? .medium : .regular)
                        .foregroundStyle(Color.primaryText)
                        .lineLimit(2)

                    if day.isSunday {
                        obligationBadge
                    }
                }
                .padding(.leading, 12)

                Spacer(minLength: 8)

                // Chevron
                Text("\u{203A}")
                    .font(.system(size: 20))
                    .foregroundStyle(Color.tertiaryText)
                    .padding(.trailing, 16)
            }
            .padding(.vertical, 14)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .id(day.id)
    }

    private var obligationBadge: some View {
        Text("SUNDAY OBLIGATION")
            .font(.system(size: 9, weight: .semibold))
            .tracking(0.5)
            .foregroundStyle(Color.sanctuaryRed)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .overlay(
                RoundedRectangle(cornerRadius: 3)
                    .stroke(Color.sanctuaryRed.opacity(0.5), lineWidth: 0.5)
            )
    }
}

// MARK: - DayDetailView

private struct DayDetailView: View {
    let day: CalendarDay
    let rite: MissalRite
    let onViewMass: (MassProper) -> Void
    @Environment(\.dismiss) private var dismiss
    @AppStorage(SettingsKey.language) private var languageRaw = LanguageMode.both.rawValue

    private var langMode: LanguageMode { LanguageMode(rawValue: languageRaw) ?? .both }
    private var ctx: LiturgicalContext { .for(date: day.date, rite: rite) }
    private var proper: MassProper? { ContentStore.shared.properForDate(day.date, rite: rite) }
    private var title: String { day.ordo?.name ?? ctx.feriaLatin }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                detail
            }
        }
        .background(Color.pageBackground.ignoresSafeArea())
    }

    private var header: some View {
        VStack(spacing: 8) {
            HStack {
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Color.goldLeaf)
                }
            }
            .padding(.top, 16)
            .padding(.trailing, 4)

            HStack(spacing: 8) {
                if let colour = day.colour {
                    Circle().fill(colour.swiftUIColor).frame(width: 8, height: 8)
                }
                Text("\(ctx.feriaEnglish)  \u{00B7}  \(ctx.englishName)")
                    .smallLabel(color: Color.goldLeaf)
            }

            Text(title)
                .font(.pageTitle)
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.ivory)
                .padding(.horizontal, 12)

            Text(LongDateFormatter.format(day.date))
                .font(.bodySm)
                .italic()
                .foregroundStyle(Color.muted)
        }
        .padding(.horizontal, 28)
        .padding(.bottom, 22)
        .frame(maxWidth: .infinity)
        .background(LinearGradient(colors: [Color.walnut, Color.walnutHi], startPoint: .top, endPoint: .bottom))
    }

    private var detail: some View {
        VStack(alignment: .leading, spacing: 18) {
            if let colour = day.colour {
                infoRow(label: "Liturgical Colour", value: colour.rawValue.capitalized, swatch: colour)
            }
            infoRow(label: "Season", value: langMode == .latinOnly ? ctx.latinName : ctx.englishName)

            if ctx.isFirstFriday || ctx.isFirstSaturday || ctx.isEmberDay {
                VStack(alignment: .leading, spacing: 6) {
                    if ctx.isFirstFriday { flag("First Friday") }
                    if ctx.isFirstSaturday { flag("First Saturday") }
                    if ctx.isEmberDay { flag("Ember Day") }
                }
            }

            if day.isSunday {
                flag("Sunday Obligation")
            }

            if let proper {
                Button { onViewMass(proper) } label: {
                    HStack {
                        Image(systemName: "book.closed")
                            .font(.system(size: 14))
                            .foregroundStyle(Color.sanctuaryRed)
                        Text("View the Mass")
                            .font(.titleM)
                            .italic()
                            .foregroundStyle(Color.primaryText)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.system(size: 12))
                            .foregroundStyle(Color.tertiaryText)
                    }
                    .padding(14)
                    .overlay(Rectangle().stroke(Color.frameLine, lineWidth: 0.5))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
        }
        .padding(.horizontal, 28)
        .padding(.top, 24)
        .padding(.bottom, 40)
    }

    private func infoRow(label: String, value: String, swatch: LiturgicalColour? = nil) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .font(.system(size: 10))
                .tracking(1.5)
                .foregroundStyle(Color.tertiaryText)
            HStack(spacing: 8) {
                if let swatch { Circle().fill(swatch.swiftUIColor).frame(width: 10, height: 10) }
                Text(value)
                    .font(.body)
                    .foregroundStyle(Color.primaryText)
            }
        }
    }

    private func flag(_ text: String) -> some View {
        Text(text)
            .font(.captionSm)
            .italic()
            .foregroundStyle(Color.sanctuaryRed)
    }
}
