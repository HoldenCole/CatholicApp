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
            GeometryReader { geo in
                ScrollView(.vertical, showsIndicators: true) {
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
                    .frame(width: geo.size.width)
                }
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
        // In Passiontide and Requiem Masses, Psalm 42 (Judica me) is omitted;
        // the priest goes directly to the Confiteor.
        if ctx.season != .passion && proper.color != "black" {
            ordinarySection("preces")
        }
        ordinarySection("confiteor")

        // INTROIT (proper)
        // In Passiontide the Gloria Patri is omitted from the Introit.
        properSection("Introitus", subtitle: "Introit",
                       text: ctx.season == .passion
                           ? stripGloriaPatri(proper.introit)
                           : proper.introit)

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
        properPreface(proper)
        ordinarySection("sanctus")
        canonWithProperInsertions()
        ordinarySection("pater")

        // Agnus Dei
        if proper.color == "black" {
            ordinarySection("agnus-requiem")
        } else {
            ordinarySection("agnus")
        }

        // Confiteor before Communion (pre-1955 rite; suppressed in 1962)
        if rite == .pre1955 {
            ordinarySection("confiteor-communion")
        }

        // Domine non sum dignus
        ordinarySection("domine")

        // COMMUNION (proper)
        properSection("Commúnio", subtitle: "Communion", text: proper.communion)

        // POSTCOMMUNION (proper)
        properSection("Postcommúnio", subtitle: "Postcommunion", text: proper.postcommunion)

        // Placeat, Blessing (omitted in Requiem Masses)
        if proper.color != "black" {
            ordinarySection("placeat")
        }

        // Dismissal: "Ite, missa est" when Gloria was said;
        // "Benedicamus Domino" when Gloria was not said;
        // "Requiescant in pace" at Requiem Masses.
        if proper.color == "black" {
            ordinarySection("requiescant")
        } else if showGloria(proper) {
            ordinarySection("ite")
        } else {
            ordinarySection("benedicamus")
        }

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

    /// Determine the correct Preface slug for the season/feast.
    /// 1. If the proper has an explicit preface field, use "preface-{value}".
    /// 2. Otherwise, derive from the liturgical season.
    /// 3. Fall back to the Common Preface ("preface").
    private func prefaceSlug(for proper: MassProper?) -> String {
        if let explicit = proper?.preface, !explicit.isEmpty {
            return "preface-\(explicit)"
        }
        switch ctx.season {
        case .advent:    return "preface-advent"
        case .christmas: return "preface-nativity"
        case .lent:      return "preface-lent"
        case .passion:   return "preface-cross"
        case .easter:    return "preface-easter"
        case .pentecost: return "preface-pentecost"
        case .perAnnum:  return "preface"
        }
    }

    /// Select the correct Preface for the season/feast.
    @ViewBuilder
    private func properPreface(_ proper: MassProper) -> some View {
        let slug = prefaceSlug(for: proper)
        if store.missal.contains(where: { $0.slug == slug }) {
            ordinarySection(slug)
        } else {
            ordinarySection("preface")
        }
    }

    /// Render the Canon, substituting proper Communicantes/Hanc igitur
    /// for Christmas, Epiphany, Easter, Ascension, Pentecost.
    @ViewBuilder
    private func canonWithProperInsertions() -> some View {
        if let variantKey = canonVariantKey(),
           let section = store.missal.first(where: { $0.slug == "canon" }) {
            let modified: [MissalSection.Line] = section.body.map { line in
                var mutable = line
                if line.lat.hasPrefix("Commúnicántes"),
                   let variant = store.canonVariant("communicantes", key: variantKey) {
                    mutable.lat = variant.lat
                    mutable.eng = variant.eng
                }
                if line.lat.hasPrefix("Hanc ígitur"),
                   let variant = store.canonVariant("hanc_igitur", key: variantKey) {
                    mutable.lat = variant.lat
                    mutable.eng = variant.eng
                }
                return mutable
            }
            ordinarySectionBlock(
                MissalSection(slug: section.slug, label: section.label,
                              title: section.title, english: section.english,
                              body: modified)
            )
        } else {
            ordinarySection("canon")
        }
    }

    private func canonVariantKey() -> String? {
        guard let slug = ctx.properSlug else { return nil }
        if slug == "christmas" || slug.hasPrefix("christmas-") { return "christmas" }
        if slug == "epiphany" { return "epiphany" }
        if slug == "easter-sunday" || slug.hasPrefix("easter-0") { return "easter" }
        if slug == "ascension" { return "ascension" }
        if slug == "pentecost-sunday" || slug.hasPrefix("easter-7") { return "pentecost" }
        return nil
    }

    /// Credo is said on all Sundays and on major feasts (rank 1 in data).
    private func showCredo(_ proper: MassProper) -> Bool {
        if ctx.isSunday { return true }
        return proper.rank == 1
    }

    /// Strip the Gloria Patri doxology from an introit text.
    /// The doxology may appear as the abbreviated "℣. Glória Patri." or
    /// the full "Glória Patri, et Fílio, et Spirítui Sancto. Sicut erat …"
    /// along with the English equivalent.
    private func stripGloriaPatri(_ text: ProperText) -> ProperText {
        let latStripped = text.lat
            .replacingOccurrences(
                of: #"\s*℣\.?\s*Glória Patri[^℣]*$"#,
                with: "",
                options: .regularExpression)
            .replacingOccurrences(
                of: #"\s*Glória Patri,\s*et Fílio.*?(Amen\.|Sancto\.)"#,
                with: "",
                options: .regularExpression)
        let engStripped = text.eng
            .replacingOccurrences(
                of: #"\s*℣\.?\s*Glory be to the Father[^℣]*$"#,
                with: "",
                options: .regularExpression)
            .replacingOccurrences(
                of: #"\s*Glory be to the Father,?\s*and to the Son.*?(Amen\.|Ghost\.)"#,
                with: "",
                options: .regularExpression)
        return ProperText(lat: latStripped, eng: engStripped)
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

        if let p = proper {
            // Psalm 42 omitted in Passiontide and Requiem Masses
            if ctx.season != .passion && p.color != "black" {
                addOrdinary("preces")
            }
        } else {
            addOrdinary("preces")
        }
        addOrdinary("confiteor")

        if let p = proper {
            // Strip Gloria Patri from introit in Passiontide
            let introit = ctx.season == .passion ? stripGloriaPatri(p.introit) : p.introit
            addProper("Introitus · Introit", lat: introit.lat, eng: introit.eng)
        }

        addOrdinary("kyrie")
        if let p = proper, showGloria(p) {
            addOrdinary("gloria")
        } else if proper == nil {
            addOrdinary("gloria")
        }

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

        let resolvedPreface = prefaceSlug(for: proper)
        if store.missal.contains(where: { $0.slug == resolvedPreface }) {
            addOrdinary(resolvedPreface)
        } else {
            addOrdinary("preface")
        }
        addOrdinary("sanctus")
        addOrdinary("canon")
        addOrdinary("pater")
        if proper?.color == "black" {
            addOrdinary("agnus-requiem")
        } else {
            addOrdinary("agnus")
        }
        addOrdinary("domine")

        if let p = proper {
            addProper("Communio · Communion", lat: p.communion.lat, eng: p.communion.eng)
        }

        if let p = proper {
            addProper("Postcommunio · Postcommunion", lat: p.postcommunion.lat, eng: p.postcommunion.eng)
        }

        if proper?.color != "black" {
            addOrdinary("placeat")
        }

        // Dismissal
        if let p = proper {
            if p.color == "black" {
                addOrdinary("requiescant")
            } else if showGloria(p) {
                addOrdinary("ite")
            } else {
                addOrdinary("benedicamus")
            }
        } else {
            addOrdinary("ite")
        }

        addOrdinary("ultimum")
        addOrdinary("leonine")

        return lines.joined(separator: "\n")
    }

    // MARK: - Ordinary-only fallback

    /// Slugs that should only appear when selected for a specific
    /// season/feast/rite -- never in the generic ordinary-only view.
    private static let properPrefaceSlugs: Set<String> = [
        "preface-advent", "preface-nativity", "preface-epiphany",
        "preface-lent", "preface-cross", "preface-easter",
        "preface-ascension", "preface-pentecost", "preface-trinity",
        "preface-bvm", "preface-joseph", "preface-apostles",
        "preface-requiem",
        "agnus-requiem"
    ]

    private var ordinaryOnly: some View {
        ForEach(store.missal.filter { !Self.properPrefaceSlugs.contains($0.slug) }) { section in
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
                        .lineLimit(2)
                    .minimumScaleFactor(0.7)
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
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
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
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
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
