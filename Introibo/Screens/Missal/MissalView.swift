import SwiftUI

struct MissalView: View {
    @State private var store = ContentStore.shared
    @State private var selectedProper: MassProper?
    @AppStorage(SettingsKey.rite) private var riteRaw = MissalRite.rite1962.rawValue
    @AppStorage(SettingsKey.theme) private var themeRaw = AppTheme.parchment.rawValue
    @AppStorage(SettingsKey.language) private var languageRaw = LanguageMode.both.rawValue
    @AppStorage(SettingsKey.fontSize) private var fontScale = FontSizeScale.defaultValue

    private var rite: MissalRite { MissalRite(rawValue: riteRaw) ?? .rite1962 }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    if !store.propers.isEmpty {
                        propersCard
                    }

                    ordinaryHeader

                    ForEach(store.missal) { section in
                        sectionBlock(section)
                    }
                }
                .padding(.horizontal, 20)
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
                            .foregroundStyle(Color.primaryText)
                        Text(rite.short)
                            .smallLabel(color: Color.goldLeaf, tracking: 2)
                    }
                }
            }
            .sheet(item: $selectedProper) { proper in
                ProperView(proper: proper)
            }
        }
    }

    // MARK: - Propers card

    private var propersCard: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Rectangle().fill(Color.sanctuaryRed.opacity(0.4)).frame(height: 1)
                Text("Próprium")
                    .font(.titleM)
                    .italic()
                    .foregroundStyle(Color.sanctuaryRed)
                    .textCase(.uppercase)
                    .tracking(2)
                    .fixedSize()
                Text("·")
                    .foregroundStyle(Color.tertiaryText)
                Text("Propers")
                    .font(.captionSm)
                    .italic()
                    .foregroundStyle(Color.secondaryText)
                    .fixedSize()
                Rectangle().fill(Color.sanctuaryRed.opacity(0.4)).frame(height: 1)
            }

            ForEach(store.propers) { proper in
                Button { selectedProper = proper } label: {
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text(proper.title)
                                .font(.titleM)
                                .italic()
                                .foregroundStyle(Color.primaryText)
                            Text(proper.english)
                                .font(.captionSm)
                                .italic()
                                .foregroundStyle(Color.secondaryText)
                        }
                        Spacer()
                        Text("›")
                            .font(.titleL)
                            .foregroundStyle(Color.goldLeaf.opacity(0.5))
                    }
                    .padding(.vertical, 6)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                if proper.slug != store.propers.last?.slug {
                    Divider().background(Color.frameLine)
                }
            }
        }
    }

    // MARK: - Ordinary header

    private var ordinaryHeader: some View {
        HStack(spacing: 10) {
            Rectangle().fill(Color.sanctuaryRed.opacity(0.4)).frame(height: 1)
            Text("Ordinárium")
                .font(.titleM)
                .italic()
                .foregroundStyle(Color.sanctuaryRed)
                .textCase(.uppercase)
                .tracking(2)
                .fixedSize()
            Text("·")
                .foregroundStyle(Color.tertiaryText)
            Text("Ordinary")
                .font(.captionSm)
                .italic()
                .foregroundStyle(Color.secondaryText)
                .fixedSize()
            Rectangle().fill(Color.sanctuaryRed.opacity(0.4)).frame(height: 1)
        }
    }

    // MARK: - Ordinary sections

    private func sectionBlock(_ section: MissalSection) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if let label = section.label {
                HStack(spacing: 10) {
                    Rectangle().fill(Color.goldLeaf.opacity(0.4)).frame(height: 0.5)
                    Text(label)
                        .smallLabel(color: Color.sanctuaryRed)
                        .fixedSize()
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
                    BilingualLine(lat: line.lat.strippingEm, eng: line.eng.strippingEm, sideBySide: true)
                }
            }
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#Preview { MissalView() }
