import SwiftUI

// Examination of Conscience — walks through the Ten Commandments with
// traditional self-examination questions for each.

struct ExamenView: View {
    @State private var store = ContentStore.shared
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    header
                    VStack(alignment: .leading, spacing: 24) {
                        introBlock
                        ForEach(store.examen) { entry in
                            commandmentBlock(entry)
                        }
                        closingBlock
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
        }
    }

    private var header: some View {
        VStack(spacing: 8) {
            Text("✠  Exámen Consciéntiæ  ✠")
                .smallLabel(color: Color.goldLeaf)
                .padding(.top, 28)
            Text("Examination of Conscience")
                .font(.pageTitle)
                .foregroundStyle(Color.ivory)
            Text("Decálogus  ·  The Ten Commandments")
                .font(.caption)
                .italic()
                .foregroundStyle(Color.muted)
                .textCase(.uppercase)
                .tracking(2.5)
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

    private var introBlock: some View {
        Text("Go through each commandment quietly and honestly. Recall specific sins and their approximate number where you can. Do not rush — but do not dwell past what is useful.")
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

    private func commandmentBlock(_ e: ExamenEntry) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                Text(e.num)
                    .font(.titleL)
                    .italic()
                    .foregroundStyle(Color.sanctuaryRed)
                    .frame(width: 44, alignment: .leading)
                VStack(alignment: .leading, spacing: 2) {
                    Text(e.commandment)
                        .font(.titleM)
                        .italic()
                        .foregroundStyle(Color.primaryText)
                    Text(e.latin)
                        .font(.captionSm)
                        .italic()
                        .foregroundStyle(Color.secondaryText)
                }
            }
            VStack(alignment: .leading, spacing: 8) {
                ForEach(Array(e.questions.enumerated()), id: \.offset) { _, q in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text("•")
                            .font(.body)
                            .foregroundStyle(Color.goldLeaf)
                        Text(q)
                            .font(.bodySm)
                            .foregroundStyle(Color.secondaryText)
                            .lineSpacing(2)
                    }
                }
            }
            .padding(.leading, 56)
            .padding(.top, 4)
        }
        .padding(.vertical, 6)
    }

    private var closingBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                Rectangle().fill(Color.goldLeaf.opacity(0.4)).frame(height: 0.5)
                Text("Post Exámen")
                    .smallLabel(color: Color.sanctuaryRed)
                    .fixedSize()
                Rectangle().fill(Color.goldLeaf.opacity(0.4)).frame(height: 0.5)
            }
            Text("Make an Act of Contrition. Resolve to avoid the occasions of sin. Proceed to confession.")
                .font(.bodyIt)
                .foregroundStyle(Color.secondaryText)
                .lineSpacing(3)
        }
    }
}
