import SwiftUI

// Rosary landing screen. Shows today's suggested mystery set (based on
// day of week + season) and lets the user pick another set. Tapping
// into a set opens the mystery reader. Not a tab — reached from Today.

struct RosaryView: View {
    @State private var store = ContentStore.shared
    @State private var selection: MysterySetData?
    @AppStorage(SettingsKey.theme) private var themeRaw = AppTheme.parchment.rawValue
    private let ctx = LiturgicalContext.current()

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                header
                todayCard
                othersList
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 24)
        }
        .background(Color.pageBackground.ignoresSafeArea())
        .navigationTitle("Sacratíssimum Rosárium")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selection) { set in
            RosaryFlowView(set: set)
        }
    }

    private var header: some View {
        VStack(spacing: 4) {
            Text("\(ctx.feriaLatin)  ·  \(ctx.latinName)")
                .smallLabel(color: .sanctuaryRed)
            Text("Oratio per Rosárium")
                .font(.titleL)
                .italic()
                .foregroundStyle(.primaryText)
            Text("Pray the Rosary")
                .font(.captionSm)
                .italic()
                .foregroundStyle(.secondaryText)
                .textCase(.uppercase)
                .tracking(2)
        }
        .padding(.top, 8)
    }

    @ViewBuilder
    private var todayCard: some View {
        if let todaySet = store.mysterySet(slug: ctx.mystery.rawValue) {
            Button { selection = todaySet } label: {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Mystéria Hodiérna  ·  Today's Mysteries")
                        .smallLabel(color: .goldLeaf)
                    Text(todaySet.name)
                        .font(.pageTitle)
                        .foregroundStyle(.primaryText)
                    Text(todaySet.english)
                        .font(.caption)
                        .italic()
                        .foregroundStyle(.secondaryText)
                        .textCase(.uppercase)
                        .tracking(2)
                    HStack {
                        Spacer()
                        Text("Incipiámus  ✠  Begin")
                            .smallLabel(color: .sanctuaryRed)
                    }
                    .padding(.top, 6)
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .overlay(Rectangle().stroke(Color.frameLine, lineWidth: 0.5))
            }
            .buttonStyle(.plain)
        }
    }

    private var othersList: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Rectangle().fill(Color.goldLeaf.opacity(0.4)).frame(height: 0.5)
                Text("Ália Mystéria")
                    .smallLabel(color: .sanctuaryRed)
                    .fixedSize()
                Rectangle().fill(Color.goldLeaf.opacity(0.4)).frame(height: 0.5)
            }
            ForEach(store.mysterySets.filter { $0.slug != ctx.mystery.rawValue }) { set in
                Button { selection = set } label: {
                    HStack(alignment: .firstTextBaseline) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(set.name)
                                .font(.titleM)
                                .italic()
                                .foregroundStyle(.primaryText)
                            Text(set.english)
                                .font(.captionSm)
                                .italic()
                                .foregroundStyle(.secondaryText)
                        }
                        Spacer()
                        Text("›")
                            .font(.titleL)
                            .foregroundStyle(.goldLeaf)
                    }
                    .padding(.vertical, 10)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                Divider().background(Color.frameLine.opacity(0.5))
            }
        }
    }
}
