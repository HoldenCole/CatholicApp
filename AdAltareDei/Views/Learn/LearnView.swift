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

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppConstants.sectionSpacing) {
                    // Header
                    learnHeader

                    // AI badge
                    aiBadge

                    // Lesson categories
                    ForEach(groupedLessons, id: \.0) { category, categoryLessons in
                        VStack(alignment: .leading, spacing: AppConstants.itemSpacing) {
                            SectionHeaderView(
                                title: category.latinName,
                                subtitle: category.displayName
                            )
                            .padding(.horizontal)

                            ForEach(categoryLessons) { lesson in
                                NavigationLink {
                                    CourseDetailView(courseSlug: lesson.slug)
                                } label: {
                                    LessonRowView(lesson: lesson, isLocked: false)
                                }
                                .buttonStyle(.plain)
                                .padding(.horizontal)
                            }
                        }
                    }
                }
                .padding(.vertical)
            }
            .background(Color.parchment)
            .navigationTitle("Learn")
            .onAppear {
                loadLessons()
            }
        }
    }

    // MARK: - Header

    private var learnHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Discere Latínam")
                .font(.latinDisplay)
                .foregroundStyle(.ink)

            Text("Learn Ecclesiastical Latin")
                .font(.englishCaption)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal)
    }

    // MARK: - AI Badge

    private var aiBadge: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(Color.goldLeaf.opacity(0.15))
                    .frame(width: 48, height: 48)

                Image(systemName: "brain.head.profile")
                    .font(.system(size: 22))
                    .foregroundStyle(.goldLeaf)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text("AI-Powered Latin Tutor")
                    .font(.uiLabelLarge)
                    .foregroundStyle(.ink)

                Text("Personalized courses adapt to your skill level. Practice pronunciation, grammar, and reading with intelligent feedback.")
                    .font(.uiCaption)
                    .foregroundStyle(.secondary)
                    .lineSpacing(2)
            }
        }
        .padding()
        .background(Color.goldLeaf.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: AppConstants.cardCornerRadius))
        .padding(.horizontal)
    }

    private func loadLessons() {
        guard let url = Bundle.main.url(forResource: "lessons", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([LatinLesson].self, from: data) else {
            return
        }
        lessons = decoded
    }
}

// MARK: - Lesson Row

struct LessonRowView: View {
    let lesson: LatinLesson
    var isLocked: Bool = false

    var body: some View {
        HStack(spacing: 14) {
            // Category icon
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color.sanctuaryRed.opacity(0.08))
                    .frame(width: 44, height: 44)

                Image(systemName: lesson.category.icon)
                    .font(.system(size: 18))
                    .foregroundStyle(.sanctuaryRed)
            }

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(lesson.title)
                        .font(.uiLabel)
                        .foregroundStyle(isLocked ? .secondary : .ink)

                    if isLocked {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(.goldLeaf)
                    }
                }

                Text(lesson.description)
                    .font(.uiCaption)
                    .foregroundStyle(.tertiary)
                    .lineLimit(2)
            }

            Spacer()

            VStack(spacing: 2) {
                Text("\(lesson.estimatedMinutes)")
                    .font(.uiLabelLarge)
                    .foregroundStyle(isLocked ? .secondary : .sanctuaryRed)
                Text("min")
                    .font(.uiCaption)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding()
        .background(Color.warmWhite)
        .clipShape(RoundedRectangle(cornerRadius: AppConstants.cardCornerRadius))
        .shadow(color: .black.opacity(0.04), radius: 8, y: 2)
        .opacity(isLocked ? 0.85 : 1.0)
    }
}

#Preview {
    LearnView()
        .environmentObject(AppSettings())
}
