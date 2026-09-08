import SwiftUI

/// Vernacular names of the Mass parts (missal.part.<id>); the Latin
/// halves of the section labels are literals at the call sites.
enum MassPartName {
    static func of(_ id: String, _ en: String) -> String {
        ContentStore.shared.uiString("missal.part.\(id)", en)
    }
    static var introit: String { of("introit", "Introit") }
    static var collect: String { of("collect", "Collect") }
    static var epistle: String { of("epistle", "Epistle") }
    static var gradual: String { of("gradual", "Gradual") }
    static var alleluia: String { of("alleluia", "Alleluia") }
    static var tract: String { of("tract", "Tract") }
    static var sequence: String { of("sequence", "Sequence") }
    static var gospel: String { of("gospel", "Gospel") }
    static var offertory: String { of("offertory", "Offertory") }
    static var secret: String { of("secret", "Secret") }
    static var preface: String { of("preface", "Preface") }
    static var communion: String { of("communion", "Communion") }
    static var postcommunion: String { of("postcommunion", "Postcommunion") }
}

struct ProperView: View {
    let proper: MassProper
    /// Deep-link scroll anchor: a proper-element name ("collect", "gospel", …)
    /// or "feast" (scroll to top). nil = no scroll. Mirrors SearchExtractors.
    var initialAnchor: String? = nil
    @Environment(\.dismiss) private var dismiss
    @AppStorage(SettingsKey.theme) private var themeRaw = AppTheme.parchment.rawValue
    @AppStorage(SettingsKey.language) private var languageRaw = LanguageMode.both.rawValue
    @AppStorage(SettingsKey.fontSize) private var fontScale = FontSizeScale.defaultValue
    @State private var showShareSheet = false
    @State private var pdfURL: URL?
    private var mode: LanguageMode { LanguageMode(rawValue: languageRaw) ?? .both }
    private func sectionLabel(_ latin: String, _ english: String) -> String {
        switch mode {
        case .latinOnly: return latin
        case .vernacular: return english
        case .both: return "\(latin)\n\(english)"
        }
    }

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: true) {
                    VStack(spacing: 0) {
                        header
                            .id("feast") // "feast" anchor → scroll to top
                        VStack(alignment: .leading, spacing: 28) {
                            properSection("Introitus", subtitle: MassPartName.introit, text: proper.introit)
                                .id("introit")
                            properSection("Orátio", subtitle: MassPartName.collect, text: proper.collect)
                                .id("collect")
                            readingSection("Léctio", subtitle: MassPartName.epistle, reading: proper.epistle)
                                .id("epistle")
                        if let gradual = proper.gradual {
                            properSection("Graduále", subtitle: MassPartName.gradual, text: gradual)
                                .id("gradual")
                        }
                        if let alleluia = proper.alleluia {
                            properSection("Allelúja", subtitle: MassPartName.alleluia, text: alleluia)
                                .id("alleluia")
                        }
                        if let tract = proper.tract {
                            properSection("Tractus", subtitle: MassPartName.tract, text: tract)
                                .id("tract")
                        }
                        if let sequence = proper.sequence {
                            properSection("Sequéntia", subtitle: MassPartName.sequence, text: sequence)
                                .id("sequence")
                        }
                        readingSection("Evangélium", subtitle: MassPartName.gospel, reading: proper.gospel)
                            .id("gospel")
                        properSection("Offertórium", subtitle: MassPartName.offertory, text: proper.offertory)
                            .id("offertory")
                        properSection("Secréta", subtitle: MassPartName.secret, text: proper.secret)
                            .id("secret")
                        properSection("Commúnio", subtitle: MassPartName.communion, text: proper.communion)
                            .id("communion")
                        properSection("Postcommúnio", subtitle: MassPartName.postcommunion, text: proper.postcommunion)
                            .id("postcommunion")
                        RelatedLinksSection(related: proper.related)
                        ReferencedBySection(sources: ContentStore.shared.linkGraph.referencedBy(
                            DeepLinkTarget(type: .missal, id: proper.slug, position: nil)
                        ))
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 24)
                }
                .frame(width: geo.size.width)
                }
                .onAppear { scrollToAnchor(proxy) }
                }
            }
            .background(Color.pageBackground.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(ContentStore.shared.uiString("common.done", "Done")) { dismiss() }
                        .foregroundStyle(Color.sanctuaryRed)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            let html = MassHTMLExporter.properHTML(proper)
                            if let url = PDFExporter.writePDF(from: html, title: proper.title) {
                                pdfURL = url
                                showShareSheet = true
                            }
                        } label: {
                            Label(ContentStore.shared.uiString("share.pdf", "Share as PDF"), systemImage: "doc.richtext")
                        }
                        ShareLink(item: properAsText()) {
                            Label(ContentStore.shared.uiString("share.text", "Share as Text"), systemImage: "doc.plaintext")
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

    /// Scrolls to the deep-link anchor on appear. Anchor strings are the proper
    /// element names ("introit"…"postcommunion") or "feast" (top); they match the
    /// `.id(...)` tags above exactly. scrollTo to a missing id is a safe no-op.
    private func scrollToAnchor(_ proxy: ScrollViewProxy) {
        guard let anchor = initialAnchor else { return }
        proxy.scrollTo(anchor, anchor: .top)
    }

    private var header: some View {
        VStack(spacing: 8) {
            Text("✠  Próprium Missæ  ✠")
                .smallLabel(color: Color.goldLeaf)
                .padding(.top, 28)
            Text(proper.title)
                .appFont(.pageTitle)
                .foregroundStyle(Color.ivory)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
            Text(proper.englishTitle)
                .appFont(.caption)
                .italic()
                .foregroundStyle(Color.muted)
                .textCase(.uppercase)
                .tracking(2.5)
            if let preface = proper.preface {
                Text("Præfátio: \(preface.capitalized)")
                    .appFont(.captionSm)
                    .italic()
                    .foregroundStyle(Color.muted)
                    .padding(.top, 2)
            }
            Rectangle()
                .fill(Color.goldLeaf.opacity(0.4))
                .frame(width: 60, height: 0.5)
                .padding(.vertical, 14)
        }
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(colors: [Color.walnut, Color.walnutHi], startPoint: .top, endPoint: .bottom)
        )
    }

    private func properAsText() -> String {
        var s = ""
        s += "✠ \(proper.title.strippingEm)\n"
        s += "  \(proper.englishTitle)\n"
        s += "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n\n"

        func section(_ latin: String, english: String, label: String, ref: String? = nil) {
            s += "┌ \(label.uppercased())\n"
            if let ref, !ref.isEmpty { s += "│ \(ref)\n" }
            s += "│\n"
            for line in latin.strippingEm.components(separatedBy: "\n") where !line.isEmpty {
                s += "│  \(line)\n"
            }
            s += "│\n"
            for line in english.strippingEm.components(separatedBy: "\n") where !line.isEmpty {
                s += "│  \(line)\n"
            }
            s += "└─────\n\n"
        }

        section(proper.introit.lat, english: proper.introit.eng, label: "Introitus · \(MassPartName.introit)")
        section(proper.collect.lat, english: proper.collect.eng, label: "Orátio · \(MassPartName.collect)")
        section(proper.epistle.lat, english: proper.epistle.eng, label: "Léctio · \(MassPartName.epistle)", ref: proper.epistle.ref)
        if let g = proper.gradual { section(g.lat, english: g.eng, label: "Graduále · \(MassPartName.gradual)") }
        if let a = proper.alleluia { section(a.lat, english: a.eng, label: "Allelúja") }
        if let t = proper.tract { section(t.lat, english: t.eng, label: "Tractus · \(MassPartName.tract)") }
        if let seq = proper.sequence { section(seq.lat, english: seq.eng, label: "Sequéntia · \(MassPartName.sequence)") }
        section(proper.gospel.lat, english: proper.gospel.eng, label: "Evangélium · \(MassPartName.gospel)", ref: proper.gospel.ref)
        section(proper.offertory.lat, english: proper.offertory.eng, label: "Offertórium · \(MassPartName.offertory)")
        section(proper.secret.lat, english: proper.secret.eng, label: "Secréta · \(MassPartName.secret)")
        if let p = proper.preface { s += "Præfátio: \(p.capitalized)\n\n" }
        section(proper.communion.lat, english: proper.communion.eng, label: "Commúnio · \(MassPartName.communion)")
        section(proper.postcommunion.lat, english: proper.postcommunion.eng, label: "Postcommúnio · \(MassPartName.postcommunion)")

        s += "— Introibo (app.introibo) —"
        return s
    }

    private func properSection(_ latin: String, subtitle: String, text: ProperText) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Rectangle().fill(Color.goldLeaf.opacity(0.4)).frame(height: 0.5)
                Text(sectionLabel(latin, subtitle))
                    .smallLabel(color: Color.sanctuaryRed)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                Rectangle().fill(Color.goldLeaf.opacity(0.4)).frame(height: 0.5)
            }
            BilingualLine(lat: text.lat, eng: text.eng, sideBySide: true)
        }
    }

    private func readingSection(_ latin: String, subtitle: String, reading: ProperReading) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Rectangle().fill(Color.goldLeaf.opacity(0.4)).frame(height: 0.5)
                Text(sectionLabel(latin, subtitle))
                    .smallLabel(color: Color.sanctuaryRed)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                Rectangle().fill(Color.goldLeaf.opacity(0.4)).frame(height: 0.5)
            }
            if !reading.ref.isEmpty {
                Text(reading.ref)
                    .appFont(.captionSm)
                    .foregroundStyle(Color.goldLeaf)
            }
            BilingualLine(lat: reading.lat, eng: reading.eng, sideBySide: true)
        }
    }
}
