import SwiftUI

// De Confessióne — landing screen offering two guided paths + direct
// access to the Examination of Conscience. Reached from Today's
// "Examination of Conscience" devotion row. Supports a deep-link mode
// where the examen pops open immediately.

struct ConfessionView: View {
    let openExamen: Bool
    @State private var store = ContentStore.shared
    @State private var selectedGuide: ConfessionGuide?
    @State private var showExamen = false

    init(openExamen: Bool = false) {
        self.openExamen = openExamen
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                header
                examenCard
                guideList
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 24)
        }
        .background(Color.pageBackground.ignoresSafeArea())
        .navigationTitle("De Confessióne")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selectedGuide) { guide in
            GuideReaderView(guide: guide)
        }
        .sheet(isPresented: $showExamen) {
            ExamenView()
        }
        .onAppear {
            if openExamen { showExamen = true }
        }
    }

    private var header: some View {
        VStack(spacing: 4) {
            Text("Sacraméntum Pæniténtiæ")
                .smallLabel(color: Color.sanctuaryRed)
            Text("The Sacrament of Penance")
                .font(.titleL)
                .italic()
                .foregroundStyle(Color.primaryText)
            Text("Two guided paths, plus the Examination of Conscience.")
                .font(.captionSm)
                .italic()
                .foregroundStyle(Color.secondaryText)
                .multilineTextAlignment(.center)
                .padding(.top, 2)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 6)
    }

    private var examenCard: some View {
        Button { showExamen = true } label: {
            VStack(alignment: .leading, spacing: 8) {
                Text("Exámen Consciéntiæ")
                    .smallLabel(color: Color.goldLeaf)
                Text("Examination of Conscience")
                    .font(.titleL)
                    .italic()
                    .foregroundStyle(Color.primaryText)
                Text("Walk through the Ten Commandments with traditional questions for each.")
                    .font(.captionSm)
                    .italic()
                    .foregroundStyle(Color.secondaryText)
                HStack {
                    Spacer()
                    Text("Incipiámus  ✠  Begin")
                        .smallLabel(color: Color.sanctuaryRed)
                }
                .padding(.top, 4)
            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(Rectangle().stroke(Color.frameLine, lineWidth: 0.5))
        }
        .buttonStyle(.plain)
    }

    private var guideList: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Rectangle().fill(Color.goldLeaf.opacity(0.4)).frame(height: 0.5)
                Text("Libri Duo  ·  Two Paths")
                    .smallLabel(color: Color.sanctuaryRed)
                    .fixedSize()
                Rectangle().fill(Color.goldLeaf.opacity(0.4)).frame(height: 0.5)
            }
            ForEach(store.confessionGuides) { guide in
                Button { selectedGuide = guide } label: {
                    guideRow(guide)
                }
                .buttonStyle(.plain)
                if guide.slug != store.confessionGuides.last?.slug {
                    Divider().background(Color.frameLine.opacity(0.5))
                }
            }
        }
    }

    private func guideRow(_ g: ConfessionGuide) -> some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(g.name)
                    .font(.titleM)
                    .italic()
                    .foregroundStyle(Color.primaryText)
                Text(g.title)
                    .font(.captionSm)
                    .italic()
                    .foregroundStyle(Color.secondaryText)
                if let sub = g.subtitle {
                    Text(sub)
                        .font(.captionSm)
                        .italic()
                        .foregroundStyle(Color.tertiaryText)
                        .lineLimit(1)
                        .padding(.top, 2)
                }
            }
            Spacer()
            Text("›").font(.titleL).foregroundStyle(Color.goldLeaf)
        }
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }
}
