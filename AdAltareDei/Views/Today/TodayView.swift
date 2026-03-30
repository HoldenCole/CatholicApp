import SwiftUI
import SwiftData

struct TodayView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var appSettings: AppSettings
    @State private var todaysDevotions: [TraditionalDevotion] = []
    @State private var showingMissalSelector = false
    @State private var showingSettings = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Header with tappable missal badge
                    headerSection

                    ornamentalDivider

                    // Penance first
                    penanceSection

                    ornamentalDivider

                    // Daily devotions (no Angelus)
                    devotionsSection

                    ornamentalDivider

                    // Rosary launcher (no mysteries listed)
                    rosarySection

                    ornamentalDivider

                    // More devotions
                    sectionTitle("More", latin: "Amplius")

                    NavigationLink {
                        StationsView()
                    } label: {
                        devotionLink("Stations of the Cross", latin: "Via Crucis")
                    }
                    .buttonStyle(.plain)

                    NavigationLink {
                        GuideView(jsonFileName: "confession_guide")
                    } label: {
                        devotionLink("Guide to Confession", latin: "De Sacramento Pænitentiæ")
                    }
                    .buttonStyle(.plain)

                    NavigationLink {
                        ExaminationView()
                    } label: {
                        devotionLink("Examination of Conscience", latin: "Examen Conscientiæ")
                    }
                    .buttonStyle(.plain)

                    NavigationLink {
                        GuideView(jsonFileName: "tlm_guide")
                    } label: {
                        devotionLink("How to Attend the TLM", latin: "Quomodo Missam Latinam Audire")
                    }
                    .buttonStyle(.plain)

                    NavigationLink {
                        DailyReadingsView()
                    } label: {
                        devotionLink("Daily Readings", latin: "Lectiones Diurnæ")
                    }
                    .buttonStyle(.plain)

                    // Closing ornament
                    Text("✿ · ✿")
                        .frame(maxWidth: .infinity)
                        .font(.system(size: 12))
                        .foregroundStyle(.goldLeaf.opacity(0.4))
                        .tracking(8)
                        .padding(.vertical, 24)
                }
                .padding(.horizontal, 24)
            }
            .background(Color.parchment)
            .navigationTitle("Today")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                            .foregroundStyle(.goldLeaf)
                    }
                }
            }
            .sheet(isPresented: $showingMissalSelector) {
                MissalSelectorSheet()
            }
            .sheet(isPresented: $showingSettings) {
                SettingsSheet()
            }
            .onAppear {
                loadDevotions()
            }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(Date().latinFeriaName)
                    .font(.custom("Palatino-Italic", size: 13))
                    .foregroundStyle(.goldLeaf)
                    .tracking(3)
                    .textCase(.uppercase)

                Spacer()

                // Tappable missal badge
                Button {
                    showingMissalSelector = true
                } label: {
                    HStack(spacing: 4) {
                        Text(appSettings.missalRite.displayName)
                            .font(.system(size: 10, weight: .semibold))
                        Image(systemName: "chevron.down")
                            .font(.system(size: 8, weight: .semibold))
                    }
                    .foregroundStyle(.goldLeaf)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color.goldLeaf.opacity(0.3), lineWidth: 1)
                    )
                }
            }

            Text(Date().englishWeekdayName)
                .font(.custom("Palatino", size: 36).weight(.bold))
                .foregroundStyle(.ink)

            Text(formattedDate)
                .font(.custom("Palatino-Italic", size: 14))
                .foregroundStyle(.secondary)
        }
        .padding(.bottom, 8)
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM d"
        let day = Calendar.current.component(.day, from: Date())
        let suffix: String
        switch day {
        case 1, 21, 31: suffix = "st"
        case 2, 22: suffix = "nd"
        case 3, 23: suffix = "rd"
        default: suffix = "th"
        }
        formatter.dateFormat = "'the' d'\(suffix) of' MMMM"
        return formatter.string(from: Date())
    }

    // MARK: - Ornamental Divider

    private var ornamentalDivider: some View {
        HStack {
            Spacer()
            Rectangle()
                .frame(height: 1)
                .foregroundStyle(.clear)
                .background(
                    LinearGradient(
                        colors: [.clear, .goldLeaf.opacity(0.3), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
            Text("✟")
                .font(.system(size: 11))
                .foregroundStyle(.goldLeaf.opacity(0.5))
            Rectangle()
                .frame(height: 1)
                .foregroundStyle(.clear)
                .background(
                    LinearGradient(
                        colors: [.clear, .goldLeaf.opacity(0.3), .clear],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
            Spacer()
        }
        .padding(.vertical, 20)
    }

    // MARK: - Penance

    private var penanceSection: some View {
        VStack(alignment: .leading, spacing: 2) {
            sectionTitle("Penance", latin: "Pænitentia")

            let penanceItems = todaysDevotions.filter { $0.isAbstinence || $0.isFasting }
            if penanceItems.isEmpty {
                Text("No special penance today.")
                    .font(.custom("Palatino-Italic", size: 14))
                    .foregroundStyle(.secondary)
            } else {
                ForEach(penanceItems) { item in
                    NavigationLink {
                        destinationForDevotion(item)
                    } label: {
                        HStack(alignment: .top, spacing: 0) {
                            Rectangle()
                                .fill(Color.sanctuaryRed)
                                .frame(width: 3)
                                .padding(.trailing, 16)

                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 6) {
                                    Text(item.title)
                                        .font(.custom("Palatino", size: 17).weight(.semibold))
                                        .foregroundStyle(.ink)

                                    if item.isAbstinence {
                                        penanceTag("Abstinence")
                                    }
                                    if item.isFasting {
                                        penanceTag("Fast")
                                    }
                                }

                                Text(shortDescription(item))
                                    .font(.custom("Georgia", size: 14))
                                    .foregroundStyle(.secondary)
                                    .lineSpacing(4)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func penanceTag(_ text: String) -> some View {
        Text(text.uppercased())
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(.sanctuaryRed)
            .padding(.horizontal, 6)
            .padding(.vertical, 1)
            .overlay(
                RoundedRectangle(cornerRadius: 3)
                    .stroke(Color.sanctuaryRed.opacity(0.3), lineWidth: 1)
            )
    }

    // MARK: - Devotions

    private var devotionsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionTitle("Today's Devotions", latin: "Devotiones Hodiernæ")

            let devotionItems = todaysDevotions.filter {
                !$0.isAbstinence && !$0.isFasting && $0.slug != "angelus_devotion"
            }
            ForEach(devotionItems) { item in
                NavigationLink {
                    destinationForDevotion(item)
                } label: {
                    devotionRowContent(item)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Rosary

    private var rosarySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            sectionTitle("The Holy Rosary", latin: "Sacratissimum Rosarium")

            NavigationLink {
                RosaryStartView(suggestedSet: MysteryScheduleService.todaysPrimarySet())
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Pray the Rosary")
                            .font(.custom("Palatino", size: 18).weight(.semibold))
                            .foregroundStyle(.ink)
                        Text("\(MysteryScheduleService.todaysPrimarySet().englishName) — \(MysteryScheduleService.todaysPrimarySet().latinName)")
                            .font(.custom("Palatino-Italic", size: 14))
                            .foregroundStyle(.sanctuaryRed)
                    }
                    Spacer()
                    Text("→")
                        .font(.system(size: 18))
                        .foregroundStyle(.goldLeaf)
                }
                .padding(18)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.sanctuaryRed.opacity(0.2), lineWidth: 1)
                )
                .overlay(alignment: .top) {
                    // Red-to-gold gradient top border
                    LinearGradient(
                        colors: [.sanctuaryRed, .goldLeaf],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                    .frame(height: 2)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Helpers

    private func sectionTitle(_ title: String, latin: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title.uppercased())
                .font(.custom("Palatino-Italic", size: 12).weight(.semibold))
                .foregroundStyle(.sanctuaryRed)
                .tracking(3)
            Text(latin)
                .font(.custom("Palatino-Italic", size: 13))
                .foregroundStyle(.secondary)
        }
        .padding(.bottom, 12)
    }

    private func devotionRowContent(_ item: TraditionalDevotion) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(timeAwareTitle(for: item))
                .font(.custom("Palatino", size: 16).weight(.medium))
                .foregroundStyle(.ink)
            Text(timeAwareLatinTitle(for: item))
                .font(.custom("Palatino-Italic", size: 13))
                .foregroundStyle(.goldLeaf)
        }
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.goldLeaf.opacity(0.08))
                .frame(height: 1)
        }
    }

    private func devotionLink(_ title: String, latin: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.custom("Palatino", size: 16).weight(.medium))
                .foregroundStyle(.ink)
            Text(latin)
                .font(.custom("Palatino-Italic", size: 13))
                .foregroundStyle(.goldLeaf)
        }
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .overlay(alignment: .bottom) {
            Rectangle().fill(Color.goldLeaf.opacity(0.08)).frame(height: 1)
        }
    }

    /// Routes each devotion to the appropriate detail view.
    @ViewBuilder
    private func destinationForDevotion(_ devotion: TraditionalDevotion) -> some View {
        switch devotion.slug {
        case "divine_office":
            DivineOfficeView()
        case "night_prayers":
            ExaminationView()
        default:
            DevotionDetailView(devotion: devotion)
        }
    }

    /// Returns time-appropriate title for devotions that change by time of day.
    private func timeAwareTitle(for devotion: TraditionalDevotion) -> String {
        guard devotion.slug == "morning_offering" else { return devotion.title }
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 12 { return "Morning Offering" }
        else if hour < 17 { return "Afternoon Offering" }
        else { return "Evening Offering" }
    }

    private func timeAwareLatinTitle(for devotion: TraditionalDevotion) -> String {
        guard devotion.slug == "morning_offering" else { return devotion.latinTitle }
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 12 { return "Oblatio Matutina" }
        else if hour < 17 { return "Oblatio Meridiana" }
        else { return "Oblatio Vespertina" }
    }

    private func shortDescription(_ devotion: TraditionalDevotion) -> String {
        // Return a brief version for the home screen
        let desc = devotion.description
        if let firstSentence = desc.components(separatedBy: ". ").first {
            return firstSentence + "."
        }
        return desc
    }

    // MARK: - Load Devotions

    private func loadDevotions() {
        guard let url = Bundle.main.url(forResource: "devotions", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let allDevotions = try? JSONDecoder().decode([TraditionalDevotion].self, from: data) else {
            return
        }

        let weekday = Calendar.current.component(.weekday, from: Date())
        todaysDevotions = allDevotions.filter { devotion in
            if let days = devotion.applicableDays {
                return days.contains(weekday)
            }
            return devotion.category == .dailyDevotion
        }
    }
}

// MARK: - Missal Selector Sheet

struct MissalSelectorSheet: View {
    @EnvironmentObject private var appSettings: AppSettings
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Choose Your Missal")
                        .font(.custom("Palatino", size: 24).weight(.bold))
                        .foregroundStyle(.ink)

                    Text("Select the rubrical calendar your community follows")
                        .font(.custom("Palatino-Italic", size: 14))
                        .foregroundStyle(.secondary)
                        .padding(.bottom, 8)

                    ForEach(MissalRite.allCases) { rite in
                        Button {
                            appSettings.missalRite = rite
                        } label: {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(rite.displayName)
                                            .font(.custom("Palatino", size: 18).weight(.semibold))
                                            .foregroundStyle(.ink)
                                        Text(rite.latinName)
                                            .font(.custom("Palatino-Italic", size: 13))
                                            .foregroundStyle(.goldLeaf)
                                    }
                                    Spacer()
                                    if appSettings.missalRite == rite {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(.sanctuaryRed)
                                            .font(.system(size: 22))
                                    } else {
                                        Circle()
                                            .stroke(Color.goldLeaf.opacity(0.3), lineWidth: 2)
                                            .frame(width: 22, height: 22)
                                    }
                                }

                                Text(rite.subtitle)
                                    .font(.custom("Georgia", size: 14))
                                    .foregroundStyle(.secondary)
                                    .lineSpacing(4)

                                VStack(alignment: .leading, spacing: 4) {
                                    ForEach(rite.keyDifferences, id: \.self) { diff in
                                        HStack(alignment: .top, spacing: 8) {
                                            Text("·")
                                                .foregroundStyle(.goldLeaf)
                                            Text(diff)
                                                .font(.custom("Georgia", size: 13))
                                                .foregroundStyle(.tertiary)
                                        }
                                    }
                                }
                                .padding(.top, 4)
                            }
                            .padding(18)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(
                                        appSettings.missalRite == rite
                                        ? Color.goldLeaf.opacity(0.4)
                                        : Color.goldLeaf.opacity(0.1),
                                        lineWidth: 1
                                    )
                            )
                            .background(
                                appSettings.missalRite == rite
                                ? Color.goldLeaf.opacity(0.03)
                                : Color.clear
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }
                .padding(24)
            }
            .background(Color.parchment)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(.sanctuaryRed)
                }
            }
        }
    }
}

#Preview {
    TodayView()
        .environmentObject(AppSettings())
        .modelContainer(for: [Prayer.self, Mystery.self, PracticeSession.self], inMemory: true)
}
