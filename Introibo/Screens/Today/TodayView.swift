import SwiftUI

// The Hódie tab — the app's home screen.
// Shows today's liturgical date, penance, devotions, rosary card,
// followed-saint card, and schola progress. Mirrors prototype/today.html.

struct TodayView: View {
    private let ctx = LiturgicalContext.current()
    @AppStorage(SettingsKey.rite) private var riteRaw = MissalRite.rite1962.rawValue
    @AppStorage(SettingsKey.penance) private var penanceRaw = PenanceDiscipline.discipline1962.rawValue
    @AppStorage(SettingsKey.theme) private var themeRaw = AppTheme.parchment.rawValue
    @State private var showSettings = false
    @State private var morningOfferingTapped = false

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
            .background(Color.pageBackground.ignoresSafeArea())
            .sheet(isPresented: $showSettings) {
                SettingsView()
            }
            .sheet(isPresented: $morningOfferingTapped) {
                if let prayer = ContentStore.shared.prayer(slug: "morning") {
                    PrayerDetailView(prayer: prayer)
                }
            }
        }
    }

    // MARK: - Dark walnut header

    private var header: some View {
        VStack(spacing: 6) {
            HStack {
                Spacer()
                Button { showSettings = true } label: {
                    Image(systemName: "gearshape")
                        .foregroundStyle(Color.goldLeaf)
                        .font(.system(size: 16))
                }
            }
            .padding(.top, 12)
            .padding(.trailing, 6)

            // Liturgical colour pip + season
            HStack(spacing: 8) {
                Circle()
                    .fill(ctx.colour.swiftUIColor)
                    .frame(width: 8, height: 8)
                Text("\(ctx.feriaLatin)  ·  \(ctx.latinName)")
                    .smallLabel(color: Color.goldLeaf)
            }
            .padding(.top, 4)

            Text(ctx.feriaEnglish)
                .font(.system(size: 34, weight: .semibold, design: .serif))
                .foregroundStyle(Color.ivory)

            Text(LongDateFormatter.format(ctx.date))
                .font(.system(size: 15, weight: .regular, design: .serif))
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

            // First Friday / First Saturday / Ember day flags
            if ctx.isFirstFriday || ctx.isFirstSaturday || ctx.isEmberDay {
                HStack(spacing: 12) {
                    if ctx.isFirstFriday {
                        Text("First Friday")
                            .font(.captionSm)
                            .italic()
                            .foregroundStyle(Color.sanctuaryRed)
                    }
                    if ctx.isFirstSaturday {
                        Text("First Saturday")
                            .font(.captionSm)
                            .italic()
                            .foregroundStyle(Color.sanctuaryRed)
                    }
                    if ctx.isEmberDay {
                        Text("Ember Day")
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
                    .font(.system(size: 8))
                    .foregroundStyle(Color.goldLeaf)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Main content

    private var mainContent: some View {
        VStack(spacing: 24) {
            dailyPsalmCard
            penanceCard
            devotionsSection
            rosaryCard
            saintCard
            scholaCard
        }
        .padding(.horizontal, 28)
        .padding(.top, 24)
        .padding(.bottom, 40)
    }

    // MARK: - Daily Psalm

    private var dailyPsalmCard: some View {
        let verse = DailyPsalm.verse()
        return VStack(alignment: .leading, spacing: 8) {
            Text("Psalmus Hodiérnus")
                .smallLabel(color: Color.sanctuaryRed)
            Text(verse.ref)
                .font(.captionSm)
                .foregroundStyle(Color.goldLeaf)
            Text(verse.latin)
                .font(.bodyIt)
                .foregroundStyle(Color.primaryText)
                .lineSpacing(4)
                .padding(.top, 2)
            Text(verse.english)
                .font(.bodySm)
                .italic()
                .foregroundStyle(Color.secondaryText)
                .lineSpacing(3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .overlay(
            Rectangle().stroke(Color.frameLine, lineWidth: 0.5)
        )
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
                Text(selected.isEmpty ? "Choose optional penances" : "Edit penances")
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
            sectionLabel("Devotiónes Hodiérnæ", subtitle: "Today's devotions")

            NavigationLink(destination: OfficeView()) {
                devotionRow("The Divine Office",
                            latin: "Officium Divínum — VIII Horæ Canónicæ")
            }
            .buttonStyle(.plain)

            NavigationLink(destination: StationsView()) {
                devotionRow("Stations of the Cross",
                            latin: "Via Crucis — XIV statiónes")
            }
            .buttonStyle(.plain)

            NavigationLink(destination: ConfessionView()) {
                devotionRow("Confession Guide",
                            latin: "De Confessióne")
            }
            .buttonStyle(.plain)

            Button {
                // Navigate to Morning Offering prayer
                morningOfferingTapped = true
            } label: {
                devotionRow("Morning Offering",
                            latin: "Oblátio Matutína")
            }
            .buttonStyle(.plain)
        }
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
                sectionLabel("Sacratíssimum Rosárium", subtitle: "of the Rosary")

                Text(ctx.mystery.latinName)
                    .font(.titleM)
                    .italic()
                    .foregroundStyle(Color.primaryText)
                Text(ctx.mystery.englishName)
                    .font(.captionSm)
                    .italic()
                    .foregroundStyle(Color.secondaryText)

                if let lastDate = UserProgress.rosaryLastDate() {
                    let fmt = DateFormatter()
                    let _ = fmt.dateStyle = .medium
                    Text("Last prayed: \(fmt.string(from: lastDate))")
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

    private var saintCard: some View {
        NavigationLink(destination: SaintsView()) {
            VStack(alignment: .leading, spacing: 8) {
                sectionLabel("Praxes Sanctórum", subtitle: "Daily practices")

                if let slug = UserProgress.followedSaint(),
                   let saint = ContentStore.shared.saints.first(where: { $0.slug == slug }) {
                    let streak = UserProgress.saintStreak(slug: slug)
                    Text(saint.name)
                        .font(.titleM)
                        .italic()
                        .foregroundStyle(Color.primaryText)
                    if streak > 0 {
                        Text("\(streak) day\(streak == 1 ? "" : "s")  ·  Continuing")
                            .font(.captionSm)
                            .foregroundStyle(Color.goldLeaf)
                    }
                } else {
                    Text("Choose a saint to follow")
                        .font(.bodyIt)
                        .foregroundStyle(Color.secondaryText)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Schola

    private var scholaCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            let mastered = UserProgress.masteredLessons()
            sectionLabel("Schola", subtitle: "Latin learning")
            Text("Mastered: \(mastered.count) of 10 lessons")
                .font(.bodySm)
                .foregroundStyle(Color.secondaryText)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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
