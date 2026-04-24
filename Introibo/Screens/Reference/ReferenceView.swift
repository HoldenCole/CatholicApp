import SwiftUI

// The Liber tab — Liber Referentiarum. Browse 37 entries across 7
// categories. Mirrors prototype/reference.html.

struct ReferenceView: View {
    @State private var store = ContentStore.shared
    @State private var selection: ReferenceEntry?

    var body: some View {
        NavigationStack {
            List {
                ForEach(groupedByCategory(), id: \.category) { group in
                    Section(header: Text(group.category)) {
                        ForEach(group.items) { entry in
                            Button { selection = entry } label: {
                                row(entry)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .background(Color.pageBackground.ignoresSafeArea())
            .navigationTitle("Líber Referentiárum")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(item: $selection) { ReferenceDetailView(entry: $0) }
        }
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
