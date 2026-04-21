import SwiftUI

// Detail sheet for a single reference entry. Shows a dark walnut header
// with category label, Latin + English titles, then sections for summary
// (with drop cap), history, practice, notes, and scripture (if present).

struct ReferenceDetailView: View {
    let entry: ReferenceEntry
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    header
                    VStack(alignment: .leading, spacing: 22) {
                        dropCapParagraph(entry.summary)
                        if let history = entry.history { section("Historia", body: history) }
                        if let practice = entry.practice { section("Praxis", body: practice) }
                        if let notes = entry.notes { section("Notandum", body: notes) }
                        if let scripture = entry.scripture { scriptureBlock(scripture) }
                    }
                    .padding(.horizontal, 28)
                    .padding(.vertical, 24)
                }
            }
            .background(Color.pageBackground.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(.sanctuaryRed)
                }
            }
        }
    }

    private var header: some View {
        VStack(spacing: 8) {
            Text("✠  \(entry.cat)  ✠")
                .smallLabel(color: .goldLeaf)
                .padding(.top, 28)
            Text(entry.title)
                .font(.pageTitle)
                .foregroundStyle(.ivory)
                .multilineTextAlignment(.center)
            if let latin = entry.latin {
                Text(latin)
                    .font(.caption)
                    .italic()
                    .foregroundStyle(.muted)
                    .textCase(.uppercase)
                    .tracking(2.5)
            }
            Rectangle()
                .fill(Color.goldLeaf.opacity(0.4))
                .frame(width: 60, height: 0.5)
                .padding(.vertical, 14)
        }
        .frame(maxWidth: .infinity)
        .background(
            LinearGradient(colors: [.walnut, .walnutHi], startPoint: .top, endPoint: .bottom)
        )
    }

    private func dropCapParagraph(_ text: String) -> some View {
        let stripped = text.strippingEm
        return Text(stripped)
            .font(.body)
            .foregroundStyle(.primaryText)
            .lineSpacing(4)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func section(_ title: String, body: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .smallLabel(color: .sanctuaryRed)
            Text(body.strippingEm)
                .font(.bodySm)
                .foregroundStyle(.secondaryText)
                .lineSpacing(3)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func scriptureBlock(_ s: ReferenceEntry.Scripture) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Scriptura  ·  \(s.ref)")
                .smallLabel(color: .sanctuaryRed)
            Text(s.lat)
                .font(.bodyIt)
                .foregroundStyle(.primaryText)
            Text(s.eng)
                .font(.captionSm)
                .italic()
                .foregroundStyle(.secondaryText)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(Rectangle().stroke(Color.frameLine, lineWidth: 0.5))
    }
}
