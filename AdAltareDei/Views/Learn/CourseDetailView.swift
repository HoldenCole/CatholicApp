import SwiftUI

/// Displays the actual educational content of a Learn course.
struct CourseDetailView: View {
    let courseSlug: String
    @State private var courseData: CourseData?

    var body: some View {
        ScrollView {
            if let course = courseData {
                VStack(alignment: .leading, spacing: 0) {
                    // Dark header
                    VStack(alignment: .leading, spacing: 4) {
                        Text(course.title)
                            .font(.custom("Palatino", size: 26).weight(.bold))
                            .foregroundStyle(.white)
                        Text(course.latinTitle)
                            .font(.custom("Palatino-Italic", size: 14))
                            .foregroundStyle(.goldLeaf)
                        Text("\(course.estimatedMinutes) min")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.white.opacity(0.4))
                            .padding(.top, 2)
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

                    // Course sections
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(course.sections.enumerated()), id: \.offset) { _, section in
                            courseSectionView(section)
                        }

                        Text("✿ · ✿")
                            .frame(maxWidth: .infinity)
                            .font(.system(size: 12))
                            .foregroundStyle(.goldLeaf.opacity(0.4))
                            .tracking(8)
                            .padding(.vertical, 32)
                    }
                    .padding(.horizontal, 24)
                }
            } else {
                LoadingView(message: "Loading course...")
            }
        }
        .background(Color.parchment)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { loadCourse() }
    }

    @ViewBuilder
    private func courseSectionView(_ section: CourseSection) -> some View {
        switch section.type {
        case "intro":
            ornamentalDivider
            Text(section.content ?? "")
                .font(.custom("Georgia-Italic", size: 16))
                .foregroundStyle(.secondary)
                .lineSpacing(6)
                .padding(.vertical, 16)

        case "lesson":
            ornamentalDivider
            if let title = section.title {
                VStack(alignment: .leading, spacing: 2) {
                    Text(title.uppercased())
                        .font(.custom("Palatino-Italic", size: 12).weight(.semibold))
                        .foregroundStyle(.sanctuaryRed)
                        .tracking(3)
                }
                .padding(.bottom, 10)
            }
            Text(section.content ?? "")
                .font(.custom("Georgia", size: 16))
                .foregroundStyle(.ink)
                .lineSpacing(6)
                .padding(.bottom, 16)

        case "tip":
            HStack(alignment: .top, spacing: 0) {
                Rectangle()
                    .fill(Color.goldLeaf)
                    .frame(width: 3)
                    .padding(.trailing, 16)
                Text(section.content ?? "")
                    .font(.custom("Georgia-Italic", size: 15))
                    .foregroundStyle(.secondary)
                    .lineSpacing(5)
            }
            .padding(.vertical, 12)

        case "practice":
            ornamentalDivider
            if let title = section.title {
                Text(title.uppercased())
                    .font(.custom("Palatino-Italic", size: 12).weight(.semibold))
                    .foregroundStyle(.sanctuaryRed)
                    .tracking(3)
                    .padding(.bottom, 10)
            }
            if let items = section.items {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    VStack(alignment: .leading, spacing: 3) {
                        Text(item.latin)
                            .font(.custom("Palatino", size: 16).weight(.medium))
                            .foregroundStyle(.ink)
                        if let phonetic = item.phonetic {
                            Text(phonetic)
                                .font(.custom("Palatino-Italic", size: 14))
                                .foregroundStyle(.sanctuaryRed)
                        }
                        Text(item.meaning)
                            .font(.custom("Georgia", size: 13))
                            .foregroundStyle(.secondary)
                        if let note = item.note ?? item.rule ?? item.rules {
                            Text(note)
                                .font(.custom("Georgia-Italic", size: 12))
                                .foregroundStyle(.goldLeaf)
                        }
                    }
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .overlay(alignment: .bottom) {
                        Rectangle()
                            .fill(Color.goldLeaf.opacity(0.08))
                            .frame(height: 1)
                    }
                }
            }

        case "summary":
            ornamentalDivider
            Text("SUMMARY")
                .font(.custom("Palatino-Italic", size: 12).weight(.semibold))
                .foregroundStyle(.sanctuaryRed)
                .tracking(3)
                .padding(.bottom, 8)
            Text(section.content ?? "")
                .font(.custom("Georgia", size: 16))
                .foregroundStyle(.ink)
                .lineSpacing(6)
                .padding(.bottom, 16)

        default:
            EmptyView()
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
        .padding(.vertical, 4)
    }

    private func loadCourse() {
        let fileName = "course_\(courseSlug)"
        guard let url = Bundle.main.url(forResource: fileName, withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode(CourseData.self, from: data) else {

            // Try numbered format
            for i in 1...10 {
                let numbered = String(format: "course_%02d", i)
                if let url = Bundle.main.url(forResource: numbered, withExtension: "json"),
                   let data = try? Data(contentsOf: url),
                   let decoded = try? JSONDecoder().decode(CourseData.self, from: data),
                   decoded.slug == courseSlug {
                    courseData = decoded
                    return
                }
            }
            return
        }
        courseData = decoded
    }
}

// MARK: - Course Data Models

struct CourseData: Codable {
    let slug: String
    let title: String
    let latinTitle: String
    let courseNumber: Int
    let estimatedMinutes: Int
    let sections: [CourseSection]
}

struct CourseSection: Codable {
    let type: String
    let title: String?
    let content: String?
    let items: [PracticeItem]?
}

struct PracticeItem: Codable {
    let latin: String
    let phonetic: String?
    let meaning: String
    let note: String?
    let rule: String?
    let rules: String?
}
