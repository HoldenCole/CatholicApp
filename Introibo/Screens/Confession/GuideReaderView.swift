import SwiftUI

// Reader for a single guided confession path (Liber I or Liber II).
// Shows the guide's name + title, subtitle (if any), then each step
// with Roman lower-case numeral, title, Latin phase, and body text.

struct GuideReaderView: View {
    let guide: ConfessionGuide
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    header
                    VStack(alignment: .leading, spacing: 24) {
                        if let sub = guide.subtitle {
                            Text(sub)
                                .font(.bodyIt)
                                .foregroundStyle(.secondaryText)
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
                        ForEach(Array(guide.steps.enumerated()), id: \.offset) { _, step in
                            stepBlock(step)
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
                        .foregroundStyle(.sanctuaryRed)
                }
            }
        }
    }

    private var header: some View {
        VStack(spacing: 8) {
            Text("✠  \(guide.name)  ✠")
                .smallLabel(color: .goldLeaf)
                .padding(.top, 28)
            Text(guide.title)
                .font(.pageTitle)
                .foregroundStyle(.ivory)
                .multilineTextAlignment(.center)
            Text("Sacraméntum Pæniténtiæ")
                .font(.caption)
                .italic()
                .foregroundStyle(.muted)
                .textCase(.uppercase)
                .tracking(2.5)
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

    private func stepBlock(_ step: ConfessionGuide.Step) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(step.num)
                    .font(.titleL)
                    .italic()
                    .foregroundStyle(.sanctuaryRed)
                    .frame(width: 44, alignment: .leading)
                VStack(alignment: .leading, spacing: 2) {
                    Text(step.title)
                        .font(.titleM)
                        .italic()
                        .foregroundStyle(.primaryText)
                    if let latin = step.latin {
                        Text(latin)
                            .font(.captionSm)
                            .italic()
                            .foregroundStyle(.secondaryText)
                    }
                }
            }
            Text(step.body)
                .font(.bodySm)
                .foregroundStyle(.secondaryText)
                .lineSpacing(3)
                .padding(.leading, 56)
        }
        .padding(.vertical, 4)
    }
}
