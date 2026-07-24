import SwiftUI

struct ReferenceView: View {
    @State private var store = ContentStore.shared
    @State private var selection: ReferenceEntry?
    @State private var searchText = ""
    @AppStorage(SettingsKey.theme) private var themeRaw = AppTheme.parchment.rawValue
    @AppStorage(SettingsKey.language) private var languageRaw = LanguageMode.both.rawValue
    private var langMode: LanguageMode { LanguageMode(rawValue: languageRaw) ?? .both }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    sectionsGrid
                    quickLinks
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 40)
            }
            .background(Color.pageBackground.ignoresSafeArea())
            .navigationTitle("Liber")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    // MARK: - Sections Grid

    private var sectionsGrid: some View {
        VStack(spacing: 12) {
            HStack(spacing: 12) {
                sectionCard(
                    icon: "text.book.closed",
                    title: "References",
                    latin: "Encyclopaedia",
                    count: "\(store.reference.count) articles",
                    destination: AnyView(ReferenceListView())
                )
                sectionCard(
                    icon: "book.closed",
                    title: "Propers",
                    latin: "Propria Missae",
                    count: "\(store.allPropers.count) formularies",
                    destination: AnyView(PropersSearchView())
                )
            }
            HStack(spacing: 12) {
                sectionCard(
                    icon: "scroll",
                    title: "History",
                    latin: "Historia Missae",
                    count: "Timeline",
                    destination: AnyView(TLMHistoryView())
                )
                sectionCard(
                    icon: "character.book.closed",
                    title: "Glossary",
                    latin: "Glossarium",
                    count: "Liturgical terms",
                    destination: AnyView(GlossaryView())
                )
            }
        }
    }

    private func sectionCard(icon: String, title: String, latin: String, count: String, destination: AnyView) -> some View {
        NavigationLink(destination: destination) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.scaledSystem(24))
                    .foregroundStyle(Color.sanctuaryRed)
                Text(title)
                    .font(.titleM)
                    .italic()
                    .foregroundStyle(Color.primaryText)
                if langMode != .vernacular {
                    Text(latin)
                        .font(.captionSm)
                        .italic()
                        .foregroundStyle(Color.secondaryText)
                }
                Text(count)
                    .font(.captionSm)
                    .foregroundStyle(Color.tertiaryText)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .overlay(Rectangle().stroke(Color.frameLine, lineWidth: 0.5))
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Quick Links

    private var quickLinks: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Rectangle().fill(Color.goldLeaf.opacity(0.4)).frame(height: 0.5)
                Text("Quick Reference")
                    .font(.captionSm)
                    .italic()
                    .foregroundStyle(Color.secondaryText)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                Rectangle().fill(Color.goldLeaf.opacity(0.4)).frame(height: 0.5)
            }

            ForEach(["The Holy Mass", "Baptism", "The Holy Eucharist", "Penance (Confession)", "The Rosary"], id: \.self) { title in
                if let entry = store.reference.first(where: { $0.title == title }) {
                    Button { selection = entry } label: {
                        HStack {
                            Text(entry.title)
                                .font(.titleM)
                                .italic()
                                .foregroundStyle(Color.primaryText)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.scaledSystem(10))
                                .foregroundStyle(Color.tertiaryText)
                        }
                        .padding(.vertical, 4)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .sheet(item: $selection) { entry in
            ReferenceDetailView(entry: entry)
        }
    }
}

// MARK: - Reference List (old Liber content)

struct ReferenceListView: View {
    @State private var store = ContentStore.shared
    @State private var selection: ReferenceEntry?
    @AppStorage(SettingsKey.theme) private var themeRaw = AppTheme.parchment.rawValue

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                ForEach(groupedByCategory(), id: \.category) { group in
                    VStack(alignment: .leading, spacing: 14) {
                        categoryHeader(group.category)
                        ForEach(group.items) { entry in
                            Button { selection = entry } label: {
                                row(entry)
                            }
                            .buttonStyle(.plain)
                            if entry.slug != group.items.last?.slug {
                                Divider().background(Color.frameLine)
                            }
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 40)
        }
        .background(Color.pageBackground.ignoresSafeArea())
        .navigationTitle("References")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selection) { ReferenceDetailView(entry: $0) }
    }

    private func categoryHeader(_ category: String) -> some View {
        HStack(spacing: 10) {
            Rectangle().fill(Color.sanctuaryRed.opacity(0.4)).frame(height: 1)
            Text(category)
                .font(.titleM)
                .italic()
                .foregroundStyle(Color.sanctuaryRed)
                .textCase(.uppercase)
                .tracking(2)
                .lineLimit(2)
                    .minimumScaleFactor(0.7)
            Rectangle().fill(Color.sanctuaryRed.opacity(0.4)).frame(height: 1)
        }
        .padding(.top, 8)
    }

    private func row(_ entry: ReferenceEntry) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(entry.title)
                .font(.titleM)
                .italic()
                .foregroundStyle(Color.primaryText)
            if let latin = entry.latin {
                Text(latin)
                    .font(.captionSm)
                    .italic()
                    .foregroundStyle(Color.secondaryText)
            }
            Text(entry.summary)
                .font(.captionSm)
                .foregroundStyle(Color.tertiaryText)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .padding(.top, 2)
        }
        .padding(.vertical, 6)
    }

    private func groupedByCategory() -> [(category: String, items: [ReferenceEntry])] {
        var seen: [String] = []
        var buckets: [String: [ReferenceEntry]] = [:]
        for e in store.reference {
            if buckets[e.cat] == nil { seen.append(e.cat); buckets[e.cat] = [] }
            buckets[e.cat]?.append(e)
        }
        return seen.map { ($0, buckets[$0] ?? []) }
    }
}

// MARK: - Propers Search

struct PropersSearchView: View {
    @State private var store = ContentStore.shared
    @State private var searchText = ""
    @State private var selectedProper: MassProper?
    @AppStorage(SettingsKey.theme) private var themeRaw = AppTheme.parchment.rawValue

    private var filtered: [MassProper] {
        if searchText.isEmpty { return store.allPropers }
        let q = searchText.lowercased()
        return store.allPropers.filter {
            $0.title.lowercased().contains(q) ||
            $0.english.lowercased().contains(q) ||
            $0.epistle.ref.lowercased().contains(q) ||
            $0.gospel.ref.lowercased().contains(q) ||
            $0.slug.lowercased().contains(q)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(Color.tertiaryText)
                TextField("Search by saint, date, or scripture", text: $searchText)
                    .font(.body)
                if !searchText.isEmpty {
                    Button { searchText = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(Color.tertiaryText)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(12)
            .background(Color.frameLine.opacity(0.3))
            .padding(.horizontal, 20)
            .padding(.top, 12)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(filtered) { proper in
                        Button { selectedProper = proper } label: {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(proper.title)
                                    .font(.titleM)
                                    .italic()
                                    .foregroundStyle(Color.primaryText)
                                Text(proper.english)
                                    .font(.captionSm)
                                    .italic()
                                    .foregroundStyle(Color.secondaryText)
                                if !proper.epistle.ref.isEmpty || !proper.gospel.ref.isEmpty {
                                    HStack(spacing: 8) {
                                        if !proper.epistle.ref.isEmpty {
                                            Text("Ep. \(proper.epistle.ref)")
                                                .font(.captionSm)
                                                .foregroundStyle(Color.tertiaryText)
                                        }
                                        if !proper.gospel.ref.isEmpty {
                                            Text("Ev. \(proper.gospel.ref)")
                                                .font(.captionSm)
                                                .foregroundStyle(Color.tertiaryText)
                                        }
                                    }
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 10)
                            .padding(.horizontal, 20)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        Divider().padding(.leading, 20)
                    }
                }
            }
        }
        .background(Color.pageBackground.ignoresSafeArea())
        .navigationTitle("Propers")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selectedProper) { proper in
            ProperView(proper: proper)
        }
    }
}

// MARK: - TLM History Timeline

struct TLMHistoryView: View {
    @AppStorage(SettingsKey.theme) private var themeRaw = AppTheme.parchment.rawValue

    private let events: [(year: String, title: String, desc: String)] = [
        ("33 AD", "The Last Supper", "Our Lord institutes the Holy Sacrifice of the Mass at the Last Supper, commanding the Apostles to do this in memory of Him."),
        ("c. 100", "Apostolic Liturgy", "The Didache describes early Christian worship with prayers over bread and wine following the pattern established by the Apostles."),
        ("c. 225", "Apostolic Tradition", "Hippolytus of Rome records the earliest known Eucharistic Prayer, showing the Roman Canon already taking shape."),
        ("c. 380", "Latin Becomes Standard", "Pope Damasus I commissions the Vulgate Bible and Latin replaces Greek as the language of the Roman liturgy."),
        ("590-604", "Pope St. Gregory the Great", "Reforms and codifies the Roman liturgy. The Canon of the Mass reaches essentially its final form. Gregorian Chant is organized."),
        ("800", "Carolingian Standardisation", "Charlemagne mandates the Roman Rite throughout his empire, spreading the Gregorian liturgy across Western Europe."),
        ("1215", "Fourth Lateran Council", "Defines transubstantiation as dogma. Mandates annual confession and communion. The Mass is the centre of Catholic life."),
        ("1474", "First Printed Missal", "The Missale Romanum is among the first books printed, standardising the texts that had been transmitted in manuscripts."),
        ("1545-1563", "Council of Trent", "Responds to the Protestant Reformation by affirming the sacrificial nature of the Mass and mandating liturgical reform."),
        ("1570", "Missal of Pius V", "Pope St. Pius V promulgates the Tridentine Missal, codifying the Roman Rite and establishing liturgical uniformity."),
        ("1604", "Clement VIII Revision", "Minor corrections to the Missale Romanum, refining rubrics without altering the substance of the rite."),
        ("1634", "Urban VIII Revision", "Further small revisions to hymns and rubrics. The Mass remains substantially unchanged for centuries."),
        ("1911-1913", "Pius X Breviary Reform", "Reorganises the Divine Office psalmody. The Mass itself remains untouched."),
        ("1955", "Holy Week Reforms", "Pius XII reforms the Holy Week liturgy, the most significant change to the Mass since 1570."),
        ("1962", "The 1962 Missal", "Pope John XXIII issues the last edition of the Tridentine Missal, incorporating minor rubrical changes. This is the Missal used by traditional Catholics today."),
        ("1969", "Novus Ordo Missae", "Paul VI promulgates the new Mass. The traditional Mass is widely suppressed but never formally abrogated."),
        ("1984", "Quattuor Abhinc Annos", "John Paul II permits limited use of the 1962 Missal under indult, beginning the restoration of the traditional Mass."),
        ("1988", "Ecclesia Dei", "After the consecrations by Archbishop Lefebvre, John Paul II establishes the Ecclesia Dei Commission and calls for generous provision of the traditional Mass."),
        ("2007", "Summorum Pontificum", "Benedict XVI declares that the traditional Mass was never abrogated and frees its celebration, recognising it as the Extraordinary Form."),
        ("2021", "Traditionis Custodes", "Francis restricts the traditional Mass. Traditional Catholic communities continue to grow worldwide."),
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                VStack(spacing: 8) {
                    Text("✠")
                        .font(.scaledSystem(36))
                        .foregroundStyle(Color.sanctuaryRed.opacity(0.6))
                        .padding(.top, 24)
                    Text("History of the Mass")
                        .font(.pageTitle)
                        .foregroundStyle(Color.ivory)
                    Text("From the Last Supper to the Present Day")
                        .font(.caption)
                        .italic()
                        .foregroundStyle(Color.muted)
                        .textCase(.uppercase)
                        .tracking(2.5)
                    Rectangle()
                        .fill(Color.goldLeaf.opacity(0.4))
                        .frame(width: 60, height: 0.5)
                        .padding(.vertical, 14)
                }
                .frame(maxWidth: .infinity)
                .background(
                    LinearGradient(colors: [Color.walnut, Color.walnutHi], startPoint: .top, endPoint: .bottom)
                )

                VStack(spacing: 0) {
                    ForEach(Array(events.enumerated()), id: \.offset) { idx, event in
                        HStack(alignment: .top, spacing: 14) {
                            VStack(spacing: 0) {
                                Circle()
                                    .fill(Color.sanctuaryRed.opacity(0.15))
                                    .frame(width: 10, height: 10)
                                    .overlay(Circle().stroke(Color.sanctuaryRed.opacity(0.5), lineWidth: 1))
                                if idx < events.count - 1 {
                                    Rectangle()
                                        .fill(Color.sanctuaryRed.opacity(0.15))
                                        .frame(width: 1)
                                        .frame(maxHeight: .infinity)
                                }
                            }
                            .frame(width: 20)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(event.year)
                                    .font(.captionSm)
                                    .foregroundStyle(Color.goldLeaf)
                                Text(event.title)
                                    .font(.titleM)
                                    .italic()
                                    .foregroundStyle(Color.primaryText)
                                Text(event.desc)
                                    .font(.bodySm)
                                    .foregroundStyle(Color.secondaryText)
                                    .lineSpacing(3)
                            }
                            .padding(.bottom, 20)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 40)
            }
        }
        .background(Color.pageBackground.ignoresSafeArea())
        .navigationTitle("History")
        .navigationBarTitleDisplayMode(.inline)
    }
}

// MARK: - Glossary

struct GlossaryView: View {
    @AppStorage(SettingsKey.theme) private var themeRaw = AppTheme.parchment.rawValue

    private let terms: [(lat: String, eng: String, def: String)] = [
        ("Introitus", "Introit", "The entrance antiphon sung as the priest approaches the altar."),
        ("Collecta", "Collect", "The prayer of the day, collecting the intentions of the faithful."),
        ("Lectio", "Epistle", "The first scripture reading, usually from the letters of St. Paul."),
        ("Graduale", "Gradual", "A psalm response sung between the Epistle and Gospel."),
        ("Evangelium", "Gospel", "The reading from one of the four Gospels."),
        ("Offertorium", "Offertory", "The antiphon accompanying the preparation of the gifts."),
        ("Secreta", "Secret", "The prayer said silently over the offerings before the Preface."),
        ("Praefatio", "Preface", "The solemn prayer of thanksgiving introducing the Canon."),
        ("Canon", "Canon", "The unchanging central prayer of the Mass containing the Consecration."),
        ("Communio", "Communion", "The antiphon sung during the distribution of Holy Communion."),
        ("Postcommunio", "Postcommunion", "The prayer of thanksgiving after Communion."),
        ("Feria", "Feria", "A weekday without a feast. The Mass of the preceding Sunday is repeated."),
        ("Dominica", "Sunday", "The Lord's Day, always at least a second-class feast."),
        ("Proprium", "Proper", "The parts of the Mass that change according to the day or feast."),
        ("Ordinarium", "Ordinary", "The unchanging parts of the Mass (Kyrie, Gloria, Credo, etc.)."),
        ("Rubrica", "Rubric", "A liturgical instruction, printed in red in the Missal."),
        ("Missa Cantata", "Sung Mass", "A Mass where the celebrant sings the prayers, with or without deacon and subdeacon."),
        ("Missa Solemnis", "Solemn Mass", "A Mass celebrated with deacon and subdeacon, incense, and full ceremonies."),
        ("Missa Lecta", "Low Mass", "A Mass spoken (not sung) by a single priest, the most common weekday form."),
        ("Tempus per Annum", "Ordinary Time", "The weeks outside Advent, Christmas, Lent, and Easter."),
        ("Quadragesima", "Lent", "The forty days of penance from Ash Wednesday to Easter."),
        ("Hebdomada Sancta", "Holy Week", "The week from Palm Sunday to Holy Saturday."),
        ("Octava", "Octave", "An eight-day celebration extending a major feast."),
        ("Vigilia", "Vigil", "The day before a feast, often observed with fasting."),
        ("Commune", "Common", "Standard Mass texts used for categories of saints (martyrs, confessors, virgins)."),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(terms.enumerated()), id: \.offset) { _, term in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(alignment: .firstTextBaseline, spacing: 10) {
                            Text(term.lat)
                                .font(.titleM)
                                .italic()
                                .foregroundStyle(Color.primaryText)
                            Text(term.eng)
                                .font(.captionSm)
                                .italic()
                                .foregroundStyle(Color.secondaryText)
                        }
                        Text(term.def)
                            .font(.bodySm)
                            .foregroundStyle(Color.secondaryText)
                            .lineSpacing(3)
                    }
                    .padding(.vertical, 10)
                    .padding(.horizontal, 20)
                    Divider().padding(.leading, 20)
                }
            }
            .padding(.vertical, 12)
        }
        .background(Color.pageBackground.ignoresSafeArea())
        .navigationTitle("Glossary")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview { ReferenceView() }
