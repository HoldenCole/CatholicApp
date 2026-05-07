import SwiftUI

struct PrayersView: View {
    @State private var store = ContentStore.shared
    @State private var selection: Prayer?
    @State private var showRuleEditor = false
    @State private var completedPrayers: Set<String> = []
    @AppStorage(SettingsKey.theme) private var themeRaw = AppTheme.parchment.rawValue
    @AppStorage(SettingsKey.language) private var languageRaw = LanguageMode.both.rawValue
    @AppStorage(SettingsKey.fontSize) private var fontScale = FontSizeScale.defaultValue

    private var ctx: LiturgicalContext { .current() }
    private var rule: UserProgress.PrayerRule { UserProgress.prayerRule() }

    private let occasions = [
        "Morning", "Before Mass", "After Mass", "Meals",
        "Marian", "Eucharistic", "Before Confession",
        "For the Departed", "In Temptation", "For Protection", "Evening"
    ]

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
                    Text("My Daily Rule")
                        .font(.captionSm)
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
                        .font(.titleM)
                        .foregroundStyle(Color.primaryText)
                }
                Button { showRuleEditor = true } label: {
                    Image(systemName: "pencil")
                        .foregroundStyle(Color.sanctuaryRed)
                        .font(.system(size: 14))
                }
                .buttonStyle(.plain)
            }

            if !rule.morning.isEmpty {
                rulePeriod("Mane", eng: "Morning", slugs: rule.morning)
            }
            if !rule.midday.isEmpty {
                rulePeriod("Meridies", eng: "Midday", slugs: rule.midday)
            }
            if !rule.evening.isEmpty {
                rulePeriod("Vesperae", eng: "Evening", slugs: rule.evening)
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
                                .font(.system(size: 18))
                            VStack(alignment: .leading, spacing: 1) {
                                Text(prayer.title.strippingEm)
                                    .font(.titleM)
                                    .italic()
                                    .foregroundStyle(isDone ? Color.tertiaryText : Color.primaryText)
                                    .strikethrough(isDone, color: Color.tertiaryText)
                                Text(prayer.eng)
                                    .font(.captionSm)
                                    .foregroundStyle(isDone ? Color.tertiaryText : Color.secondaryText)
                            }
                            Spacer()
                            Button {
                                selection = prayer
                            } label: {
                                Image(systemName: "book.pages")
                                    .foregroundStyle(Color.sanctuaryRed)
                                    .font(.system(size: 14))
                            }
                            .buttonStyle(.plain)
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
                    .font(.titleL)
                    .foregroundStyle(Color.sanctuaryRed)
                Text("Create Your Prayer Rule")
                    .font(.titleM)
                    .italic()
                    .foregroundStyle(Color.primaryText)
                Text("Choose prayers for morning, midday, and evening")
                    .font(.captionSm)
                    .italic()
                    .foregroundStyle(Color.secondaryText)
                    .multilineTextAlignment(.center)
                Text("Begin")
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
                    .font(.titleM)
                    .italic()
                    .foregroundStyle(Color.sanctuaryRed)
                    .textCase(.uppercase)
                    .tracking(2)
                    .fixedSize()
                Rectangle().fill(Color.sanctuaryRed.opacity(0.4)).frame(height: 1)
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ForEach(occasions, id: \.self) { occasion in
                    let count = store.prayers.filter { ($0.occasions ?? []).contains(occasion) }.count
                    NavigationLink(destination: OccasionView(occasion: occasion, prayers: store.prayers.filter { ($0.occasions ?? []).contains(occasion) })) {
                        VStack(spacing: 4) {
                            Text(occasion)
                                .font(.captionSm)
                                .foregroundStyle(Color.primaryText)
                                .multilineTextAlignment(.center)
                            Text("\(count)")
                                .font(.captionSm)
                                .foregroundStyle(Color.tertiaryText)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .overlay(Rectangle().stroke(Color.frameLine, lineWidth: 0.5))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Full Library

    private var fullLibrarySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Rectangle().fill(Color.goldLeaf.opacity(0.4)).frame(height: 0.5)
                Text("All Prayers")
                    .font(.captionSm)
                    .italic()
                    .foregroundStyle(Color.secondaryText)
                    .fixedSize()
                Rectangle().fill(Color.goldLeaf.opacity(0.4)).frame(height: 0.5)
            }

            ForEach(store.prayers) { p in
                Button { selection = p } label: {
                    HStack(alignment: .firstTextBaseline, spacing: 14) {
                        Text(String(p.title.strippingEm.prefix(1)))
                            .font(.titleL)
                            .italic()
                            .foregroundStyle(Color.sanctuaryRed)
                            .frame(width: 22, alignment: .leading)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(p.title.strippingEm)
                                .font(.titleM)
                                .italic()
                                .foregroundStyle(Color.primaryText)
                            Text(p.eng)
                                .font(.captionSm)
                                .italic()
                                .foregroundStyle(Color.secondaryText)
                        }
                        Spacer()
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                if p.slug != store.prayers.last?.slug {
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

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                ForEach(prayers) { p in
                    Button { selection = p } label: {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(p.title.strippingEm)
                                .font(.titleM)
                                .italic()
                                .foregroundStyle(Color.primaryText)
                            Text(p.eng)
                                .font(.captionSm)
                                .italic()
                                .foregroundStyle(Color.secondaryText)
                            if let note = p.note {
                                Text(note)
                                    .font(.captionSm)
                                    .foregroundStyle(Color.tertiaryText)
                                    .lineLimit(2)
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
        .navigationTitle(occasion)
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

    var body: some View {
        NavigationStack {
            List {
                ruleSection("Morning", latin: "Mane", slugs: $rule.morning)
                ruleSection("Midday", latin: "Meridies", slugs: $rule.midday)
                ruleSection("Evening", latin: "Vesperae", slugs: $rule.evening)
            }
            .listStyle(.insetGrouped)
            .scrollContentBackground(.hidden)
            .background(Color.pageBackground.ignoresSafeArea())
            .navigationTitle("Edit Prayer Rule")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(Color.sanctuaryRed)
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        UserProgress.savePrayerRule(rule)
                        dismiss()
                    }
                    .foregroundStyle(Color.sanctuaryRed)
                }
            }
        }
    }

    private func ruleSection(_ eng: String, latin: String, slugs: Binding<[String]>) -> some View {
        Section {
            ForEach(slugs.wrappedValue, id: \.self) { slug in
                if let prayer = store.prayer(slug: slug) {
                    HStack {
                        Text(prayer.title.strippingEm)
                            .foregroundStyle(Color.primaryText)
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

            Menu {
                ForEach(store.prayers.filter { !rule.allSlugs.contains($0.slug) }) { prayer in
                    Button(prayer.title.strippingEm) {
                        slugs.wrappedValue.append(prayer.slug)
                    }
                }
            } label: {
                HStack {
                    Image(systemName: "plus.circle")
                        .foregroundStyle(Color.sanctuaryRed)
                    Text("Add Prayer")
                        .foregroundStyle(Color.sanctuaryRed)
                }
            }
            .listRowBackground(Color.pageBackground)
        } header: {
            Text("\(latin)  .  \(eng)")
        }
    }
}

#Preview { PrayersView() }
