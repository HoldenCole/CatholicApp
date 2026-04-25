import SwiftUI

struct ReferenceView: View {
    @State private var store = ContentStore.shared
    @State private var selection: ReferenceEntry?
    @AppStorage(SettingsKey.theme) private var themeRaw = AppTheme.parchment.rawValue

    var body: some View {
        NavigationStack {
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
                .padding(.horizontal, 28)
                .padding(.top, 24)
                .padding(.bottom, 40)
            }
            .background(Color.pageBackground.ignoresSafeArea())
            .navigationTitle("Líber Referentiárum")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(item: $selection) { ReferenceDetailView(entry: $0) }
        }
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
                .fixedSize()
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

#Preview { ReferenceView() }
