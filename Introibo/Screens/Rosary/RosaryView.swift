import SwiftUI

// Rosary landing screen. Shows today's suggested mystery set (based on
// day of week + season) and lets the user pick another set. Tapping
// into a set opens the mystery reader. Not a tab — reached from Today.

struct RosaryView: View {
    @State private var store = ContentStore.shared
    @State private var selection: MysterySetData?
    @State private var showNotification = false
    @AppStorage(SettingsKey.theme) private var themeRaw = AppTheme.parchment.rawValue
    @AppStorage(SettingsKey.language) private var languageRaw = LanguageMode.both.rawValue
    private var langMode: LanguageMode { LanguageMode(rawValue: languageRaw) ?? .both }
    private var ctx: LiturgicalContext { .current() }

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
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button { showNotification = true } label: {
                    Image(systemName: NotificationStore.schedule(for: "devotion.rosary")?.isEnabled == true ? "bell.fill" : "bell")
                        .foregroundStyle(Color.sanctuaryRed)
                }
                .sheet(isPresented: $showNotification) {
                    NotificationScheduleSheet(scheduleId: "devotion.rosary", title: "The Holy Rosary", subtitle: "Remind me to pray the Rosary")
                }
            }
        }
        .sheet(item: $selection) { set in
            RosaryFlowView(set: set)
        }
    }

    private var header: some View {
        VStack(spacing: 4) {
            LanguageAwareText(latin: "\(ctx.feriaLatin)  \u{00B7}  \(ctx.latinName)", english: "\(ctx.feriaEnglish)  \u{00B7}  \(ctx.englishName)", separator: "")
                .smallLabel(color: Color.sanctuaryRed)
            Text("Oratio per Rosárium")
                .font(.titleL)
                .italic()
                .foregroundStyle(Color.primaryText)
            Text("Pray the Rosary")
                .font(.captionSm)
                .italic()
                .foregroundStyle(Color.secondaryText)
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
                    LanguageAwareText(latin: "Mystéria Hodiérna", english: "Today\u{2019}s Mysteries")
                        .smallLabel(color: Color.goldLeaf)
                    if langMode != .vernacular {
                        Text(todaySet.name)
                            .font(.pageTitle)
                            .foregroundStyle(Color.primaryText)
                    }
                    if langMode != .latinOnly {
                        Text(todaySet.english)
                            .font(langMode == .vernacular ? .pageTitle : .caption)
                            .italic()
                            .foregroundStyle(langMode == .vernacular ? Color.primaryText : Color.secondaryText)
                            .textCase(.uppercase)
                            .tracking(2)
                    }
                    HStack {
                        Spacer()
                        Text("Incipiámus  ✠  Begin")
                            .smallLabel(color: Color.sanctuaryRed)
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
                    .smallLabel(color: Color.sanctuaryRed)
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
                                .foregroundStyle(Color.primaryText)
                            Text(set.english)
                                .font(.captionSm)
                                .italic()
                                .foregroundStyle(Color.secondaryText)
                        }
                        Spacer()
                        Text("›")
                            .font(.titleL)
                            .foregroundStyle(Color.goldLeaf)
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
