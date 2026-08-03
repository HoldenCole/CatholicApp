import SwiftUI

struct MissalView: View {
    @State private var store = ContentStore.shared
    @AppStorage(SettingsKey.rite) private var riteRaw = MissalRite.rite1962.rawValue
    @AppStorage(SettingsKey.theme) private var themeRaw = AppTheme.parchment.rawValue
    @AppStorage(SettingsKey.language) private var languageRaw = LanguageMode.both.rawValue
    @AppStorage(SettingsKey.fontSize) private var fontScale = FontSizeScale.defaultValue
    @AppStorage(SettingsKey.showLeoninePrayers) private var showLeoninePrayers = true

    @State private var pdfURL: URL?
    @State private var showShareSheet = false

    private var rite: MissalRite { MissalRite(rawValue: riteRaw) ?? .rite1962 }
    private var mode: LanguageMode { LanguageMode(rawValue: languageRaw) ?? .both }
    private var ctx: LiturgicalContext { .current() }

    private func sectionLabel(_ latin: String, _ english: String) -> String {
        switch mode {
        case .latinOnly: return latin
        case .vernacular: return english
        case .both: return "\(latin)\n\(english)"
        }
    }

    private var todayProper: MassProper? {
        if let proper = store.properForDate(Date(), rite: rite) { return proper }
        guard let slug = ctx.properSlug else { return nil }
        return store.proper(slug: slug)
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
                        Text(todayProper?.englishTitle ?? "Ordo Missæ")
                            .font(.titleM)
                            .italic()
                            .foregroundStyle(Color.primaryText)
                        Text(rite.short)
                            .smallLabel(color: Color.goldLeaf, tracking: 2)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            let t = massShareTitle
                            if let url = PDFExporter.writePDF(from: fullMassHTML(), title: t.latin) {
                                pdfURL = url
                                showShareSheet = true
                            }
                        } label: {
                            Label("Share as PDF", systemImage: "doc.richtext")
                        }
                        ShareLink(item: fullMassText()) {
                            Label("Share as Text", systemImage: "doc.plaintext")
                        }
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                            .foregroundStyle(Color.sanctuaryRed)
                    }
                }
            }
            .sheet(isPresented: $showShareSheet) {
                if let url = pdfURL {
                    ShareSheet(items: [url])
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
        ordinarySection("libera")

        // Agnus Dei
        if proper.color == "black" {
            ordinarySection("agnus-requiem")
        } else {
            ordinarySection("agnus")
        }

        // Libera nos (embolism), the priest's communion prayers, and his
        // communion — then the Confiteor and communion of the faithful
        // (retained in preconciliar practice; suppressed by Inter
        // Oecumenici 1964).
        ordinarySection("orationes-ante-communionem")
        ordinarySection("panem-caelestem")

        // Domine non sum dignus (the priest's, said thrice)
        ordinarySection("domine")
        ordinarySection("communio-sacerdotis")
        ordinarySection("confiteor-communion")

        // COMMUNION (proper)
        properSection("Commúnio", subtitle: "Communion", text: proper.communion)

        ordinarySection("ablutiones")

        // POSTCOMMUNION (proper)
        properSection("Postcommúnio", subtitle: "Postcommunion", text: proper.postcommunion)

        // Dismissal precedes the Placeat:
        // "Ite, missa est" when Gloria was said;
        // "Ite, missa est, alleluia, alleluia" during the Easter octave;
        // "Benedicamus Domino" when Gloria was not said;
        // "Requiescant in pace" at Requiem Masses.
        if proper.color == "black" {
            ordinarySection("requiescant")
        } else if isEasterOctave {
            ordinarySection("ite-alleluia")
        } else if showGloria(proper) || rite == .rite1962 {
            // 1960 rubrics: Ite missa est even when the Gloria is not said;
            // Benedicamus Domino survives only in the older rites.
            ordinarySection("ite")
        } else {
            ordinarySection("benedicamus")
        }

        // Placeat is said at every Mass; the blessing alone is omitted at
        // Requiems.
        ordinarySection("placeat")
        if proper.color != "black" {
            ordinarySection("benedictio")
        }

        // Last Gospel — Palm Sunday substitutes Matt 21:1-9 in the pre-1955 rite.
        // Other days default to John 1:1-14 ("ultimum").
        let lastGospelSlug = lastGospelOverride(for: proper) ?? "ultimum"
        ordinarySection(lastGospelSlug)

        // Leonine Prayers — suppressed by Inter Oecumenici (1964) but retained
        // in 1962 and earlier rubrics as a customary appendix after Low Mass.
        // Gated by user setting (default: shown for strict 1962 observance).
        if showLeoninePrayers {
            ordinarySection("leonine")
        }
    }

    /// Returns an alternate Last Gospel slug when the rubrics call for substitution.
    /// Currently: Palm Sunday in the pre-1955 rite uses Matt 21 (the blessing-of-palms
    /// gospel) as the Last Gospel of the principal Mass.
    private func lastGospelOverride(for proper: MassProper?) -> String? {
        let slug = ctx.properSlug ?? ""
        if rite == .pre1955 && (slug == "palm-sunday" || slug == "quad6-0") {
            return store.missal.first(where: { $0.slug == "ultimum-palm-sunday" })?.slug
        }
        return nil
    }

    // MARK: - Rubric helpers

    /// Returns true when the current day is within the Easter Octave
    /// (Easter Sunday through the following Saturday) or the Pentecost Octave
    /// (Pentecost Sunday through the following Saturday). On those days the
    /// dismissal uses the doubled-Alleluia form: "Ite, missa est, alleluia,
    /// alleluia."
    /// The doubled "Ite, missa est, alleluia" belongs to the EASTER octave
    /// only (Pentecost's octave keeps the ordinary dismissal).
    private var isEasterOctave: Bool {
        guard let key = ctx.temporalKey else { return false }
        return key.hasPrefix("pasc0-")
    }

    /// Gloria is omitted during penitential seasons (Advent, Lent, Passion,
    /// pre-Lent) on ferial days. It IS said on fixed feasts even in those
    /// seasons, and always during Easter and Christmas seasons.
    private func showGloria(_ proper: MassProper) -> Bool {
        // Honor explicit DO rubric rule when present.
        if let override = proper.glorOverride { return override }
        let season = ctx.season
        if proper.color == "violet" || proper.color == "black" {
            return false
        }
        if season == .easter || season == .christmas { return true }
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
        if let variantKey = canonVariantKey(for: rite),
           let section = store.missal.first(where: { $0.slug == "canon" }) {
            let modified: [MissalSection.Line] = section.body.map { line in
                var mutable = line
                if line.lat.hasPrefix("Commúnicántes") || line.lat.hasPrefix("Communicántes"),
                   let variant = store.canonVariant("communicantes", key: variantKey) {
                    mutable.lat = variant.lat
                    mutable.eng = variant.eng
                }
                if line.lat.hasPrefix("Hanc ígitur"),
                   let variant = store.canonVariant("hanc_igitur", key: variantKey) {
                    mutable.lat = variant.lat
                    mutable.eng = variant.eng
                }
                mutable = Self.withJosephClause(mutable, rite: rite)
                return mutable
            }
            ordinarySectionBlock(
                MissalSection(slug: section.slug, label: section.label,
                              title: section.title, english: section.english,
                              body: modified)
            )
        } else if let section = store.missal.first(where: { $0.slug == "canon" }) {
            ordinarySectionBlock(
                MissalSection(slug: section.slug, label: section.label,
                              title: section.title, english: section.english,
                              body: section.body.map { Self.withJosephClause($0, rite: rite) })
            )
        } else {
            ordinarySection("canon")
        }
    }

    /// The 1962 Canon (decree of 13 Nov 1962) adds "sed et beati Joseph,
    /// ejusdem Virginis Sponsi" to the Communicantes; the older rites do not.
    static func withJosephClause(_ line: MissalSection.Line, rite: MissalRite) -> MissalSection.Line {
        guard rite == .rite1962,
              line.lat.hasPrefix("Commúnicántes") || line.lat.hasPrefix("Communicántes"),
              !line.lat.contains("beáti Joseph") else { return line }
        var mutable = line
        mutable.lat = mutable.lat.replacingOccurrences(
            of: "Jesu Christi: sed et",
            with: "Jesu Christi: sed et beáti Joseph, ejúsdem Vírginis Sponsi: sed et")
        if let range = mutable.eng.range(of: ": and also of the blessed Apostles") {
            mutable.eng = mutable.eng.replacingCharacters(
                in: range,
                with: ": and also of blessed Joseph, spouse of the same Virgin: and also of the blessed Apostles")
        } else if let range = mutable.eng.range(of: ": y también de tus bienaventurados Apóstoles") {
            // Spanish vernacular overlay active.
            mutable.eng = mutable.eng.replacingCharacters(
                in: range,
                with: ": y también del bienaventurado José, esposo de la misma Virgen: y también de tus bienaventurados Apóstoles")
        }
        return mutable
    }

    /// Returns the Communicantes/Hanc igitur variant key (if any) for the
    /// current day. Identical across all three rites: the 1960 Codex
    /// Rubricarum retained the octaves of Easter and Pentecost (abolishing
    /// all the others except Christmas), so the proper texts run the whole
    /// octave everywhere; Christmas runs through its octave day (Jan 1),
    /// and Epiphany/Ascension fire on the feast itself.
    private func canonVariantKey(for rite: MissalRite) -> String? {
        guard let slug = ctx.properSlug else { return nil }
        // Nativity: Christmas through its octave day (the Circumcision,
        // Jan 1) and the Sunday within the octave. NOT the Holy Name Sunday
        // (christmas-2, Jan 2-5) — the octave has ended.
        if slug == "christmas" || slug == "christmas-1" || slug == "circumcision" { return "christmas" }
        if slug == "st-stephen" || slug == "holy-innocents" { return "christmas" }
        if let key = ctx.temporalKey, key.hasPrefix("nat"), !key.hasPrefix("nat2") {
            let jan = ["nat08", "nat09", "nat10", "nat11"]
            if !jan.contains(key) { return "christmas" }
        }
        if slug.hasPrefix("sancti-12-2") || slug.hasPrefix("sancti-12-3") { return "christmas" }
        if slug == "epiphany" { return "epiphany" }
        if slug == "ascension" { return "ascension" }

        // The 1960 Codex Rubricarum RETAINED the octaves of Easter and
        // Pentecost (it abolished all the others): the proper Communicantes
        // and Hanc igitur run the whole octave in all three rites, vigils
        // included.
        if slug == "easter-sunday" || slug == "holy-saturday" || slug.hasPrefix("easter-0-") {
            return "easter"
        }
        if slug == "pentecost-sunday" || slug == "vigil-pentecost" || slug.hasPrefix("easter-7-") {
            return "pentecost"
        }
        return nil
    }

    /// Credo is said on all Sundays and on major feasts (rank 1 in data).
    /// Also fires on feasts of Apostles, Evangelists, and Doctors regardless
    /// of legacy rank, since these classes always have Credo per the rubrics
    /// (Ritus servandus VI; cf. 1962 Rubricæ Generales nos. 475–477).
    /// Detected from the officium string (preserved as the proper's title)
    /// to remain conservative — only triggers on a clear textual signal.
    private func showCredo(_ proper: MassProper) -> Bool {
        if let override = proper.credoOverride { return override }
        if ctx.isSunday { return true }
        if proper.rank == 1 { return true }
        if isApostleEvangelistOrDoctor(proper) { return true }
        return false
    }

    /// Returns true when the officium (proper.title) names an Apostle,
    /// Evangelist, or Doctor of the Church. Case-insensitive Latin match.
    private func isApostleEvangelistOrDoctor(_ proper: MassProper) -> Bool {
        let officium = proper.title.lowercased()
        // Latin: "Apostoli" / "Apostolorum", "Evangelistæ" (or ASCII "Evangelistae"),
        // "Doctoris" / "Doctorum" / "Doctores".
        let needles = ["apostoli", "apostolorum",
                       "evangelistæ", "evangelistae", "evangelistarum",
                       "doctoris", "doctorum", "doctores"]
        return needles.contains(where: { officium.contains($0) })
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

    private enum MassShareItem {
        case ordinary(title: String, english: String?, lines: [(lat: String, eng: String)])
        case properText(label: String, lat: String, eng: String, ref: String?)
    }

    /// The single source of truth for the interleave walk — both the text
    /// share and the PDF render from these items, so they can never drift.
    private func fullMassItems() -> [MassShareItem] {
        var items: [MassShareItem] = []
        let proper = todayProper

        func addOrdinary(_ slug: String) {
            guard let section = store.missal.first(where: { $0.slug == slug }) else { return }
            items.append(.ordinary(
                title: section.title,
                english: section.english,
                lines: section.body.map { ($0.lat.strippingEm, $0.eng.strippingEm) }
            ))
        }

        func addProper(_ label: String, lat: String, eng: String, ref: String? = nil) {
            items.append(.properText(label: label, lat: lat.strippingEm,
                                     eng: eng.strippingEm, ref: ref))
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
            addProper("Orátio · Collect", lat: p.collect.lat, eng: p.collect.eng)
            addProper("Léctio · Epistle", lat: p.epistle.lat, eng: p.epistle.eng, ref: p.epistle.ref)
            if let g = p.gradual { addProper("Graduále · Gradual", lat: g.lat, eng: g.eng) }
            if let a = p.alleluia { addProper("Allelúja", lat: a.lat, eng: a.eng) }
            if let t = p.tract { addProper("Tractus · Tract", lat: t.lat, eng: t.eng) }
            if let seq = p.sequence { addProper("Sequéntia · Sequence", lat: seq.lat, eng: seq.eng) }
            addProper("Evangélium · Gospel", lat: p.gospel.lat, eng: p.gospel.eng, ref: p.gospel.ref)
        }

        if let p = proper {
            if showCredo(p) { addOrdinary("credo") }
        } else {
            addOrdinary("credo")
        }

        if let p = proper {
            addProper("Offertórium · Offertory", lat: p.offertory.lat, eng: p.offertory.eng)
        }

        addOrdinary("offertory_prayers")

        if let p = proper {
            addProper("Secréta · Secret", lat: p.secret.lat, eng: p.secret.eng)
        }

        let resolvedPreface = prefaceSlug(for: proper)
        if store.missal.contains(where: { $0.slug == resolvedPreface }) {
            addOrdinary(resolvedPreface)
        } else {
            addOrdinary("preface")
        }
        addOrdinary("sanctus")
        // Canon with proper Communicantes / Hanc igitur (on-screen parity)
        if let variantKey = canonVariantKey(for: rite),
           let section = store.missal.first(where: { $0.slug == "canon" }) {
            let lines: [(lat: String, eng: String)] = section.body.map { line in
                var mutable = line
                if line.lat.hasPrefix("Commúnicántes") || line.lat.hasPrefix("Communicántes"),
                   let v = store.canonVariant("communicantes", key: variantKey) {
                    mutable.lat = v.lat; mutable.eng = v.eng
                }
                if line.lat.hasPrefix("Hanc ígitur"),
                   let v = store.canonVariant("hanc_igitur", key: variantKey) {
                    mutable.lat = v.lat; mutable.eng = v.eng
                }
                mutable = Self.withJosephClause(mutable, rite: rite)
                return (mutable.lat.strippingEm, mutable.eng.strippingEm)
            }
            items.append(.ordinary(title: section.title, english: section.english, lines: lines))
        } else if let section = store.missal.first(where: { $0.slug == "canon" }) {
            let lines = section.body.map { line -> (lat: String, eng: String) in
                let l = Self.withJosephClause(line, rite: rite)
                return (l.lat.strippingEm, l.eng.strippingEm)
            }
            items.append(.ordinary(title: section.title, english: section.english, lines: lines))
        } else {
            addOrdinary("canon")
        }
        addOrdinary("pater")
        addOrdinary("libera")
        if proper?.color == "black" {
            addOrdinary("agnus-requiem")
        } else {
            addOrdinary("agnus")
        }
        addOrdinary("orationes-ante-communionem")
        addOrdinary("panem-caelestem")
        addOrdinary("domine")
        addOrdinary("communio-sacerdotis")
        // Confiteor before Communion — retained in preconciliar practice
        addOrdinary("confiteor-communion")

        if let p = proper {
            addProper("Commúnio · Communion", lat: p.communion.lat, eng: p.communion.eng)
        }
        addOrdinary("ablutiones")

        if let p = proper {
            addProper("Postcommúnio · Postcommunion", lat: p.postcommunion.lat, eng: p.postcommunion.eng)
        }

        // Dismissal precedes the Placeat.
        if let p = proper {
            if p.color == "black" {
                addOrdinary("requiescant")
            } else if isEasterOctave {
                addOrdinary("ite-alleluia")
            } else if showGloria(p) || rite == .rite1962 {
                addOrdinary("ite")
            } else {
                addOrdinary("benedicamus")
            }
        } else {
            addOrdinary("ite")
        }

        addOrdinary("placeat")
        if proper?.color != "black" {
            addOrdinary("benedictio")
        }

        addOrdinary(lastGospelOverride(for: proper) ?? "ultimum")
        if showLeoninePrayers {
            addOrdinary("leonine")
        }

        return items
    }

    private var massShareTitle: (latin: String, english: String) {
        if let p = todayProper { return (p.title.strippingEm, p.englishTitle) }
        return ("Ordo Missæ", rite.short)
    }

    private func fullMassText() -> String {
        var s = ""
        if let proper = todayProper {
            s += "✠ \(proper.title.strippingEm)\n"
            s += "  \(proper.englishTitle)\n"
            s += "  \(rite.short)\n"
        } else {
            s += "✠ Ordo Missæ\n"
            s += "  \(rite.short)\n"
        }
        s += "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n"

        for item in fullMassItems() {
            switch item {
            case .ordinary(let title, let english, let lines):
                s += "══ \(title.uppercased())"
                if let english { s += " · \(english)" }
                s += " ══\n\n"
                for line in lines {
                    s += "\(line.lat)\n"
                    s += "\(line.eng)\n\n"
                }
            case .properText(let label, let lat, let eng, let ref):
                s += "┌ \(label.uppercased())\n"
                if let ref, !ref.isEmpty { s += "│ \(ref)\n" }
                s += "│\n"
                for line in lat.components(separatedBy: "\n") where !line.isEmpty {
                    s += "│  \(line)\n"
                }
                s += "│\n"
                for line in eng.components(separatedBy: "\n") where !line.isEmpty {
                    s += "│  \(line)\n"
                }
                s += "└─────\n\n"
            }
        }

        s += "— Introibo (app.introibo) —"
        return s
    }

    private func fullMassHTML() -> String {
        let sections = fullMassItems().map { item -> (label: String, lat: String, eng: String, ref: String?) in
            switch item {
            case .ordinary(let title, let english, let lines):
                let label = english.map { "\(title)  ·  \($0)" } ?? title
                return (label: label,
                        lat: lines.map { $0.lat }.joined(separator: "\n"),
                        eng: lines.map { $0.eng }.joined(separator: "\n"),
                        ref: nil)
            case .properText(let label, let lat, let eng, let ref):
                return (label: label, lat: lat, eng: eng, ref: ref)
            }
        }
        let t = massShareTitle
        return MassHTMLExporter.massHTML(title: t.latin, englishTitle: t.english, sections: sections)
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
        "preface-sacred-heart",
        "preface-christ-king",
        "agnus-requiem",
        "ite-alleluia"
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
