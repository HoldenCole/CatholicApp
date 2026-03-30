import SwiftUI

/// Displays the actual prayers for a Divine Office hour as a continuous scroll,
/// similar to the Missal view — Latin on left, English on right.
struct OfficeHourPrayerView: View {
    let hourSlug: String
    let hourTitle: String
    @State private var officeData: OfficeHourData?

    var body: some View {
        ScrollView {
            if let office = officeData {
                VStack(alignment: .leading, spacing: 0) {
                    // Dark header
                    VStack(alignment: .leading, spacing: 4) {
                        Text(office.title)
                            .font(.custom("Palatino", size: 26).weight(.bold))
                            .foregroundStyle(.white)
                        Text(office.latinTitle)
                            .font(.custom("Palatino-Italic", size: 14))
                            .foregroundStyle(.goldLeaf)
                        Text(office.description)
                            .font(.custom("Georgia-Italic", size: 13))
                            .foregroundStyle(.white.opacity(0.4))
                            .lineSpacing(3)
                            .padding(.top, 2)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 20)
                    .background(
                        LinearGradient(
                            colors: [Color(hex: "1C1410"), Color(hex: "2a2118")],
                            startPoint: .top, endPoint: .bottom
                        )
                    )

                    // Sections flow continuously
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(Array(office.sections.enumerated()), id: \.offset) { _, section in
                            officeSectionView(section)
                        }

                        Text("✿ · ✿")
                            .frame(maxWidth: .infinity)
                            .font(.system(size: 12))
                            .foregroundStyle(.goldLeaf.opacity(0.4))
                            .tracking(8)
                            .padding(.vertical, 32)
                    }
                    .padding(.horizontal, 20)
                }
            } else {
                LoadingView(message: "Loading \(hourTitle)...")
            }
        }
        .background(Color.parchment)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { loadOffice() }
    }

    @ViewBuilder
    private func officeSectionView(_ section: OfficeSectionData) -> some View {
        // Posture indicator
        if let posture = section.posture {
            postureBar(posture)
                .padding(.top, 16)
        }

        // Section title
        VStack(alignment: .leading, spacing: 2) {
            Text(section.title)
                .font(.custom("Palatino", size: 19).weight(.semibold))
                .foregroundStyle(.ink)
        }
        .padding(.top, section.posture == nil ? 16 : 8)
        .padding(.bottom, 4)

        // Rubric
        if let rubric = section.rubric {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "hand.point.right")
                    .foregroundStyle(.sanctuaryRed)
                    .font(.system(size: 12))
                Text(rubric)
                    .font(.custom("Georgia-Italic", size: 13))
                    .foregroundStyle(.sanctuaryRed.opacity(0.7))
                    .lineSpacing(4)
            }
            .padding(.bottom, 8)
        }

        // Side-by-side text (or proper placeholder)
        if let isProper = section.isProper, isProper {
            properPlaceholder
        } else {
            missalColumns(latin: section.latinText, english: section.englishText)
        }

        // Gold divider
        sectionDivider
    }

    // MARK: - Components

    private func postureBar(_ posture: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: postureIcon(posture))
                .font(.system(size: 11))
                .foregroundStyle(.goldLeaf)
            Text(posture.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.goldLeaf)
                .tracking(1.5)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 12)
        .background(Color.goldLeaf.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 4))
    }

    private func postureIcon(_ posture: String) -> String {
        switch posture {
        case "stand": return "figure.stand"
        case "sit": return "figure.seated.side.right"
        case "kneel": return "figure.mind.and.body"
        default: return "figure.stand"
        }
    }

    private func missalColumns(latin: String, english: String) -> some View {
        let latinLines = latin.components(separatedBy: "\n").filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        let englishLines = english.components(separatedBy: "\n").filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        let lineCount = max(latinLines.count, englishLines.count)

        return VStack(spacing: 0) {
            ForEach(0..<lineCount, id: \.self) { index in
                HStack(alignment: .top, spacing: 0) {
                    Text(index < latinLines.count ? latinLines[index] : "")
                        .font(.custom("Palatino", size: 15))
                        .foregroundStyle(.ink)
                        .lineSpacing(5)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.trailing, 10)

                    Rectangle()
                        .fill(Color.goldLeaf.opacity(0.2))
                        .frame(width: 1)

                    Text(index < englishLines.count ? englishLines[index] : "")
                        .font(.custom("Georgia", size: 15))
                        .foregroundStyle(.secondary)
                        .lineSpacing(5)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading, 10)
                }
                .padding(.vertical, 4)
            }
        }
    }

    private var properPlaceholder: some View {
        VStack(spacing: 6) {
            Image(systemName: "calendar")
                .font(.system(size: 20))
                .foregroundStyle(.goldLeaf.opacity(0.4))
            Text("Proper — changes daily")
                .font(.custom("Palatino-Italic", size: 13))
                .foregroundStyle(.goldLeaf.opacity(0.6))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(Color.goldLeaf.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var sectionDivider: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [.clear, .goldLeaf.opacity(0.2), .clear],
                    startPoint: .leading, endPoint: .trailing
                )
            )
            .frame(height: 1)
            .padding(.vertical, 12)
    }

    // MARK: - Load

    private func loadOffice() {
        let fileName = "divine_office_\(hourSlug)"
        guard let url = Bundle.main.url(forResource: fileName, withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([OfficeHourData].self, from: data),
              let first = decoded.first else {
            return
        }
        officeData = first
    }
}

// MARK: - Data Models

struct OfficeHourData: Codable {
    let hour: String
    let title: String
    let latinTitle: String
    let time: String?
    let description: String
    let sections: [OfficeSectionData]
}

struct OfficeSectionData: Codable {
    let slug: String
    let title: String
    let rubric: String?
    let latinText: String
    let englishText: String
    let posture: String?
    let isProper: Bool?
}
