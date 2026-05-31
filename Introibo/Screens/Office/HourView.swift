import SwiftUI

struct HourView: View {
    let hour: Hour
    /// Deep-link scroll anchor: "part:<index>" into `hour.parts`, matching the
    /// office extractor. nil = no scroll. Mirrors SearchExtractors.hours.
    var initialAnchor: String? = nil
    @Environment(\.dismiss) private var dismiss
    @AppStorage(SettingsKey.theme) private var themeRaw = AppTheme.parchment.rawValue
    @AppStorage(SettingsKey.language) private var languageRaw = LanguageMode.both.rawValue
    @AppStorage(SettingsKey.fontSize) private var fontScale = FontSizeScale.defaultValue
    @State private var showNotification = false
    @State private var showAddToRule = false

    private var hasNotification: Bool {
        NotificationStore.schedule(for: "office.\(hour.slug)")?.isEnabled ?? false
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: true) {
                    VStack(spacing: 0) {
                        header
                        VStack(alignment: .leading, spacing: 22) {
                            intro
                            ForEach(Array(hour.parts.enumerated()), id: \.offset) { offset, part in
                                partView(part)
                                    .id("part:\(offset)")
                            }
                            RelatedLinksSection(related: hour.related)
                            ReferencedBySection(sources: ContentStore.shared.linkGraph.referencedBy(
                                DeepLinkTarget(type: .office, id: hour.slug, position: nil)
                            ))
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 24)
                    }
                }
                .onAppear { scrollToAnchor(proxy) }
            }
            .background(Color.pageBackground.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Color.sanctuaryRed)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    HStack(spacing: 16) {
                        Button { showAddToRule = true } label: {
                            Image(systemName: isInRule ? "bookmark.fill" : "bookmark")
                                .foregroundStyle(Color.sanctuaryRed)
                        }
                        Button { showNotification = true } label: {
                            Image(systemName: hasNotification ? "bell.fill" : "bell")
                                .foregroundStyle(Color.sanctuaryRed)
                        }
                        .sheet(isPresented: $showNotification) {
                            NotificationScheduleSheet(
                                scheduleId: "office.\(hour.slug)",
                                title: hour.name,
                                subtitle: "\(hour.eng) — \(hour.time)"
                            )
                        }
                    }
                }
            }
            .confirmationDialog("Add to Prayer Rule", isPresented: $showAddToRule) {
                Button("Morning") { addToRule("morning") }
                Button("Midday") { addToRule("midday") }
                Button("Evening") { addToRule("evening") }
                if isInRule {
                    Button("Remove from Rule", role: .destructive) { removeFromRule() }
                }
                Button("Cancel", role: .cancel) { }
            } message: {
                Text("Add \(hour.eng) to your prayer rule")
            }
        }
    }

    /// Scrolls to the deep-link anchor ("part:<index>") on appear. The index
    /// matches the position into `hour.parts` produced by the office extractor;
    /// scrollTo to a missing id is a safe no-op.
    private func scrollToAnchor(_ proxy: ScrollViewProxy) {
        guard let anchor = initialAnchor else { return }
        proxy.scrollTo(anchor, anchor: .top)
    }

    private var ruleSlug: String { "office-\(hour.slug)" }

    private var isInRule: Bool {
        let rule = UserProgress.prayerRule()
        return rule.allSlugs.contains(ruleSlug)
    }

    private func addToRule(_ period: String) {
        UserProgress.addToRule(ruleSlug, period: period)
    }

    private func removeFromRule() {
        UserProgress.removeFromRule(ruleSlug)
    }

    private var header: some View {
        VStack(spacing: 8) {
            Text("✠  Hora \(romanOrder())  ✠")
                .smallLabel(color: Color.goldLeaf)
                .padding(.top, 28)
            Text(hour.name)
                .font(.pageTitle)
                .foregroundStyle(Color.ivory)
            Text(hour.eng)
                .font(.caption)
                .italic()
                .foregroundStyle(Color.muted)
                .textCase(.uppercase)
                .tracking(2.5)
            Text(hour.time)
                .font(.captionSm)
                .italic()
                .foregroundStyle(Color.muted)
                .padding(.top, 2)
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

    private func romanOrder() -> String {
        let numerals = ["","I","II","III","IV","V","VI","VII","VIII"]
        return hour.order < numerals.count ? numerals[hour.order] : "\(hour.order)"
    }

    private var intro: some View {
        Text(hour.intro)
            .font(.bodyIt)
            .foregroundStyle(Color.secondaryText)
            .lineSpacing(4)
            .padding(.leading, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(
                Rectangle()
                    .fill(Color.sanctuaryRed.opacity(0.4))
                    .frame(width: 1)
                , alignment: .leading
            )
    }

    @ViewBuilder
    private func partView(_ p: Hour.Part) -> some View {
        switch p.type {
        case "vr":        vrBlock(p)
        case "hymn":      hymnBlock(p)
        case "antiphon":  simpleBlock(p, labelFallback: "Antíphona")
        case "psalm":     psalmBlock(p)
        case "capitulum": capitulumBlock(p)
        case "canticle":  psalmBlock(p)
        case "pater":     pateInlineBlock(p)
        case "collect":   simpleBlock(p, labelFallback: "Collécta")
        case "closing":   simpleBlock(p, labelFallback: "Conclúsio")
        case "confiteor": confiteorBlock(p)
        case "responsory": responsoryBlock(p)
        case "marian":    marianBlock(p)
        case "heading":   headingBlock(p)
        case "reading":   readingBlock(p)
        case "lectio":    readingBlock(p)
        case "preces":    precesBlock(p)
        case "invitatory": invitatoryBlock(p)
        case "responsory_breve": responsoryBreveBlock(p)
        case "suppressed": EmptyView()
        default: EmptyView()
        }
    }

    private func vrBlock(_ p: Hour.Part) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(p.label ?? "Versus")
                .smallLabel(color: Color.sanctuaryRed)
            if let lat = p.lat, let eng = p.eng {
                BilingualLine(lat: lat, eng: eng, sideBySide: true)
            }
            if let latR = p.latR, let engR = p.engR {
                BilingualLine(lat: latR, eng: engR, sideBySide: true)
                    .padding(.top, 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func hymnBlock(_ p: Hour.Part) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                Rectangle().fill(Color.goldLeaf.opacity(0.4)).frame(height: 0.5)
                Text(p.label ?? "Hymnus")
                    .smallLabel(color: Color.sanctuaryRed)
                    .fixedSize(horizontal: true, vertical: false)
                Rectangle().fill(Color.goldLeaf.opacity(0.4)).frame(height: 0.5)
            }
            if let title = p.title {
                Text(title)
                    .font(.titleM)
                    .italic()
                    .foregroundStyle(Color.primaryText)
            }
            if let lat = p.lat, let eng = p.eng {
                let latStanzas = lat.components(separatedBy: "\n\n")
                let engStanzas = eng.components(separatedBy: "\n\n")
                let count = max(latStanzas.count, engStanzas.count)
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(0..<count, id: \.self) { i in
                        BilingualLine(
                            lat: i < latStanzas.count ? latStanzas[i] : "",
                            eng: i < engStanzas.count ? engStanzas[i] : "",
                            sideBySide: true
                        )
                    }
                }
            }
        }
    }

    private func simpleBlock(_ p: Hour.Part, labelFallback: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(p.label ?? labelFallback)
                .smallLabel(color: Color.sanctuaryRed)
            if let ref = p.ref {
                Text(ref)
                    .font(.captionSm)
                    .foregroundStyle(Color.goldLeaf)
            }
            if let lat = p.lat, let eng = p.eng {
                BilingualLine(lat: lat, eng: eng, sideBySide: true)
            } else {
                if let lat = p.lat {
                    Text(lat.strippingEm).font(.body).foregroundStyle(Color.primaryText).lineSpacing(3)
                }
                if let eng = p.eng {
                    Text(eng.strippingEm).font(.bodySm).italic().foregroundStyle(Color.secondaryText).lineSpacing(2)
                }
            }
        }
    }

    private func psalmBlock(_ p: Hour.Part) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if let antLat = p.antiphonLat, !antLat.isEmpty {
                Text("Ant.")
                    .smallLabel(color: Color.sanctuaryRed)
                BilingualLine(
                    lat: antLat,
                    eng: p.antiphonEng ?? "",
                    sideBySide: true
                )
                .padding(.bottom, 4)
            }
            HStack(spacing: 10) {
                Rectangle().fill(Color.goldLeaf.opacity(0.4)).frame(height: 0.5)
                Text(p.label ?? "Psalmus")
                    .smallLabel(color: Color.sanctuaryRed)
                    .fixedSize(horizontal: true, vertical: false)
                if let ref = p.ref {
                    Text(ref)
                        .font(.captionSm)
                        .foregroundStyle(Color.goldLeaf)
                        .fixedSize(horizontal: true, vertical: false)
                }
                Rectangle().fill(Color.goldLeaf.opacity(0.4)).frame(height: 0.5)
            }
            if let verses = p.verses {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(Array(verses.enumerated()), id: \.offset) { _, v in
                        BilingualLine(lat: v.lat, eng: v.eng, sideBySide: true)
                    }
                }
            }
        }
    }

    private func pateInlineBlock(_ p: Hour.Part) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(p.label ?? "Pater Noster")
                .smallLabel(color: Color.sanctuaryRed)
            if let lat = p.lat, let eng = p.eng {
                let latParts = lat.components(separatedBy: "\n\n")
                let engParts = eng.components(separatedBy: "\n\n")
                let count = max(latParts.count, engParts.count)
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(0..<count, id: \.self) { i in
                        BilingualLine(
                            lat: i < latParts.count ? latParts[i] : "",
                            eng: i < engParts.count ? engParts[i] : "",
                            sideBySide: true
                        )
                    }
                }
            }
        }
    }

    private func confiteorBlock(_ p: Hour.Part) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(p.label ?? "Confíteor")
                .smallLabel(color: Color.sanctuaryRed)
            if let lat = p.lat, let eng = p.eng {
                let latParts = lat.components(separatedBy: "\n\n")
                let engParts = eng.components(separatedBy: "\n\n")
                let count = max(latParts.count, engParts.count)
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(0..<count, id: \.self) { i in
                        BilingualLine(
                            lat: i < latParts.count ? latParts[i] : "",
                            eng: i < engParts.count ? engParts[i] : "",
                            sideBySide: true
                        )
                    }
                }
            }
        }
    }

    private func responsoryBlock(_ p: Hour.Part) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(p.label ?? "Respons\u{00f3}rium")
                .smallLabel(color: Color.sanctuaryRed)
            if let ref = p.ref {
                Text(ref).font(.captionSm).foregroundStyle(Color.goldLeaf)
            }
            // Full Matins responsory (v1/r1/v2/r2 fields)
            if p.v1Lat != nil {
                if let lat = p.v1Lat, let eng = p.v1Eng {
                    responsoryLine(lat: lat, eng: eng, indent: false)
                }
                if let lat = p.r1Lat, let eng = p.r1Eng {
                    responsoryLine(lat: lat, eng: eng, indent: true)
                        .padding(.top, 4)
                }
                if let lat = p.v2Lat, let eng = p.v2Eng {
                    responsoryLine(lat: lat, eng: eng, indent: true)
                        .padding(.top, 6)
                }
                if let lat = p.r2Lat, let eng = p.r2Eng {
                    responsoryLine(lat: lat, eng: eng, indent: false)
                        .padding(.top, 4)
                }
            }
            // Short / Breve responsory (lat/eng inline with R./V. lines)
            else if let lat = p.lat, let eng = p.eng {
                let latLines = lat.components(separatedBy: "\n")
                let engLines = eng.components(separatedBy: "\n")
                let count = max(latLines.count, engLines.count)
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(0..<count, id: \.self) { i in
                        let latLine = i < latLines.count ? latLines[i] : ""
                        let engLine = i < engLines.count ? engLines[i] : ""
                        let isVersicle = latLine.hasPrefix("\u{2123}") || latLine.hasPrefix("V.")
                        responsoryLine(
                            lat: latLine,
                            eng: engLine,
                            indent: isVersicle
                        )
                    }
                }
            }
        }
    }

    /// Renders a single responsory line with optional indentation for versicles.
    private func responsoryLine(lat: String, eng: String, indent: Bool) -> some View {
        BilingualLine(lat: lat, eng: eng, sideBySide: true)
            .padding(.leading, indent ? 16 : 0)
    }

    /// Dedicated capitulum (short chapter) rendering with scripture reference
    /// displayed in italic below the label.
    private func capitulumBlock(_ p: Hour.Part) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(p.label ?? "Cap\u{00ed}tulum")
                .smallLabel(color: Color.sanctuaryRed)
            if let ref = p.ref {
                Text(ref)
                    .font(.captionSm)
                    .italic()
                    .foregroundStyle(Color.goldLeaf)
            }
            if let lat = p.lat, let eng = p.eng {
                BilingualLine(lat: lat, eng: eng, sideBySide: true)
            } else {
                if let lat = p.lat {
                    Text(lat.strippingEm).font(.body).foregroundStyle(Color.primaryText).lineSpacing(3)
                }
                if let eng = p.eng {
                    Text(eng.strippingEm).font(.bodySm).italic().foregroundStyle(Color.secondaryText).lineSpacing(2)
                }
            }
        }
    }

    /// Preces Feriales rendering. Handles three sub-formats produced by the
    /// assembler: simple lat/eng text (Kyrie, Pater Noster, Psalm), and
    /// verse-based intercession versicles.
    private func precesBlock(_ p: Hour.Part) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(p.label ?? "Preces")
                .smallLabel(color: Color.sanctuaryRed)
            if let verses = p.verses {
                // Versicle-based preces (intercessions, concluding versicles)
                VStack(alignment: .leading, spacing: 10) {
                    ForEach(Array(verses.enumerated()), id: \.offset) { _, v in
                        BilingualLine(lat: v.lat, eng: v.eng, sideBySide: true)
                    }
                }
            } else if let lat = p.lat, let eng = p.eng {
                // Prose preces (Kyrie, Pater Noster, Psalm text)
                let latParts = lat.components(separatedBy: "\n")
                let engParts = eng.components(separatedBy: "\n")
                let count = max(latParts.count, engParts.count)
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(0..<count, id: \.self) { i in
                        let latLine = i < latParts.count ? latParts[i] : ""
                        let engLine = i < engParts.count ? engParts[i] : ""
                        if !latLine.isEmpty || !engLine.isEmpty {
                            BilingualLine(lat: latLine, eng: engLine, sideBySide: true)
                        }
                    }
                }
            }
        }
    }

    /// Invitatory rendering: antiphon + Psalm 94 with the invitatory antiphon
    /// woven between psalm sections. Falls back to simpleBlock if the part
    /// lacks the expected structure.
    private func invitatoryBlock(_ p: Hour.Part) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(p.label ?? "Invitatorium")
                .smallLabel(color: Color.sanctuaryRed)
            if let lat = p.lat, let eng = p.eng {
                BilingualLine(lat: lat, eng: eng, sideBySide: true)
                    .padding(.leading, 10)
            }
            if let verses = p.verses {
                VStack(alignment: .leading, spacing: 12) {
                    ForEach(Array(verses.enumerated()), id: \.offset) { _, v in
                        BilingualLine(lat: v.lat, eng: v.eng, sideBySide: true)
                    }
                }
            }
        }
    }

    /// Short responsory (responsory_breve) at small hours. Compact R/V format
    /// with indented versicles.
    private func responsoryBreveBlock(_ p: Hour.Part) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(p.label ?? "Resp. Breve")
                .smallLabel(color: Color.sanctuaryRed)
            if let lat = p.lat, let eng = p.eng {
                let latLines = lat.components(separatedBy: "\n")
                let engLines = eng.components(separatedBy: "\n")
                let count = max(latLines.count, engLines.count)
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(0..<count, id: \.self) { i in
                        let latLine = i < latLines.count ? latLines[i] : ""
                        let engLine = i < engLines.count ? engLines[i] : ""
                        let isVersicle = latLine.hasPrefix("\u{2123}") || latLine.hasPrefix("V.")
                        BilingualLine(lat: latLine, eng: engLine, sideBySide: true)
                            .padding(.leading, isVersicle ? 16 : 0)
                    }
                }
            }
        }
    }

    private func marianBlock(_ p: Hour.Part) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                Rectangle().fill(Color.goldLeaf.opacity(0.4)).frame(height: 0.5)
                Text(p.title ?? "Antíphona Mariana")
                    .smallLabel(color: Color.sanctuaryRed)
                    .lineLimit(1)
                if let season = p.season {
                    Text("(\(season))")
                        .font(.captionSm)
                        .italic()
                        .foregroundStyle(Color.tertiaryText)
                }
                Rectangle().fill(Color.goldLeaf.opacity(0.4)).frame(height: 0.5)
            }
            if let lat = p.lat {
                let eng = p.engBody ?? p.eng ?? ""
                BilingualLine(lat: lat, eng: eng, sideBySide: true)
            }
        }
    }

    private func headingBlock(_ p: Hour.Part) -> some View {
        HStack(spacing: 10) {
            Rectangle().fill(Color.sanctuaryRed.opacity(0.3)).frame(height: 0.5)
            Text(p.label ?? "")
                .font(.titleM)
                .italic()
                .foregroundStyle(Color.sanctuaryRed)
                .lineLimit(1)
            Rectangle().fill(Color.sanctuaryRed.opacity(0.3)).frame(height: 0.5)
        }
        .padding(.top, 10)
    }

    private func readingBlock(_ p: Hour.Part) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(p.label ?? "Léctio")
                .smallLabel(color: Color.goldLeaf)
            if let ref = p.ref {
                Text(ref)
                    .font(.captionSm)
                    .foregroundStyle(Color.goldLeaf)
            }
            if let lat = p.lat, let eng = p.eng {
                BilingualLine(lat: lat, eng: eng, sideBySide: true)
            } else {
                if let lat = p.lat {
                    Text(lat.strippingEm).font(.body).foregroundStyle(Color.primaryText).lineSpacing(3)
                }
                if let eng = p.eng {
                    Text(eng.strippingEm).font(.bodySm).italic().foregroundStyle(Color.secondaryText).lineSpacing(2)
                }
            }
        }
    }
}
