import SwiftUI

// Single-prayer detail sheet. Shows:
//   - Category label (gold, uppercase, with cross markers)
//   - Title (Latin) + English subtitle in dark walnut header
//   - Optional liturgical note
//   - Line-by-line Latin and English, with a drop cap on the first Latin word

struct PrayerDetailView: View {
    let prayer: Prayer
    /// Deep-link scroll anchor. Prayers index as a whole document (extractor
    /// emits position nil), so this is always nil today; accepted for a uniform
    /// detail-view signature and no-ops. Mirrors SearchExtractors.prayers.
    var initialAnchor: String? = nil
    @Environment(\.dismiss) private var dismiss
    @AppStorage(SettingsKey.theme) private var themeRaw = AppTheme.parchment.rawValue
    @AppStorage(SettingsKey.language) private var languageRaw = LanguageMode.both.rawValue
    @AppStorage(SettingsKey.fontSize) private var fontScale = FontSizeScale.defaultValue
    @State private var showNotification = false

    private var hasNotification: Bool {
        NotificationStore.schedule(for: "prayer.\(prayer.slug)")?.isEnabled ?? false
    }

    var body: some View {
        NavigationStack {
            GeometryReader { geo in
                ScrollView(.vertical, showsIndicators: true) {
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
                        RelatedLinksSection(related: prayer.related)
                            .padding(.horizontal, 28)
                            .padding(.top, 12)
                    }
                    .padding(.bottom, 40)
                    .frame(width: geo.size.width, alignment: .leading)
                }
            }
            .background(Color.pageBackground.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Color.sanctuaryRed)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button { showNotification = true } label: {
                        Image(systemName: hasNotification ? "bell.fill" : "bell")
                            .foregroundStyle(Color.sanctuaryRed)
                    }
                }
            }
            .sheet(isPresented: $showNotification) {
                NotificationScheduleSheet(
                    scheduleId: "prayer.\(prayer.slug)",
                    title: prayer.title.strippingEm,
                    subtitle: prayer.eng
                )
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
        if isFirst && LanguageMode.current() == .both {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                dropCapText(line.lat.strippingEm)
                    .frame(maxWidth: .infinity, alignment: .leading)
                Text(line.eng.strippingEm)
                    .font(.bodySm)
                    .italic()
                    .foregroundStyle(Color.secondaryText)
                    .lineSpacing(2)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        } else if isFirst && LanguageMode.current() == .latinOnly {
            dropCapText(line.lat.strippingEm)
        } else {
            BilingualLine(lat: line.lat.strippingEm, eng: line.eng.strippingEm, sideBySide: true)
        }
    }

    @ViewBuilder
    private func dropCapText(_ lat: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 2) {
            Text(String(lat.prefix(1)))
                .font(.system(size: min(42 * FontSizeScale.current(), 60), weight: .regular, design: .serif).italic())
                .foregroundStyle(Color.sanctuaryRed)
                .baselineOffset(-4)
            Text(String(lat.dropFirst()))
                .font(.body)
                .foregroundStyle(Color.primaryText)
                .lineSpacing(3)
        }
    }
}

#Preview {
    if let p = ContentStore.shared.prayer(slug: "ave") {
        PrayerDetailView(prayer: p)
    }
}
