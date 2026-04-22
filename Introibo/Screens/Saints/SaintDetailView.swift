import SwiftUI

// Saint detail sheet. Shows name, title, quote, charism, and the daily
// practice schedule (Morning / Throughout Day / Evening) with a
// follow/unfollow button and streak counter. Mirrors the overlay
// from prototype/saints.html.

struct SaintDetailView: View {
    let saint: Saint
    @Environment(\.dismiss) private var dismiss
    @AppStorage(ProgressKey.followedSaint) private var followedSlug: String = ""
    @State private var streak: Int = 0

    private var isFollowed: Bool { followedSlug == saint.slug }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    header
                    VStack(alignment: .leading, spacing: 24) {
                        quoteBlock
                        followButton
                        ForEach(Array(saint.sections.enumerated()), id: \.offset) { _, section in
                            sectionBlock(section)
                        }
                    }
                    .padding(.horizontal, 28)
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
            .onAppear { streak = UserProgress.saintStreak(slug: saint.slug) }
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 8) {
            Text("✠  Praxes Sanctórum  ✠")
                .smallLabel(color: Color.goldLeaf)
                .padding(.top, 28)
            Text(saint.name)
                .font(.pageTitle)
                .foregroundStyle(Color.ivory)
                .multilineTextAlignment(.center)
            Text(saint.title)
                .font(.caption)
                .italic()
                .foregroundStyle(Color.muted)
                .textCase(.uppercase)
                .tracking(2.5)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 28)
            if isFollowed && streak > 0 {
                HStack(spacing: 6) {
                    ForEach(0..<min(streak, 7), id: \.self) { _ in
                        Circle().fill(Color.goldLeaf).frame(width: 6, height: 6)
                    }
                    if streak > 7 {
                        Text("+ \(streak - 7)")
                            .font(.captionSm)
                            .foregroundStyle(Color.goldLeaf)
                    }
                }
                .padding(.top, 6)
            }
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

    // MARK: - Quote

    private var quoteBlock: some View {
        Text("\u{201C}\(saint.quote)\u{201D}")
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

    // MARK: - Follow button

    private var followButton: some View {
        Button {
            if isFollowed {
                followedSlug = ""
            } else {
                followedSlug = saint.slug
                UserProgress.bumpSaintStreak(slug: saint.slug)
                streak = UserProgress.saintStreak(slug: saint.slug)
            }
        } label: {
            Text(isFollowed ? "Unfollow" : "Follow this Saint")
                .smallLabel(color: isFollowed ? Color.secondaryText : Color.sanctuaryRed, tracking: 3)
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity)
                .overlay(Rectangle().stroke(
                    isFollowed ? Color.secondaryText.opacity(0.4) : Color.sanctuaryRed.opacity(0.6),
                    lineWidth: 0.5
                ))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Section

    private func sectionBlock(_ section: Saint.Section) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Rectangle().fill(Color.goldLeaf.opacity(0.3)).frame(height: 0.5)
                Text(section.lat)
                    .font(.caption)
                    .italic()
                    .foregroundStyle(Color.sanctuaryRed)
                    .textCase(.uppercase)
                    .tracking(3)
                    .fixedSize()
                Text("·")
                    .foregroundStyle(Color.tertiaryText)
                Text(section.eng)
                    .font(.captionSm)
                    .italic()
                    .foregroundStyle(Color.secondaryText)
                    .fixedSize()
                Rectangle().fill(Color.goldLeaf.opacity(0.3)).frame(height: 0.5)
            }

            ForEach(Array(section.practices.enumerated()), id: \.offset) { idx, p in
                VStack(alignment: .leading, spacing: 2) {
                    Text(p.t)
                        .font(.titleM)
                        .italic()
                        .foregroundStyle(Color.primaryText)
                    Text(p.d)
                        .font(.bodySm)
                        .foregroundStyle(Color.secondaryText)
                        .lineSpacing(3)
                }
                .padding(.vertical, 4)
                if idx < section.practices.count - 1 {
                    Divider().background(Color.frameLine.opacity(0.5))
                }
            }
        }
    }
}
