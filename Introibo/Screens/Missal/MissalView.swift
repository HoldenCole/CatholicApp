import SwiftUI

// The Missa tab — the Ordinary of the Mass. Mirrors prototype/missal.html.
// Shows all 13 sections in order, each with a section label, Latin +
// English title, and line-by-line Latin/English text.

struct MissalView: View {
    @State private var store = ContentStore.shared
    @AppStorage(SettingsKey.rite) private var riteRaw = MissalRite.rite1962.rawValue
    @AppStorage(SettingsKey.theme) private var themeRaw = AppTheme.parchment.rawValue
    @AppStorage(SettingsKey.language) private var languageRaw = LanguageMode.both.rawValue
    @AppStorage(SettingsKey.fontSize) private var fontSizeRaw = FontSizeOption.medium.rawValue

    private var rite: MissalRite { MissalRite(rawValue: riteRaw) ?? .rite1962 }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    ForEach(store.missal) { section in
                        sectionBlock(section)
                    }
                }
                .padding(.horizontal, 28)
                .padding(.top, 24)
                .padding(.bottom, 40)
            }
            .background(Color.pageBackground.ignoresSafeArea())
            .navigationTitle("Ordo Missæ")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    VStack(spacing: 2) {
                        Text("Ordo Missæ")
                            .font(.titleM)
                            .italic()
                            .foregroundStyle(.primaryText)
                        Text(rite.short)
                            .smallLabel(color: .goldLeaf, tracking: 2)
                    }
                }
            }
        }
    }

    private func sectionBlock(_ section: MissalSection) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if let label = section.label {
                HStack(spacing: 10) {
                    Rectangle().fill(Color.goldLeaf.opacity(0.4)).frame(height: 0.5)
                    Text(label)
                        .smallLabel(color: .sanctuaryRed)
                        .fixedSize()
                    Rectangle().fill(Color.goldLeaf.opacity(0.4)).frame(height: 0.5)
                }
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(section.title)
                    .font(.titleL)
                    .italic()
                    .foregroundStyle(.primaryText)
                if let english = section.english {
                    Text(english)
                        .font(.captionSm)
                        .italic()
                        .foregroundStyle(.secondaryText)
                }
            }

            VStack(alignment: .leading, spacing: 16) {
                ForEach(Array(section.body.enumerated()), id: \.offset) { _, line in
                    BilingualLine(lat: line.lat.strippingEm, eng: line.eng.strippingEm, sideBySide: true)
                }
            }
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview { MissalView() }
