import SwiftUI

// MARK: - "Citatur In · Referenced By" footer (Phase 3)
//
// The bidirectional counterpart to RelatedLinksSection. Lists every entry that
// links TO the current document (computed by LinkGraph.referencedBy). Each row's
// LinkSource carries the source entry's own DeepLinkTarget, opened through
// `DeepLinkRouter.shared.open(_:)` on tap — the same navigation entry point the
// inline `introibo://link` taps and the "See Also" rows resolve to.
//
// Renders nothing when `sources` is empty, so detail views can include it
// unconditionally; it stays invisible until seed links are added (Phase 4).
//
// Mirror of:
//   android/app/src/main/java/com/lampstandhq/introibo/ui/components/ReferencedBySection.kt

struct ReferencedBySection: View {
    let sources: [LinkSource]

    var body: some View {
        if !sources.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("Citatur In  \u{00B7}  Referenced By")
                    .smallLabel(color: Color.goldLeaf)

                VStack(alignment: .leading, spacing: 10) {
                    ForEach(sources, id: \.self) { source in
                        Button {
                            DeepLinkRouter.shared.open(source.target)
                        } label: {
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                Image(systemName: "arrow.uturn.backward")
                                    .font(.scaledSystem(11, weight: .regular))
                                    .foregroundStyle(Color.sanctuaryRed.opacity(0.7))
                                Text(source.label)
                                    .font(.body)
                                    .foregroundStyle(Color.sanctuaryRed)
                                    .multilineTextAlignment(.leading)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 8)
        }
    }
}
