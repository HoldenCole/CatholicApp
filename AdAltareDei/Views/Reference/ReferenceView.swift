import SwiftUI

struct ReferenceView: View {
    @State private var entries: [ReferenceEntry] = []
    @State private var searchText = ""

    private var groupedEntries: [(ReferenceCategory, [ReferenceEntry])] {
        let filtered = searchText.isEmpty ? entries : entries.filter {
            $0.title.localizedCaseInsensitiveContains(searchText) ||
            $0.latinTitle.localizedCaseInsensitiveContains(searchText) ||
            $0.summary.localizedCaseInsensitiveContains(searchText)
        }
        let grouped = Dictionary(grouping: filtered) { $0.category }
        return ReferenceCategory.allCases.compactMap { cat in
            guard let items = grouped[cat], !items.isEmpty else { return nil }
            return (cat, items.sorted { $0.sortOrder < $1.sortOrder })
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    ForEach(groupedEntries, id: \.0) { category, items in
                        VStack(alignment: .leading, spacing: 0) {
                            // Section header
                            HStack(spacing: 10) {
                                Image(systemName: category.icon)
                                    .font(.system(size: 14))
                                    .foregroundStyle(.sanctuaryRed)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(category.displayName.uppercased())
                                        .font(.custom("Palatino-Italic", size: 12).weight(.semibold))
                                        .foregroundStyle(.sanctuaryRed)
                                        .tracking(3)
                                    Text(category.latinName)
                                        .font(.custom("Palatino-Italic", size: 13))
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .padding(.bottom, 12)

                            // Items
                            ForEach(items) { entry in
                                NavigationLink {
                                    ReferenceDetailView(entry: entry)
                                } label: {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(entry.title)
                                            .font(.custom("Palatino", size: 17).weight(.medium))
                                            .foregroundStyle(.ink)
                                        Text(entry.latinTitle)
                                            .font(.custom("Palatino-Italic", size: 13))
                                            .foregroundStyle(.goldLeaf)
                                        Text(entry.summary)
                                            .font(.custom("Georgia", size: 13))
                                            .foregroundStyle(.secondary)
                                            .lineLimit(2)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.vertical, 12)
                                    .overlay(alignment: .bottom) {
                                        Rectangle()
                                            .fill(Color.goldLeaf.opacity(0.08))
                                            .frame(height: 1)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 16)
            }
            .background(Color.parchment)
            .navigationTitle("Reference")
            .searchable(text: $searchText, prompt: "Search...")
            .onAppear { loadEntries() }
        }
    }

    private func loadEntries() {
        let files = ["reference_prayers", "reference_mass", "reference_devotions", "reference_penance", "reference_calendar", "reference_latin"]
        var all: [ReferenceEntry] = []
        for file in files {
            if let url = Bundle.main.url(forResource: file, withExtension: "json"),
               let data = try? Data(contentsOf: url),
               let decoded = try? JSONDecoder().decode([ReferenceEntry].self, from: data) {
                all.append(contentsOf: decoded)
            }
        }
        entries = all
    }
}

#Preview {
    ReferenceView()
}
