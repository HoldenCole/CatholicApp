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

private enum CalViewMode: String, CaseIterable {
    case list, month

    var icon: String {
        switch self {
        case .list:  return "list.bullet"
        case .month: return "square.grid.3x3"
        }
    }
}

struct CalendarView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage(SettingsKey.rite) private var riteRaw = MissalRite.rite1962.rawValue

    @State private var year: Int
    @State private var month: Int
    @State private var selectedDay: CalendarDay?
    @State private var pendingProper: MassProper?
    @State private var properToShow: MassProper?
    @State private var viewMode: CalViewMode = .list

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
            switch viewMode {
            case .list:  dayList
            case .month: monthGrid
            }
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
        HStack(spacing: 12) {
            Text("Kalendárium")
                .smallLabel(color: Color.sanctuaryRed)
            Spacer()
            viewModePicker
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
        }
        .padding(.horizontal, 24)
        .padding(.top, 20)
        .padding(.bottom, 8)
    }

    private var viewModePicker: some View {
        HStack(spacing: 0) {
            ForEach(CalViewMode.allCases, id: \.self) { mode in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) { viewMode = mode }
                } label: {
                    Image(systemName: mode.icon)
                        .font(.system(size: 12))
                        .foregroundStyle(viewMode == mode ? Color.parchment : Color.tertiaryText)
                        .frame(width: 30, height: 26)
                        .background(
                            RoundedRectangle(cornerRadius: 4)
                                .fill(viewMode == mode ? Color.sanctuaryRed : Color.clear)
                        )
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 5)
                .stroke(Color.frameLine, lineWidth: 0.5)
        )
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
                    ForEach(Array(model.days.enumerated()), id: \.element.id) { idx, day in
                        if showsSeasonHeader(at: idx), let label = day.seasonLabel {
                            SeasonDivider(label: label)
                        }
                        DayRow(day: day) { selectedDay = day }
                            .id(day.id)
                        if idx < model.days.count - 1 && !showsSeasonHeader(at: idx + 1) {
                            Rectangle()
                                .fill(Color.goldLeaf.opacity(0.16))
                                .frame(height: 0.5)
                                .padding(.leading, 78)
                        }
                    }
                }
                .padding(.bottom, 28)
            }
            .onAppear {
                if let todayDay = model.days.first(where: { $0.isToday }) {
                    proxy.scrollTo(todayDay.id, anchor: .center)
                }
            }
        }
    }

    /// True when day `idx` begins a new liturgical season (or is the first day).
    private func showsSeasonHeader(at idx: Int) -> Bool {
        guard idx >= 0, idx < model.days.count else { return false }
        guard model.days[idx].seasonLabel != nil else { return false }
        if idx == 0 { return true }
        return model.days[idx - 1].seasonLabel != model.days[idx].seasonLabel
    }

    // MARK: Month grid

    private static let gridWeekdayLetters = ["S", "M", "T", "W", "T", "F", "S"]
    private static let gridColumns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 7)

    private var monthGrid: some View {
        VStack(spacing: 0) {
            HStack(spacing: 2) {
                ForEach(Array(Self.gridWeekdayLetters.enumerated()), id: \.offset) { _, letter in
                    Text(letter)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Color.tertiaryText)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            ScrollView {
                LazyVGrid(columns: Self.gridColumns, spacing: 2) {
                    ForEach(0..<model.leadingBlanks, id: \.self) { _ in
                        Color.clear.frame(height: 52)
                    }
                    ForEach(model.days) { day in
                        gridCell(day)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 20)
            }
        }
    }

    @AppStorage(SettingsKey.language) private var calLangRaw = LanguageMode.both.rawValue
    private var calLang: LanguageMode { LanguageMode(rawValue: calLangRaw) ?? .both }

    private func gridCell(_ d: CalendarDay) -> some View {
        Button { selectedDay = d } label: {
            VStack(spacing: 2) {
                ZStack {
                    Circle()
                        .fill(d.isToday
                              ? Color.sanctuaryRed
                              : (d.colour?.swiftUIColor ?? Color.frameLine).opacity(0.14))
                    Circle()
                        .stroke(gridRingColor(d), lineWidth: d.isMajor ? 1.5 : 0.5)
                    Text("\(d.day)")
                        .font(.system(size: 13, weight: d.isMajor ? .semibold : .regular, design: .serif))
                        .foregroundStyle(d.isToday ? Color.parchment : Color.primaryText)
                }
                .frame(width: 30, height: 30)

                Text(gridLabel(d))
                    .font(.system(size: 8))
                    .foregroundStyle(Color.secondaryText)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(height: 20)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func gridRingColor(_ d: CalendarDay) -> Color {
        if d.isToday { return Color.sanctuaryRed }
        return (d.colour?.swiftUIColor ?? Color.frameLine).opacity(d.isMajor ? 0.8 : 0.3)
    }

    private func gridLabel(_ d: CalendarDay) -> String {
        if calLang != .latinOnly, let eng = d.englishName {
            let parts = eng.split(separator: ",")
            return String(parts.first ?? Substring(eng))
        }
        let label = d.label ?? ""
        let parts = label.split(separator: " ")
        return parts.prefix(3).joined(separator: " ")
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

// MARK: - Season divider

private struct SeasonDivider: View {
    let label: String
    var body: some View {
        HStack(spacing: 12) {
            Rectangle().fill(Color.goldLeaf.opacity(0.3)).frame(height: 0.5)
            Text(label.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .tracking(2.5)
                .foregroundStyle(Color.goldLeaf)
                .fixedSize()
            Rectangle().fill(Color.goldLeaf.opacity(0.3)).frame(height: 0.5)
        }
        .padding(.horizontal, 28)
        .padding(.top, 24)
        .padding(.bottom, 12)
    }
}

// MARK: - Day row (illuminated medallion)

private struct DayRow: View {
    let day: CalendarDay
    let onTap: () -> Void
    @AppStorage(SettingsKey.language) private var languageRaw = LanguageMode.both.rawValue
    private var mode: LanguageMode { LanguageMode(rawValue: languageRaw) ?? .both }

    var body: some View {
        Button(action: onTap) {
            HStack(alignment: .top, spacing: 14) {
                medallion

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(day.weekdayAbbrev)
                            .font(.system(size: 10, weight: .medium))
                            .tracking(1)
                            .foregroundStyle(Color.tertiaryText)
                        if day.isSunday {
                            Text("\u{2720}")   // ✠ — day of obligation
                                .font(.system(size: 9))
                                .foregroundStyle(Color.sanctuaryRed)
                        }
                    }

                    if mode != .vernacular {
                        Text(day.label ?? "Feria")
                            .font(.body)
                            .fontWeight(day.isMajor ? .semibold : .regular)
                            .foregroundStyle(Color.primaryText)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if mode != .latinOnly {
                        Text(day.englishLine)
                            .font(.captionSm)
                            .italic()
                            .foregroundStyle(Color.secondaryText)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Spacer(minLength: 4)

                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundStyle(Color.tertiaryText.opacity(0.6))
                    .padding(.top, 2)
            }
            .padding(.horizontal, 22)
            .padding(.vertical, 13)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .id(day.id)
    }

    // Circular day medallion: a soft liturgical-colour wash + ring around the
    // serif day number. Today is a filled sanctuary-red disc; major feasts get
    // a heavier ring.
    private var medallion: some View {
        ZStack {
            Circle()
                .fill(day.isToday
                      ? Color.sanctuaryRed
                      : (day.colour?.swiftUIColor ?? Color.frameLine).opacity(0.14))
            Circle()
                .stroke(ringColor, lineWidth: day.isMajor ? 1.5 : 1)
            Text("\(day.day)")
                .font(.system(size: 16, weight: day.isMajor ? .semibold : .regular, design: .serif))
                .foregroundStyle(day.isToday ? Color.parchment : Color.primaryText)
        }
        .frame(width: 40, height: 40)
    }

    private var ringColor: Color {
        if day.isToday { return Color.sanctuaryRed }
        let base = day.colour?.swiftUIColor ?? Color.frameLine
        return base.opacity(day.isMajor ? 0.8 : 0.45)
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

            if langMode != .latinOnly, let english = day.englishName {
                Text(english)
                    .font(.bodySm)
                    .italic()
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color.goldLeaf.opacity(0.85))
                    .padding(.horizontal, 16)
            }

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
