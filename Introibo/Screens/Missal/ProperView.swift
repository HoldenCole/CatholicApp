import SwiftUI

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
    @AppStorage(SettingsKey.fontSize) private var fontScale = FontSizeScale.defaultValue
    private var mode: LanguageMode { LanguageMode(rawValue: languageRaw) ?? .both }
    private func sectionLabel(_ latin: String, _ english: String) -> String {
        switch mode {
        case .latinOnly: return latin
        case .vernacular: return english
        case .both: return "\(latin)  \u{00B7}  \(english)"
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
                            properSection("Introitus", subtitle: "Introit", text: proper.introit)
                                .id("introit")
                            properSection("Orátio", subtitle: "Collect", text: proper.collect)
                                .id("collect")
                            readingSection("Léctio", subtitle: "Epistle", reading: proper.epistle)
                                .id("epistle")
                        if let gradual = proper.gradual {
                            properSection("Graduále", subtitle: "Gradual", text: gradual)
                                .id("gradual")
                        }
                        if let alleluia = proper.alleluia {
                            properSection("Allelúja", subtitle: "Alleluia", text: alleluia)
                                .id("alleluia")
                        }
                        if let tract = proper.tract {
                            properSection("Tractus", subtitle: "Tract", text: tract)
                                .id("tract")
                        }
                        if let sequence = proper.sequence {
                            properSection("Sequéntia", subtitle: "Sequence", text: sequence)
                                .id("sequence")
                        }
                        readingSection("Evangélium", subtitle: "Gospel", reading: proper.gospel)
                            .id("gospel")
                        properSection("Offertórium", subtitle: "Offertory", text: proper.offertory)
                            .id("offertory")
                        properSection("Secréta", subtitle: "Secret", text: proper.secret)
                            .id("secret")
                        properSection("Commúnio", subtitle: "Communion", text: proper.communion)
                            .id("communion")
                        properSection("Postcommúnio", subtitle: "Postcommunion", text: proper.postcommunion)
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
                    Button("Done") { dismiss() }
                        .foregroundStyle(Color.sanctuaryRed)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button {
                            let html = MassHTMLExporter.properHTML(proper)
                            if let data = PDFExporter.generatePDF(from: html) {
                                let url = FileManager.default.temporaryDirectory
                                    .appendingPathComponent("Introibo-Proper.pdf")
                                try? data.write(to: url)
                                pdfURL = url
                                showShareSheet = true
                            }
                        } label: {
                            Label("Share as PDF", systemImage: "doc.richtext")
                        }
                        ShareLink(item: properAsText()) {
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
                .font(.pageTitle)
                .foregroundStyle(Color.ivory)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
            Text(proper.englishTitle)
                .font(.caption)
                .italic()
                .foregroundStyle(Color.muted)
                .textCase(.uppercase)
                .tracking(2.5)
            if let preface = proper.preface {
                Text("Præfátio: \(preface.capitalized)")
                    .font(.captionSm)
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

        section(proper.introit.lat, english: proper.introit.eng, label: "Introitus · Introit")
        section(proper.collect.lat, english: proper.collect.eng, label: "Orátio · Collect")
        section(proper.epistle.lat, english: proper.epistle.eng, label: "Léctio · Epistle", ref: proper.epistle.ref)
        if let g = proper.gradual { section(g.lat, english: g.eng, label: "Graduále · Gradual") }
        if let a = proper.alleluia { section(a.lat, english: a.eng, label: "Allelúja") }
        if let t = proper.tract { section(t.lat, english: t.eng, label: "Tractus · Tract") }
        if let seq = proper.sequence { section(seq.lat, english: seq.eng, label: "Sequéntia · Sequence") }
        section(proper.gospel.lat, english: proper.gospel.eng, label: "Evangélium · Gospel", ref: proper.gospel.ref)
        section(proper.offertory.lat, english: proper.offertory.eng, label: "Offertórium · Offertory")
        section(proper.secret.lat, english: proper.secret.eng, label: "Secréta · Secret")
        if let p = proper.preface { s += "Præfátio: \(p.capitalized)\n\n" }
        section(proper.communion.lat, english: proper.communion.eng, label: "Commúnio · Communion")
        section(proper.postcommunion.lat, english: proper.postcommunion.eng, label: "Postcommúnio · Postcommunion")

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
                    .font(.captionSm)
                    .foregroundStyle(Color.goldLeaf)
            }
            BilingualLine(lat: reading.lat, eng: reading.eng, sideBySide: true)
        }
    }
}
