import SwiftUI

struct LearnView: View {
    @State private var lessons: [LatinLesson] = []
    @EnvironmentObject private var appSettings: AppSettings

    private var groupedLessons: [(LessonCategory, [LatinLesson])] {
        let grouped = Dictionary(grouping: lessons) { $0.category }
        return LessonCategory.allCases.compactMap { category in
            guard let items = grouped[category], !items.isEmpty else { return nil }
            return (category, items.sorted { $0.sortOrder < $1.sortOrder })
        }
    }

    private var totalLessons: Int { lessons.count }

    /// Roman numeral for course number
    private func romanNumeral(_ n: Int) -> String {
        let values = [(10, "X"), (9, "IX"), (5, "V"), (4, "IV"), (1, "I")]
        var result = ""
        var remaining = n
        for (value, numeral) in values {
            while remaining >= value {
                result += numeral
                remaining -= value
            }
        }
        return result
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Dark header
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Discere Latínam")
                            .font(.custom("Palatino", size: 26).weight(.bold))
                            .foregroundStyle(.white)
                        Text("Learn Ecclesiastical Latin")
                            .font(.custom("Palatino-Italic", size: 14))
                            .foregroundStyle(.goldLeaf)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 20)
                    .background(
                        LinearGradient(
                            colors: [Color(hex: "1C1410"), Color(hex: "2a2118")],
                            startPoint: .top, endPoint: .bottom
                        )
                    )

                    VStack(alignment: .leading, spacing: 0) {
                        // Progress bar
                        HStack {
                            Text("Your progress")
                                .font(.custom("Palatino-Italic", size: 11))
                                .foregroundStyle(.sanctuaryRed)
                            Spacer()
                            Text("0 of \(totalLessons) complete")
                                .font(.custom("Palatino-Italic", size: 11))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.top, 16)
                        .padding(.bottom, 4)

                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color.goldLeaf.opacity(0.12))
                                    .frame(height: 3)
                                // Progress would be dynamic
                            }
                        }
                        .frame(height: 3)
                        .padding(.bottom, 4)

                        // Courses by category
                        ForEach(Array(groupedLessons.enumerated()), id: \.offset) { index, group in
                            let (category, categoryLessons) = group

                            ornamentalDivider

                            // Section header
                            VStack(alignment: .leading, spacing: 2) {
                                Text(category.latinName.uppercased())
                                    .font(.custom("Palatino-Italic", size: 12).weight(.semibold))
                                    .foregroundStyle(.sanctuaryRed)
                                    .tracking(3)
                                Text(category.displayName)
                                    .font(.custom("Palatino-Italic", size: 13))
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.bottom, 10)

                            // Lesson rows with Roman numerals
                            ForEach(categoryLessons) { lesson in
                                NavigationLink {
                                    CourseDetailView(courseSlug: lesson.slug)
                                } label: {
                                    HStack(alignment: .top, spacing: 12) {
                                        Text(romanNumeral(lesson.sortOrder))
                                            .font(.custom("Palatino", size: 22).weight(.light))
                                            .foregroundStyle(.sanctuaryRed.opacity(0.35))
                                            .frame(minWidth: 32, alignment: .trailing)

                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(lesson.title)
                                                .font(.custom("Palatino", size: 15).weight(.medium))
                                                .foregroundStyle(.ink)
                                            Text(lesson.latinTitle)
                                                .font(.custom("Palatino-Italic", size: 12))
                                                .foregroundStyle(.goldLeaf)
                                        }

                                        Spacer()

                                        VStack(spacing: 0) {
                                            Text("\(lesson.estimatedMinutes)")
                                                .font(.custom("Palatino", size: 16))
                                                .foregroundStyle(.sanctuaryRed)
                                            Text("min")
                                                .font(.system(size: 9))
                                                .foregroundStyle(.secondary)
                                        }
                                        .padding(.top, 4)
                                    }
                                    .padding(.vertical, 12)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .overlay(alignment: .bottom) {
                                        Rectangle()
                                            .fill(Color.goldLeaf.opacity(0.06))
                                            .frame(height: 1)
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        // Closing ornament
                        Text("✿ · ✿")
                            .frame(maxWidth: .infinity)
                            .font(.system(size: 12))
                            .foregroundStyle(.goldLeaf.opacity(0.4))
                            .tracking(8)
                            .padding(.vertical, 28)
                    }
                    .padding(.horizontal, 24)
                }
            }
            .background(Color.parchment)
            .navigationTitle("Learn")
            .onAppear { loadLessons() }
        }
    }

    private var ornamentalDivider: some View {
        HStack {
            Spacer()
            Rectangle()
                .frame(height: 1)
                .foregroundStyle(.clear)
                .background(
                    LinearGradient(
                        colors: [.clear, .goldLeaf.opacity(0.25), .clear],
                        startPoint: .leading, endPoint: .trailing
                    )
                )
            Spacer()
        }
        .padding(.vertical, 12)
    }

    private func loadLessons() {
        guard let url = Bundle.main.url(forResource: "lessons", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([LatinLesson].self, from: data) else { return }
        lessons = decoded
    }
}

#Preview {
    LearnView()
        .environmentObject(AppSettings())
}
