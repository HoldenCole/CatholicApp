import SwiftUI

struct TutorialView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var page = 0

    private let steps: [(icon: String, tab: String, title: String, desc: String)] = [
        ("sun.horizon", "Hódie", "Today",
         "Your daily liturgical companion. See today's feast, psalm, Mass propers, penance obligations, prayer rule progress, and patron saint streak. Everything updates automatically based on the 1962 calendar."),
        ("book.closed", "Missa", "The Missal",
         "Follow along at Mass with the complete 1962 Missale Romanum. The Ordinary and 422 daily Propers are interleaved in correct liturgical order, from the Prayers at the Foot of the Altar through the Last Gospel."),
        ("book.pages", "Orátio", "Prayers",
         "38 traditional prayers in Latin and English. Build a personal prayer rule with morning, midday, and evening schedules. Browse by occasion or set notifications to remind you to pray."),
        ("graduationcap", "Schola", "Latin School",
         "Learn Ecclesiastical Latin with 10 progressive lessons, 91 flashcards with phonetic pronunciation, and quizzes. Track your mastery and discover a new Latin word each day."),
        ("text.book.closed", "Liber", "Reference Library",
         "41 articles on Catholic doctrine, a searchable database of all 422 Mass propers, a timeline of the Traditional Latin Mass from the Last Supper to today, and a glossary of 25 liturgical terms."),
    ]

    var body: some View {
        VStack(spacing: 0) {
            TabView(selection: $page) {
                ForEach(Array(steps.enumerated()), id: \.offset) { idx, step in
                    stepPage(step, index: idx).tag(idx)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut, value: page)

            VStack(spacing: 14) {
                HStack(spacing: 8) {
                    ForEach(0..<steps.count, id: \.self) { i in
                        Circle()
                            .fill(i == page ? Color.sanctuaryRed : Color.frameLine)
                            .frame(width: 8, height: 8)
                    }
                }

                Button {
                    if page < steps.count - 1 {
                        withAnimation { page += 1 }
                    } else {
                        dismiss()
                    }
                } label: {
                    Text(page < steps.count - 1 ? "Next" : "Begin  ✠")
                        .font(.system(size: 14, weight: .semibold, design: .serif))
                        .italic()
                        .foregroundStyle(Color.ivory)
                        .tracking(2)
                        .padding(.vertical, 16)
                        .frame(maxWidth: .infinity)
                        .background(Color.sanctuaryRed)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 28)

                if page < steps.count - 1 {
                    Button { dismiss() } label: {
                        Text("Skip Tutorial")
                            .font(.captionSm)
                            .italic()
                            .foregroundStyle(Color.tertiaryText)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.bottom, 36)
        }
        .background(Color.pageBackground.ignoresSafeArea())
    }

    private func stepPage(_ step: (icon: String, tab: String, title: String, desc: String), index: Int) -> some View {
        ScrollView {
            VStack(spacing: 20) {
                Spacer(minLength: 50)

                ZStack {
                    Circle()
                        .fill(Color.sanctuaryRed)
                        .frame(width: 80, height: 80)
                    Image(systemName: step.icon)
                        .font(.system(size: 30))
                        .foregroundStyle(Color.ivory)
                }

                VStack(spacing: 6) {
                    Text(step.title)
                        .font(.system(size: 32, weight: .semibold, design: .serif))
                        .italic()
                        .foregroundStyle(Color.primaryText)
                    Text(step.tab)
                        .smallLabel(color: Color.goldLeaf)
                }

                Rectangle()
                    .fill(Color.goldLeaf.opacity(0.4))
                    .frame(width: 40, height: 1)

                Text(step.desc)
                    .font(.body)
                    .foregroundStyle(Color.secondaryText)
                    .lineSpacing(4)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 36)

                tabPreview(highlight: index)
                    .padding(.top, 16)

                Spacer(minLength: 40)
            }
        }
    }

    private func tabPreview(highlight: Int) -> some View {
        HStack(spacing: 0) {
            ForEach(Array(steps.enumerated()), id: \.offset) { idx, step in
                VStack(spacing: 4) {
                    Image(systemName: step.icon)
                        .font(.system(size: 16))
                    Text(step.tab)
                        .font(.system(size: 9, design: .serif))
                }
                .foregroundStyle(idx == highlight ? Color.sanctuaryRed : Color.tertiaryText)
                .frame(maxWidth: .infinity)
            }
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.pageBackground)
                .shadow(color: Color.ink.opacity(0.08), radius: 8, y: 2)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.frameLine, lineWidth: 0.5)
        )
        .padding(.horizontal, 40)
    }
}
