import SwiftUI

/// Reusable view for structured guides (Confession, TLM, etc.)
/// Loads JSON with title, introduction, and sections containing steps.
struct GuideView: View {
    let jsonFileName: String
    @State private var guideData: GuideData?

    var body: some View {
        ScrollView {
            if let guide = guideData {
                VStack(alignment: .leading, spacing: 0) {
                    // Dark header
                    VStack(alignment: .leading, spacing: 4) {
                        Text(guide.title)
                            .font(.custom("Palatino", size: 24).weight(.bold))
                            .foregroundStyle(.white)
                        if let latin = guide.latinTitle {
                            Text(latin)
                                .font(.custom("Palatino-Italic", size: 14))
                                .foregroundStyle(.goldLeaf)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 20)
                    .background(LinearGradient(colors: [Color(hex: "1C1410"), Color(hex: "2a2118")], startPoint: .top, endPoint: .bottom))

                    VStack(alignment: .leading, spacing: 0) {
                        ornamentalDivider

                        // Introduction
                        if let intro = guide.introduction {
                            Text(intro)
                                .font(.custom("Georgia-Italic", size: 15))
                                .foregroundStyle(.secondary)
                                .lineSpacing(5)
                                .padding(.vertical, 12)
                        }

                        // Sections
                        ForEach(Array(guide.sections.enumerated()), id: \.offset) { _, section in
                            ornamentalDivider
                            sectionView(section)
                        }

                        // Frequent confession note (if present)
                        if let freq = guide.frequentConfession {
                            ornamentalDivider
                            sectionLabel(freq.title, latin: nil)
                            Text(freq.content)
                                .font(.custom("Georgia", size: 15))
                                .foregroundStyle(.ink)
                                .lineSpacing(5)
                                .padding(.bottom, 12)
                        }

                        closingOrnament
                    }
                    .padding(.horizontal, 24)
                }
            } else {
                LoadingView()
            }
        }
        .background(Color.parchment)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { loadData() }
    }

    private func sectionView(_ section: GuideSectionData) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            sectionLabel(section.title, latin: section.latinTitle)

            if let steps = section.steps {
                ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                    HStack(alignment: .top, spacing: 14) {
                        // Step number
                        ZStack {
                            Circle()
                                .fill(Color.sanctuaryRed.opacity(0.1))
                                .frame(width: 28, height: 28)
                            Text("\(index + 1)")
                                .font(.custom("Palatino", size: 13).weight(.semibold))
                                .foregroundStyle(.sanctuaryRed)
                        }
                        .padding(.top, 2)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(step.title)
                                .font(.custom("Palatino", size: 16).weight(.semibold))
                                .foregroundStyle(.ink)
                            Text(step.content)
                                .font(.custom("Georgia", size: 15))
                                .foregroundStyle(.secondary)
                                .lineSpacing(5)
                        }
                    }
                    .padding(.vertical, 10)
                    .overlay(alignment: .bottom) {
                        Rectangle().fill(Color.goldLeaf.opacity(0.06)).frame(height: 1)
                    }
                }
            }

            if let items = section.items {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.title)
                            .font(.custom("Palatino", size: 16).weight(.semibold))
                            .foregroundStyle(.ink)
                        Text(item.content)
                            .font(.custom("Georgia", size: 15))
                            .foregroundStyle(.secondary)
                            .lineSpacing(5)
                    }
                    .padding(.vertical, 10)
                    .overlay(alignment: .bottom) {
                        Rectangle().fill(Color.goldLeaf.opacity(0.06)).frame(height: 1)
                    }
                }
            }
        }
    }

    // MARK: - Components

    private func sectionLabel(_ title: String, latin: String?) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title.uppercased())
                .font(.custom("Palatino-Italic", size: 12).weight(.semibold))
                .foregroundStyle(.sanctuaryRed)
                .tracking(3)
            if let latin {
                Text(latin)
                    .font(.custom("Palatino-Italic", size: 13))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.bottom, 12)
    }

    private var ornamentalDivider: some View {
        HStack { Spacer(); Rectangle().frame(height: 1).foregroundStyle(.clear).background(LinearGradient(colors: [.clear, .goldLeaf.opacity(0.25), .clear], startPoint: .leading, endPoint: .trailing)); Spacer() }.padding(.vertical, 12)
    }

    private var closingOrnament: some View {
        Text("✿ · ✿").frame(maxWidth: .infinity).font(.system(size: 12)).foregroundStyle(.goldLeaf.opacity(0.4)).tracking(8).padding(.vertical, 32)
    }

    private func loadData() {
        guard let url = Bundle.main.url(forResource: jsonFileName, withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode(GuideData.self, from: data) else { return }
        guideData = decoded
    }
}

// MARK: - Data Models
struct GuideData: Codable {
    let title: String
    let latinTitle: String?
    let introduction: String?
    let sections: [GuideSectionData]
    let frequentConfession: FrequentConfessionData?
}
struct GuideSectionData: Codable {
    let title: String
    let latinTitle: String?
    let steps: [GuideStepData]?
    let items: [GuideStepData]?
}
struct GuideStepData: Codable {
    let title: String
    let content: String
}
struct FrequentConfessionData: Codable {
    let title: String
    let content: String
}
