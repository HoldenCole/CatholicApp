import Foundation

// MARK: - TutorialStep

/// A single step in a tutorial sequence. Each step shows a text pill,
/// optionally spotlights a named element, and positions itself on screen.
struct TutorialStep: Identifiable {
    let id: String
    let text: String
    let spotlightElementID: String? // nil = no spotlight, full dim
    let pillPosition: PillPosition  // .top, .bottom, .center

    enum PillPosition {
        case top, bottom, center
    }
}

// MARK: - Feature tutorials

/// Named feature tutorials that can be launched from Settings.
enum FeatureTutorial: String, CaseIterable, Identifiable {
    case homeNavigation = "homeNav"
    case office         = "office"
    case missal         = "missal"
    case prayers        = "prayers"
    case rosary         = "rosary"
    case stations       = "stations"
    case saints         = "saints"
    case learn          = "learn"
    case confession     = "confession"
    case reference      = "reference"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .homeNavigation: return ContentStore.shared.uiString("tutorial.feature.homeNavigation", "Home and Navigation")
        case .office:         return ContentStore.shared.uiString("tutorial.feature.office", "The Divine Office")
        case .missal:         return ContentStore.shared.uiString("tutorial.feature.missal", "The Missal")
        case .prayers:        return ContentStore.shared.uiString("tutorial.feature.prayers", "Prayers and Prayer Rule")
        case .rosary:         return ContentStore.shared.uiString("tutorial.feature.rosary", "The Rosary")
        case .stations:       return ContentStore.shared.uiString("tutorial.feature.stations", "Stations of the Cross")
        case .saints:         return ContentStore.shared.uiString("tutorial.feature.saints", "Following a Saint")
        case .learn:          return ContentStore.shared.uiString("tutorial.feature.learn", "Latin Learning")
        case .confession:     return ContentStore.shared.uiString("tutorial.feature.confession", "Confession Guide")
        case .reference:      return ContentStore.shared.uiString("tutorial.feature.reference", "Reference Library")
        }
    }

    var latinLabel: String {
        switch self {
        case .homeNavigation: return "Hodie"
        case .office:         return "Officium Divinum"
        case .missal:         return "Missale Romanum"
        case .prayers:        return "Oratio"
        case .rosary:         return "Rosarium"
        case .stations:       return "Via Crucis"
        case .saints:         return "Sancti Patroni"
        case .learn:          return "Schola"
        case .confession:     return "Confessio"
        case .reference:      return "Encyclopaedia"
        }
    }

    var systemImage: String {
        switch self {
        case .homeNavigation: return "sun.horizon"
        case .office:         return "clock"
        case .missal:         return "book.closed"
        case .prayers:        return "book.pages"
        case .rosary:         return "circle.grid.cross"
        case .stations:       return "cross"
        case .saints:         return "person.fill"
        case .learn:          return "graduationcap"
        case .confession:     return "heart"
        case .reference:      return "text.book.closed"
        }
    }

    var steps: [TutorialStep] {
        switch self {

        case .homeNavigation:
            return [
                TutorialStep(id: "home.1", text: ContentStore.shared.uiString("tutorial.step.home.1", "This is your daily home screen. It updates automatically based on today\u{2019}s liturgical calendar."), spotlightElementID: nil, pillPosition: .top),
                TutorialStep(id: "home.2", text: ContentStore.shared.uiString("tutorial.step.home.2", "The header shows today\u{2019}s feast, liturgical season, colour, and any special observances."), spotlightElementID: nil, pillPosition: .top),
                TutorialStep(id: "home.3", text: ContentStore.shared.uiString("tutorial.step.home.3", "The daily psalm rotates through 44 verses. A new one appears each day."), spotlightElementID: nil, pillPosition: .top),
                TutorialStep(id: "home.4", text: ContentStore.shared.uiString("tutorial.step.home.4", "Tap the Propers card to read today\u{2019}s Mass texts: Introit, Collect, Epistle, Gospel, and more."), spotlightElementID: "propersCard", pillPosition: .bottom),
                TutorialStep(id: "home.5", text: ContentStore.shared.uiString("tutorial.step.home.5", "Your penance obligations are shown here, based on the discipline you chose in Settings."), spotlightElementID: nil, pillPosition: .center),
                TutorialStep(id: "home.6", text: ContentStore.shared.uiString("tutorial.step.home.6", "The Divine Office, Rosary, Stations, and Confession live in the devotions section."), spotlightElementID: "devotionsSection", pillPosition: .bottom),
                TutorialStep(id: "home.7", text: ContentStore.shared.uiString("tutorial.step.home.7", "The five tabs at the bottom are: Today, Missal, Prayers, Latin Lessons, and Reference."), spotlightElementID: nil, pillPosition: .bottom),
                TutorialStep(id: "home.8", text: ContentStore.shared.uiString("tutorial.step.home.8", "Tap the gear icon to change your rite, language, penance discipline, theme, and notifications."), spotlightElementID: "settingsButton", pillPosition: .bottom),
            ]

        case .office:
            return [
                TutorialStep(id: "office.1", text: ContentStore.shared.uiString("tutorial.step.office.1", "The Divine Office contains all eight canonical hours of the 1962 Roman Breviary."), spotlightElementID: nil, pillPosition: .top),
                TutorialStep(id: "office.2", text: ContentStore.shared.uiString("tutorial.step.office.2", "The clock dial shows each hour at its traditional time. The current hour glows."), spotlightElementID: nil, pillPosition: .center),
                TutorialStep(id: "office.3", text: ContentStore.shared.uiString("tutorial.step.office.3", "Tap any hour to open it. The app assembles the correct psalms and hymns for today automatically."), spotlightElementID: nil, pillPosition: .center),
                TutorialStep(id: "office.4", text: ContentStore.shared.uiString("tutorial.step.office.4", "On Sundays, Matins has three nocturns with nine psalms and nine readings. On weekdays, one nocturn."), spotlightElementID: nil, pillPosition: .top),
                TutorialStep(id: "office.5", text: ContentStore.shared.uiString("tutorial.step.office.5", "Hymns change with the liturgical season: Advent, Lent, Passiontide, Easter, and Christmastide."), spotlightElementID: nil, pillPosition: .center),
                TutorialStep(id: "office.6", text: ContentStore.shared.uiString("tutorial.step.office.6", "The Marian antiphon at Compline changes four times a year with the seasons."), spotlightElementID: nil, pillPosition: .center),
                TutorialStep(id: "office.7", text: ContentStore.shared.uiString("tutorial.step.office.7", "Each hour includes all versicles, responses, antiphons, and blessings for praying the Breviary."), spotlightElementID: nil, pillPosition: .bottom),
                TutorialStep(id: "office.8", text: ContentStore.shared.uiString("tutorial.step.office.8", "You can set notification reminders for the canonical hours using the bell icon."), spotlightElementID: nil, pillPosition: .bottom),
            ]

        case .missal:
            return [
                TutorialStep(id: "missal.1", text: ContentStore.shared.uiString("tutorial.step.missal.1", "The Missal tab shows today\u{2019}s complete Mass: the Ordinary interleaved with today\u{2019}s Propers."), spotlightElementID: nil, pillPosition: .top),
                TutorialStep(id: "missal.2", text: ContentStore.shared.uiString("tutorial.step.missal.2", "Red italic labels indicate who is speaking: the priest, the servers, or all together."), spotlightElementID: nil, pillPosition: .top),
                TutorialStep(id: "missal.3", text: ContentStore.shared.uiString("tutorial.step.missal.3", "The Prayers at the Foot include both the priest\u{2019}s and the servers\u{2019} Confiteor."), spotlightElementID: nil, pillPosition: .center),
                TutorialStep(id: "missal.4", text: ContentStore.shared.uiString("tutorial.step.missal.4", "Today\u{2019}s Propers appear in their correct positions: Introit, Collect, Epistle, Gradual, Gospel, Offertory, Secret, Communion, Postcommunion."), spotlightElementID: nil, pillPosition: .center),
                TutorialStep(id: "missal.5", text: ContentStore.shared.uiString("tutorial.step.missal.5", "The Roman Canon is complete, including all the prayers from Te Igitur through Per Ipsum."), spotlightElementID: nil, pillPosition: .center),
                TutorialStep(id: "missal.6", text: ContentStore.shared.uiString("tutorial.step.missal.6", "The Leonine Prayers appear after the Last Gospel, as prayed after Low Mass."), spotlightElementID: nil, pillPosition: .bottom),
                TutorialStep(id: "missal.7", text: ContentStore.shared.uiString("tutorial.step.missal.7", "Tap the share icon to export the full Mass as text."), spotlightElementID: nil, pillPosition: .top),
                TutorialStep(id: "missal.8", text: ContentStore.shared.uiString("tutorial.step.missal.8", "Latin and English appear side by side. Change the language mode in Settings."), spotlightElementID: nil, pillPosition: .bottom),
            ]

        case .prayers:
            return [
                TutorialStep(id: "prayers.1", text: ContentStore.shared.uiString("tutorial.step.prayers.1", "The prayer library contains 42 traditional prayers in Latin and English, including litanies."), spotlightElementID: nil, pillPosition: .top),
                TutorialStep(id: "prayers.2", text: ContentStore.shared.uiString("tutorial.step.prayers.2", "Build a personal prayer rule by choosing prayers for morning, midday, and evening."), spotlightElementID: nil, pillPosition: .top),
                TutorialStep(id: "prayers.3", text: ContentStore.shared.uiString("tutorial.step.prayers.3", "Your prayer rule appears on the Today screen with checkmarks as you complete each prayer."), spotlightElementID: nil, pillPosition: .center),
                TutorialStep(id: "prayers.4", text: ContentStore.shared.uiString("tutorial.step.prayers.4", "Browse prayers by occasion: Before Mass, Marian, Eucharistic, For the Departed, and more."), spotlightElementID: nil, pillPosition: .center),
                TutorialStep(id: "prayers.5", text: ContentStore.shared.uiString("tutorial.step.prayers.5", "Search the full library by name. Sort alphabetically or by the traditional ordering."), spotlightElementID: nil, pillPosition: .center),
                TutorialStep(id: "prayers.6", text: ContentStore.shared.uiString("tutorial.step.prayers.6", "Tap the bell icon on any prayer to set a daily reminder notification."), spotlightElementID: nil, pillPosition: .bottom),
                TutorialStep(id: "prayers.7", text: ContentStore.shared.uiString("tutorial.step.prayers.7", "Each prayer shows full Latin with accents and a faithful English translation."), spotlightElementID: nil, pillPosition: .bottom),
            ]

        case .rosary:
            return [
                TutorialStep(id: "rosary.1", text: ContentStore.shared.uiString("tutorial.step.rosary.1", "The Rosary guides you bead by bead through the traditional three mystery sets."), spotlightElementID: nil, pillPosition: .top),
                TutorialStep(id: "rosary.2", text: ContentStore.shared.uiString("tutorial.step.rosary.2", "Today\u{2019}s mysteries are chosen automatically: Joyful, Sorrowful, or Glorious based on the day."), spotlightElementID: nil, pillPosition: .top),
                TutorialStep(id: "rosary.3", text: ContentStore.shared.uiString("tutorial.step.rosary.3", "You can also choose a different mystery set manually."), spotlightElementID: nil, pillPosition: .center),
                TutorialStep(id: "rosary.4", text: ContentStore.shared.uiString("tutorial.step.rosary.4", "Each decade shows the mystery title, a meditation, and the fruit of the mystery."), spotlightElementID: nil, pillPosition: .center),
                TutorialStep(id: "rosary.5", text: ContentStore.shared.uiString("tutorial.step.rosary.5", "Swipe forward through each bead. The prayers appear in Latin and English."), spotlightElementID: nil, pillPosition: .center),
                TutorialStep(id: "rosary.6", text: ContentStore.shared.uiString("tutorial.step.rosary.6", "Your Rosary history is tracked on the Today screen."), spotlightElementID: nil, pillPosition: .bottom),
            ]

        case .stations:
            return [
                TutorialStep(id: "stations.1", text: ContentStore.shared.uiString("tutorial.step.stations.1", "The fourteen Stations of the Cross with traditional meditations."), spotlightElementID: nil, pillPosition: .top),
                TutorialStep(id: "stations.2", text: ContentStore.shared.uiString("tutorial.step.stations.2", "Each station includes the versicle, a meditation, and a stanza of the Stabat Mater."), spotlightElementID: nil, pillPosition: .top),
                TutorialStep(id: "stations.3", text: ContentStore.shared.uiString("tutorial.step.stations.3", "Navigate between stations using the arrows at the bottom."), spotlightElementID: nil, pillPosition: .center),
                TutorialStep(id: "stations.4", text: ContentStore.shared.uiString("tutorial.step.stations.4", "The Latin and English texts appear together for each station."), spotlightElementID: nil, pillPosition: .center),
                TutorialStep(id: "stations.5", text: ContentStore.shared.uiString("tutorial.step.stations.5", "Pray the Stations any time from the devotions section on the Today screen."), spotlightElementID: nil, pillPosition: .bottom),
            ]

        case .saints:
            return [
                TutorialStep(id: "saints.1", text: ContentStore.shared.uiString("tutorial.step.saints.1", "Follow a patron saint to build daily spiritual practices and track your progress."), spotlightElementID: nil, pillPosition: .top),
                TutorialStep(id: "saints.2", text: ContentStore.shared.uiString("tutorial.step.saints.2", "Seven patron saints are available, each with their own practices and prayers."), spotlightElementID: nil, pillPosition: .top),
                TutorialStep(id: "saints.3", text: ContentStore.shared.uiString("tutorial.step.saints.3", "Each saint has three sections of daily practices. Check them off as you complete them."), spotlightElementID: nil, pillPosition: .center),
                TutorialStep(id: "saints.4", text: ContentStore.shared.uiString("tutorial.step.saints.4", "Build a streak by completing practices on consecutive days."), spotlightElementID: nil, pillPosition: .center),
                TutorialStep(id: "saints.5", text: ContentStore.shared.uiString("tutorial.step.saints.5", "Your saint\u{2019}s progress appears on the Today screen with a progress ring."), spotlightElementID: nil, pillPosition: .center),
                TutorialStep(id: "saints.6", text: ContentStore.shared.uiString("tutorial.step.saints.6", "You can change your patron saint anytime from the Saints screen."), spotlightElementID: nil, pillPosition: .bottom),
            ]

        case .learn:
            return [
                TutorialStep(id: "learn.1", text: ContentStore.shared.uiString("tutorial.step.learn.1", "Learn Ecclesiastical Latin with ten structured lessons."), spotlightElementID: nil, pillPosition: .top),
                TutorialStep(id: "learn.2", text: ContentStore.shared.uiString("tutorial.step.learn.2", "Each lesson covers pronunciation, grammar, or prayer vocabulary."), spotlightElementID: nil, pillPosition: .top),
                TutorialStep(id: "learn.3", text: ContentStore.shared.uiString("tutorial.step.learn.3", "Flashcards help you memorize key Latin words and phrases."), spotlightElementID: nil, pillPosition: .center),
                TutorialStep(id: "learn.4", text: ContentStore.shared.uiString("tutorial.step.learn.4", "Take quizzes to test your knowledge. Score high to mark a lesson as mastered."), spotlightElementID: nil, pillPosition: .center),
                TutorialStep(id: "learn.5", text: ContentStore.shared.uiString("tutorial.step.learn.5", "A daily flashcard appears on the Today screen, rotating through the vocabulary."), spotlightElementID: nil, pillPosition: .center),
                TutorialStep(id: "learn.6", text: ContentStore.shared.uiString("tutorial.step.learn.6", "Your mastery progress is shown with a progress ring on the Schola tab."), spotlightElementID: nil, pillPosition: .bottom),
            ]

        case .confession:
            return [
                TutorialStep(id: "confession.1", text: ContentStore.shared.uiString("tutorial.step.confession.1", "Prepare for Confession with a traditional examination of conscience."), spotlightElementID: nil, pillPosition: .top),
                TutorialStep(id: "confession.2", text: ContentStore.shared.uiString("tutorial.step.confession.2", "The examination follows the Ten Commandments, each with specific questions."), spotlightElementID: nil, pillPosition: .top),
                TutorialStep(id: "confession.3", text: ContentStore.shared.uiString("tutorial.step.confession.3", "Two step-by-step confession guides walk you through the sacrament."), spotlightElementID: nil, pillPosition: .center),
                TutorialStep(id: "confession.4", text: ContentStore.shared.uiString("tutorial.step.confession.4", "The basic guide covers the essential form. The advanced guide follows St. Catherine of Siena."), spotlightElementID: nil, pillPosition: .center),
                TutorialStep(id: "confession.5", text: ContentStore.shared.uiString("tutorial.step.confession.5", "Access the Confession guide from the devotions section on the Today screen."), spotlightElementID: nil, pillPosition: .bottom),
            ]

        case .reference:
            return [
                TutorialStep(id: "ref.1", text: ContentStore.shared.uiString("tutorial.step.ref.1", "The reference library contains articles on the sacraments, the Mass, prayer, penance, and more."), spotlightElementID: nil, pillPosition: .top),
                TutorialStep(id: "ref.2", text: ContentStore.shared.uiString("tutorial.step.ref.2", "Browse by category: References, Propers, History, or Latin glossary."), spotlightElementID: nil, pillPosition: .top),
                TutorialStep(id: "ref.3", text: ContentStore.shared.uiString("tutorial.step.ref.3", "The Propers section lets you search all 425 daily Mass formularies by name or scripture."), spotlightElementID: nil, pillPosition: .center),
                TutorialStep(id: "ref.4", text: ContentStore.shared.uiString("tutorial.step.ref.4", "The History section is a timeline of the Mass from 33 AD to the present day."), spotlightElementID: nil, pillPosition: .center),
                TutorialStep(id: "ref.5", text: ContentStore.shared.uiString("tutorial.step.ref.5", "The Glossary explains 25 essential liturgical Latin terms."), spotlightElementID: nil, pillPosition: .center),
                TutorialStep(id: "ref.6", text: ContentStore.shared.uiString("tutorial.step.ref.6", "Quick reference links at the bottom take you to the most important articles."), spotlightElementID: nil, pillPosition: .bottom),
            ]
        }
    }
}

// MARK: - Predefined tour sequences

extension TutorialStep {
    /// Main tour for new users (shown after onboarding).
    static var mainTour: [TutorialStep] { [
        TutorialStep(id: "home", text: ContentStore.shared.uiString("tutorial.step.main.home", "This is your daily home. Today\u{2019}s feast, today\u{2019}s Propers, today\u{2019}s penance. Tap anywhere to continue."), spotlightElementID: nil, pillPosition: .top),
        TutorialStep(id: "propers", text: ContentStore.shared.uiString("tutorial.step.main.propers", "Today\u{2019}s Propers are here. Tap to open the day\u{2019}s Mass when you\u{2019}re ready."), spotlightElementID: "propersCard", pillPosition: .bottom),
        TutorialStep(id: "mass", text: ContentStore.shared.uiString("tutorial.step.main.mass", "The full Mass with today\u{2019}s Propers, in the correct order. Scroll to follow along."), spotlightElementID: nil, pillPosition: .top),
        TutorialStep(id: "nav", text: ContentStore.shared.uiString("tutorial.step.main.nav", "The Divine Office, the Rosary, the Stations, and more live here."), spotlightElementID: "devotionsSection", pillPosition: .bottom),
        TutorialStep(id: "settings", text: ContentStore.shared.uiString("tutorial.step.main.settings", "Anytime, you can change your rite, language, and notifications in Settings."), spotlightElementID: "settingsButton", pillPosition: .bottom),
    ] }

    /// Upgrade tour for returning users after an app update.
    static var upgradeTour: [TutorialStep] { [
        TutorialStep(id: "office", text: ContentStore.shared.uiString("tutorial.step.upgrade.office", "The Divine Office has been rebuilt for accurate prayer use."), spotlightElementID: "devotionsSection", pillPosition: .bottom),
        TutorialStep(id: "mass", text: ContentStore.shared.uiString("tutorial.step.upgrade.mass", "The Roman Canon is now complete and the Mass order has been corrected throughout."), spotlightElementID: "propersCard", pillPosition: .bottom),
        TutorialStep(id: "settings", text: ContentStore.shared.uiString("tutorial.step.upgrade.settings", "You can now configure rite, penance, language, and notifications anytime in Settings."), spotlightElementID: "settingsButton", pillPosition: .bottom),
        TutorialStep(id: "tutorials", text: ContentStore.shared.uiString("tutorial.step.upgrade.tutorials", "Per-feature tutorials are available in Settings whenever you need a walkthrough."), spotlightElementID: nil, pillPosition: .center),
    ] }
}
