import SwiftUI

struct MissalView: View {
    @State private var store = ContentStore.shared
    @AppStorage(SettingsKey.rite) private var riteRaw = MissalRite.rite1962.rawValue
    @AppStorage(SettingsKey.theme) private var themeRaw = AppTheme.parchment.rawValue
    @AppStorage(SettingsKey.language) private var languageRaw = LanguageMode.both.rawValue
    @AppStorage(SettingsKey.fontSize) private var fontScale = FontSizeScale.defaultValue

    private var rite: MissalRite { MissalRite(rawValue: riteRaw) ?? .rite1962 }
    private var ctx: LiturgicalContext { .current() }

    private var todayProper: MassProper? {
        guard let slug = ctx.properSlug else { return nil }
        if let proper = store.proper(slug: slug) { return proper }
        let cal = Calendar.liturgical
        let dow = cal.component(.weekday, from: Date()) - 1
        if dow > 0 {
            let lastSunday = Date().addingDays(-dow)
            if let sundaySlug = ProperCalendar.properSlug(for: lastSunday) {
                return store.proper(slug: sundaySlug)
            }
        }
        return nil
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    if let proper = todayProper {
                        interleavedMass(proper)
                    } else {
                        ordinaryOnly
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 40)
            }
            .background(Color.pageBackground.ignoresSafeArea())
            .navigationTitle("Ordo Missæ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 2) {
                        Text(todayProper?.english ?? "Ordo Missæ")
                            .font(.titleM)
                            .italic()
                            .foregroundStyle(Color.primaryText)
                        Text(rite.short)
                            .smallLabel(color: Color.goldLeaf, tracking: 2)
                    }
                }
            }
        }
    }

    // MARK: - Interleaved Mass (Ordinary + Propers)

    @ViewBuilder
    private func interleavedMass(_ proper: MassProper) -> some View {
        // Prayers at the Foot of the Altar
        ordinarySection("preces")
        ordinarySection("confiteor")

        // INTROIT (proper)
        properSection("Introitus", subtitle: "Introit", text: proper.introit)

        // Kyrie, Gloria
        ordinarySection("kyrie")
        ordinarySection("gloria")

        // COLLECT (proper)
        properSection("Orátio", subtitle: "Collect", text: proper.collect)

        // EPISTLE (proper)
        readingSection("Léctio", subtitle: "Epistle", reading: proper.epistle)

        // GRADUAL (proper)
        if let gradual = proper.gradual {
            properSection("Graduále", subtitle: "Gradual", text: gradual)
        }
        if let tract = proper.tract {
            properSection("Tractus", subtitle: "Tract", text: tract)
        }
        if let sequence = proper.sequence {
            properSection("Sequéntia", subtitle: "Sequence", text: sequence)
        }

        // GOSPEL (proper)
        readingSection("Evangélium", subtitle: "Gospel", reading: proper.gospel)

        // Credo
        ordinarySection("credo")

        // OFFERTORY (proper)
        properSection("Offertórium", subtitle: "Offertory", text: proper.offertory)

        // SECRET (proper)
        properSection("Secréta", subtitle: "Secret", text: proper.secret)

        // Sanctus, Canon, Pater Noster
        ordinarySection("sanctus")
        ordinarySection("canon")
        ordinarySection("pater")

        // Agnus Dei
        ordinarySection("agnus")

        // COMMUNION (proper)
        properSection("Commúnio", subtitle: "Communion", text: proper.communion)

        ordinarySection("domine")

        // POSTCOMMUNION (proper)
        properSection("Postcommúnio", subtitle: "Postcommunion", text: proper.postcommunion)

        // Last Gospel
        ordinarySection("ultimum")
    }

    // MARK: - Ordinary-only fallback

    private var ordinaryOnly: some View {
        ForEach(store.missal) { section in
            ordinarySectionBlock(section)
        }
    }

    // MARK: - Ordinary section by slug

    @ViewBuilder
    private func ordinarySection(_ slug: String) -> some View {
        if let section = store.missal.first(where: { $0.slug == slug }) {
            ordinarySectionBlock(section)
        }
    }

    private func ordinarySectionBlock(_ section: MissalSection) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if let label = section.label {
                HStack(spacing: 10) {
                    Rectangle().fill(Color.goldLeaf.opacity(0.4)).frame(height: 0.5)
                    Text(label)
                        .smallLabel(color: Color.sanctuaryRed)
                        .fixedSize()
                    Rectangle().fill(Color.goldLeaf.opacity(0.4)).frame(height: 0.5)
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(section.title)
                    .font(.titleL)
                    .italic()
                    .foregroundStyle(Color.primaryText)
                if let english = section.english {
                    Text(english)
                        .font(.captionSm)
                        .italic()
                        .foregroundStyle(Color.secondaryText)
                }
            }
            VStack(alignment: .leading, spacing: 16) {
                ForEach(Array(section.body.enumerated()), id: \.offset) { _, line in
                    BilingualLine(lat: line.lat, eng: line.eng, sideBySide: true)
                }
            }
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Proper sections

    private func properSection(_ latin: String, subtitle: String, text: ProperText) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Rectangle().fill(Color.sanctuaryRed.opacity(0.5)).frame(height: 1)
                Text("\(latin)  ·  \(subtitle)")
                    .smallLabel(color: Color.sanctuaryRed)
                    .fixedSize()
                Rectangle().fill(Color.sanctuaryRed.opacity(0.5)).frame(height: 1)
            }
            BilingualLine(lat: text.lat, eng: text.eng, sideBySide: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4)
        .padding(.leading, 4)
        .overlay(
            Rectangle()
                .fill(Color.sanctuaryRed.opacity(0.15))
                .frame(width: 2)
            , alignment: .leading
        )
    }

    private func readingSection(_ latin: String, subtitle: String, reading: ProperReading) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Rectangle().fill(Color.sanctuaryRed.opacity(0.5)).frame(height: 1)
                Text("\(latin)  ·  \(subtitle)")
                    .smallLabel(color: Color.sanctuaryRed)
                    .fixedSize()
                Rectangle().fill(Color.sanctuaryRed.opacity(0.5)).frame(height: 1)
            }
            if !reading.ref.isEmpty {
                Text(reading.ref)
                    .font(.captionSm)
                    .foregroundStyle(Color.goldLeaf)
            }
            BilingualLine(lat: reading.lat, eng: reading.eng, sideBySide: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4)
        .padding(.leading, 4)
        .overlay(
            Rectangle()
                .fill(Color.sanctuaryRed.opacity(0.15))
                .frame(width: 2)
            , alignment: .leading
        )
    }
}

#Preview { MissalView() }
