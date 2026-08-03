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
    case list, month, year

    var icon: String {
        switch self {
        case .list:  return "list.bullet"
        case .month: return "square.grid.3x3"
        case .year:  return "calendar"
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

    @AppStorage(SettingsKey.penance) private var calPenanceRaw = PenanceDiscipline.discipline1962.rawValue

    private var rite: MissalRite { MissalRite(rawValue: riteRaw) ?? .rite1962 }
    private var discipline: PenanceDiscipline { PenanceDiscipline(rawValue: calPenanceRaw) ?? .discipline1962 }
    private var store: ContentStore { .shared }

    init(initial: Date = Date()) {
        let cal = Calendar.liturgical
        _year = State(initialValue: cal.component(.year, from: initial))
        _month = State(initialValue: cal.component(.month, from: initial))
    }

    private var yearRange: ClosedRange<Int> { store.ordoYearRange(rite: rite) }
    private var model: CalendarMonth {
        CalendarMonth.build(year: year, month: month, rite: rite, store: store,
                            discipline: discipline)
    }
    private var canGoPrev: Bool { !(year == yearRange.lowerBound && month == 1) }
    private var canGoNext: Bool { !(year == yearRange.upperBound && month == 12) }

    var body: some View {
        // Built ONCE per render pass — each build computes a LiturgicalContext
        // (computus) for every day of the month, so this must not be a
        // computed property the row helpers re-trigger dozens of times.
        let model = self.model

        VStack(spacing: 0) {
            chrome
            if viewMode != .year {
                navRow
            } else {
                yearNavRow
            }
            Divider().overlay(Color.frameLine)
            switch viewMode {
            case .list:  dayList(model)
            case .month: monthGrid(model)
            case .year:  YearOverview(year: year, rite: rite, store: store) { date in
                let cal = Calendar.liturgical
                self.year = cal.component(.year, from: date)
                self.month = cal.component(.month, from: date)
                withAnimation(.easeInOut(duration: 0.2)) { viewMode = .list }
            }
            }
        }
        .background(Color.pageBackground.ignoresSafeArea())
        // Clamp into the rite's data horizon (a device date past the bundled
        // ordos would otherwise open an empty year).
        .onAppear {
            year = min(max(year, yearRange.lowerBound), yearRange.upperBound)
        }
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
            moveableFeastMenu
            viewModePicker
            if !isCurrentMonth {
                Button { jumpToToday() } label: {
                    Text(ContentStore.shared.uiString("calendar.today", "Today"))
                        .font(.captionSm)
                        .foregroundStyle(Color.sanctuaryRed)
                }
            }
            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.scaledSystem(15, weight: .medium))
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
                        .font(.scaledSystem(12))
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

    // MARK: Moveable feasts (quick jump)

    private var moveableFeastMenu: some View {
        Menu {
            ForEach(LiturgicalYearModel.moveableDates(year: year, rite: rite, store: store),
                    id: \.label) { feast in
                Button {
                    let cal = Calendar.liturgical
                    self.month = cal.component(.month, from: feast.date)
                    if viewMode == .year {
                        withAnimation(.easeInOut(duration: 0.2)) { viewMode = .list }
                    }
                } label: {
                    Text(ContentStore.shared.uiString("calendar.moveable." + feast.label.lowercased().replacingOccurrences(of: " ", with: "_"), feast.label) + " \u{00B7} " + Self.shortDate.string(from: feast.date))
                }
            }
        } label: {
            Image(systemName: "sparkles")
                .font(.scaledSystem(13))
                .foregroundStyle(Color.goldLeaf)
        }
    }

    private static let shortDate: DateFormatter = {
        let df = DateFormatter()
        df.calendar = Calendar.liturgical
        df.locale = Locale(identifier: "en_US_POSIX")
        df.dateFormat = "MMM d"
        return df
    }()

    // MARK: Year navigation (year-overview mode)

    private var yearNavRow: some View {
        HStack(spacing: 16) {
            navButton("\u{2039}", enabled: year > yearRange.lowerBound) { year -= 1 }
            Spacer()
            VStack(spacing: 2) {
                Text(String(year))
                    .font(.titleM)
                    .foregroundStyle(Color.primaryText)
                Text(ContentStore.shared.uiString("calendar.year_overview", "The Liturgical Year"))
                    .font(.captionSm)
                    .foregroundStyle(Color.tertiaryText)
            }
            Spacer()
            navButton("\u{203A}", enabled: year < yearRange.upperBound) { year += 1 }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 10)
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
                .font(.scaledSystem(22, weight: .medium))
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

    private func dayList(_ model: CalendarMonth) -> some View {
        let days = model.days
        return ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(days.enumerated()), id: \.element.id) { idx, day in
                        if showsSeasonHeader(in: days, at: idx), let label = day.seasonLabel {
                            SeasonDivider(label: label)
                        }
                        DayRow(day: day) { selectedDay = day }
                            .id(day.id)
                        if idx < days.count - 1 && !showsSeasonHeader(in: days, at: idx + 1) {
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
                if let todayDay = days.first(where: { $0.isToday }) {
                    proxy.scrollTo(todayDay.id, anchor: .center)
                }
            }
        }
    }

    /// True when day `idx` begins a new liturgical season (or is the first day).
    private func showsSeasonHeader(in days: [CalendarDay], at idx: Int) -> Bool {
        guard idx >= 0, idx < days.count else { return false }
        guard days[idx].seasonLabel != nil else { return false }
        if idx == 0 { return true }
        return days[idx - 1].seasonLabel != days[idx].seasonLabel
    }

    // MARK: Month grid

    private static let gridWeekdayLetters = ["S", "M", "T", "W", "T", "F", "S"]
    private static let gridColumns = Array(repeating: GridItem(.flexible(), spacing: 2), count: 7)

    private func monthGrid(_ model: CalendarMonth) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 2) {
                ForEach(Array(Self.gridWeekdayLetters.enumerated()), id: \.offset) { _, letter in
                    Text(letter)
                        .font(.scaledSystem(10, weight: .medium))
                        .foregroundStyle(Color.tertiaryText)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)

            ScrollView {
                LazyVGrid(columns: Self.gridColumns, spacing: 2) {
                    ForEach(0..<model.leadingBlanks, id: \.self) { _ in
                        Color.clear.frame(height: 60)
                    }
                    ForEach(model.days) { day in
                        gridCell(day)
                    }
                }
                .id("\(year)-\(month)")
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
                        .font(.scaledSystem(13, weight: d.isMajor ? .semibold : .regular, design: .serif))
                        .foregroundStyle(d.isToday ? Color.parchment : Color.primaryText)
                }
                .frame(width: 30, height: 30)

                Text(gridLabel(d))
                    .font(.scaledSystem(8))
                    .foregroundStyle(Color.secondaryText)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(height: 20)

                DayMarkerPips(day: d)
                    .frame(height: 8)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 60)
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

// MARK: - Year overview ("where am I in the year")

private struct YearOverview: View {
    let year: Int
    let rite: MissalRite
    let store: ContentStore
    /// Jump into the month list at `date`.
    let onOpen: (Date) -> Void

    var body: some View {
        // Computed once per render pass: each iterates the whole year.
        let segments = LiturgicalYearModel.seasons(year: year, rite: rite, store: store)
        let markers = LiturgicalYearModel.markers(year: year, rite: rite, store: store)
        // Day-granular "today": segment bounds are midnight-anchored, so a
        // raw Date() comparison fails on the LAST day of every season.
        let today = Calendar.liturgical.startOfDay(for: Date())

        ScrollViewReader { proxy in
            ScrollView {
                VStack(spacing: 10) {
                    ForEach(segments) { seg in
                        segmentCard(seg, markers: markers, today: today)
                            .id(seg.id)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .onAppear {
                if let current = segments.first(where: { seg in
                    (seg.startDate...seg.endDate).contains(today)
                }) {
                    proxy.scrollTo(current.id, anchor: .center)
                }
            }
        }
    }

    private func segmentCard(_ seg: SeasonSegment, markers: [YearMarker], today: Date) -> some View {
        let tint = Self.seasonTint(seg.seasonKey)
        let isCurrent = (seg.startDate...seg.endDate).contains(today)
        let segMarkers = markers.filter { $0.date >= seg.startDate && $0.date <= seg.endDate }

        return VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 8) {
                Rectangle()
                    .fill(tint)
                    .frame(width: 4)
                    .frame(maxHeight: .infinity)
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Text(ContentStore.shared.uiString("calendar.season." + seg.label.lowercased().replacingOccurrences(of: " ", with: "_"), seg.label).uppercased())
                            .font(.scaledSystem(11, weight: .semibold))
                            .tracking(2)
                            .foregroundStyle(tint)
                        Spacer()
                        if isCurrent {
                            Text(ContentStore.shared.uiString("calendar.you_are_here", "You are here").uppercased())
                                .font(.scaledSystem(9, weight: .semibold))
                                .tracking(1.5)
                                .foregroundStyle(Color.parchment)
                                .padding(.horizontal, 7)
                                .padding(.vertical, 3)
                                .background(Capsule().fill(Color.sanctuaryRed))
                        }
                        Text("\(seg.dayCount) " + ContentStore.shared.uiString("calendar.days", "days"))
                            .font(.scaledSystem(10))
                            .foregroundStyle(Color.tertiaryText)
                    }
                    Text("\(Self.rangeDate.string(from: seg.startDate)) \u{2013} \(Self.rangeDate.string(from: seg.endDate))")
                        .font(.captionSm)
                        .italic()
                        .foregroundStyle(Color.secondaryText)

                    ForEach(segMarkers) { marker in
                        Button { onOpen(marker.date) } label: {
                            HStack(spacing: 8) {
                                Circle()
                                    .fill(LiturgicalColour.from(ordoColor: marker.color).swiftUIColor)
                                    .frame(width: 6, height: 6)
                                Text(Self.markerDate.string(from: marker.date))
                                    .font(.scaledSystem(11, design: .serif))
                                    .foregroundStyle(Color.tertiaryText)
                                    .frame(width: 46, alignment: .leading)
                                Text(marker.english ?? marker.name)
                                    .font(.scaledSystem(13, design: .serif))
                                    .foregroundStyle(Color.primaryText)
                                    .lineLimit(1)
                                Spacer(minLength: 0)
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 12)
                .padding(.trailing, 12)
            }
        }
        .background(tint.opacity(isCurrent ? 0.10 : 0.05))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(isCurrent ? Color.sanctuaryRed.opacity(0.35) : Color.frameLine, lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    /// Muted band tints — colour is information, but legibility rules.
    private static func seasonTint(_ key: String) -> Color {
        switch key {
        case "advent", "lent": return Color(red: 0.42, green: 0.21, blue: 0.60)
        case "pre-lent":       return Color(red: 0.55, green: 0.35, blue: 0.62)
        case "christmas":      return Color(red: 0.65, green: 0.53, blue: 0.16)
        case "easter":         return Color(red: 0.72, green: 0.60, blue: 0.20)
        default:               return Color(red: 0.23, green: 0.36, blue: 0.16)
        }
    }

    private static let rangeDate: DateFormatter = {
        let df = DateFormatter()
        df.calendar = Calendar.liturgical
        df.locale = Locale(identifier: "en_US_POSIX")
        df.dateFormat = "MMMM d"
        return df
    }()

    private static let markerDate: DateFormatter = {
        let df = DateFormatter()
        df.calendar = Calendar.liturgical
        df.locale = Locale(identifier: "en_US_POSIX")
        df.dateFormat = "MMM d"
        return df
    }()
}

// MARK: - Day markers (octave / vigil / Ember / fast pips)

/// Tiny letter pips shared by the month grid and the day list: V vigil,
/// O octave day, E Ember day, plus a filled dot on strict fast days under the
/// user's discipline. Presentation only — all flags come from the ordo/context.
struct DayMarkerPips: View {
    let day: CalendarDay

    var body: some View {
        HStack(spacing: 3) {
            if day.isVigil { pip("V", Color(red: 0.42, green: 0.21, blue: 0.60)) }
            if day.isOctaveDay { pip("O", Color.goldLeaf) }
            if day.isEmberDay { pip("E", Color.sanctuaryRed) }
            if day.penanceStrict {
                Circle()
                    .fill(Color.sanctuaryRed.opacity(0.75))
                    .frame(width: 4, height: 4)
            }
        }
    }

    private func pip(_ letter: String, _ color: Color) -> some View {
        Text(letter)
            .font(.scaledSystem(7, weight: .bold))
            .foregroundStyle(color.opacity(0.9))
    }
}

// MARK: - Season divider

private struct SeasonDivider: View {
    let label: String
    var body: some View {
        HStack(spacing: 12) {
            Rectangle().fill(Color.goldLeaf.opacity(0.3)).frame(height: 0.5)
            Text(label.uppercased())
                .font(.scaledSystem(10, weight: .semibold))
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
                            .font(.scaledSystem(10, weight: .medium))
                            .tracking(1)
                            .foregroundStyle(Color.tertiaryText)
                        if day.isSunday {
                            Text("\u{2720}")   // ✠ — day of obligation
                                .font(.scaledSystem(9))
                                .foregroundStyle(Color.sanctuaryRed)
                        }
                        DayMarkerPips(day: day)
                    }

                    if mode != .vernacular {
                        Text(day.label ?? ContentStore.shared.uiString("calendar.feria", "Feria"))
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
                    .font(.scaledSystem(12))
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
                .font(.scaledSystem(16, weight: day.isMajor ? .semibold : .regular, design: .serif))
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
    @AppStorage(SettingsKey.penance) private var penanceRaw = PenanceDiscipline.discipline1962.rawValue
    @State private var showShareSheet = false
    @State private var pdfURL: URL?

    private var langMode: LanguageMode { LanguageMode(rawValue: languageRaw) ?? .both }
    private var discipline: PenanceDiscipline { PenanceDiscipline(rawValue: penanceRaw) ?? .discipline1962 }
    private var ctx: LiturgicalContext { .for(date: day.date, rite: rite, discipline: discipline) }
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
        .sheet(isPresented: $showShareSheet) {
            if let url = pdfURL { ShareSheet(items: [url]) }
        }
    }

    private func sharePDF() {
        var flags: [String] = []
        if ctx.isFirstFriday { flags.append(ContentStore.shared.uiString("flag.first_friday", "First Friday")) }
        if ctx.isFirstSaturday { flags.append(ContentStore.shared.uiString("flag.first_saturday", "First Saturday")) }
        if ctx.isEmberDay { flags.append(ContentStore.shared.uiString("flag.ember_day", "Ember Day")) }
        if day.isSunday { flags.append(ContentStore.shared.uiString("flag.sunday_obligation", "Sunday Obligation")) }

        let colourHex: String? = day.colour.map {
            switch $0 {
            case .violet: return "#6A359A"
            case .rose:   return "#A04860"
            case .white:  return "#7A5A0E"
            case .red:    return "#8B1A1A"
            case .green:  return "#3A5D28"
            case .black:  return "#2A2521"
            }
        }

        let html = MassHTMLExporter.calendarDayHTML(
            latinTitle: title,
            englishTitle: day.englishName,
            longDate: LongDateFormatter.format(day.date),
            colour: day.colour?.rawValue.capitalized,
            colourHex: colourHex,
            season: ctx.englishName,
            flags: flags,
            penanceTitle: ctx.penance.title,
            penanceDesc: ctx.penance.desc,
            penanceStrict: ctx.penance.strict,
            discipline: discipline.short
        )
        if let url = PDFExporter.writePDF(from: html, title: title) {
            pdfURL = url
            showShareSheet = true
        }
    }

    private var shareText: String {
        let eng = day.englishName ?? title
        let colour = day.colour?.rawValue.capitalized ?? ""
        let season = ctx.englishName
        let penance = ctx.penance.title
        let disc = discipline.short
        return "\(LongDateFormatter.format(day.date))\n\(title)\n\(eng)\n\(colour) · \(season)\n\(penance) (\(disc))"
    }

    private var header: some View {
        VStack(spacing: 8) {
            HStack {
                Spacer()
                Menu {
                    Button { sharePDF() } label: {
                        Label(ContentStore.shared.uiString("share.pdf", "Share as PDF"), systemImage: "doc.richtext")
                    }
                    ShareLink(item: shareText) {
                        Label(ContentStore.shared.uiString("share.text", "Share as Text"), systemImage: "doc.plaintext")
                    }
                } label: {
                    Image(systemName: "square.and.arrow.up")
                        .font(.scaledSystem(14))
                        .foregroundStyle(Color.goldLeaf)
                }
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.scaledSystem(15, weight: .medium))
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
                infoRow(label: ContentStore.shared.uiString("calendar.colour", "Liturgical Colour"), value: colour.rawValue.capitalized, swatch: colour)
            }
            infoRow(label: ContentStore.shared.uiString("calendar.season_label", "Season"), value: langMode == .latinOnly ? ctx.latinName : ctx.englishName)

            if ctx.isFirstFriday || ctx.isFirstSaturday || ctx.isEmberDay
                || day.isVigil || day.isOctaveDay {
                VStack(alignment: .leading, spacing: 6) {
                    if ctx.isFirstFriday { flag(ContentStore.shared.uiString("flag.first_friday", "First Friday")) }
                    if ctx.isFirstSaturday { flag(ContentStore.shared.uiString("flag.first_saturday", "First Saturday")) }
                    if ctx.isEmberDay { flag(ContentStore.shared.uiString("flag.ember_day", "Ember Day")) }
                    if day.isVigil { flag(ContentStore.shared.uiString("flag.vigil", "Vigil")) }
                    if day.isOctaveDay { flag(ContentStore.shared.uiString("flag.octave", "Within an Octave")) }
                }
            }

            if day.isSunday {
                flag(ContentStore.shared.uiString("flag.sunday_obligation", "Sunday Obligation"))
            }

            // Penance / fasting section
            penanceSection

            if let proper {
                Button { onViewMass(proper) } label: {
                    HStack {
                        Image(systemName: "book.closed")
                            .font(.scaledSystem(14))
                            .foregroundStyle(Color.sanctuaryRed)
                        Text(ContentStore.shared.uiString("calendar.view_mass", "View the Mass"))
                            .font(.titleM)
                            .italic()
                            .foregroundStyle(Color.primaryText)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.scaledSystem(12))
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
                .font(.scaledSystem(10))
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

    private var penanceSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(ContentStore.shared.uiString("penance.fast_abstinence", "Fasting & Abstinence").uppercased())
                    .font(.scaledSystem(10))
                    .tracking(1.5)
                    .foregroundStyle(Color.tertiaryText)
                Spacer()
                Text(discipline.short)
                    .font(.scaledSystem(9))
                    .foregroundStyle(Color.goldLeaf)
            }

            HStack(spacing: 8) {
                Circle()
                    .fill(ctx.penance.strict ? Color.sanctuaryRed : Color.goldLeaf)
                    .frame(width: 8, height: 8)
                Text(ctx.penance.title)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundStyle(Color.primaryText)
            }

            Text(ctx.penance.desc)
                .font(.captionSm)
                .foregroundStyle(Color.secondaryText)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(ctx.penance.strict ? Color.sanctuaryRed.opacity(0.3) : Color.frameLine, lineWidth: 0.5)
        )
    }
}
