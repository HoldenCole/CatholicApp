import SwiftUI

// Saints browser. Shows all 7 saints as cards; user can tap to open
// the detail view with practice schedule, or follow/unfollow. Mirrors
// prototype/saints.html.

struct SaintsView: View {
    @State private var store = ContentStore.shared
    @State private var selection: Saint?
    @AppStorage(ProgressKey.followedSaint) private var followedSlug: String = ""

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    ForEach(store.saints) { saint in
                        Button { selection = saint } label: {
                            saintCard(saint)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 28)
                .padding(.vertical, 24)
            }
            .background(Color.pageBackground.ignoresSafeArea())
            .navigationTitle("Praxes Sanctórum")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(item: $selection) { SaintDetailView(saint: $0) }
        }
    }

    private func saintCard(_ saint: Saint) -> some View {
        let isFollowed = saint.slug == followedSlug
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(saint.name)
                    .font(.titleL)
                    .italic()
                    .foregroundStyle(.primaryText)
                Spacer()
                if isFollowed {
                    Text("Following")
                        .smallLabel(color: .goldLeaf, tracking: 2)
                }
            }
            Text(saint.title)
                .font(.captionSm)
                .italic()
                .foregroundStyle(.secondaryText)
            Text(saint.quote)
                .font(.bodyIt)
                .foregroundStyle(.tertiaryText)
                .lineSpacing(3)
                .padding(.top, 4)
                .lineLimit(3)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(Rectangle().stroke(Color.frameLine, lineWidth: 0.5))
    }
}

#Preview { SaintsView() }
