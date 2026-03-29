import SwiftUI

struct MissalView: View {
    @EnvironmentObject private var appSettings: AppSettings
    @StateObject private var viewModel = MissalViewModel()
    @State private var showingMissalSelector = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    // Dark header with tappable missal selector
                    missalHeader

                    // Continuous Mass — all sections flow as one scroll
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(viewModel.groupedSections, id: \.0) { part, sections in
                            // Part divider
                            partHeader(part)

                            ForEach(sections) { section in
                                // Posture indicator
                                if let posture = section.posture {
                                    postureBar(posture)
                                }

                                // Section title
                                sectionHeader(section)

                                // Rubric
                                if !section.rubric.isEmpty {
                                    rubricBlock(section.rubric)
                                }

                                // Side-by-side Latin / English text
                                if !section.isProper {
                                    missalColumns(
                                        latin: section.latinText,
                                        english: section.englishText
                                    )
                                } else {
                                    properPlaceholder(section)
                                }

                                // Gold fade between sections
                                sectionDivider
                            }
                        }

                        // Closing ornament
                        Text("✿ · ✿")
                            .frame(maxWidth: .infinity)
                            .font(.system(size: 12))
                            .foregroundStyle(.goldLeaf.opacity(0.4))
                            .tracking(8)
                            .padding(.vertical, 32)
                    }
                    .padding(.horizontal, 20)
                }
            }
            .background(Color.parchment)
            .navigationTitle("Missal")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showingMissalSelector) {
                MissalSelectorSheet()
            }
            .onAppear {
                viewModel.loadSections()
            }
        }
    }

    // MARK: - Dark Header

    private var missalHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Ordo Missæ")
                        .font(.custom("Palatino", size: 26).weight(.bold))
                        .foregroundStyle(.white)

                    Text(Date().liturgicalDateString)
                        .font(.custom("Palatino-Italic", size: 14))
                        .foregroundStyle(.white.opacity(0.5))
                }

                Spacer()

                // Tappable missal rite selector
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
                    .padding(.vertical, 5)
                    .overlay(
                        RoundedRectangle(cornerRadius: 4)
                            .stroke(Color.goldLeaf.opacity(0.4), lineWidth: 1)
                    )
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
        .padding(.bottom, 20)
        .background(
            LinearGradient(
                colors: [Color(hex: "1C1410"), Color(hex: "2a2118")],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    // MARK: - Part Header

    private func partHeader(_ part: MassPart) -> some View {
        HStack {
            Spacer()
            VStack(spacing: 4) {
                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [.clear, .goldLeaf.opacity(0.3), .clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(height: 1)

                Text(part.latinName.uppercased())
                    .font(.custom("Palatino-Italic", size: 11).weight(.semibold))
                    .foregroundStyle(.sanctuaryRed)
                    .tracking(3)
                Text(part.displayName)
                    .font(.custom("Palatino-Italic", size: 12))
                    .foregroundStyle(.secondary)

                Rectangle()
                    .fill(
                        LinearGradient(
                            colors: [.clear, .goldLeaf.opacity(0.3), .clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(height: 1)
            }
            Spacer()
        }
        .padding(.vertical, 20)
    }

    // MARK: - Posture Bar

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
        .padding(.bottom, 8)
    }

    private func postureIcon(_ posture: String) -> String {
        switch posture {
        case "stand": return "figure.stand"
        case "sit": return "figure.seated.side.right"
        case "kneel": return "figure.mind.and.body"
        default: return "figure.stand"
        }
    }

    // MARK: - Section Header

    private func sectionHeader(_ section: MissalSection) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(section.latinTitle)
                .font(.custom("Palatino", size: 20).weight(.semibold))
                .foregroundStyle(.ink)
            Text(section.title)
                .font(.custom("Palatino-Italic", size: 14))
                .foregroundStyle(.secondary)
        }
        .padding(.bottom, 8)
    }

    // MARK: - Rubric

    private func rubricBlock(_ text: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "hand.point.right")
                .foregroundStyle(.sanctuaryRed)
                .font(.system(size: 12))

            Text(text)
                .font(.custom("Georgia-Italic", size: 13))
                .foregroundStyle(.sanctuaryRed.opacity(0.7))
                .lineSpacing(4)
        }
        .padding(.bottom, 12)
    }

    // MARK: - Side-by-Side Columns

    private func missalColumns(latin: String, english: String) -> some View {
        let latinLines = splitIntoLines(latin)
        let englishLines = splitIntoLines(english)
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
                .padding(.vertical, 6)
            }
        }
    }

    // MARK: - Proper Placeholder

    private func properPlaceholder(_ section: MissalSection) -> some View {
        VStack(spacing: 6) {
            Image(systemName: "calendar")
                .font(.system(size: 20))
                .foregroundStyle(.goldLeaf.opacity(0.4))
            Text("Proper — changes daily")
                .font(.custom("Palatino-Italic", size: 13))
                .foregroundStyle(.goldLeaf.opacity(0.6))
            Text("Consult your hand missal or parish bulletin for today's readings and propers.")
                .font(.custom("Georgia", size: 12))
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(Color.goldLeaf.opacity(0.03))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    // MARK: - Divider

    private var sectionDivider: some View {
        Rectangle()
            .fill(
                LinearGradient(
                    colors: [.clear, .goldLeaf.opacity(0.2), .clear],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .frame(height: 1)
            .padding(.vertical, 16)
    }

    // MARK: - Helpers

    private func splitIntoLines(_ text: String) -> [String] {
        text.components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }
}

#Preview {
    MissalView()
        .environmentObject(AppSettings())
}
