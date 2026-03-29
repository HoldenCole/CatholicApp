import SwiftUI

struct ReferenceDetailView: View {
    let entry: ReferenceEntry

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Header
                VStack(alignment: .leading, spacing: 4) {
                    Text(entry.title)
                        .font(.custom("Palatino", size: 28).weight(.bold))
                        .foregroundStyle(.ink)

                    Text(entry.latinTitle)
                        .font(.custom("Palatino-Italic", size: 16))
                        .foregroundStyle(.goldLeaf)

                    Text(entry.summary)
                        .font(.custom("Georgia-Italic", size: 15))
                        .foregroundStyle(.secondary)
                        .lineSpacing(4)
                        .padding(.top, 4)
                }
                .padding(.bottom, 8)

                ornamentalDivider

                // History
                section(title: "History", latin: "Historia", content: entry.history)

                ornamentalDivider

                // Explanation
                section(title: "What It Is", latin: "Explicatio", content: entry.explanation)

                // Practice (if available)
                if let practice = entry.practice {
                    ornamentalDivider
                    section(title: "How to Practice", latin: "Praxis", content: practice)
                }

                // Biblical Foundation (if available)
                if let refs = entry.scriptureRefs, !refs.isEmpty {
                    ornamentalDivider
                    VStack(alignment: .leading, spacing: 8) {
                        sectionHeader("Biblical Foundation", latin: "Fundamentum Biblicum")

                        if let explanation = entry.scriptureExplanation {
                            Text(explanation)
                                .font(.custom("Georgia", size: 16))
                                .foregroundStyle(.ink)
                                .lineSpacing(6)
                                .padding(.bottom, 4)
                        }

                        ForEach(refs, id: \.self) { ref in
                            HStack(alignment: .top, spacing: 8) {
                                Text("·")
                                    .foregroundStyle(.goldLeaf)
                                Text(ref)
                                    .font(.custom("Palatino-Italic", size: 15))
                                    .foregroundStyle(.ink)
                            }
                        }
                    }
                    .padding(.vertical, 16)
                }

                // Theologians (if available)
                if let quotes = entry.theologianQuotes, !quotes.isEmpty {
                    ornamentalDivider
                    VStack(alignment: .leading, spacing: 12) {
                        sectionHeader("The Theologians", latin: "Doctores Ecclesiæ")

                        ForEach(Array(quotes.enumerated()), id: \.offset) { _, quote in
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(alignment: .top, spacing: 0) {
                                    Rectangle()
                                        .fill(Color.sanctuaryRed)
                                        .frame(width: 3)
                                        .padding(.trailing, 16)

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text("\"\(quote.quote)\"")
                                            .font(.custom("Georgia-Italic", size: 15))
                                            .foregroundStyle(.ink)
                                            .lineSpacing(4)
                                        HStack(spacing: 4) {
                                            Text("—")
                                                .foregroundStyle(.sanctuaryRed)
                                            Text(quote.author)
                                                .font(.custom("Palatino-Italic", size: 13))
                                                .foregroundStyle(.sanctuaryRed)
                                            if let source = quote.source {
                                                Text("·")
                                                    .foregroundStyle(.goldLeaf)
                                                Text(source)
                                                    .font(.custom("Palatino-Italic", size: 12))
                                                    .foregroundStyle(.secondary)
                                            }
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(.vertical, 16)
                }

                // Church Teaching (if available)
                if let teaching = entry.churchTeaching {
                    ornamentalDivider
                    section(title: "Church Teaching", latin: "Magisterium", content: teaching)
                }

                // Closing ornament
                Text("✿ · ✿")
                    .frame(maxWidth: .infinity)
                    .font(.system(size: 12))
                    .foregroundStyle(.goldLeaf.opacity(0.4))
                    .tracking(8)
                    .padding(.vertical, 32)
            }
            .padding(.horizontal, 24)
        }
        .background(Color.parchment)
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Components

    private func section(title: String, latin: String, content: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionHeader(title, latin: latin)

            Text(content)
                .font(.custom("Georgia", size: 16))
                .foregroundStyle(.ink)
                .lineSpacing(6)
        }
        .padding(.vertical, 16)
    }

    private func sectionHeader(_ title: String, latin: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(title.uppercased())
                .font(.custom("Palatino-Italic", size: 12).weight(.semibold))
                .foregroundStyle(.sanctuaryRed)
                .tracking(3)
            Text(latin)
                .font(.custom("Palatino-Italic", size: 12))
                .foregroundStyle(.secondary)
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
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
            Spacer()
        }
    }
}
