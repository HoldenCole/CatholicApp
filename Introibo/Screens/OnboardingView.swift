import SwiftUI

struct OnboardingView: View {
    @Binding var hasCompletedOnboarding: Bool
    @State private var page = 0

    var body: some View {
        VStack(spacing: 0) {
            // Page content
            TabView(selection: $page) {
                welcomePage.tag(0)
                traditionPage.tag(1)
                featuresPage.tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(.easeInOut, value: page)

            // Page dots + button
            VStack(spacing: 16) {
                // Dots
                HStack(spacing: 8) {
                    ForEach(0..<3, id: \.self) { i in
                        Circle()
                            .fill(i == page ? Color.sanctuaryRed : Color.frameLine)
                            .frame(width: 8, height: 8)
                    }
                }

                // Button
                Button {
                    if page < 2 {
                        withAnimation { page += 1 }
                    } else {
                        hasCompletedOnboarding = true
                    }
                } label: {
                    Text(page < 2 ? "Continue" : "Introíbo ad altáre Dei  ✠")
                        .font(.system(size: 14, weight: .semibold, design: .serif))
                        .italic()
                        .foregroundStyle(Color.ivory)
                        .tracking(2)
                        .padding(.vertical, 18)
                        .frame(maxWidth: .infinity)
                        .background(Color.sanctuaryRed)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 28)

                // Skip (on first two pages only)
                if page < 2 {
                    Button {
                        hasCompletedOnboarding = true
                    } label: {
                        Text("Skip")
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

    // MARK: - Page 1: Welcome

    private var welcomePage: some View {
        ScrollView {
            VStack(spacing: 20) {
                Spacer(minLength: 60)

                // Monstrance icon
                monstranceIcon
                    .frame(width: 100, height: 100)

                // Title
                VStack(spacing: 8) {
                    Text("Introíbo")
                        .font(.system(size: 44, weight: .semibold, design: .serif))
                        .italic()
                        .foregroundStyle(Color.primaryText)
                    Text("Ad altáre Dei")
                        .font(.caption)
                        .italic()
                        .foregroundStyle(Color.secondaryText)
                        .textCase(.uppercase)
                        .tracking(3)
                    Rectangle()
                        .fill(Color.sanctuaryRed.opacity(0.4))
                        .frame(width: 40, height: 1)
                        .padding(.top, 8)
                }

                Text("A prayer companion for\ntraditional Catholics")
                    .font(.titleM)
                    .italic()
                    .foregroundStyle(Color.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.top, 8)

                // Principles
                HStack(spacing: 16) {
                    VStack(spacing: 6) {
                        Text("Ad free")
                            .font(.captionSm)
                            .italic()
                            .foregroundStyle(Color.primaryText)
                        Text("Latin first")
                            .font(.captionSm)
                            .italic()
                            .foregroundStyle(Color.primaryText)
                    }
                    Rectangle()
                        .fill(Color.goldLeaf.opacity(0.3))
                        .frame(width: 0.5, height: 30)
                    VStack(spacing: 6) {
                        Text("1962 Calendar")
                            .font(.captionSm)
                            .italic()
                            .foregroundStyle(Color.primaryText)
                        Text("Works offline")
                            .font(.captionSm)
                            .italic()
                            .foregroundStyle(Color.primaryText)
                    }
                }
                .padding(.top, 20)

                Spacer(minLength: 40)
            }
        }
    }

    // MARK: - Page 2: Tradition First

    private var traditionPage: some View {
        ScrollView {
            VStack(spacing: 20) {
                Spacer(minLength: 60)

                Text("✠")
                    .font(.system(size: 48))
                    .foregroundStyle(Color.sanctuaryRed)

                Text("Tradition First")
                    .font(.system(size: 34, weight: .semibold, design: .serif))
                    .italic()
                    .foregroundStyle(Color.primaryText)

                Rectangle()
                    .fill(Color.sanctuaryRed.opacity(0.4))
                    .frame(width: 40, height: 1)

                VStack(alignment: .leading, spacing: 18) {
                    traditionRow(
                        title: "The 1962 Missal",
                        desc: "Every prayer, rubric, and response of the Traditional Latin Mass. No Novus Ordo."
                    )
                    traditionRow(
                        title: "The Roman Breviary",
                        desc: "All eight canonical hours as they were prayed before the reforms. Not the Liturgy of the Hours."
                    )
                    traditionRow(
                        title: "Latin Always",
                        desc: "Every prayer in Ecclesiastical Latin with faithful English translation. Latin is never hidden or secondary."
                    )
                    traditionRow(
                        title: "No Luminous Mysteries",
                        desc: "The traditional three sets of mysteries: Joyful, Sorrowful, Glorious. As it has always been."
                    )
                    traditionRow(
                        title: "Traditional Penance",
                        desc: "Friday abstinence, Lenten fast, Ember Days. Choose 1962, 1917, or stricter pre-Pius XII discipline."
                    )
                }
                .padding(.horizontal, 32)
                .padding(.top, 8)

                Spacer(minLength: 40)
            }
        }
    }

    // MARK: - Page 3: Features

    private var featuresPage: some View {
        ScrollView {
            VStack(spacing: 20) {
                Spacer(minLength: 40)

                monstranceIcon
                    .frame(width: 60, height: 60)

                Text("Everything You Need")
                    .font(.system(size: 28, weight: .semibold, design: .serif))
                    .italic()
                    .foregroundStyle(Color.primaryText)

                Rectangle()
                    .fill(Color.sanctuaryRed.opacity(0.4))
                    .frame(width: 40, height: 1)

                VStack(alignment: .leading, spacing: 16) {
                    featureRow(icon: "sun.horizon", title: "Liturgical Today", desc: "Daily psalm, penance, season, feast days, and today's Mass propers.")
                    featureRow(icon: "book.closed", title: "1962 Missal", desc: "Complete Ordinary and 422 daily Propers interleaved in correct Mass order.")
                    featureRow(icon: "book.pages", title: "30 Prayers", desc: "Every essential prayer in Latin and English, from the Pater Noster to the Angelus.")
                    featureRow(icon: "cross", title: "Rosary & Stations", desc: "Interactive bead-by-bead Rosary. 14 Stations with meditations.")
                    featureRow(icon: "clock", title: "Divine Office", desc: "All 8 canonical hours of the 1962 Breviary.")
                    featureRow(icon: "heart", title: "Confession Guide", desc: "Examination of conscience and two guided confession paths.")
                    featureRow(icon: "person.fill", title: "Follow a Saint", desc: "7 patron saints with daily practice schedules.")
                    featureRow(icon: "graduationcap", title: "Learn Latin", desc: "10 lessons with 91 flashcards and quizzes.")
                    featureRow(icon: "text.book.closed", title: "Reference Library", desc: "41 articles on the calendar, sacraments, and devotions.")
                }
                .padding(.horizontal, 28)
                .padding(.top, 8)

                Spacer(minLength: 40)
            }
        }
    }

    // MARK: - Components

    private var monstranceIcon: some View {
        // SVG-style monstrance rendered with SwiftUI shapes
        ZStack {
            // Outer ring
            Circle()
                .stroke(Color.parchment, lineWidth: 1.2)
                .frame(width: 60, height: 60)
            // Inner gold ring
            Circle()
                .stroke(Color.goldLeaf.opacity(0.45), lineWidth: 0.8)
                .frame(width: 40, height: 40)
            // Host
            Circle()
                .fill(Color.goldLeaf.opacity(0.65))
                .frame(width: 16, height: 16)
            // Cross on host
            Rectangle()
                .fill(Color.sanctuaryRed.opacity(0.4))
                .frame(width: 0.8, height: 8)
            Rectangle()
                .fill(Color.sanctuaryRed.opacity(0.4))
                .frame(width: 8, height: 0.8)
            // Stem
            Rectangle()
                .fill(Color.parchment)
                .frame(width: 3, height: 18)
                .offset(y: 38)
            // Base steps
            RoundedRectangle(cornerRadius: 1)
                .fill(Color.parchment.opacity(0.78))
                .frame(width: 14, height: 2.5)
                .offset(y: 50)
            RoundedRectangle(cornerRadius: 1)
                .fill(Color.parchment.opacity(0.65))
                .frame(width: 22, height: 2.5)
                .offset(y: 53.5)
            RoundedRectangle(cornerRadius: 1.2)
                .fill(Color.parchment.opacity(0.52))
                .frame(width: 30, height: 2.5)
                .offset(y: 57)
            // Cross on top
            Rectangle()
                .fill(Color.parchment.opacity(0.72))
                .frame(width: 2, height: 10)
                .offset(y: -38)
            Rectangle()
                .fill(Color.parchment.opacity(0.72))
                .frame(width: 8, height: 2)
                .offset(y: -35)
        }
        .frame(width: 100, height: 120)
        .background(
            Circle()
                .fill(Color.sanctuaryRed)
                .frame(width: 90, height: 90)
        )
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private func featureRow(icon: String, title: String, desc: String) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundStyle(Color.sanctuaryRed)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.titleM)
                    .italic()
                    .foregroundStyle(Color.primaryText)
                Text(desc)
                    .font(.captionSm)
                    .foregroundStyle(Color.secondaryText)
                    .lineSpacing(2)
            }
        }
    }

    private func traditionRow(title: String, desc: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.titleM)
                .italic()
                .foregroundStyle(Color.sanctuaryRed)
            Text(desc)
                .font(.bodySm)
                .foregroundStyle(Color.secondaryText)
                .lineSpacing(3)
        }
    }
}
