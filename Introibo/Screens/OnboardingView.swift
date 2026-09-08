import SwiftUI

struct OnboardingView: View {
    @Binding var hasCompletedOnboarding: Bool

    @SceneStorage("onboarding.page") private var page = 0
    @AppStorage(SettingsKey.rite) private var selectedRite: String = MissalRite.rite1962.rawValue
    @AppStorage(SettingsKey.penance) private var selectedPenance: String = PenanceDiscipline.discipline1962.rawValue
    @AppStorage(SettingsKey.language) private var selectedLanguage: String = LanguageMode.both.rawValue
    @AppStorage(SettingsKey.vernacularLang) private var selectedVernacular: String = VernacularLanguage.english.rawValue
    @State private var selectedSaint: String? = nil
    @State private var notifLiturgical = false
    @State private var notifPrayerRule = false
    @State private var notifOffice = false

    private let totalPages = 9
    private let lastPage = 8

    // MARK: - Body

    var body: some View {
        ZStack(alignment: .top) {
            // Background — walnut gradient for first and last, parchment for middle
            Group {
                if page == 1 || page == lastPage {
                    LinearGradient(
                        colors: [Color.walnut, Color.walnutHi],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                } else {
                    Color.pageBackground
                }
            }
            .ignoresSafeArea()

            VStack(spacing: 0) {
                // Top bar: back button
                HStack {
                    if page > 0 {
                        Button {
                            withAnimation { page -= 1 }
                        } label: {
                            Image(systemName: "chevron.left")
                                .appFont(.scaledSystem(16, weight: .medium))
                                .foregroundStyle(page == lastPage ? Color.ivory : Color.secondaryText)
                                .padding(12)
                        }
                        .buttonStyle(.plain)
                    }
                    Spacer()
                }
                .frame(height: 44)
                .padding(.horizontal, 12)

                // Page content
                TabView(selection: $page) {
                    vernacularScreen.tag(0)
                    welcomeScreen.tag(1)
                    whatIsScreen.tag(2)
                    riteScreen.tag(3)
                    penanceScreen.tag(4)
                    languageScreen.tag(5)
                    saintScreen.tag(6)
                    notificationsScreen.tag(7)
                    finalScreen.tag(8)
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .animation(.easeInOut, value: page)

                // Bottom: dots + button (hidden on final screen)
                if page < lastPage {
                    VStack(spacing: 16) {
                        // Progress dots
                        HStack(spacing: 6) {
                            ForEach(0..<totalPages, id: \.self) { i in
                                Circle()
                                    .fill(i == page ? Color.sanctuaryRed : Color.frameLine)
                                    .frame(width: 7, height: 7)
                            }
                        }

                        // Continue button
                        Button {
                            withAnimation { page += 1 }
                        } label: {
                            Text(ContentStore.shared.uiString("common.continue", "Continue"))
                                .appFont(.scaledSystem(15, weight: .semibold, design: .serif))
                                .italic()
                                .foregroundStyle(Color.ivory)
                                .tracking(1.5)
                                .padding(.vertical, 18)
                                .frame(maxWidth: .infinity)
                                .background(Color.sanctuaryRed)
                        }
                        .buttonStyle(.plain)
                        .padding(.horizontal, 28)
                    }
                    .padding(.bottom, 36)
                }
            }
        }
    }

    // MARK: - Screen 0: Vernacular language
    //
    // First, so that everything after it (and the app) reads in the
    // chosen language. Each option describes itself in its own language.

    private var vernacularScreen: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                Spacer(minLength: 40)

                Text("Intro\u{00ED}bo")
                    .appFont(.scaledSystem(34, weight: .semibold, design: .serif))
                    .italic()
                    .foregroundStyle(Color.primaryText)

                Text("LINGUA VERN\u{00C1}CULA")
                    .smallLabel(color: Color.sanctuaryRed)

                Text(ContentStore.shared.uiString("onboarding.vernacular", "Choose your language"))
                    .appFont(.scaledSystem(26, weight: .semibold, design: .serif))
                    .foregroundStyle(Color.primaryText)

                Text(ContentStore.shared.uiString("onboarding.vernacular_sub", "Latin is always shown. Choose the language of the translations and of the app."))
                    .appFont(.bodySm)
                    .foregroundStyle(Color.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                VStack(spacing: 12) {
                    selectionCard(
                        title: "English",
                        description: "Translations and the app in English.",
                        isSelected: selectedVernacular == VernacularLanguage.english.rawValue
                    ) {
                        chooseVernacular(.english)
                    }

                    selectionCard(
                        title: "Espa\u{00F1}ol",
                        description: "Traducciones y aplicaci\u{00F3}n en espa\u{00F1}ol.",
                        isSelected: selectedVernacular == VernacularLanguage.spanish.rawValue
                    ) {
                        chooseVernacular(.spanish)
                    }
                }
                .padding(.horizontal, 28)
                .padding(.top, 8)

                Spacer(minLength: 40)
            }
        }
    }

    private func chooseVernacular(_ v: VernacularLanguage) {
        guard selectedVernacular != v.rawValue else { return }
        selectedVernacular = v.rawValue
        ContentStore.shared.applyVernacular(v)
    }

    // MARK: - Screen 1: Welcome

    private var welcomeScreen: some View {
        VStack(spacing: 20) {
            Spacer()

            monstranceIcon
                .frame(width: 80, height: 80)

            VStack(spacing: 8) {
                Text("Intro\u{00ED}bo")
                    .appFont(.scaledSystem(48, weight: .semibold, design: .serif))
                    .italic()
                    .foregroundStyle(Color.ivory)

                Text("Ad alt\u{00E1}re Dei")
                    .appFont(.caption)
                    .foregroundStyle(Color.ivory.opacity(0.6))
                    .textCase(.uppercase)
                    .tracking(3)

                Rectangle()
                    .fill(Color.goldLeaf.opacity(0.5))
                    .frame(width: 40, height: 1)
                    .padding(.top, 8)
            }

            Spacer()
            Spacer()
        }
    }

    // MARK: - Screen 1: What Is Introibo

    private var whatIsScreen: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 20) {
                Spacer(minLength: 60)

                Text("\u{2720}")
                    .appFont(.scaledSystem(48))
                    .foregroundStyle(Color.sanctuaryRed)

                Text(ContentStore.shared.uiString("onboarding.tagline", "A companion for the\ntraditional Catholic life."))
                    .appFont(.titleL)
                    .italic()
                    .foregroundStyle(Color.primaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                Rectangle()
                    .fill(Color.sanctuaryRed.opacity(0.4))
                    .frame(width: 40, height: 1)

                Text(ContentStore.shared.uiString("onboarding.features", "The complete 1962 Missal, the Roman Breviary, traditional prayers in Latin and English, daily propers, confession guides, and the traditional liturgical calendar. All in one place, working offline."))
                    .appFont(.body)
                    .foregroundStyle(Color.secondaryText)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .padding(.horizontal, 32)

                Spacer(minLength: 60)
            }
        }
    }

    // MARK: - Screen 2: Rite Selection

    private var riteScreen: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                Spacer(minLength: 40)

                Text("MISSALE ROMANUM")
                    .smallLabel(color: Color.sanctuaryRed)

                Text(ContentStore.shared.uiString("onboarding.rite", "Choose your rite"))
                    .appFont(.scaledSystem(26, weight: .semibold, design: .serif))
                    .foregroundStyle(Color.primaryText)

                Text(ContentStore.shared.uiString("onboarding.rite_sub", "This determines your liturgical calendar and rubrics."))
                    .appFont(.bodySm)
                    .foregroundStyle(Color.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                VStack(spacing: 12) {
                    selectionCard(
                        title: ContentStore.shared.uiString("onboarding.rite.1962.title", "1962 Roman Missal"),
                        description: ContentStore.shared.uiString("onboarding.rite.1962.desc", "The standard traditional rite. Used by FSSP, ICKSP, and most traditional parishes."),
                        isSelected: selectedRite == MissalRite.rite1962.rawValue
                    ) {
                        selectedRite = MissalRite.rite1962.rawValue
                    }

                    selectionCard(
                        title: ContentStore.shared.uiString("onboarding.rite.1955.title", "1955 Holy Week"),
                        description: ContentStore.shared.uiString("onboarding.rite.1955.desc", "Before the 1955 Holy Week reforms. Retains the older Palm Sunday, Good Friday, and Easter Vigil."),
                        isSelected: selectedRite == MissalRite.rite1955.rawValue
                    ) {
                        selectedRite = MissalRite.rite1955.rawValue
                    }

                    selectionCard(
                        title: ContentStore.shared.uiString("onboarding.rite.pre1955.title", "Pre-1955 Rubrics"),
                        description: ContentStore.shared.uiString("onboarding.rite.pre1955.desc", "The fullest traditional rubrics before any 20th-century simplifications."),
                        isSelected: selectedRite == MissalRite.pre1955.rawValue
                    ) {
                        selectedRite = MissalRite.pre1955.rawValue
                    }
                }
                .padding(.horizontal, 28)
                .padding(.top, 8)

                Spacer(minLength: 40)
            }
        }
    }

    // MARK: - Screen 3: Penance Discipline

    private var penanceScreen: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                Spacer(minLength: 40)

                Text("DE P\u{00C6}NIT\u{00C9}NTIA")
                    .smallLabel(color: Color.sanctuaryRed)

                Text(ContentStore.shared.uiString("onboarding.penance", "Choose your penance discipline"))
                    .appFont(.scaledSystem(26, weight: .semibold, design: .serif))
                    .foregroundStyle(Color.primaryText)

                Text(ContentStore.shared.uiString("onboarding.penance_sub", "The app will show your daily obligations automatically."))
                    .appFont(.bodySm)
                    .foregroundStyle(Color.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                VStack(spacing: 12) {
                    selectionCard(
                        title: ContentStore.shared.uiString("onboarding.penance.1962.title", "1962 Code"),
                        description: ContentStore.shared.uiString("onboarding.penance.1962.desc", "Friday abstinence. Lenten fast (ages 21\u{2013}59). The standard traditional discipline."),
                        isSelected: selectedPenance == PenanceDiscipline.discipline1962.rawValue
                    ) {
                        selectedPenance = PenanceDiscipline.discipline1962.rawValue
                    }

                    selectionCard(
                        title: ContentStore.shared.uiString("onboarding.penance.1917.title", "1917 Code"),
                        description: ContentStore.shared.uiString("onboarding.penance.1917.desc", "Stricter. Includes Advent fasting, vigil fasts, and broader abstinence rules."),
                        isSelected: selectedPenance == PenanceDiscipline.discipline1917.rawValue
                    ) {
                        selectedPenance = PenanceDiscipline.discipline1917.rawValue
                    }

                    selectionCard(
                        title: ContentStore.shared.uiString("onboarding.penance.strict.title", "Full Traditional"),
                        description: ContentStore.shared.uiString("onboarding.penance.strict.desc", "The strictest observance. Ember Day fasts, all traditional vigils, Saturday abstinence."),
                        isSelected: selectedPenance == PenanceDiscipline.strict.rawValue
                    ) {
                        selectedPenance = PenanceDiscipline.strict.rawValue
                    }
                }
                .padding(.horizontal, 28)
                .padding(.top, 8)

                Spacer(minLength: 40)
            }
        }
    }

    // MARK: - Screen 4: Language

    private var languageScreen: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                Spacer(minLength: 40)

                Text("LINGUA")
                    .smallLabel(color: Color.sanctuaryRed)

                Text(ContentStore.shared.uiString("onboarding.language", "Choose your language"))
                    .appFont(.scaledSystem(26, weight: .semibold, design: .serif))
                    .foregroundStyle(Color.primaryText)

                Text(ContentStore.shared.uiString("onboarding.language_sub", "Every prayer appears in Ecclesiastical Latin. Choose how you\u{2019}d like to see it."))
                    .appFont(.bodySm)
                    .foregroundStyle(Color.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                VStack(spacing: 12) {
                    selectionCard(
                        title: LanguageMode.both.label,
                        description: ContentStore.shared.uiString("onboarding.langmode.both_desc", "Side by side. See both languages together."),
                        isSelected: selectedLanguage == LanguageMode.both.rawValue
                    ) {
                        selectedLanguage = LanguageMode.both.rawValue
                    }

                    selectionCard(
                        title: LanguageMode.latinOnly.label,
                        description: ContentStore.shared.uiString("onboarding.langmode.latin_desc", "Immerse yourself in the sacred language."),
                        isSelected: selectedLanguage == LanguageMode.latinOnly.rawValue
                    ) {
                        selectedLanguage = LanguageMode.latinOnly.rawValue
                    }

                    selectionCard(
                        title: LanguageMode.vernacular.label,
                        description: ContentStore.shared.uiString("onboarding.langmode.vernacular_desc", "Read in the vernacular."),
                        isSelected: selectedLanguage == LanguageMode.vernacular.rawValue
                    ) {
                        selectedLanguage = LanguageMode.vernacular.rawValue
                    }
                }
                .padding(.horizontal, 28)
                .padding(.top, 8)

                Spacer(minLength: 40)
            }
        }
    }

    // MARK: - Screen 5: Follow a Saint

    private var saintScreen: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                Spacer(minLength: 40)

                Text("SANCTI PATRONI")
                    .smallLabel(color: Color.sanctuaryRed)

                Text(ContentStore.shared.uiString("onboarding.saint", "Follow a patron saint"))
                    .appFont(.scaledSystem(26, weight: .semibold, design: .serif))
                    .foregroundStyle(Color.primaryText)

                Text(ContentStore.shared.uiString("onboarding.saint_sub", "Track daily practices, build streaks, and grow in holiness with a patron\u{2019}s guidance."))
                    .appFont(.bodySm)
                    .foregroundStyle(Color.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                VStack(spacing: 10) {
                    ForEach(saintOptions, id: \.slug) { saint in
                        saintCard(
                            name: ContentStore.shared.uiString("onboarding.saint.\(saint.slug).name", saint.name),
                            motto: ContentStore.shared.uiString("onboarding.saint.\(saint.slug).motto", saint.motto),
                            isSelected: selectedSaint == saint.slug
                        ) {
                            if selectedSaint == saint.slug {
                                selectedSaint = nil
                                UserProgress.setFollowedSaint(nil)
                            } else {
                                selectedSaint = saint.slug
                                UserProgress.setFollowedSaint(saint.slug)
                            }
                        }
                    }
                }
                .padding(.horizontal, 28)
                .padding(.top, 8)

                // Skip option
                Button {
                    selectedSaint = nil
                    UserProgress.setFollowedSaint(nil)
                    withAnimation { page += 1 }
                } label: {
                    Text(ContentStore.shared.uiString("onboarding.choose_later", "I\u{2019}ll choose later"))
                        .appFont(.body)
                        .foregroundStyle(Color.secondaryText)
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 28)
                .padding(.top, 12)

                Spacer(minLength: 40)
            }
        }
    }

    // MARK: - Screen 6: Notifications

    private var notificationsScreen: some View {
        ScrollView(showsIndicators: false) {
            VStack(spacing: 16) {
                Spacer(minLength: 40)

                Text("NOTIFICATIONES")
                    .smallLabel(color: Color.sanctuaryRed)

                Text(ContentStore.shared.uiString("onboarding.schedule", "Stay on schedule"))
                    .appFont(.scaledSystem(26, weight: .semibold, design: .serif))
                    .foregroundStyle(Color.primaryText)

                Text(ContentStore.shared.uiString("onboarding.schedule_sub", "Introibo can remind you to pray at the traditional hours."))
                    .appFont(.bodySm)
                    .foregroundStyle(Color.secondaryText)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                VStack(spacing: 14) {
                    notificationToggle(
                        title: ContentStore.shared.uiString("onboarding.notif.liturgical", "Daily liturgical update"),
                        description: ContentStore.shared.uiString("onboarding.notif.liturgical_desc", "What feast it is, penance obligations, today\u{2019}s propers."),
                        isOn: $notifLiturgical
                    )

                    notificationToggle(
                        title: ContentStore.shared.uiString("onboarding.notif.rule", "Prayer rule reminders"),
                        description: ContentStore.shared.uiString("onboarding.notif.rule_desc", "Morning, midday, and evening prayer nudges."),
                        isOn: $notifPrayerRule
                    )

                    notificationToggle(
                        title: ContentStore.shared.uiString("onboarding.notif.office", "Divine Office bells"),
                        description: ContentStore.shared.uiString("onboarding.notif.office_desc", "Notifications at the canonical hours."),
                        isOn: $notifOffice
                    )
                }
                .padding(.horizontal, 28)
                .padding(.top, 8)

                Spacer(minLength: 16)

                // Skip option — visually distinct from toggles
                Button {
                    withAnimation { page += 1 }
                } label: {
                    Text(ContentStore.shared.uiString("onboarding.setup_later", "I\u{2019}ll set this up later"))
                        .appFont(.body)
                        .foregroundStyle(Color.secondaryText)
                        .padding(.vertical, 12)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 28)

                Spacer(minLength: 40)
            }
        }
    }

    // MARK: - Screen 7: Final

    private var finalScreen: some View {
        VStack(spacing: 20) {
            Spacer()

            Text("\u{2720}")
                .appFont(.scaledSystem(56))
                .foregroundStyle(Color.goldLeaf)

            Text("Intro\u{00ED}bo ad alt\u{00E1}re Dei")
                .appFont(.pageTitle)
                .foregroundStyle(Color.ivory)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Text("Ad Deum qui l\u{00E6}t\u{00ED}ficat juvent\u{00FA}tem meam.")
                .appFont(.caption)
                .foregroundStyle(Color.muted)
                .italic()
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Rectangle()
                .fill(Color.goldLeaf.opacity(0.5))
                .frame(width: 40, height: 1)
                .padding(.top, 4)

            Spacer()

            // Begin button
            Button {
                hasCompletedOnboarding = true
            } label: {
                Text(ContentStore.shared.uiString("stations.begin", "·  Begin"))
                    .appFont(.scaledSystem(17, weight: .semibold, design: .serif))
                    .italic()
                    .foregroundStyle(Color.ivory)
                    .tracking(2)
                    .padding(.vertical, 20)
                    .frame(maxWidth: .infinity)
                    .background(Color.sanctuaryRed)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 28)
            .padding(.bottom, 48)
        }
    }

    // MARK: - Reusable Components

    private func selectionCard(
        title: String,
        description: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .appFont(.titleM)
                        .italic()
                        .foregroundStyle(Color.primaryText)
                    Text(description)
                        .appFont(.captionSm)
                        .foregroundStyle(Color.secondaryText)
                        .lineSpacing(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .appFont(.scaledSystem(20))
                        .foregroundStyle(Color.sanctuaryRed)
                        .padding(.top, 2)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(
                        isSelected ? Color.sanctuaryRed : Color.frameLine,
                        lineWidth: isSelected ? 2 : 0.5
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private func saintCard(
        name: String,
        motto: String,
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(name)
                        .appFont(.titleM)
                        .italic()
                        .foregroundStyle(Color.primaryText)
                    Text(motto)
                        .appFont(.captionSm)
                        .foregroundStyle(Color.secondaryText)
                        .italic()
                }
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .appFont(.scaledSystem(20))
                        .foregroundStyle(Color.goldLeaf)
                        .padding(.top, 2)
                }
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(
                        isSelected ? Color.goldLeaf : Color.frameLine,
                        lineWidth: isSelected ? 2 : 0.5
                    )
            )
        }
        .buttonStyle(.plain)
    }

    private func notificationToggle(
        title: String,
        description: String,
        isOn: Binding<Bool>
    ) -> some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .appFont(.titleM)
                    .italic()
                    .foregroundStyle(Color.primaryText)
                Text(description)
                    .appFont(.captionSm)
                    .foregroundStyle(Color.secondaryText)
                    .lineSpacing(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            Toggle("", isOn: isOn)
                .labelsHidden()
                .tint(Color.sanctuaryRed)
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.frameLine, lineWidth: 0.5)
        )
    }

    // MARK: - Monstrance Icon

    private var monstranceIcon: some View {
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

    // MARK: - Saint Data

    private struct SaintOption {
        let slug: String
        let name: String
        let motto: String
    }

    private let saintOptions: [SaintOption] = [
        SaintOption(slug: "pio", name: "St. Padre Pio", motto: "Pray, hope, and don\u{2019}t worry."),
        SaintOption(slug: "therese", name: "St. Th\u{00E9}r\u{00E8}se of Lisieux", motto: "My vocation is love."),
        SaintOption(slug: "aquinas", name: "St. Thomas Aquinas", motto: "Doctor Ang\u{00E9}licus"),
        SaintOption(slug: "benedict", name: "St. Benedict of Nursia", motto: "Ora et Lab\u{00F3}ra"),
        SaintOption(slug: "teresa", name: "St. Teresa of \u{00C1}vila", motto: "Nada te turbe"),
        SaintOption(slug: "escriva", name: "St. Josemar\u{00ED}a Escriv\u{00E1}", motto: "Sanctify ordinary work"),
        SaintOption(slug: "desales", name: "St. Francis de Sales", motto: "Doctor of charity"),
    ]
}
