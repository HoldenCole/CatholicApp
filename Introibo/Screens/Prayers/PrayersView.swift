import SwiftUI

struct PrayersView: View {
    @State private var store = ContentStore.shared
    @State private var selection: Prayer?
    @State private var showRuleEditor = false
    @State private var completedPrayers: Set<String> = []
    @AppStorage(SettingsKey.theme) private var themeRaw = AppTheme.parchment.rawValue
    @AppStorage(SettingsKey.language) private var languageRaw = LanguageMode.both.rawValue
    @AppStorage(SettingsKey.fontSize) private var fontScale = FontSizeScale.defaultValue
    @State private var sortAlphabetical = false
    @State private var showRuleNotification = false
    @State private var searchText = ""

    private var ctx: LiturgicalContext { .current() }
    private var rule: UserProgress.PrayerRule { UserProgress.prayerRule() }
    private var hasActiveRuleNotification: Bool {
        NotificationStore.all().contains { $0.id.hasPrefix("rule.") && $0.isEnabled }
    }

    /// Occasion tags as they appear in prayers.json; the tile label is the
    /// vernacular form (prayers.occasion.<slug>).
    private let occasions = [
        "Morning", "Before Mass", "During Mass", "After Mass", "Meals",
        "Marian", "Eucharistic", "Before Confession",
        "For the Departed", "In Temptation", "For Protection", "Evening"
    ]
    static func occasionLabel(_ occasion: String) -> String {
        let key = "prayers.occasion." + occasion.lowercased().replacingOccurrences(of: " ", with: "_")
        return ContentStore.shared.uiString(key, occasion)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    if !rule.isEmpty {
                        dailyRuleSection
                    } else {
                        setupRuleCard
                    }
                    occasionsSection
                    fullLibrarySection
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 40)
            }
            .background(Color.pageBackground.ignoresSafeArea())
            .navigationTitle("Oratio")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(item: $selection) { p in
                PrayerDetailView(prayer: p)
            }
            .sheet(isPresented: $showRuleEditor) {
                PrayerRuleEditor()
            }
            .onAppear {
                completedPrayers = UserProgress.completedPrayers()
            }
        }
    }

    // MARK: - Daily Rule

    private var dailyRuleSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Regula Orationis")
                        .smallLabel(color: Color.sanctuaryRed)
                    Text(ContentStore.shared.uiString("prayers.my_rule", "My Daily Rule"))
                        .appFont(.captionSm)
                        .italic()
                        .foregroundStyle(Color.secondaryText)
                }
                Spacer()
                let done = completedPrayers.intersection(Set(rule.allSlugs)).count
                let total = rule.totalCount
                ZStack {
                    Circle()
                        .stroke(Color.frameLine, lineWidth: 3)
                        .frame(width: 40, height: 40)
                    Circle()
                        .trim(from: 0, to: total > 0 ? Double(done) / Double(total) : 0)
                        .stroke(done == total && total > 0 ? Color.goldLeaf : Color.sanctuaryRed, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                        .frame(width: 40, height: 40)
                        .rotationEffect(.degrees(-90))
                    Text("\(done)")
                        .appFont(.titleM)
                        .foregroundStyle(Color.primaryText)
                }
                Button { showRuleNotification = true } label: {
                    Image(systemName: hasActiveRuleNotification ? "bell.fill" : "bell")
                        .foregroundStyle(Color.sanctuaryRed)
                        .appFont(.scaledSystem(14))
                }
                .buttonStyle(.plain)
                .sheet(isPresented: $showRuleNotification) {
                    NotificationScheduleSheet(
                        scheduleId: "rule.daily",
                        title: ContentStore.shared.uiString("prayers.rule_reminder", "Prayer Rule Reminder"),
                        subtitle: ContentStore.shared.uiString("prayers.rule_reminder_sub", "Get reminded to pray your daily rule")
                    )
                }
            }

            // Labelled edit affordance: the only way back into the rule
            // editor once a rule exists (the setup card no longer renders).
            Button { showRuleEditor = true } label: {
                HStack(spacing: 6) {
                    Image(systemName: "pencil")
                    Text(ContentStore.shared.uiString("prayers.edit_rule", "Edit rule"))
                }
                .appFont(.captionSm)
                .foregroundStyle(Color.sanctuaryRed)
                .frame(minHeight: 44)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityLabel(ContentStore.shared.uiString("prayers.edit_rule_title", "Edit Prayer Rule"))

            if !rule.morning.isEmpty {
                rulePeriod("Mane", eng: ContentStore.shared.uiString("common.morning", "Morning"), slugs: rule.morning)
            }
            if !rule.midday.isEmpty {
                rulePeriod("Meridies", eng: ContentStore.shared.uiString("common.midday", "Midday"), slugs: rule.midday)
            }
            if !rule.evening.isEmpty {
                rulePeriod("Vesperae", eng: ContentStore.shared.uiString("common.evening", "Evening"), slugs: rule.evening)
            }
        }
        .padding(16)
        .overlay(Rectangle().stroke(Color.sanctuaryRed.opacity(0.3), lineWidth: 1))
    }

    private func rulePeriod(_ lat: String, eng: String, slugs: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(lat)  .  \(eng)")
                .smallLabel(color: Color.goldLeaf)

            ForEach(slugs, id: \.self) { slug in
                if let prayer = store.prayer(slug: slug) {
                    let isDone = completedPrayers.contains(slug)
                    Button {
                        UserProgress.togglePrayer(slug)
                        completedPrayers = UserProgress.completedPrayers()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: isDone ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(isDone ? Color.goldLeaf : Color.frameLine)
                                .appFont(.titleM)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(prayer.title.strippingEm)
                                    .appFont(.titleM)
                                    .italic()
                                    .foregroundStyle(isDone ? Color.tertiaryText : Color.primaryText)
                                    .strikethrough(isDone, color: Color.tertiaryText)
                                Text(prayer.eng)
                                    .appFont(.captionSm)
                                    .foregroundStyle(isDone ? Color.tertiaryText : Color.secondaryText)
                            }
                            Spacer()
                            Button {
                                selection = prayer
                            } label: {
                                Image(systemName: "book.pages")
                                    .foregroundStyle(Color.sanctuaryRed)
                                    .appFont(.scaledSystem(14))
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 4)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                } else if slug.hasPrefix("office-"), let h = store.hour(slug: String(slug.dropFirst(7))) {
                    let isDone = completedPrayers.contains(slug)
                    Button {
                        UserProgress.togglePrayer(slug)
                        completedPrayers = UserProgress.completedPrayers()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: isDone ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(isDone ? Color.goldLeaf : Color.frameLine)
                                .appFont(.titleM)
                            VStack(alignment: .leading, spacing: 1) {
                                Text(h.name)
                                    .appFont(.titleM)
                                    .italic()
                                    .foregroundStyle(isDone ? Color.tertiaryText : Color.primaryText)
                                    .strikethrough(isDone, color: Color.tertiaryText)
                                Text("\(h.eng) — \(h.time)")
                                    .appFont(.captionSm)
                                    .foregroundStyle(isDone ? Color.tertiaryText : Color.secondaryText)
                            }
                            Spacer()
                            Image(systemName: "clock")
                                .foregroundStyle(Color.sanctuaryRed)
                                .appFont(.scaledSystem(14))
                        }
                        .padding(.vertical, 4)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Setup CTA

    private var setupRuleCard: some View {
        Button { showRuleEditor = true } label: {
            VStack(spacing: 10) {
                Text("✠")
                    .appFont(.titleL)
                    .foregroundStyle(Color.sanctuaryRed)
                Text(ContentStore.shared.uiString("prayers.create_rule", "Create Your Prayer Rule"))
                    .appFont(.titleM)
                    .italic()
                    .foregroundStyle(Color.primaryText)
                Text(ContentStore.shared.uiString("prayers.create_rule_sub", "Choose prayers for morning, midday, and evening"))
                    .appFont(.captionSm)
                    .italic()
                    .foregroundStyle(Color.secondaryText)
                    .multilineTextAlignment(.center)
                Text(ContentStore.shared.uiString("stations.begin", "·  Begin"))
                    .smallLabel(color: Color.sanctuaryRed)
                    .padding(.top, 4)
            }
            .frame(maxWidth: .infinity)
            .padding(20)
            .overlay(Rectangle().stroke(Color.sanctuaryRed.opacity(0.3), lineWidth: 1))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Occasions

    private var occasionsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Rectangle().fill(Color.sanctuaryRed.opacity(0.4)).frame(height: 1)
                Text("Occasiones")
                    .appFont(.titleM)
                    .italic()
                    .foregroundStyle(Color.sanctuaryRed)
                    .textCase(.uppercase)
                    .tracking(2)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                Rectangle().fill(Color.sanctuaryRed.opacity(0.4)).frame(height: 1)
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(occasions, id: \.self) { occasion in
                    let count = store.prayers.filter { ($0.occasions ?? []).contains(occasion) }.count
                    NavigationLink(destination: OccasionView(occasion: occasion, prayers: store.prayers.filter { ($0.occasions ?? []).contains(occasion) })) {
                        VStack(spacing: 4) {
                            Text(Self.occasionLabel(occasion))
                                .appFont(.captionSm)
                                .foregroundStyle(Color.primaryText)
                                .multilineTextAlignment(.center)
                            Text("\(count)")
                                .appFont(.captionSm)
                                .foregroundStyle(Color.tertiaryText)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .overlay(Rectangle().stroke(Color.frameLine, lineWidth: 0.5))
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Full Library

    private var sortedPrayers: [Prayer] {
        var list = store.prayers
        if !searchText.isEmpty {
            let q = searchText.lowercased()
            list = list.filter {
                $0.title.strippingEm.lowercased().contains(q) ||
                $0.eng.lowercased().contains(q)
            }
        }
        if sortAlphabetical {
            list.sort { $0.title.strippingEm.localizedCaseInsensitiveCompare($1.title.strippingEm) == .orderedAscending }
        }
        return list
    }

    private var fullLibrarySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Rectangle().fill(Color.goldLeaf.opacity(0.4)).frame(height: 0.5)
                Text(ContentStore.shared.uiString("prayers.all", "All Prayers"))
                    .appFont(.captionSm)
                    .italic()
                    .foregroundStyle(Color.secondaryText)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                Rectangle().fill(Color.goldLeaf.opacity(0.4)).frame(height: 0.5)
            }

            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(Color.tertiaryText)
                    .appFont(.scaledSystem(14))
                TextField(ContentStore.shared.uiString("prayers.search", "Search prayers"), text: $searchText)
                    .appFont(.body)
                if !searchText.isEmpty {
                    Button { searchText = "" } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(Color.tertiaryText)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(10)
            .background(Color.frameLine.opacity(0.3))
            .cornerRadius(8)

            HStack {
                Spacer()
                Button {
                    sortAlphabetical.toggle()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: sortAlphabetical ? "textformat.abc" : "list.number")
                            .appFont(.scaledSystem(11))
                        Text(sortAlphabetical ? "A - Z" : ContentStore.shared.uiString("prayers.sort.default", "Default"))
                            .appFont(.captionSm)
                    }
                    .foregroundStyle(Color.sanctuaryRed)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .overlay(RoundedRectangle(cornerRadius: 4).stroke(Color.sanctuaryRed.opacity(0.3), lineWidth: 0.5))
                }
                .buttonStyle(.plain)
            }

            ForEach(sortedPrayers) { p in
                Button { selection = p } label: {
                    HStack(alignment: .firstTextBaseline, spacing: 14) {
                        Text(String(p.title.strippingEm.prefix(1)))
                            .appFont(.titleL)
                            .italic()
                            .foregroundStyle(Color.sanctuaryRed)
                            .frame(width: 22, alignment: .leading)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(p.title.strippingEm)
                                .appFont(.titleM)
                                .italic()
                                .foregroundStyle(Color.primaryText)
                            Text(p.eng)
                                .appFont(.captionSm)
                                .italic()
                                .foregroundStyle(Color.secondaryText)
                        }
                        Spacer()
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                if p.slug != sortedPrayers.last?.slug {
                    Divider().background(Color.frameLine)
                }
            }
        }
    }
}

// MARK: - Occasion View

struct OccasionView: View {
    let occasion: String
    let prayers: [Prayer]
    @State private var selection: Prayer?
    @AppStorage(SettingsKey.theme) private var themeRaw = AppTheme.parchment.rawValue

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                ForEach(prayers) { p in
                    Button { selection = p } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(p.title.strippingEm)
                                .appFont(.titleM)
                                .italic()
                                .foregroundStyle(Color.primaryText)
                            Text(p.eng)
                                .appFont(.captionSm)
                                .italic()
                                .foregroundStyle(Color.secondaryText)
                            if let note = p.note {
                                Text(note)
                                    .appFont(.captionSm)
                                    .foregroundStyle(Color.tertiaryText)
                                    .lineLimit(2)
                                    .minimumScaleFactor(0.8)
                                    .padding(.top, 2)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 6)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    if p.slug != prayers.last?.slug {
                        Divider().background(Color.frameLine)
                    }
                }
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 24)
        }
        .background(Color.pageBackground.ignoresSafeArea())
        .navigationTitle(PrayersView.occasionLabel(occasion))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $selection) { p in
            PrayerDetailView(prayer: p)
        }
    }
}

// MARK: - Prayer Rule Editor

struct PrayerRuleEditor: View {
    @Environment(\.dismiss) private var dismiss
    @State private var rule = UserProgress.prayerRule()
    @State private var store = ContentStore.shared
    @AppStorage(SettingsKey.theme) private var themeRaw = AppTheme.parchment.rawValue
    @State private var addingTo: RulePeriod? = nil

    enum RulePeriod: String, Identifiable {
        case morning, midday, evening
        var id: String { rawValue }
        var title: String {
            switch self {
            case .morning: return ContentStore.shared.uiString("common.morning", "Morning")
            case .midday: return ContentStore.shared.uiString("common.midday", "Midday")
            case .evening: return ContentStore.shared.uiString("common.evening", "Evening")
            }
        }
    }

    var body: some View {
        NavigationStack {
            List {
                ruleSection(.morning, eng: ContentStore.shared.uiString("common.morning", "Morning"), latin: "Mane", slugs: $rule.morning)
                ruleSection(.midday, eng: ContentStore.shared.uiString("common.midday", "Midday"), latin: "Meridies", slugs: $rule.midday)
                ruleSection(.evening, eng: ContentStore.shared.uiString("common.evening", "Evening"), latin: "Vesperae", slugs: $rule.evening)
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Color.pageBackground.ignoresSafeArea())
            .navigationTitle(ContentStore.shared.uiString("prayers.edit_rule_title", "Edit Prayer Rule"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button(ContentStore.shared.uiString("common.cancel", "Cancel")) { dismiss() }
                        .foregroundStyle(Color.sanctuaryRed)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(ContentStore.shared.uiString("common.save", "Save")) {
                        UserProgress.savePrayerRule(rule)
                        dismiss()
                    }
                    .foregroundStyle(Color.sanctuaryRed)
                }
            }
            .sheet(item: $addingTo) { period in
                RuleItemPicker(
                    periodTitle: period.title,
                    slugs: binding(for: period),
                    otherSlugs: otherSlugs(than: period)
                )
            }
        }
    }

    private func binding(for period: RulePeriod) -> Binding<[String]> {
        switch period {
        case .morning: return $rule.morning
        case .midday: return $rule.midday
        case .evening: return $rule.evening
        }
    }

    private func otherSlugs(than period: RulePeriod) -> Set<String> {
        var all = Set(rule.allSlugs)
        for slug in binding(for: period).wrappedValue { all.remove(slug) }
        return all
    }

    /// Display title for a rule slug — a prayer, or an Office hour
    /// ("office-<slug>"). Hours added via the hour view's bookmark were
    /// previously invisible here because only prayers were resolved.
    private func itemTitle(_ slug: String) -> String? {
        if slug.hasPrefix("office-") {
            return store.hour(slug: String(slug.dropFirst(7)))?.name
        }
        return store.prayer(slug: slug)?.title.strippingEm
    }

    private func ruleSection(_ period: RulePeriod, eng: String, latin: String,
                             slugs: Binding<[String]>) -> some View {
        Section {
            ForEach(slugs.wrappedValue, id: \.self) { slug in
                if let title = itemTitle(slug) {
                    HStack {
                        Text(title)
                            .appFont(.body)
                            .foregroundStyle(Color.primaryText)
                        if slug.hasPrefix("office-") {
                            Image(systemName: "clock")
                                .appFont(.scaledSystem(12))
                                .foregroundStyle(Color.sanctuaryRed)
                        }
                        Spacer()
                        Button {
                            slugs.wrappedValue.removeAll { $0 == slug }
                        } label: {
                            Image(systemName: "minus.circle.fill")
                                .foregroundStyle(Color.sanctuaryRed)
                        }
                        .buttonStyle(.plain)
                    }
                    .listRowBackground(Color.pageBackground)
                }
            }

            Button {
                addingTo = period
            } label: {
                HStack {
                    Image(systemName: "plus.circle")
                        .foregroundStyle(Color.sanctuaryRed)
                    Text(ContentStore.shared.uiString("prayers.add_items", "Add prayers or hours"))
                        .appFont(.body)
                        .foregroundStyle(Color.sanctuaryRed)
                }
            }
            .listRowBackground(Color.pageBackground)
        } header: {
            Text("\(latin)  .  \(eng)")
                .appFont(.caption)
        }
    }
}

/// Sectioned picker for building a prayer rule: the canonical hours first,
/// then every prayer grouped by category. Tap to toggle; items already used
/// in another period are hidden (an item lives in one period at a time).
struct RuleItemPicker: View {
    @Environment(\.dismiss) private var dismiss
    let periodTitle: String
    @Binding var slugs: [String]
    let otherSlugs: Set<String>
    @State private var store = ContentStore.shared

    private static let categoryOrder = ["Rosárium", "Missa", "Devotiónes", "Ante Crucifíxum"]

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(store.hours, id: \.slug) { hour in
                        let slug = "office-\(hour.slug)"
                        if !otherSlugs.contains(slug) {
                            pickerRow(slug: slug, title: hour.name,
                                      subtitle: "\(hour.eng) — \(hour.time)")
                        }
                    }
                } header: {
                    Text(ContentStore.shared.uiString("prayers.canonical_hours", "Horæ Canonicæ  ·  Canonical Hours"))
                }

                ForEach(Self.categoryOrder, id: \.self) { category in
                    let prayers = store.prayers.filter {
                        $0.category == category && !otherSlugs.contains($0.slug)
                    }
                    if !prayers.isEmpty {
                        Section {
                            ForEach(prayers) { prayer in
                                pickerRow(slug: prayer.slug,
                                          title: prayer.title.strippingEm,
                                          subtitle: prayer.eng)
                            }
                        } header: {
                            Text(category)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Color.pageBackground.ignoresSafeArea())
            .navigationTitle(ContentStore.shared.uiString("prayers.add_to_period", "Add to {0}").replacingOccurrences(of: "{0}", with: "\(periodTitle)"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(ContentStore.shared.uiString("common.done", "Done")) { dismiss() }
                        .foregroundStyle(Color.sanctuaryRed)
                }
            }
        }
    }

    private func pickerRow(slug: String, title: String, subtitle: String) -> some View {
        let selected = slugs.contains(slug)
        return Button {
            if selected {
                slugs.removeAll { $0 == slug }
            } else {
                slugs.append(slug)
            }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .appFont(.body)
                        .foregroundStyle(Color.primaryText)
                    Text(subtitle)
                        .appFont(.captionSm)
                        .foregroundStyle(Color.secondaryText)
                }
                Spacer()
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(selected ? Color.sanctuaryRed : Color.frameLine)
            }
        }
        .buttonStyle(.plain)
        .listRowBackground(Color.pageBackground)
    }
}

#Preview { PrayersView() }
