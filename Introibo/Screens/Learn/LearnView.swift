import SwiftUI

// The Schola tab — Schola Latina. 10 Latin lessons from vowels through
// reading the Vulgate. Tracks mastery. Mirrors prototype/learn.html.

struct LearnView: View {
    @State private var store = ContentStore.shared
    @State private var selection: Course?
    @State private var mastered: Set<String> = UserProgress.masteredLessons()
    @AppStorage(SettingsKey.theme) private var themeRaw = AppTheme.parchment.rawValue

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    progressBanner
                    ForEach(store.courses) { course in
                        Button { selection = course } label: {
                            lessonRow(course)
                        }
                        .buttonStyle(.plain)
                        if course.slug != store.courses.last?.slug {
                            Divider().background(Color.frameLine.opacity(0.5))
                        }
                    }
                }
                .padding(.horizontal, 28)
                .padding(.vertical, 24)
            }
            .background(Color.pageBackground.ignoresSafeArea())
            .navigationTitle("Schola Latína")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(item: $selection) { course in
                CourseDetailView(course: course, onMasteryChange: {
                    mastered = UserProgress.masteredLessons()
                })
            }
        }
    }

    private var progressBanner: some View {
        VStack(spacing: 4) {
            Text("Mastered")
                .smallLabel(color: Color.sanctuaryRed)
            Text("\(mastered.count)  /  10")
                .font(.system(size: 38, weight: .semibold, design: .serif))
                .italic()
                .foregroundStyle(Color.primaryText)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 18)
        .overlay(Rectangle().stroke(Color.frameLine, lineWidth: 0.5))
    }

    private func lessonRow(_ c: Course) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Text(roman(c.num))
                .font(.titleL)
                .italic()
                .foregroundStyle(Color.sanctuaryRed)
                .frame(width: 40, alignment: .leading)

            VStack(alignment: .leading, spacing: 2) {
                Text(c.title)
                    .font(.titleM)
                    .italic()
                    .foregroundStyle(Color.primaryText)
                Text(c.latin)
                    .font(.captionSm)
                    .italic()
                    .foregroundStyle(Color.secondaryText)
            }

            Spacer()
            if mastered.contains(c.slug) {
                Image(systemName: "checkmark.seal")
                    .foregroundStyle(Color.goldLeaf)
                    .font(.system(size: 18))
            }
        }
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }

    private func roman(_ n: Int) -> String {
        ["","I","II","III","IV","V","VI","VII","VIII","IX","X"][n]
    }
}

#Preview { LearnView() }
