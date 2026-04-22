import SwiftUI

// The Orátio tab — Liber Orationum.
// Top: "Oratio Hodierna" featured prayer of the day.
// Below: the full 21-prayer library, grouped by category.

struct PrayersView: View {
    @State private var store = ContentStore.shared
    @State private var selection: Prayer?

    private var ctx: LiturgicalContext { .current() }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    featuredCard
                    ForEach(store.prayersByCategory(), id: \.category) { group in
                        categorySection(group.category, items: group.items)
                    }
                }
                .padding(.horizontal, 28)
                .padding(.top, 24)
                .padding(.bottom, 40)
            }
            .background(Color.pageBackground.ignoresSafeArea())
            .navigationTitle("Líber Orationum")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(item: $selection) { p in
                PrayerDetailView(prayer: p)
            }
        }
    }

    // MARK: - Sections

    @ViewBuilder
    private var featuredCard: some View {
        if let featured = store.prayer(slug: DailyPrayer.slug(for: ctx)) {
            Button { selection = featured } label: {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Oratio Hodiérna  ·  Today's Prayer")
                        .smallLabel(color: Color.goldLeaf)
                    Text(String(featured.title.prefix(1)))
                        .font(.custom("Georgia", size: 54).italic())
                        .foregroundStyle(Color.sanctuaryRed)
                    Text(featured.title.strippingEm)
                        .font(.titleXL)
                        .italic()
                        .foregroundStyle(Color.primaryText)
                    Text(featured.eng)
                        .font(.captionSm)
                        .italic()
                        .foregroundStyle(Color.secondaryText)
                    Text(previewLine(featured))
                        .font(.bodyIt)
                        .foregroundStyle(Color.secondaryText)
                        .lineLimit(1)
                        .padding(.top, 4)
                    HStack {
                        Spacer()
                        Text("Aperi  ✠  Open")
                            .smallLabel(color: Color.sanctuaryRed)
                    }
                    .padding(.top, 4)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
                .overlay(
                    Rectangle().stroke(Color.frameLine, lineWidth: 0.5)
                )
            }
            .buttonStyle(.plain)
        }
    }

    private func categorySection(_ category: String, items: [Prayer]) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            categoryHeader(category)
            ForEach(items) { p in
                Button { selection = p } label: { prayerRow(p) }
                    .buttonStyle(.plain)
                if p.slug != items.last?.slug {
                    Divider().background(Color.frameLine)
                }
            }
        }
    }

    private func categoryHeader(_ category: String) -> some View {
        HStack(spacing: 10) {
            Rectangle().fill(Color.goldLeaf.opacity(0.4)).frame(height: 0.5)
            Text(category)
                .font(.caption)
                .italic()
                .foregroundStyle(Color.sanctuaryRed)
                .textCase(.uppercase)
                .tracking(3)
                .fixedSize()
            Rectangle().fill(Color.goldLeaf.opacity(0.4)).frame(height: 0.5)
        }
    }

    private func prayerRow(_ p: Prayer) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 14) {
            Text(String(p.title.strippingEm.prefix(1)))
                .font(.titleL)
                .italic()
                .foregroundStyle(Color.sanctuaryRed)
                .frame(width: 22, alignment: .leading)
            VStack(alignment: .leading, spacing: 2) {
                Text(p.title.strippingEm)
                    .font(.titleM)
                    .italic()
                    .foregroundStyle(Color.primaryText)
                Text(p.eng)
                    .font(.captionSm)
                    .italic()
                    .foregroundStyle(Color.secondaryText)
            }
            Spacer()
            if p.note?.lowercased().contains("daily") ?? false {
                Text("Daily")
                    .smallLabel(color: Color.goldLeaf, tracking: 2)
            }
        }
        .contentShape(Rectangle())
    }

    private func previewLine(_ p: Prayer) -> String {
        let first = p.lines.first?.lat.strippingEm ?? ""
        if first.count <= 48 { return first + "…" }
        let cut = String(first.prefix(46))
        // Break at last whitespace so we don't split a word.
        if let idx = cut.lastIndex(of: " ") {
            return String(cut[..<idx]) + "…"
        }
        return cut + "…"
    }
}

#Preview {
    PrayersView()
}
