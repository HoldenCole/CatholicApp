import SwiftUI

struct HourView: View {
    let hour: Hour
    @Environment(\.dismiss) private var dismiss
    @AppStorage(SettingsKey.theme) private var themeRaw = AppTheme.parchment.rawValue
    @AppStorage(SettingsKey.language) private var languageRaw = LanguageMode.both.rawValue
    @AppStorage(SettingsKey.fontSize) private var fontScale = FontSizeScale.defaultValue

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    header
                    VStack(alignment: .leading, spacing: 22) {
                        intro
                        ForEach(Array(hour.parts.enumerated()), id: \.offset) { _, part in
                            partView(part)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 24)
                }
            }
            .background(Color.pageBackground.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Color.sanctuaryRed)
                }
            }
        }
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
        ["","I","II","III","IV","V","VI","VII","VIII"][hour.order]
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
        case "capitulum": simpleBlock(p, labelFallback: "Capítulum")
        case "canticle":  psalmBlock(p)
        case "pater":     pateInlineBlock(p)
        case "collect":   simpleBlock(p, labelFallback: "Collécta")
        case "closing":   simpleBlock(p, labelFallback: "Conclúsio")
        case "confiteor": confiteorBlock(p)
        case "responsory": responsoryBlock(p)
        case "marian":    marianBlock(p)
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
                    .fixedSize()
                Rectangle().fill(Color.goldLeaf.opacity(0.4)).frame(height: 0.5)
            }
            if let title = p.title {
                Text(title)
                    .font(.titleM)
                    .italic()
                    .foregroundStyle(Color.primaryText)
            }
            if let lat = p.lat, let eng = p.eng {
                BilingualLine(lat: lat, eng: eng, sideBySide: true)
            } else {
                if let lat = p.lat {
                    Text(lat).font(.body).foregroundStyle(Color.primaryText).lineSpacing(3)
                }
                if let eng = p.eng {
                    Text(eng).font(.bodySm).italic().foregroundStyle(Color.secondaryText).lineSpacing(2)
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
                    Text(lat).font(.body).foregroundStyle(Color.primaryText).lineSpacing(3)
                }
                if let eng = p.eng {
                    Text(eng).font(.bodySm).italic().foregroundStyle(Color.secondaryText).lineSpacing(2)
                }
            }
        }
    }

    private func psalmBlock(_ p: Hour.Part) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 10) {
                Rectangle().fill(Color.goldLeaf.opacity(0.4)).frame(height: 0.5)
                Text(p.label ?? "Psalmus")
                    .smallLabel(color: Color.sanctuaryRed)
                    .fixedSize()
                if let ref = p.ref {
                    Text(ref)
                        .font(.captionSm)
                        .foregroundStyle(Color.goldLeaf)
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
        HStack {
            Text("Pater Noster")
                .smallLabel(color: Color.sanctuaryRed)
            Spacer()
            Text("silently")
                .font(.captionSm)
                .italic()
                .foregroundStyle(Color.tertiaryText)
        }
    }

    private func confiteorBlock(_ p: Hour.Part) -> some View {
        HStack {
            Text(p.label ?? "Confíteor")
                .smallLabel(color: Color.sanctuaryRed)
            Spacer()
            Text("In the customary form")
                .font(.captionSm)
                .italic()
                .foregroundStyle(Color.tertiaryText)
        }
    }

    private func responsoryBlock(_ p: Hour.Part) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(p.label ?? "Respónsum")
                .smallLabel(color: Color.sanctuaryRed)
            if let ref = p.ref {
                Text(ref).font(.captionSm).foregroundStyle(Color.goldLeaf)
            }
            if let lat = p.v1Lat, let eng = p.v1Eng {
                BilingualLine(lat: lat, eng: eng, sideBySide: true)
            }
            if let lat = p.r1Lat, let eng = p.r1Eng {
                BilingualLine(lat: lat, eng: eng, sideBySide: true)
                    .padding(.top, 4)
            }
            if let lat = p.v2Lat, let eng = p.v2Eng {
                BilingualLine(lat: lat, eng: eng, sideBySide: true)
                    .padding(.top, 6)
            }
            if let lat = p.r2Lat, let eng = p.r2Eng {
                BilingualLine(lat: lat, eng: eng, sideBySide: true)
                    .padding(.top, 4)
            }
        }
    }

    private func marianBlock(_ p: Hour.Part) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                Rectangle().fill(Color.goldLeaf.opacity(0.4)).frame(height: 0.5)
                Text(p.title ?? "Antíphona Mariana")
                    .smallLabel(color: Color.sanctuaryRed)
                    .fixedSize()
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
}
