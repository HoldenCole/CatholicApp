import SwiftUI

/// Detail view for a saint — shown when tapping a saint in the selector.
/// Explains their spirituality so users can decide if it fits them.
struct SaintProfileView: View {
    let saint: SaintProfile

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Dark header
                VStack(alignment: .leading, spacing: 4) {
                    Text(saint.name)
                        .font(.custom("Palatino", size: 26).weight(.bold))
                        .foregroundStyle(.white)
                    Text(saint.title)
                        .font(.custom("Palatino-Italic", size: 14))
                        .foregroundStyle(.goldLeaf)
                    HStack(spacing: 12) {
                        Text(saint.feastDay)
                            .font(.custom("Georgia", size: 12))
                            .foregroundStyle(.white.opacity(0.4))
                        Text("·")
                            .foregroundStyle(.goldLeaf.opacity(0.3))
                        Text(saint.era)
                            .font(.custom("Georgia", size: 12))
                            .foregroundStyle(.white.opacity(0.4))
                    }
                    .padding(.top, 4)
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
                    ornamentalDivider

                    // Charism — the one-line summary
                    HStack(alignment: .top, spacing: 0) {
                        Rectangle()
                            .fill(Color.sanctuaryRed)
                            .frame(width: 3)
                            .padding(.trailing, 16)
                        Text(saint.charism)
                            .font(.custom("Georgia-Italic", size: 16))
                            .foregroundStyle(.ink)
                            .lineSpacing(5)
                    }
                    .padding(.vertical, 8)

                    ornamentalDivider

                    // Biography
                    sectionLabel("Who Was \(saint.name)?", latin: "Vita")
                    Text(saint.biography)
                        .font(.custom("Georgia", size: 16))
                        .foregroundStyle(.ink)
                        .lineSpacing(6)
                        .padding(.bottom, 16)

                    ornamentalDivider

                    // Best for
                    sectionLabel("This Path Is For You If...", latin: "Pro Te")
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(bestForItems, id: \.self) { item in
                            HStack(alignment: .top, spacing: 10) {
                                Text("·")
                                    .foregroundStyle(.sanctuaryRed)
                                Text(item)
                                    .font(.custom("Georgia", size: 15))
                                    .foregroundStyle(.ink)
                                    .lineSpacing(4)
                            }
                        }
                    }
                    .padding(.bottom, 16)

                    ornamentalDivider

                    // What you'll do each day
                    sectionLabel("Your Daily Rule", latin: "Regula Quotidiana")

                    let morningCount = saint.dailyPractices.filter { $0.timeOfDay == "morning" }.count
                    let dayCount = saint.dailyPractices.filter { $0.timeOfDay == "anytime" || $0.timeOfDay == "midday" }.count
                    let eveningCount = saint.dailyPractices.filter { $0.timeOfDay == "evening" }.count
                    let penanceCount = saint.penances?.count ?? 0

                    VStack(alignment: .leading, spacing: 6) {
                        ruleHighlight("\(saint.dailyPractices.count) daily practices")
                        if morningCount > 0 { ruleDetail("\(morningCount) morning practices") }
                        if dayCount > 0 { ruleDetail("\(dayCount) throughout the day") }
                        if eveningCount > 0 { ruleDetail("\(eveningCount) evening practices") }
                        if penanceCount > 0 { ruleDetail("\(penanceCount) penances") }
                    }
                    .padding(.bottom, 16)

                    // Key practices preview
                    ornamentalDivider
                    sectionLabel("Key Practices", latin: "Praxes Principales")

                    ForEach(Array(saint.dailyPractices.prefix(4).enumerated()), id: \.offset) { _, practice in
                        VStack(alignment: .leading, spacing: 2) {
                            Text(practice.title)
                                .font(.custom("Palatino", size: 15).weight(.medium))
                                .foregroundStyle(.ink)
                            Text(practice.description)
                                .font(.custom("Georgia", size: 13))
                                .foregroundStyle(.secondary)
                                .lineSpacing(3)
                                .lineLimit(2)
                        }
                        .padding(.vertical, 10)
                        .overlay(alignment: .bottom) {
                            Rectangle().fill(Color.goldLeaf.opacity(0.06)).frame(height: 1)
                        }
                    }

                    if saint.dailyPractices.count > 4 {
                        Text("+ \(saint.dailyPractices.count - 4) more practices")
                            .font(.custom("Palatino-Italic", size: 13))
                            .foregroundStyle(.goldLeaf)
                            .padding(.vertical, 8)
                    }

                    ornamentalDivider

                    // A quote to inspire
                    sectionLabel("In Their Words", latin: "Verbis Suis")
                    if let quote = saint.quotes.first {
                        HStack(alignment: .top, spacing: 0) {
                            Rectangle()
                                .fill(Color.goldLeaf)
                                .frame(width: 2)
                                .padding(.trailing, 16)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("\"\(quote.quote)\"")
                                    .font(.custom("Georgia-Italic", size: 16))
                                    .foregroundStyle(.ink)
                                    .lineSpacing(5)
                                Text("— \(saint.name)")
                                    .font(.custom("Palatino-Italic", size: 13))
                                    .foregroundStyle(.sanctuaryRed)
                            }
                        }
                        .padding(.bottom, 16)
                    }

                    // Follow button
                    NavigationLink {
                        SaintDailyView(saint: saint)
                    } label: {
                        Text("Follow \(saint.name)")
                            .font(.custom("Palatino", size: 16).weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color.sanctuaryRed)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }

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
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Best For items (derived from charism/practices)

    private var bestForItems: [String] {
        switch saint.slug {
        case "padre_pio":
            return [
                "You want an intense, deeply devotional prayer life",
                "You are drawn to the mystical tradition and offering suffering",
                "The Rosary and Eucharistic adoration speak to your heart",
                "You want to grow in the practice of frequent Confession"
            ]
        case "therese":
            return [
                "You feel called to holiness but think your life is too ordinary",
                "Grand penances intimidate you — you prefer small, hidden acts",
                "You struggle with prayer feeling dry or empty",
                "You want to grow in trust and childlike confidence in God"
            ]
        case "thomas_aquinas":
            return [
                "You love learning and want to deepen your understanding of the faith",
                "You believe the intellect is a gift to be used for God's glory",
                "You want a balance of study and contemplative prayer",
                "You are drawn to teaching others what you discover"
            ]
        case "benedict":
            return [
                "You thrive with structure and a predictable daily rhythm",
                "You want to sanctify both prayer time and work time equally",
                "Stability and perseverance are virtues you want to grow in",
                "You value silence, hospitality, and community"
            ]
        case "teresa_avila":
            return [
                "You want to go deep in interior prayer and contemplation",
                "You value honesty, humor, and practical common sense in spirituality",
                "You want to understand the stages of the spiritual life",
                "You are not afraid of a challenging, transformative path"
            ]
        case "escriva":
            return [
                "You are a layperson who wants holiness in the middle of the world",
                "You believe your professional work can be a path to God",
                "You want a structured 'plan of life' with concrete daily norms",
                "You value discipline, order, and sanctifying the ordinary"
            ]
        case "francis_de_sales":
            return [
                "You want a gentle, accessible approach to the spiritual life",
                "You are hard on yourself and need to learn patience with your faults",
                "You want holiness that fits your current state of life perfectly",
                "You are drawn to kindness, peace, and interior freedom"
            ]
        default:
            return ["This saint offers a unique path to holiness suited to your temperament and circumstances."]
        }
    }

    // MARK: - Components

    private func sectionLabel(_ title: String, latin: String) -> some View {
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

    private func ruleHighlight(_ text: String) -> some View {
        Text(text)
            .font(.custom("Palatino", size: 16).weight(.semibold))
            .foregroundStyle(.ink)
    }

    private func ruleDetail(_ text: String) -> some View {
        HStack(spacing: 8) {
            Text("·")
                .foregroundStyle(.goldLeaf)
            Text(text)
                .font(.custom("Georgia", size: 14))
                .foregroundStyle(.secondary)
        }
    }

    private var ornamentalDivider: some View {
        HStack {
            Spacer()
            Rectangle().frame(height: 1).foregroundStyle(.clear)
                .background(LinearGradient(colors: [.clear, .goldLeaf.opacity(0.25), .clear], startPoint: .leading, endPoint: .trailing))
            Spacer()
        }
        .padding(.vertical, 12)
    }
}
