import SwiftUI

// Reader for a single Rosary mystery set. Shows an opening prayer
// list and the five mysteries with meditation text + fruit. At the
// bottom: closing prayers (Salve Regína, Fátima) + a "Mark as prayed"
// button that persists to UserProgress.
//
// A full bead-by-bead flow (one step at a time) is a follow-up batch;
// the reader suffices for the prototype parity.

struct MysteryReaderView: View {
    let set: MysterySetData
    @Environment(\.dismiss) private var dismiss
    @State private var didMark = false

    private let store = ContentStore.shared

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    header
                    VStack(alignment: .leading, spacing: 24) {
                        openingBlock
                        ForEach(Array(set.mysteries.enumerated()), id: \.offset) { idx, m in
                            mysteryBlock(m, index: idx + 1)
                        }
                        closingBlock
                        markButton
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

    // MARK: - Header

    private var header: some View {
        VStack(spacing: 8) {
            Text("✠  Sacratíssimum Rosárium  ✠")
                .smallLabel(color: Color.goldLeaf)
                .padding(.top, 28)
            Text(set.name)
                .font(.pageTitle)
                .foregroundStyle(Color.ivory)
            Text(set.english)
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

    // MARK: - Opening

    private var openingBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Inítium  ·  Opening Prayers")
                .smallLabel(color: Color.sanctuaryRed)
            Text("Signum Crucis  ·  Credo  ·  Pater Noster  ·  tria Ave María  ·  Glória Patri")
                .font(.bodyIt)
                .foregroundStyle(Color.secondaryText)
        }
    }

    // MARK: - Mystery block

    private func mysteryBlock(_ m: Mystery, index: Int) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Rectangle().fill(Color.goldLeaf.opacity(0.4)).frame(height: 0.5)
                Text("\(m.num)  ·  \(index) of 5")
                    .smallLabel(color: Color.sanctuaryRed)
                    .fixedSize()
                Rectangle().fill(Color.goldLeaf.opacity(0.4)).frame(height: 0.5)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(m.title)
                    .font(.titleL)
                    .italic()
                    .foregroundStyle(Color.primaryText)
                Text(m.eng)
                    .font(.captionSm)
                    .italic()
                    .foregroundStyle(Color.secondaryText)
                Text(m.ref)
                    .font(.captionSm)
                    .foregroundStyle(Color.goldLeaf)
                    .padding(.top, 2)
            }
            Text(m.body)
                .font(.body)
                .foregroundStyle(Color.primaryText)
                .lineSpacing(4)
                .padding(.top, 4)
            HStack {
                Text("Fructus")
                    .smallLabel(color: Color.goldLeaf)
                Text("·")
                    .foregroundStyle(Color.tertiaryText)
                Text(m.fruit)
                    .font(.captionSm)
                    .italic()
                    .foregroundStyle(Color.secondaryText)
            }
            .padding(.top, 4)
        }
    }

    // MARK: - Closing

    private var closingBlock: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                Rectangle().fill(Color.goldLeaf.opacity(0.4)).frame(height: 0.5)
                Text("Finis  ·  Closing Prayers")
                    .smallLabel(color: Color.sanctuaryRed)
                    .fixedSize()
                Rectangle().fill(Color.goldLeaf.opacity(0.4)).frame(height: 0.5)
            }
            Text("Salve Regína  ·  Orátio ad Fátima  ·  Signum Crucis")
                .font(.bodyIt)
                .foregroundStyle(Color.secondaryText)
        }
    }

    // MARK: - Mark button

    private var markButton: some View {
        Button {
            UserProgress.markRosaryPrayed(set: set.slug)
            didMark = true
        } label: {
            Text(didMark ? "✠ Marked as prayed today" : "Mark as prayed today")
                .smallLabel(color: didMark ? Color.goldLeaf : Color.sanctuaryRed, tracking: 3)
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity)
                .overlay(Rectangle().stroke(
                    didMark ? Color.goldLeaf.opacity(0.6) : Color.sanctuaryRed.opacity(0.6),
                    lineWidth: 0.5
                ))
        }
        .buttonStyle(.plain)
        .padding(.top, 12)
    }
}
