import SwiftUI

struct LearnView: View {
    @State private var store = ContentStore.shared
    @State private var selection: Course?
    @State private var mastered: Set<String> = UserProgress.masteredLessons()
    @AppStorage(SettingsKey.theme) private var themeRaw = AppTheme.parchment.rawValue

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    header
                    dailyCard
                    lessonsSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 40)
            }
            .background(Color.pageBackground.ignoresSafeArea())
            .navigationTitle("Schola Latina")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(item: $selection) { course in
                CourseDetailView(course: course, onMasteryChange: {
                    mastered = UserProgress.masteredLessons()
                })
            }
        }
    }

    private var header: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .stroke(Color.frameLine, lineWidth: 5)
                    .frame(width: 80, height: 80)
                Circle()
                    .trim(from: 0, to: Double(mastered.count) / 10.0)
                    .stroke(Color.sanctuaryRed, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .frame(width: 80, height: 80)
                    .rotationEffect(.degrees(-90))
                VStack(spacing: 0) {
                    Text("\(mastered.count)")
                        .font(.system(size: 28, weight: .semibold, design: .serif))
                        .foregroundStyle(Color.primaryText)
                    Text("of 10")
                        .font(.captionSm)
                        .foregroundStyle(Color.tertiaryText)
                }
            }

            Text("Lessons Mastered")
                .font(.captionSm)
                .italic()
                .foregroundStyle(Color.secondaryText)

            HStack(spacing: 4) {
                ForEach(store.courses) { c in
                    Circle()
                        .fill(mastered.contains(c.slug) ? Color.goldLeaf : Color.frameLine)
                        .frame(width: 8, height: 8)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }

    private var dailyCard: some View {
        let allCards = store.courses.flatMap { c in
            c.sections.filter { $0.type == "cards" }.flatMap { $0.items ?? [] }
        }.filter { $0.lat != nil && $0.eng != nil }

        let dayIndex = Calendar.current.component(.dayOfYear, from: Date()) % max(allCards.count, 1)
        let card = allCards.isEmpty ? nil : allCards[dayIndex]

        return Group {
            if let card = card {
                VStack(spacing: 10) {
                    Text("Verbum Hodie")
                        .smallLabel(color: Color.goldLeaf)
                    Text(card.lat ?? "")
                        .font(.titleL)
                        .italic()
                        .foregroundStyle(Color.primaryText)
                    if let phon = card.phon {
                        Text("[\(phon)]")
                            .font(.captionSm)
                            .foregroundStyle(Color.tertiaryText)
                    }
                    Text(card.eng ?? "")
                        .font(.body)
                        .italic()
                        .foregroundStyle(Color.secondaryText)
                }
                .frame(maxWidth: .infinity)
                .padding(20)
                .overlay(Rectangle().stroke(Color.goldLeaf.opacity(0.3), lineWidth: 0.5))
            }
        }
    }

    private var lessonsSection: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 10) {
                Rectangle().fill(Color.sanctuaryRed.opacity(0.4)).frame(height: 1)
                Text("Lectiones")
                    .font(.titleM)
                    .italic()
                    .foregroundStyle(Color.sanctuaryRed)
                    .textCase(.uppercase)
                    .tracking(2)
                    .fixedSize()
                Rectangle().fill(Color.sanctuaryRed.opacity(0.4)).frame(height: 1)
            }
            .padding(.bottom, 16)

            ForEach(store.courses) { course in
                Button { selection = course } label: {
                    lessonRow(course)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func lessonRow(_ c: Course) -> some View {
        let isMastered = mastered.contains(c.slug)
        let cardCount = c.sections.filter { $0.type == "cards" }.flatMap { $0.items ?? [] }.count

        return HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(isMastered ? Color.goldLeaf.opacity(0.12) : Color.sanctuaryRed.opacity(0.08))
                    .frame(width: 44, height: 44)
                Circle()
                    .stroke(isMastered ? Color.goldLeaf.opacity(0.5) : Color.sanctuaryRed.opacity(0.3), lineWidth: 1)
                    .frame(width: 44, height: 44)
                Text(roman(c.num))
                    .font(.titleM)
                    .italic()
                    .foregroundStyle(isMastered ? Color.goldLeaf : Color.sanctuaryRed)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(c.title)
                    .font(.titleM)
                    .italic()
                    .foregroundStyle(Color.primaryText)
                Text(c.latin)
                    .font(.captionSm)
                    .italic()
                    .foregroundStyle(Color.secondaryText)
                HStack(spacing: 8) {
                    HStack(spacing: 3) {
                        Image(systemName: "rectangle.on.rectangle")
                            .font(.system(size: 9))
                        Text("\(cardCount)")
                            .font(.captionSm)
                    }
                    .foregroundStyle(Color.tertiaryText)
                    if isMastered {
                        HStack(spacing: 3) {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 9))
                            Text("Mastered")
                                .font(.captionSm)
                        }
                        .foregroundStyle(Color.goldLeaf)
                    }
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12))
                .foregroundStyle(Color.tertiaryText)
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 8)
        .contentShape(Rectangle())
    }

    private func roman(_ n: Int) -> String {
        ["","I","II","III","IV","V","VI","VII","VIII","IX","X"][n]
    }
}

#Preview { LearnView() }
