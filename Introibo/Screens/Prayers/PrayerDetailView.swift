import SwiftUI

// Single-prayer detail sheet. Shows:
//   - Category label (gold, uppercase, with cross markers)
//   - Title (Latin) + English subtitle in dark walnut header
//   - Optional liturgical note
//   - Line-by-line Latin and English, with a drop cap on the first Latin word

struct PrayerDetailView: View {
    let prayer: Prayer
    @Environment(\.dismiss) private var dismiss
    @AppStorage(SettingsKey.theme) private var themeRaw = AppTheme.parchment.rawValue
    @AppStorage(SettingsKey.language) private var languageRaw = LanguageMode.both.rawValue
    @AppStorage(SettingsKey.fontSize) private var fontSizeRaw = FontSizeOption.medium.rawValue

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    header
                    if let note = prayer.note, !note.isEmpty {
                        Text(note.strippingEm)
                            .font(.bodyIt)
                            .foregroundStyle(Color.secondaryText)
                            .padding(.horizontal, 28)
                            .padding(.bottom, 4)
                    }
                    ForEach(Array(prayer.lines.enumerated()), id: \.offset) { idx, line in
                        lineBlock(line, isFirst: idx == 0)
                            .padding(.horizontal, 28)
                    }
                }
                .padding(.bottom, 40)
                .frame(maxWidth: .infinity, alignment: .leading)
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

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 10) {
            Text("✠  \(prayer.category)  ✠")
                .smallLabel(color: Color.goldLeaf)
                .padding(.top, 28)
            Text(prayer.title.strippingEm)
                .font(.pageTitle)
                .foregroundStyle(Color.ivory)
                .multilineTextAlignment(.center)
            Text(prayer.eng)
                .font(.caption)
                .italic()
                .foregroundStyle(Color.muted)
                .textCase(.uppercase)
                .tracking(2.5)
            Rectangle()
                .fill(Color.goldLeaf.opacity(0.4))
                .frame(width: 60, height: 0.5)
                .padding(.top, 4)
                .padding(.bottom, 18)
        }
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(
                colors: [Color.walnut, Color.walnutHi],
                startPoint: .top, endPoint: .bottom
            )
        )
    }

    // MARK: - Line block

    @ViewBuilder
    private func lineBlock(_ line: Prayer.Line, isFirst: Bool) -> some View {
        if isFirst {
            VStack(alignment: .leading, spacing: 4) {
                latinText(line.lat.strippingEm)
                if LanguageMode.current() != .latinOnly {
                    Text(line.eng.strippingEm)
                        .font(.bodySm)
                        .italic()
                        .foregroundStyle(Color.secondaryText)
                }
            }
        } else {
            BilingualLine(lat: line.lat.strippingEm, eng: line.eng.strippingEm, sideBySide: true)
        }
    }

    @ViewBuilder
    private func latinText(_ lat: String) -> some View {
        let mode = LanguageMode.current()
        if mode != .vernacular, let first = lat.first {
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(String(first))
                    .font(.custom("Georgia", size: 48).italic())
                    .foregroundStyle(Color.sanctuaryRed)
                    .baselineOffset(-6)
                Text(String(lat.dropFirst()))
                    .font(.body)
                    .foregroundStyle(Color.primaryText)
            }
        }
    }
}

#Preview {
    if let p = ContentStore.shared.prayer(slug: "ave") {
        PrayerDetailView(prayer: p)
    }
}
