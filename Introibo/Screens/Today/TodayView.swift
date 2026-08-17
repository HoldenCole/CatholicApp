import SwiftUI

// The Hódie tab — the app's home screen.
// Shows today's liturgical date, penance, devotions, rosary card,
// followed-saint card, and schola progress. Mirrors prototype/today.html.

struct TodayView: View {
    private var ctx: LiturgicalContext { .current() }
    @AppStorage(SettingsKey.rite) private var riteRaw = MissalRite.rite1962.rawValue
    @AppStorage(SettingsKey.penance) private var penanceRaw = PenanceDiscipline.discipline1962.rawValue
    @AppStorage(SettingsKey.theme) private var themeRaw = AppTheme.parchment.rawValue
    @AppStorage(SettingsKey.language) private var languageRaw = LanguageMode.both.rawValue
    private var langMode: LanguageMode { LanguageMode(rawValue: languageRaw) ?? .both }
    @State private var showSettings = false
    @State private var showSearch = false
    @State private var showCalendar = false
    @State private var offeringTapped = false
    @State private var showProper = false
    @State private var tutorialNavTarget: String? = nil
    private var tutorial: TutorialManager { TutorialManager.shared }

    private var rite: MissalRite { MissalRite(rawValue: riteRaw) ?? .rite1962 }
    private var discipline: PenanceDiscipline { PenanceDiscipline(rawValue: penanceRaw) ?? .discipline1962 }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    header
                    mainContent
                }
            }
            .navigationDestination(item: $tutorialNavTarget) { target in
                switch target {
                case "office":     OfficeView()
                case "stations":   StationsView()
                case "rosary":     RosaryView()
                case "confession": ConfessionView()
                case "saints":     SaintsView()
                default:           EmptyView()
                }
            }
            .onChange(of: tutorial.targetSubScreen) { _, newTarget in
                if let target = newTarget {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                        tutorialNavTarget = target
                    }
                }
            }
            .background(Color.pageBackground.ignoresSafeArea())
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .fullScreenCover(isPresented: $showSearch) {
                SearchView()
            }
            .fullScreenCover(isPresented: $showCalendar) {
                CalendarView()
            }
            .sheet(isPresented: $offeringTapped) {
                if let prayer = ContentStore.shared.prayer(slug: offeringSlug()) {
                    PrayerDetailView(prayer: prayer)
                }
            }
            .sheet(isPresented: $showProper) {
                if let proper = ContentStore.shared.properForDate(ctx.date, rite: rite) {
                    ProperView(proper: proper)
                } else if let slug = ctx.properSlug,
                          let proper = ContentStore.shared.proper(slug: slug) {
                    ProperView(proper: proper)
                }
            }
        }
    }

    // MARK: - Dark walnut header

    private var header: some View {
        VStack(spacing: 6) {
            HStack(spacing: 18) {
                Spacer()
                Button { showCalendar = true } label: {
                    Image(systemName: "calendar")
                        .foregroundStyle(Color.goldLeaf)
                        .font(.scaledSystem(16))
                }
                .spotlightAnchor("calendarButton")
                Button { showSearch = true } label: {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(Color.goldLeaf)
                        .font(.scaledSystem(16))
                }
                .spotlightAnchor("searchButton")
                Button { showSettings = true } label: {
                    Image(systemName: "gearshape")
                        .foregroundStyle(Color.goldLeaf)
                        .font(.scaledSystem(16))
                }
                .spotlightAnchor("settingsButton")
            }
            .padding(.top, 12)
            .padding(.trailing, 6)

            // Liturgical colour pip + season
            HStack(spacing: 8) {
                Circle()
                    .fill(ctx.colour.swiftUIColor)
                    .frame(width: 8, height: 8)
                // The big title below already names the weekday — the caps line
                // carries only the season, so it reads as one quiet line
                // instead of three crowded ones.
                LanguageAwareText(latin: ctx.latinName, english: ctx.englishName)
                    .smallLabel(color: Color.goldLeaf)
            }
            .padding(.top, 4)

            Text(langMode == .latinOnly ? ctx.feriaLatin : ctx.feriaEnglish)
                .font(.pageTitle)
                .foregroundStyle(Color.ivory)

            Text(LongDateFormatter.format(ctx.date))
                .font(.bodySm)
                .italic()
                .foregroundStyle(Color.muted)

            riteLabel
                .padding(.top, 8)

            // Seasonal note (countdown, octave, etc)
            if let note = ctx.seasonalNote {
                Text(note)
                    .font(.captionSm)
                    .italic()
                    .foregroundStyle(Color.goldLeaf)
                    .padding(.top, 6)
            }

            // Marian antiphon (suppressed during Triduum)
            if !ctx.marian.isSuppressed {
                Text(ctx.marian.title)
                    .font(.captionSm)
                    .italic()
                    .foregroundStyle(Color.muted)
                    .padding(.top, 2)
            }

            // First Friday / First Saturday / Ember day flags
            if ctx.isFirstFriday || ctx.isFirstSaturday || ctx.isEmberDay {
                HStack(spacing: 12) {
                    if ctx.isFirstFriday {
                        Text(ContentStore.shared.uiString("flag.first_friday", "First Friday"))
                            .font(.captionSm)
                            .italic()
                            .foregroundStyle(Color.sanctuaryRed)
                    }
                    if ctx.isFirstSaturday {
                        Text(ContentStore.shared.uiString("flag.first_saturday", "First Saturday"))
                            .font(.captionSm)
                            .italic()
                            .foregroundStyle(Color.sanctuaryRed)
                    }
                    if ctx.isEmberDay {
                        Text(ContentStore.shared.uiString("flag.ember_day", "Ember Day"))
                            .font(.captionSm)
                            .italic()
                            .foregroundStyle(Color.sanctuaryRed)
                    }
                }
                .padding(.top, 4)
            }

            // Liturgical colour bar
            Rectangle()
                .fill(ctx.colour.swiftUIColor.opacity(0.5))
                .frame(height: 2)
                .padding(.horizontal, 60)
                .padding(.top, 14)
        }
        .padding(.horizontal, 28)
        .padding(.bottom, 22)
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(colors: [Color.walnut, Color.walnutHi], startPoint: .top, endPoint: .bottom)
        )
    }

    private var riteLabel: some View {
        Button { showSettings = true } label: {
            HStack(spacing: 6) {
                Text("Ritus  ·  \(rite.short)")
                    .smallLabel(color: Color.goldLeaf, tracking: 2)
                Text("›")
                    .font(.scaledSystem(8))
                    .foregroundStyle(Color.goldLeaf)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Main content

    private var mainContent: some View {
        VStack(spacing: 24) {
            upcomingFeastsCard
            dailyPsalmCard
            propersCard
            penanceCard
            saintCard
            prayerRuleCard
            devotionsSection
            rosaryCard
            scholaCard
        }
        .padding(.horizontal, 28)
        .padding(.top, 24)
        .padding(.bottom, 40)
    }

    // MARK: - Upcoming feasts (next 14 days)

    @AppStorage(SettingsKey.showUpcomingFeasts) private var showUpcomingFeasts = false

    @ViewBuilder
    private var upcomingFeastsCard: some View {
        let upcoming = showUpcomingFeasts
            ? LiturgicalYearModel.upcoming(rite: rite, store: ContentStore.shared)
            : []
        if !upcoming.isEmpty {
            Button { showCalendar = true } label: {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("VENTURA \u{00B7} " + ContentStore.shared.uiString("today.upcoming", "Upcoming").uppercased())
                            .font(.scaledSystem(10, weight: .semibold))
                            .tracking(2)
                            .foregroundStyle(Color.tertiaryText)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.scaledSystem(11))
                            .foregroundStyle(Color.tertiaryText)
                    }
                    ForEach(upcoming.prefix(4), id: \.date) { day in
                        HStack(spacing: 10) {
                            Circle()
                                .fill((day.colour?.swiftUIColor ?? Color.frameLine).opacity(0.85))
                                .frame(width: 6, height: 6)
                            Text(Self.upcomingDate.string(from: day.date))
                                .font(.scaledSystem(12, design: .serif))
                                .foregroundStyle(Color.tertiaryText)
                                .frame(width: 52, alignment: .leading)
                            Text(langMode == .latinOnly
                                 ? (day.label ?? day.weekdayName)
                                 : (day.englishName ?? day.label ?? day.weekdayName))
                                .font(.scaledSystem(14, design: .serif))
                                .foregroundStyle(Color.primaryText)
                                .lineLimit(1)
                            Spacer(minLength: 0)
                            DayMarkerPips(day: day)
                        }
                    }
                }
                .padding(16)
                .overlay(Rectangle().stroke(Color.frameLine, lineWidth: 0.5))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    private static let upcomingDate: DateFormatter = {
        let df = DateFormatter()
        df.calendar = Calendar.liturgical
        df.locale = Locale(identifier: "en_US_POSIX")
        df.dateFormat = "EEE d MMM"
        return df
    }()

    // MARK: - Prayer Rule Card

    @ViewBuilder
    private var prayerRuleCard: some View {
        if !UserProgress.prayerRule().isEmpty {
            NavigationLink(destination: PrayersView()) {
                HStack(spacing: 14) {
                    let rule = UserProgress.prayerRule()
                    let done = UserProgress.completedPrayers().intersection(Set(rule.allSlugs)).count
                    let total = rule.totalCount
                    let progress = total > 0 ? Double(done) / Double(total) : 0

                    ZStack {
                        Circle()
                            .stroke(Color.frameLine, lineWidth: 3)
                            .frame(width: 44, height: 44)
                        Circle()
                            .trim(from: 0, to: progress)
                            .stroke(progress >= 1.0 ? Color.goldLeaf : Color.sanctuaryRed, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                            .frame(width: 44, height: 44)
                            .rotationEffect(.degrees(-90))
                        Text("\(done)")
                            .font(.titleM)
                            .foregroundStyle(Color.primaryText)
                    }

                    VStack(alignment: .leading, spacing: 3) {
                        Text(ContentStore.shared.uiString("today.prayer_rule", "Prayer Rule"))
                            .font(.titleM)
                            .italic()
                            .foregroundStyle(Color.primaryText)
                        Text(progress >= 1.0 ? ContentStore.shared.uiString("today.prayer_rule.done", "All prayers complete") : ContentStore.shared.uiString("today.prayer_rule.progress", "{done} of {total} prayers today").replacingOccurrences(of: "{done}", with: "\(done)").replacingOccurrences(of: "{total}", with: "\(total)"))
                            .font(.captionSm)
                            .foregroundStyle(progress >= 1.0 ? Color.goldLeaf : Color.secondaryText)
                    }

                    Spacer()

                    Text(ContentStore.shared.uiString("common.open", "Open"))
                        .font(.captionSm)
                        .foregroundStyle(Color.sanctuaryRed)
                }
                .padding(14)
                .overlay(Rectangle().stroke(Color.frameLine, lineWidth: 0.5))
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Daily Psalm

    private var dailyPsalmCard: some View {
        let verse = DailyPsalm.verse()
        return VStack(alignment: .leading, spacing: 8) {
            LanguageAwareText(latin: "Psalmus Hodiérnus", english: "Daily Psalm")
                .smallLabel(color: Color.sanctuaryRed)
            Text(verse.ref)
                .font(.captionSm)
                .foregroundStyle(Color.goldLeaf)
            BilingualLine(lat: verse.latin, eng: verse.english)
                .lineSpacing(3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .overlay(
            Rectangle().stroke(Color.frameLine, lineWidth: 0.5)
        )
    }

    // MARK: - Propers of the Day

    @ViewBuilder
    private var propersCard: some View {
        if let proper = ContentStore.shared.properForDate(ctx.date, rite: rite) ?? (ctx.properSlug.flatMap { ContentStore.shared.proper(slug: $0) }) {
            Button { showProper = true } label: {
                VStack(alignment: .leading, spacing: 8) {
                    LanguageAwareText(latin: "Próprium Missæ", english: "Today\u{2019}s Propers")
                        .smallLabel(color: Color.goldLeaf)
                    Text(proper.title)
                        .font(.titleM)
                        .italic()
                        .foregroundStyle(Color.primaryText)
                    // Subtitle: the vernacular feast name. DO sanctoral
                    // imports carry the Latin officium in `english` too, so
                    // prefer the ordo-name translation and drop the line
                    // entirely rather than repeat the Latin.
                    let subtitle = ContentStore.shared.ordoNameEnglish(proper.title)
                        ?? proper.english
                    if subtitle != proper.title {
                        Text(subtitle)
                            .font(.captionSm)
                            .italic()
                            .foregroundStyle(Color.secondaryText)
                    }

                    if !proper.epistle.ref.isEmpty || !proper.gospel.ref.isEmpty {
                        HStack(spacing: 12) {
                            if !proper.epistle.ref.isEmpty {
                                HStack(spacing: 4) {
                                    Text("Ep.")
                                        .font(.captionSm)
                                        .foregroundStyle(Color.sanctuaryRed)
                                    Text(proper.epistle.ref)
                                        .font(.captionSm)
                                        .foregroundStyle(Color.tertiaryText)
                                }
                            }
                            if !proper.gospel.ref.isEmpty {
                                HStack(spacing: 4) {
                                    Text("Ev.")
                                        .font(.captionSm)
                                        .foregroundStyle(Color.sanctuaryRed)
                                    Text(proper.gospel.ref)
                                        .font(.captionSm)
                                        .foregroundStyle(Color.tertiaryText)
                                }
                            }
                        }
                        .padding(.top, 2)
                    }

                    HStack {
                        Spacer()
                        Text("Léctio Hodiérna  ✠  Read")
                            .smallLabel(color: Color.sanctuaryRed)
                    }
                    .padding(.top, 4)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(16)
                .overlay(Rectangle().stroke(Color.frameLine, lineWidth: 0.5))
            }
            .buttonStyle(.plain)
            .spotlightAnchor("propersCard")
        }
    }

    // MARK: - Penance card

    @State private var showPenanceSheet = false

    private var penanceCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Pæniténtia")
                    .smallLabel(color: Color.sanctuaryRed)
                Spacer()
                Button { showSettings = true } label: {
                    Text(discipline.short)
                        .smallLabel(color: Color.goldLeaf)
                }
                .buttonStyle(.plain)
            }
            Text(ctx.penance.rubric)
                .font(.captionSm)
                .foregroundStyle(Color.tertiaryText)

            Text(ctx.penance.title)
                .font(.titleM)
                .italic()
                .foregroundStyle(Color.primaryText)
                .padding(.top, 4)

            Text(ctx.penance.desc)
                .font(.bodySm)
                .foregroundStyle(Color.secondaryText)
                .lineSpacing(3)

            // Saint-specific penance
            if let slug = UserProgress.followedSaint(),
               let saint = ContentStore.shared.saints.first(where: { $0.slug == slug }),
               let saintPenance = saint.penance {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text(saint.penanceLatin ?? "Praxis Sancti")
                            .smallLabel(color: Color.goldLeaf)
                        Text("·")
                            .foregroundStyle(Color.tertiaryText)
                        Text(saint.name)
                            .font(.captionSm)
                            .italic()
                            .foregroundStyle(Color.secondaryText)
                    }
                    Text(saintPenance)
                        .font(.bodySm)
                        .italic()
                        .foregroundStyle(Color.primaryText)
                        .lineSpacing(3)
                }
                .padding(.top, 8)
            }

            // Next obligation
            if let next = nextObligationDay() {
                HStack(spacing: 6) {
                    Image(systemName: "arrow.right.circle")
                        .font(.scaledSystem(11))
                        .foregroundStyle(Color.sanctuaryRed)
                    Text("Next obligation: \(next)")
                        .font(.captionSm)
                        .italic()
                        .foregroundStyle(Color.secondaryText)
                }
                .padding(.top, 6)
            }

            // Optional penances
            let selected = OptionalPenances.selected()
            if !selected.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Pæniténtiæ Voluntáriæ")
                        .smallLabel(color: Color.goldLeaf)
                        .padding(.top, 4)
                    ForEach(selected) { p in
                        Text("· \(p.title)")
                            .font(.captionSm)
                            .italic()
                            .foregroundStyle(Color.primaryText)
                    }
                }
            }

            Button { showPenanceSheet = true } label: {
                Text(selected.isEmpty ? ContentStore.shared.uiString("today.penance.choose", "Choose optional penances") : ContentStore.shared.uiString("today.penance.edit", "Edit penances"))
                    .font(.captionSm)
                    .italic()
                    .foregroundStyle(Color.sanctuaryRed)
                    .padding(.top, 6)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .sheet(isPresented: $showPenanceSheet) {
            OptionalPenanceSheet()
        }
    }

    // MARK: - Devotions

    private var devotionsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionLabel("Devotiónes Hodiérnæ", subtitle: ContentStore.shared.uiString("today.devotions.sub", "Today's devotions"))

            NavigationLink(destination: OfficeView()) {
                devotionRow(ContentStore.shared.uiString("today.devotion.office", "The Divine Office"),
                            latin: "Officium Divínum, VIII Horæ Canónicæ")
            }
            .buttonStyle(.plain)

            NavigationLink(destination: StationsView()) {
                devotionRow(ContentStore.shared.uiString("today.devotion.stations", "Stations of the Cross"),
                            latin: "Via Crucis, XIV statiónes")
            }
            .buttonStyle(.plain)

            NavigationLink(destination: ConfessionView()) {
                devotionRow(ContentStore.shared.uiString("today.devotion.confession", "Confession Guide"),
                            latin: "De Confessióne")
            }
            .buttonStyle(.plain)

            Button {
                offeringTapped = true
            } label: {
                devotionRow(offeringTitle(), latin: offeringLatin())
            }
            .buttonStyle(.plain)
        }
        .spotlightAnchor("devotionsSection")
    }

    private func offeringSlug() -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 12 { return "morning" }
        if hour < 18 { return "salve" }
        return "suscipe"
    }

    private func offeringTitle() -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 12 { return "Morning Offering" }
        if hour < 18 { return "Afternoon Prayer" }
        return "Night Prayer"
    }

    private func offeringLatin() -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 12 { return "Oblátio Matutína" }
        if hour < 18 { return "Salve Regína" }
        return "Súscipe, Dómine"
    }

    private func devotionRow(_ title: String, latin: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.titleM)
                .foregroundStyle(Color.primaryText)
            Text(latin)
                .font(.captionSm)
                .italic()
                .foregroundStyle(Color.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }

    // MARK: - Rosary

    private var rosaryCard: some View {
        NavigationLink(destination: RosaryView()) {
            VStack(alignment: .leading, spacing: 8) {
                sectionLabel("Sacratíssimum Rosárium", subtitle: ContentStore.shared.uiString("today.rosary.sub", "of the Rosary"))

                if langMode != .vernacular {
                    Text(ctx.mystery.latinName)
                        .font(.titleM)
                        .italic()
                        .foregroundStyle(Color.primaryText)
                }
                if langMode != .latinOnly {
                    Text(ctx.mystery.englishName)
                        .font(langMode == .vernacular ? .titleM : .captionSm)
                        .italic()
                        .foregroundStyle(langMode == .vernacular ? Color.primaryText : Color.secondaryText)
                }

                if let lastDate = UserProgress.rosaryLastDate() {
                    Text("Last prayed: \(Self.dateFmt.string(from: lastDate))")
                        .font(.captionSm)
                        .foregroundStyle(Color.tertiaryText)
                        .padding(.top, 4)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Saint

    @State private var showSaintDetail = false

    private var saintCard: some View {
        Group {
            if let slug = UserProgress.followedSaint(),
               let saint = ContentStore.shared.saints.first(where: { $0.slug == slug }) {
                Button { showSaintDetail = true } label: {
                    saintCardFollowing(saint)
                }
                .buttonStyle(.plain)
                .sheet(isPresented: $showSaintDetail) {
                    SaintDetailView(saint: saint)
                }
            } else {
                NavigationLink(destination: SaintsView()) {
                    saintCardEmpty
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func saintCardFollowing(_ saint: Saint) -> some View {
        let streak = UserProgress.saintStreak(slug: saint.slug)
        let total = saint.sections.flatMap { $0.practices }.count
        let done = UserProgress.completedPractices().count
        let progress = total > 0 ? Double(done) / Double(total) : 0

        return HStack(spacing: 16) {
            ZStack {
                Circle()
                    .stroke(Color.frameLine, lineWidth: 4)
                    .frame(width: 56, height: 56)
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(progress >= 1.0 ? Color.goldLeaf : Color.sanctuaryRed, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: 56, height: 56)
                    .rotationEffect(.degrees(-90))
                Text("\(done)")
                    .font(.titleL)
                    .foregroundStyle(Color.primaryText)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(saint.name)
                    .font(.titleL)
                    .italic()
                    .foregroundStyle(Color.primaryText)
                Text(progress >= 1.0 ? "All practices complete" : "\(done) of \(total) practices today")
                    .font(.captionSm)
                    .foregroundStyle(progress >= 1.0 ? Color.goldLeaf : Color.secondaryText)
                if streak > 0 {
                    Text("\(streak) day streak")
                        .font(.captionSm)
                        .foregroundStyle(Color.goldLeaf)
                }
            }

            Spacer()

            Text(ContentStore.shared.uiString("common.open", "Open"))
                .font(.captionSm)
                .foregroundStyle(Color.sanctuaryRed)
        }
        .padding(16)
        .frame(maxWidth: .infinity)
        .overlay(Rectangle().stroke(Color.sanctuaryRed.opacity(0.3), lineWidth: 1))
        .contentShape(Rectangle())
    }

    private var saintCardEmpty: some View {
        VStack(spacing: 8) {
            Text("✠")
                .font(.titleL)
                .foregroundStyle(Color.sanctuaryRed)
            Text(ContentStore.shared.uiString("today.saints.follow", "Follow a Saint"))
                .font(.titleM)
                .italic()
                .foregroundStyle(Color.primaryText)
            Text("Choose a patron saint and track daily practices")
                .font(.captionSm)
                .italic()
                .foregroundStyle(Color.secondaryText)
                .multilineTextAlignment(.center)
            Text(ContentStore.shared.uiString("today.saints.begin", "Begin"))
                .smallLabel(color: Color.sanctuaryRed)
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .overlay(Rectangle().stroke(Color.sanctuaryRed.opacity(0.3), lineWidth: 1))
        .contentShape(Rectangle())
    }

    // MARK: - Schola

    private var scholaCard: some View {
        NavigationLink(destination: LearnView()) {
            VStack(alignment: .leading, spacing: 8) {
                let mastered = UserProgress.masteredLessons()
                sectionLabel("Schola", subtitle: ContentStore.shared.uiString("today.schola.sub", "Latin learning"))
                Text("Mastered: \(mastered.count) of \(ContentStore.shared.courses.count) lessons")
                    .font(.bodySm)
                    .foregroundStyle(Color.secondaryText)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private static let dateFmt: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        return f
    }()

    // MARK: - Next obligation

    private func nextObligationDay() -> String? {
        let cal = Calendar.liturgical
        var d = Date().addingDays(1)
        for _ in 0..<60 {
            let c = LiturgicalContext.for(date: d, rite: rite, discipline: discipline)
            if c.penance.strict || (c.isFriday && !c.isSunday) {
                let df = DateFormatter()
                df.locale = Locale(identifier: "en_US_POSIX")
                df.dateFormat = "EEEE, MMMM d"
                let label = df.string(from: d)
                let kind = c.penance.title
                return "\(label) (\(kind))"
            }
            d = d.addingDays(1)
        }
        return nil
    }

    // MARK: - Helpers

    private func sectionLabel(_ title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .smallLabel(color: Color.sanctuaryRed)
            Text(subtitle)
                .font(.captionSm)
                .italic()
                .foregroundStyle(Color.tertiaryText)
        }
    }
}

#Preview { TodayView() }
