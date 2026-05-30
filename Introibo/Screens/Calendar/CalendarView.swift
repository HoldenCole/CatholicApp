import SwiftUI

// MARK: - CalendarView (v1.2 feature 3: liturgical calendar)
//
// A browsable month grid of the traditional calendar, presented full-screen
// from the Today header. Each day shows its liturgical colour; tapping a day
// opens a detail with the day's feast/feria, season, colour, and a link to
// that day's Mass. Everything is computed from the bundled ordo tables via
// `CalendarMonth.build` / `ContentStore.ordoForDate` — zero network.
//
// The displayed rite follows the user's setting, so the calendar always agrees
// with the rest of the app. Month navigation is bounded to the years the ordo
// data actually covers (ContentStore.ordoYearRange).
//
// Android mirror: android/.../ui/calendar/CalendarScreen.kt

struct CalendarView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(SettingsKey.rite) private var riteRaw = MissalRite.rite1962.rawValue

    @State private var year: Int
    @State private var month: Int
    @State private var selectedDay: CalendarDay?
    // "View the Mass" presents ProperView as a SIBLING sheet of the day detail,
    // chained through the day sheet's onDismiss — never a sheet nested inside a
    // sheet (which presents unreliably under a fullScreenCover).
    @State private var pendingProper: MassProper?
    @State private var properToShow: MassProper?

    private var rite: MissalRite { MissalRite(rawValue: riteRaw) ?? .rite1962 }
    private var store: ContentStore { .shared }

    /// `initial` decides which month opens first (defaults to the current month).
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
    private var canGoPrevYear: Bool { year > yearRange.lowerBound }
    private var canGoNextYear: Bool { year < yearRange.upperBound }

    private static let weekdayLetters = ["S", "M", "T", "W", "T", "F", "S"]
    private static let columns = Array(repeating: GridItem(.flexible(), spacing: 4), count: 7)

    var body: some View {
        VStack(spacing: 0) {
            chrome
            navRow
            weekdayHeader
            Divider().overlay(Color.frameLine)
            grid
            Spacer(minLength: 0)
            legend
        }
        .background(Color.pageBackground.ignoresSafeArea())
        .sheet(item: $selectedDay, onDismiss: presentPendingProper) { day in
            DayDetailView(day: day, rite: rite) { proper in
                pendingProper = proper
                selectedDay = nil          // dismiss → onDismiss presents the Mass
            }
        }
        .sheet(item: $properToShow) { proper in
            ProperView(proper: proper)
        }
    }

    /// Called once the day-detail sheet has fully dismissed; presents the Mass
    /// the user requested, if any. Deferred to the next runloop tick so the two
    /// sheet transitions never overlap.
    private func presentPendingProper() {
        guard let proper = pendingProper else { return }
        pendingProper = nil
        DispatchQueue.main.async { properToShow = proper }
    }

    // MARK: Chrome (title bar)

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
            navButton("\u{00AB}", enabled: canGoPrevYear) { step(months: -12) }   // « previous year
            navButton("\u{2039}", enabled: canGoPrev) { step(months: -1) }        // ‹ previous month
            Spacer()
            Text(model.title)
                .font(.titleM)
                .foregroundStyle(Color.primaryText)
            Spacer()
            navButton("\u{203A}", enabled: canGoNext) { step(months: 1) }         // › next month
            navButton("\u{00BB}", enabled: canGoNextYear) { step(months: 12) }    // » next year
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 12)
    }

    private func navButton(_ glyph: String, enabled: Bool, _ action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(glyph)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(enabled ? Color.goldLeaf : Color.frameLine)
                .frame(width: 24)
        }
        .disabled(!enabled)
    }

    private var weekdayHeader: some View {
        HStack(spacing: 4) {
            ForEach(Array(Self.weekdayLetters.enumerated()), id: \.offset) { _, letter in
                Text(letter)
                    .font(.captionSm)
                    .foregroundStyle(Color.tertiaryText)
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 6)
    }

    // MARK: Grid

    private var grid: some View {
        LazyVGrid(columns: Self.columns, spacing: 4) {
            ForEach(cells) { cell in
                switch cell {
                case .blank:
                    Color.clear.frame(height: 46)
                case .day(let d):
                    dayCell(d)
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.top, 8)
    }

    private var cells: [CalCell] {
        (0..<model.leadingBlanks).map { CalCell.blank($0) } + model.days.map { CalCell.day($0) }
    }

    private func dayCell(_ d: CalendarDay) -> some View {
        Button { selectedDay = d } label: {
            VStack(spacing: 4) {
                Text("\(d.day)")
                    .font(.bodySm)
                    .fontWeight(d.isMajor ? .semibold : .regular)
                    .foregroundStyle(d.isToday ? Color.parchment : Color.primaryText)
                Circle()
                    .fill(d.colour?.swiftUIColor ?? Color.clear)
                    .frame(width: 6, height: 6)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 46)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(d.isToday ? Color.sanctuaryRed : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: Legend

    private var legend: some View {
        let pairs: [(LiturgicalColour, String)] = [
            (.white, "White"), (.red, "Red"), (.green, "Green"),
            (.violet, "Violet"), (.rose, "Rose"), (.black, "Black"),
        ]
        return HStack(spacing: 14) {
            ForEach(Array(pairs.enumerated()), id: \.offset) { _, pair in
                HStack(spacing: 4) {
                    Circle().fill(pair.0.swiftUIColor).frame(width: 6, height: 6)
                    Text(pair.1).font(.system(size: 9)).foregroundStyle(Color.tertiaryText)
                }
            }
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity)
    }

    // MARK: Navigation logic

    private var isCurrentMonth: Bool {
        let cal = Calendar.liturgical
        let now = Date()
        return year == cal.component(.year, from: now) && month == cal.component(.month, from: now)
    }

    private func jumpToToday() {
        let cal = Calendar.liturgical
        let now = Date()
        year = cal.component(.year, from: now)
        month = cal.component(.month, from: now)
    }

    /// Steps the displayed month by `months` (can be ±1 or ±12), clamped to the
    /// ordo year range so paging can never run off the bundled data.
    private func step(months: Int) {
        var m = month + months
        var y = year
        while m > 12 { m -= 12; y += 1 }
        while m < 1 { m += 12; y -= 1 }
        y = min(max(y, yearRange.lowerBound), yearRange.upperBound)
        year = y
        month = m
    }
}

// MARK: - Grid cell

private enum CalCell: Identifiable {
    case blank(Int)
    case day(CalendarDay)

    var id: String {
        switch self {
        case .blank(let i): return "blank-\(i)"
        case .day(let d):   return "day-\(d.day)"
        }
    }
}

// MARK: - DayDetailView

private struct DayDetailView: View {
    let day: CalendarDay
    let rite: MissalRite
    /// Invoked when the user taps "View the Mass"; the parent dismisses this
    /// sheet and presents the proper as a sibling sheet.
    let onViewMass: (MassProper) -> Void
    @Environment(\.dismiss) private var dismiss
    @AppStorage(SettingsKey.language) private var languageRaw = LanguageMode.both.rawValue

    private var langMode: LanguageMode { LanguageMode(rawValue: languageRaw) ?? .both }
    private var ctx: LiturgicalContext { .for(date: day.date, rite: rite) }
    private var proper: MassProper? { ContentStore.shared.properForDate(day.date, rite: rite) }

    /// Primary day title — the winning ordo name (Latin), or the feria name if
    /// the date is outside the ordo range.
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
