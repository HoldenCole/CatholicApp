import SwiftUI

// The Hódie tab — the app's home screen.
// Shows today's liturgical date, penance, devotions, rosary card,
// followed-saint card, and schola progress. Mirrors prototype/today.html.

struct TodayView: View {
    private let ctx = LiturgicalContext.current()
    @AppStorage(SettingsKey.rite) private var riteRaw = MissalRite.rite1962.rawValue
    @AppStorage(SettingsKey.penance) private var penanceRaw = PenanceDiscipline.discipline1962.rawValue
    @State private var showSettings = false

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

            Text("\(ctx.feriaLatin)  ·  \(ctx.latinName)")
                .smallLabel(color: Color.goldLeaf)
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

            Rectangle()
                .fill(Color.goldLeaf.opacity(0.4))
                .frame(height: 0.5)
                .padding(.horizontal, 28)
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

    // MARK: - Penance card

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
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Devotions

    private var devotionsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionLabel("Devotiónes Hodiérnæ", subtitle: "Today's devotions")

            NavigationLink(destination: OfficeView()) {
                devotionRow("The Divine Office",
                            latin: "Officium Divínum — Laudes & Vespers")
            }
            .buttonStyle(.plain)

            NavigationLink(destination: StationsView()) {
                devotionRow("Stations of the Cross",
                            latin: "Via Crucis — XIV statiónes")
            }
            .buttonStyle(.plain)

            NavigationLink(destination: ConfessionView(openExamen: true)) {
                devotionRow("Examination of Conscience",
                            latin: "Exámen Consciéntiæ")
            }
            .buttonStyle(.plain)

            devotionRow("Morning Offering",
                        latin: "Oblátio Matutína")
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
