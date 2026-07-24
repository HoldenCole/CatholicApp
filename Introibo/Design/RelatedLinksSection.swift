import SwiftUI

// MARK: - "Vide Etiam · See Also" footer (Phase 2)
//
// A small, discoverable footer block listing related links. Each row's target
// string is parsed via `LinkTarget.parse` and opened through
// `DeepLinkRouter.shared.open(_:)` on tap — the same navigation entry point the
// inline `introibo://link` taps resolve to.
//
// Renders nothing when `related` is nil or empty, so detail views can include it
// unconditionally; it stays invisible until seed links are added (Phase 4).
//
// Mirror of:
//   android/app/src/main/java/com/lampstandhq/introibo/ui/components/RelatedLinksSection.kt

struct RelatedLinksSection: View {
    let related: [RelatedLink]?

    var body: some View {
        if let related, !related.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("Vide Etiam  \u{00B7}  See Also")
                    .smallLabel(color: Color.goldLeaf)

                VStack(alignment: .leading, spacing: 10) {
                    ForEach(related, id: \.self) { link in
                        if let target = LinkTarget.parse(link.target) {
                            Button {
                                DeepLinkRouter.shared.open(target)
                            } label: {
                                HStack(alignment: .firstTextBaseline, spacing: 8) {
                                    Image(systemName: "arrow.up.right")
                                        .font(.scaledSystem(11, weight: .regular))
                                        .foregroundStyle(Color.sanctuaryRed.opacity(0.7))
                                    Text(link.label)
                                        .font(.body)
                                        .foregroundStyle(Color.sanctuaryRed)
                                        .multilineTextAlignment(.leading)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 8)
        }
    }
}
