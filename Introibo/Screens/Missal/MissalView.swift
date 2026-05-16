import SwiftUI

struct MissalView: View {
    @State private var store = ContentStore.shared
    @AppStorage(SettingsKey.rite) private var riteRaw = MissalRite.rite1962.rawValue
    @AppStorage(SettingsKey.theme) private var themeRaw = AppTheme.parchment.rawValue
    @AppStorage(SettingsKey.language) private var languageRaw = LanguageMode.both.rawValue
    @AppStorage(SettingsKey.fontSize) private var fontScale = FontSizeScale.defaultValue

    private var rite: MissalRite { MissalRite(rawValue: riteRaw) ?? .rite1962 }
    private var mode: LanguageMode { LanguageMode(rawValue: languageRaw) ?? .both }
    private var ctx: LiturgicalContext { .current() }

    private func sectionLabel(_ latin: String, _ english: String) -> String {
        switch mode {
        case .latinOnly: return latin
        case .vernacular: return english
        case .both: return "\(latin)  \u{00B7}  \(english)"
        }
    }

    private var todayProper: MassProper? {
        guard let slug = ctx.properSlug else { return nil }
        if let proper = store.proper(slug: slug) { return proper }
        let cal = Calendar.liturgical
        let dow = cal.component(.weekday, from: Date()) - 1
        if dow > 0 {
            let lastSunday = Date().addingDays(-dow)
            if let sundaySlug = ProperCalendar.properSlug(for: lastSunday, rite: rite) {
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
                ToolbarItem(placement: .navigationBarTrailing) {
                    ShareLink(item: fullMassText()) {
                        Image(systemName: "square.and.arrow.up")
                            .foregroundStyle(Color.sanctuaryRed)
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

        // Kyrie
        ordinarySection("kyrie")

        // Gloria — omitted in Advent, Lent, Passion, and pre-Lent;
        // shown on Sundays in ordinary time, Easter, Christmas,
        // and on fixed sanctorale feasts in any season.
        if showGloria(proper) {
            ordinarySection("gloria")
        }

        // COLLECT (proper)
        properSection("Orátio", subtitle: "Collect", text: proper.collect)

        // EPISTLE (proper)
        readingSection("Léctio", subtitle: "Epistle", reading: proper.epistle)

        // GRADUAL (proper)
        if let gradual = proper.gradual {
            properSection("Graduále", subtitle: "Gradual", text: gradual)
        }
        if let alleluia = proper.alleluia {
            properSection("Allelúja", subtitle: "Alleluia", text: alleluia)
        }
        if let tract = proper.tract {
            properSection("Tractus", subtitle: "Tract", text: tract)
        }
        if let sequence = proper.sequence {
            properSection("Sequéntia", subtitle: "Sequence", text: sequence)
        }

        // GOSPEL (proper)
        readingSection("Evangélium", subtitle: "Gospel", reading: proper.gospel)

        // Credo — said on all Sundays and on major feasts (rank 1)
        if showCredo(proper) {
            ordinarySection("credo")
        }

        // OFFERTORY (proper)
        properSection("Offertórium", subtitle: "Offertory", text: proper.offertory)

        // Offertory prayers (Ordinary)
        ordinarySection("offertory_prayers")

        // SECRET (proper)
        properSection("Secréta", subtitle: "Secret", text: proper.secret)

        // Preface, Sanctus, Canon, Pater Noster
        ordinarySection("preface")
        ordinarySection("sanctus")
        ordinarySection("canon")
        ordinarySection("pater")

        // Agnus Dei
        ordinarySection("agnus")

        // Domine non sum dignus
        ordinarySection("domine")

        // COMMUNION (proper)
        properSection("Commúnio", subtitle: "Communion", text: proper.communion)

        // POSTCOMMUNION (proper)
        properSection("Postcommúnio", subtitle: "Postcommunion", text: proper.postcommunion)

        // Placeat, Blessing
        ordinarySection("placeat")

        // Ite, Missa Est
        ordinarySection("ite")

        // Last Gospel
        ordinarySection("ultimum")

        // Leonine Prayers (after Low Mass)
        ordinarySection("leonine")
    }

    // MARK: - Rubric helpers

    /// Gloria is omitted during penitential seasons (Advent, Lent, Passion,
    /// pre-Lent) on ferial days. It IS said on fixed feasts even in those
    /// seasons, and always during Easter and Christmas seasons.
    private func showGloria(_ proper: MassProper) -> Bool {
        let season = ctx.season
        if season == .easter || season == .christmas { return true }
        if proper.color == "violet" || proper.color == "black" {
            return false
        }
        if ctx.isSunday {
            let preLent = ["septuagesima", "sexagesima", "quinquagesima"]
            if let slug = ctx.properSlug, preLent.contains(slug) { return false }
            return season != .advent && season != .lent && season != .passion
        }
        return proper.rank == 1
    }

    /// Credo is said on all Sundays and on major feasts (rank 1 in data).
    private func showCredo(_ proper: MassProper) -> Bool {
        if ctx.isSunday { return true }
        return proper.rank == 1
    }

    // MARK: - Export full Mass as text

    private func fullMassText() -> String {
        var lines: [String] = []
        let proper = todayProper

        if let proper = proper {
            lines.append(proper.title)
            lines.append(proper.english)
            lines.append(rite.short)
            lines.append("")
        } else {
            lines.append("Ordo Missæ")
            lines.append(rite.short)
            lines.append("")
        }

        func addOrdinary(_ slug: String) {
            if let section = store.missal.first(where: { $0.slug == slug }) {
                lines.append("═══ \(section.title) ═══")
                if let eng = section.english { lines.append(eng) }
                lines.append("")
                for line in section.body {
                    lines.append(line.lat)
                    lines.append(line.eng)
                    lines.append("")
                }
            }
        }

        func addProper(_ label: String, lat: String, eng: String) {
            lines.append("─── \(label) ───")
            lines.append(lat)
            lines.append(eng)
            lines.append("")
        }

        func addReading(_ label: String, ref: String, lat: String, eng: String) {
            lines.append("─── \(label) ───")
            if !ref.isEmpty { lines.append(ref) }
            lines.append(lat)
            lines.append(eng)
            lines.append("")
        }

        addOrdinary("preces")
        addOrdinary("confiteor")

        if let p = proper {
            addProper("Introitus · Introit", lat: p.introit.lat, eng: p.introit.eng)
        }

        addOrdinary("kyrie")
        addOrdinary("gloria")

        if let p = proper {
            addProper("Oratio · Collect", lat: p.collect.lat, eng: p.collect.eng)
            addReading("Lectio · Epistle", ref: p.epistle.ref, lat: p.epistle.lat, eng: p.epistle.eng)
            if let g = p.gradual { addProper("Graduale · Gradual", lat: g.lat, eng: g.eng) }
            if let a = p.alleluia { addProper("Alleluia", lat: a.lat, eng: a.eng) }
            if let t = p.tract { addProper("Tractus · Tract", lat: t.lat, eng: t.eng) }
            if let s = p.sequence { addProper("Sequentia · Sequence", lat: s.lat, eng: s.eng) }
            addReading("Evangelium · Gospel", ref: p.gospel.ref, lat: p.gospel.lat, eng: p.gospel.eng)
        }

        addOrdinary("credo")

        if let p = proper {
            addProper("Offertorium · Offertory", lat: p.offertory.lat, eng: p.offertory.eng)
        }

        addOrdinary("offertory_prayers")

        if let p = proper {
            addProper("Secreta · Secret", lat: p.secret.lat, eng: p.secret.eng)
        }

        addOrdinary("preface")
        addOrdinary("sanctus")
        addOrdinary("canon")
        addOrdinary("pater")
        addOrdinary("agnus")
        addOrdinary("domine")

        if let p = proper {
            addProper("Communio · Communion", lat: p.communion.lat, eng: p.communion.eng)
        }

        if let p = proper {
            addProper("Postcommunio · Postcommunion", lat: p.postcommunion.lat, eng: p.postcommunion.eng)
        }

        addOrdinary("placeat")
        addOrdinary("ultimum")
        addOrdinary("leonine")

        return lines.joined(separator: "\n")
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
                    VStack(alignment: .leading, spacing: 4) {
                        if let rubric = line.rubric {
                            Text(rubric)
                                .font(.captionSm)
                                .italic()
                                .foregroundStyle(Color.sanctuaryRed)
                        }
                        BilingualLine(lat: line.lat, eng: line.eng, sideBySide: true)
                    }
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
                Text(sectionLabel(latin, subtitle))
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
                Text(sectionLabel(latin, subtitle))
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
