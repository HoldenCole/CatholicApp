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
                    ShareLink(item: properAsText()) {
                        Image(systemName: "square.and.arrow.up")
                            .foregroundStyle(Color.sanctuaryRed)
                    }
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
            Text(proper.english)
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
        var lines: [String] = []
        lines.append(proper.title)
        lines.append(proper.english)
        lines.append("")

        func addSection(_ label: String, lat: String, eng: String) {
            lines.append("— \(label) —")
            lines.append(lat)
            lines.append(eng)
            lines.append("")
        }

        func addReading(_ label: String, ref: String, lat: String, eng: String) {
            lines.append("— \(label) —")
            if !ref.isEmpty { lines.append(ref) }
            lines.append(lat)
            lines.append(eng)
            lines.append("")
        }

        addSection("Introitus", lat: proper.introit.lat, eng: proper.introit.eng)
        addSection("Oratio", lat: proper.collect.lat, eng: proper.collect.eng)
        addReading("Lectio", ref: proper.epistle.ref, lat: proper.epistle.lat, eng: proper.epistle.eng)
        if let g = proper.gradual { addSection("Graduale", lat: g.lat, eng: g.eng) }
        if let a = proper.alleluia { addSection("Alleluia", lat: a.lat, eng: a.eng) }
        if let t = proper.tract { addSection("Tractus", lat: t.lat, eng: t.eng) }
        if let s = proper.sequence { addSection("Sequentia", lat: s.lat, eng: s.eng) }
        addReading("Evangelium", ref: proper.gospel.ref, lat: proper.gospel.lat, eng: proper.gospel.eng)
        addSection("Offertorium", lat: proper.offertory.lat, eng: proper.offertory.eng)
        addSection("Secreta", lat: proper.secret.lat, eng: proper.secret.eng)
        if let p = proper.preface { lines.append("Preface: \(p.capitalized)"); lines.append("") }
        addSection("Communio", lat: proper.communion.lat, eng: proper.communion.eng)
        addSection("Postcommunio", lat: proper.postcommunion.lat, eng: proper.postcommunion.eng)

        return lines.joined(separator: "\n")
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
