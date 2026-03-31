import SwiftUI

/// Daily view for following a saint's practices — checkboxes, quote, progress.
struct SaintDailyView: View {
    let saint: SaintProfile
    @State private var completedPractices: Set<String> = []
    @State private var dailyQuote: SaintQuote?

    /// UserDefaults key for today's completed practices for this saint
    private var storageKey: String {
        "saint_\(saint.slug)_\(Date().dateKey)"
    }

    private func loadCompleted() {
        if let saved = UserDefaults.standard.array(forKey: storageKey) as? [String] {
            completedPractices = Set(saved)
        }
    }

    private func saveCompleted() {
        UserDefaults.standard.set(Array(completedPractices), forKey: storageKey)
    }

    private var progress: Double {
        guard !saint.dailyPractices.isEmpty else { return 0 }
        return Double(completedPractices.count) / Double(saint.dailyPractices.count)
    }

    private var morningPractices: [SaintPractice] {
        saint.dailyPractices.filter { $0.timeOfDay == "morning" }
    }
    private var daytimePractices: [SaintPractice] {
        saint.dailyPractices.filter { $0.timeOfDay == "anytime" || $0.timeOfDay == "midday" }
    }
    private var eveningPractices: [SaintPractice] {
        saint.dailyPractices.filter { $0.timeOfDay == "evening" }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                // Dark header with saint info
                VStack(alignment: .leading, spacing: 4) {
                    Text(saint.name)
                        .font(.custom("Palatino", size: 24).weight(.bold))
                        .foregroundStyle(.white)
                    Text(saint.title)
                        .font(.custom("Palatino-Italic", size: 13))
                        .foregroundStyle(.goldLeaf)

                    // Progress bar
                    HStack {
                        Text("\(completedPractices.count) of \(saint.dailyPractices.count)")
                            .font(.custom("Palatino-Italic", size: 11))
                            .foregroundStyle(.white.opacity(0.5))
                        Spacer()
                        Text("\(Int(progress * 100))%")
                            .font(.custom("Palatino", size: 11).weight(.semibold))
                            .foregroundStyle(.goldLeaf)
                    }
                    .padding(.top, 8)

                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color.goldLeaf.opacity(0.15))
                                .frame(height: 4)
                            RoundedRectangle(cornerRadius: 2)
                                .fill(
                                    LinearGradient(
                                        colors: [.sanctuaryRed, .goldLeaf],
                                        startPoint: .leading, endPoint: .trailing
                                    )
                                )
                                .frame(width: geo.size.width * progress, height: 4)
                                .animation(.spring(response: 0.4), value: progress)
                        }
                    }
                    .frame(height: 4)
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
                    // Daily quote
                    if let quote = dailyQuote {
                        quoteView(quote)
                    }

                    ornamentalDivider

                    // Morning practices
                    if !morningPractices.isEmpty {
                        practiceSection("Morning", latin: "Mane", practices: morningPractices)
                    }

                    // Daytime practices
                    if !daytimePractices.isEmpty {
                        ornamentalDivider
                        practiceSection("Throughout the Day", latin: "Per Diem", practices: daytimePractices)
                    }

                    // Evening practices
                    if !eveningPractices.isEmpty {
                        ornamentalDivider
                        practiceSection("Evening", latin: "Vespere", practices: eveningPractices)
                    }

                    // Penances (if any)
                    if let penances = saint.penances, !penances.isEmpty {
                        ornamentalDivider
                        practiceSection("Penances", latin: "Pænitentiæ", practices: penances)
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
        .onAppear {
            let dayOfYear = Calendar.current.ordinality(of: .day, in: .year, for: Date()) ?? 0
            let index = dayOfYear % saint.quotes.count
            dailyQuote = saint.quotes[index]
            loadCompleted()
        }
    }

    // MARK: - Quote

    private func quoteView(_ quote: SaintQuote) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .top, spacing: 0) {
                Rectangle()
                    .fill(Color.goldLeaf)
                    .frame(width: 2)
                    .padding(.trailing, 16)

                VStack(alignment: .leading, spacing: 4) {
                    Text("TODAY'S WORD")
                        .font(.custom("Palatino-Italic", size: 10))
                        .foregroundStyle(.goldLeaf)
                        .tracking(2)

                    Text("\"\(quote.quote)\"")
                        .font(.custom("Georgia-Italic", size: 16))
                        .foregroundStyle(.ink)
                        .lineSpacing(5)

                    Text("— \(saint.name)")
                        .font(.custom("Palatino-Italic", size: 13))
                        .foregroundStyle(.sanctuaryRed)
                }
            }
        }
        .padding(.vertical, 16)
    }

    // MARK: - Practice Section

    private func practiceSection(_ title: String, latin: String, practices: [SaintPractice]) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title.uppercased())
                    .font(.custom("Palatino-Italic", size: 12).weight(.semibold))
                    .foregroundStyle(.sanctuaryRed)
                    .tracking(3)
                Text(latin)
                    .font(.custom("Palatino-Italic", size: 13))
                    .foregroundStyle(.secondary)
            }
            .padding(.bottom, 10)

            ForEach(practices) { practice in
                practiceRow(practice)
            }
        }
    }

    private func practiceRow(_ practice: SaintPractice) -> some View {
        let isCompleted = completedPractices.contains(practice.slug)

        return Button {
            withAnimation(.spring(response: 0.3)) {
                if isCompleted {
                    completedPractices.remove(practice.slug)
                } else {
                    completedPractices.insert(practice.slug)
                }
                saveCompleted()
            }
        } label: {
            HStack(alignment: .top, spacing: 14) {
                // Checkbox
                ZStack {
                    RoundedRectangle(cornerRadius: 4)
                        .stroke(isCompleted ? Color.comfortMastered : Color.goldLeaf.opacity(0.3), lineWidth: 1.5)
                        .frame(width: 22, height: 22)

                    if isCompleted {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.comfortMastered)
                            .frame(width: 22, height: 22)
                        Image(systemName: "checkmark")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundStyle(.white)
                    }
                }
                .padding(.top, 2)

                VStack(alignment: .leading, spacing: 3) {
                    Text(practice.title)
                        .font(.custom("Palatino", size: 16).weight(.medium))
                        .foregroundStyle(isCompleted ? .secondary : .ink)
                        .strikethrough(isCompleted, color: .secondary)

                    Text(practice.description)
                        .font(.custom("Georgia", size: 13))
                        .foregroundStyle(.secondary)
                        .lineSpacing(3)
                        .lineLimit(isCompleted ? 1 : nil)
                }
            }
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .overlay(alignment: .bottom) {
                Rectangle()
                    .fill(Color.goldLeaf.opacity(0.06))
                    .frame(height: 1)
            }
        }
    }

    private var ornamentalDivider: some View {
        HStack {
            Spacer()
            Rectangle().frame(height: 1).foregroundStyle(.clear)
                .background(LinearGradient(colors: [.clear, .goldLeaf.opacity(0.25), .clear], startPoint: .leading, endPoint: .trailing))
            Text("✟").font(.system(size: 11)).foregroundStyle(.goldLeaf.opacity(0.5))
            Rectangle().frame(height: 1).foregroundStyle(.clear)
                .background(LinearGradient(colors: [.clear, .goldLeaf.opacity(0.25), .clear], startPoint: .leading, endPoint: .trailing))
            Spacer()
        }
        .padding(.vertical, 14)
    }
}
