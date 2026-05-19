import SwiftUI

struct TutorialView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var page = 0

    private let steps: [(icon: String, title: String, items: [(String, String)])] = [
        ("sun.horizon", "Today", [
            ("calendar", "Your daily liturgical companion with feast day, season, and liturgical colour"),
            ("book.closed", "Tap the Propers card to read today's Epistle and Gospel"),
            ("person.fill", "Follow a patron saint and track your daily practices with streaks"),
            ("cross.fill", "Penance obligations shown automatically based on the 1962 calendar"),
            ("hands.sparkles", "Prayer rule progress and devotion links update throughout the day"),
        ]),
        ("book.closed", "The Missal", [
            ("text.book.closed", "Complete 1962 Missale Romanum with 428 daily Propers"),
            ("arrow.up.arrow.down", "Ordinary and Propers interleaved in correct liturgical order"),
            ("list.bullet", "Full Offertory prayers, Preface, Canon, and Last Gospel included"),
            ("square.and.arrow.up", "Tap the share icon to save or send any proper as text"),
            ("globe", "Switch between Latin, English, or side-by-side in Settings"),
        ]),
        ("book.pages", "Prayers", [
            ("checkmark.circle", "Build a personal prayer rule for morning, midday, and evening"),
            ("bell", "Tap the bell icon to set notification reminders for any prayer"),
            ("magnifyingglass", "Search prayers by name in the library"),
            ("square.grid.2x2", "Browse 12 occasion categories: Before Mass, During Mass, Marian, and more"),
            ("arrow.up.arrow.down", "Sort your library by custom order or A-Z"),
        ]),
        ("gearshape", "Settings", [
            ("book.closed", "Choose your Missal rite: 1962, 1955, or pre-1955 rubrics"),
            ("cross.fill", "Select penance discipline: 1962, 1917, or stricter pre-Pius XII"),
            ("globe", "Display language: Latin and English, Latin only, or English only"),
            ("paintbrush", "Three themes: Parchment, Clean White, and Dark Walnut"),
            ("textformat.size", "Adjust text size with the font scale slider"),
        ]),
        ("star", "More Features", [
            ("rosette", "Interactive bead-by-bead Rosary with three traditional mystery sets"),
            ("cross", "14 Stations of the Cross with meditations and Stabat Mater"),
            ("clock", "All 8 canonical hours of the 1962 Divine Office"),
            ("graduationcap", "Learn Latin with 10 lessons, 91 flashcards, and quizzes"),
            ("heart", "Confession guide with examination of conscience"),
        ]),
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
                    Text(page < steps.count - 1 ? "Next" : "Introíbo ad altáre Dei  ✠")
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

    private func stepPage(_ step: (icon: String, title: String, items: [(String, String)]), index: Int) -> some View {
        ScrollView {
            VStack(spacing: 20) {
                Spacer(minLength: 30)

                ZStack {
                    Circle()
                        .fill(Color.sanctuaryRed)
                        .frame(width: 72, height: 72)
                    Image(systemName: step.icon)
                        .font(.system(size: 28))
                        .foregroundStyle(Color.ivory)
                }

                Text(step.title)
                    .font(.system(size: 30, weight: .semibold, design: .serif))
                    .italic()
                    .foregroundStyle(Color.primaryText)

                Rectangle()
                    .fill(Color.goldLeaf.opacity(0.4))
                    .frame(width: 40, height: 1)

                VStack(alignment: .leading, spacing: 16) {
                    ForEach(Array(step.items.enumerated()), id: \.offset) { _, item in
                        HStack(alignment: .top, spacing: 14) {
                            Image(systemName: item.0)
                                .font(.system(size: 16))
                                .foregroundStyle(Color.sanctuaryRed)
                                .frame(width: 24, alignment: .center)
                                .padding(.top, 2)
                            Text(item.1)
                                .font(.body)
                                .foregroundStyle(Color.secondaryText)
                                .lineSpacing(3)
                        }
                    }
                }
                .padding(.horizontal, 32)

                Spacer(minLength: 30)
            }
        }
    }
}
