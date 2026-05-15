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
        case .homeNavigation: return "Home and Navigation"
        case .office:         return "The Divine Office"
        case .missal:         return "The Missal"
        case .prayers:        return "Prayers and Prayer Rule"
        case .rosary:         return "The Rosary"
        case .stations:       return "Stations of the Cross"
        case .saints:         return "Following a Saint"
        case .learn:          return "Latin Learning"
        case .confession:     return "Confession Guide"
        case .reference:      return "Reference Library"
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
                TutorialStep(id: "home.1", text: "This is your daily home screen. It updates automatically based on today\u{2019}s liturgical calendar.", spotlightElementID: nil, pillPosition: .top),
                TutorialStep(id: "home.2", text: "The header shows today\u{2019}s feast, liturgical season, colour, and any special observances.", spotlightElementID: nil, pillPosition: .top),
                TutorialStep(id: "home.3", text: "The daily psalm rotates through 44 verses. A new one appears each day.", spotlightElementID: nil, pillPosition: .top),
                TutorialStep(id: "home.4", text: "Tap the Propers card to read today\u{2019}s Mass texts: Introit, Collect, Epistle, Gospel, and more.", spotlightElementID: "propersCard", pillPosition: .bottom),
                TutorialStep(id: "home.5", text: "Your penance obligations are shown here, based on the discipline you chose in Settings.", spotlightElementID: nil, pillPosition: .center),
                TutorialStep(id: "home.6", text: "The Divine Office, Rosary, Stations, and Confession live in the devotions section.", spotlightElementID: "devotionsSection", pillPosition: .bottom),
                TutorialStep(id: "home.7", text: "The five tabs at the bottom are: Today, Missal, Prayers, Latin Lessons, and Reference.", spotlightElementID: nil, pillPosition: .bottom),
                TutorialStep(id: "home.8", text: "Tap the gear icon to change your rite, language, penance discipline, theme, and notifications.", spotlightElementID: "settingsButton", pillPosition: .bottom),
            ]

        case .office:
            return [
                TutorialStep(id: "office.1", text: "The Divine Office contains all eight canonical hours of the 1962 Roman Breviary.", spotlightElementID: nil, pillPosition: .top),
                TutorialStep(id: "office.2", text: "The clock dial shows each hour at its traditional time. The current hour glows.", spotlightElementID: nil, pillPosition: .center),
                TutorialStep(id: "office.3", text: "Tap any hour to open it. The app assembles the correct psalms and hymns for today automatically.", spotlightElementID: nil, pillPosition: .center),
                TutorialStep(id: "office.4", text: "On Sundays, Matins has three nocturns with nine psalms and nine readings. On weekdays, one nocturn.", spotlightElementID: nil, pillPosition: .top),
                TutorialStep(id: "office.5", text: "Hymns change with the liturgical season: Advent, Lent, Passiontide, Easter, and Christmastide.", spotlightElementID: nil, pillPosition: .center),
                TutorialStep(id: "office.6", text: "The Marian antiphon at Compline changes four times a year with the seasons.", spotlightElementID: nil, pillPosition: .center),
                TutorialStep(id: "office.7", text: "Each hour includes all versicles, responses, antiphons, and blessings for praying the Breviary.", spotlightElementID: nil, pillPosition: .bottom),
                TutorialStep(id: "office.8", text: "You can set notification reminders for the canonical hours using the bell icon.", spotlightElementID: nil, pillPosition: .bottom),
            ]

        case .missal:
            return [
                TutorialStep(id: "missal.1", text: "The Missal tab shows today\u{2019}s complete Mass: the Ordinary interleaved with today\u{2019}s Propers.", spotlightElementID: nil, pillPosition: .top),
                TutorialStep(id: "missal.2", text: "Red italic labels indicate who is speaking: the priest, the servers, or all together.", spotlightElementID: nil, pillPosition: .top),
                TutorialStep(id: "missal.3", text: "The Prayers at the Foot include both the priest\u{2019}s and the servers\u{2019} Confiteor.", spotlightElementID: nil, pillPosition: .center),
                TutorialStep(id: "missal.4", text: "Today\u{2019}s Propers appear in their correct positions: Introit, Collect, Epistle, Gradual, Gospel, Offertory, Secret, Communion, Postcommunion.", spotlightElementID: nil, pillPosition: .center),
                TutorialStep(id: "missal.5", text: "The Roman Canon is complete, including all the prayers from Te Igitur through Per Ipsum.", spotlightElementID: nil, pillPosition: .center),
                TutorialStep(id: "missal.6", text: "The Leonine Prayers appear after the Last Gospel, as prayed after Low Mass.", spotlightElementID: nil, pillPosition: .bottom),
                TutorialStep(id: "missal.7", text: "Tap the share icon to export the full Mass as text.", spotlightElementID: nil, pillPosition: .top),
                TutorialStep(id: "missal.8", text: "Latin and English appear side by side. Change the language mode in Settings.", spotlightElementID: nil, pillPosition: .bottom),
            ]

        case .prayers:
            return [
                TutorialStep(id: "prayers.1", text: "The prayer library contains 41 traditional prayers in Latin and English, including litanies.", spotlightElementID: nil, pillPosition: .top),
                TutorialStep(id: "prayers.2", text: "Build a personal prayer rule by choosing prayers for morning, midday, and evening.", spotlightElementID: nil, pillPosition: .top),
                TutorialStep(id: "prayers.3", text: "Your prayer rule appears on the Today screen with checkmarks as you complete each prayer.", spotlightElementID: nil, pillPosition: .center),
                TutorialStep(id: "prayers.4", text: "Browse prayers by occasion: Before Mass, Marian, Eucharistic, For the Departed, and more.", spotlightElementID: nil, pillPosition: .center),
                TutorialStep(id: "prayers.5", text: "Search the full library by name. Sort alphabetically or by the traditional ordering.", spotlightElementID: nil, pillPosition: .center),
                TutorialStep(id: "prayers.6", text: "Tap the bell icon on any prayer to set a daily reminder notification.", spotlightElementID: nil, pillPosition: .bottom),
                TutorialStep(id: "prayers.7", text: "Each prayer shows full Latin with accents and a faithful English translation.", spotlightElementID: nil, pillPosition: .bottom),
            ]

        case .rosary:
            return [
                TutorialStep(id: "rosary.1", text: "The Rosary guides you bead by bead through the traditional three mystery sets.", spotlightElementID: nil, pillPosition: .top),
                TutorialStep(id: "rosary.2", text: "Today\u{2019}s mysteries are chosen automatically: Joyful, Sorrowful, or Glorious based on the day.", spotlightElementID: nil, pillPosition: .top),
                TutorialStep(id: "rosary.3", text: "You can also choose a different mystery set manually.", spotlightElementID: nil, pillPosition: .center),
                TutorialStep(id: "rosary.4", text: "Each decade shows the mystery title, a meditation, and the fruit of the mystery.", spotlightElementID: nil, pillPosition: .center),
                TutorialStep(id: "rosary.5", text: "Swipe forward through each bead. The prayers appear in Latin and English.", spotlightElementID: nil, pillPosition: .center),
                TutorialStep(id: "rosary.6", text: "Your Rosary history is tracked on the Today screen.", spotlightElementID: nil, pillPosition: .bottom),
            ]

        case .stations:
            return [
                TutorialStep(id: "stations.1", text: "The fourteen Stations of the Cross with traditional meditations.", spotlightElementID: nil, pillPosition: .top),
                TutorialStep(id: "stations.2", text: "Each station includes the versicle, a meditation, and a stanza of the Stabat Mater.", spotlightElementID: nil, pillPosition: .top),
                TutorialStep(id: "stations.3", text: "Navigate between stations using the arrows at the bottom.", spotlightElementID: nil, pillPosition: .center),
                TutorialStep(id: "stations.4", text: "The Latin and English texts appear together for each station.", spotlightElementID: nil, pillPosition: .center),
                TutorialStep(id: "stations.5", text: "Pray the Stations any time from the devotions section on the Today screen.", spotlightElementID: nil, pillPosition: .bottom),
            ]

        case .saints:
            return [
                TutorialStep(id: "saints.1", text: "Follow a patron saint to build daily spiritual practices and track your progress.", spotlightElementID: nil, pillPosition: .top),
                TutorialStep(id: "saints.2", text: "Seven patron saints are available, each with their own practices and prayers.", spotlightElementID: nil, pillPosition: .top),
                TutorialStep(id: "saints.3", text: "Each saint has three sections of daily practices. Check them off as you complete them.", spotlightElementID: nil, pillPosition: .center),
                TutorialStep(id: "saints.4", text: "Build a streak by completing practices on consecutive days.", spotlightElementID: nil, pillPosition: .center),
                TutorialStep(id: "saints.5", text: "Your saint\u{2019}s progress appears on the Today screen with a progress ring.", spotlightElementID: nil, pillPosition: .center),
                TutorialStep(id: "saints.6", text: "You can change your patron saint anytime from the Saints screen.", spotlightElementID: nil, pillPosition: .bottom),
            ]

        case .learn:
            return [
                TutorialStep(id: "learn.1", text: "Learn Ecclesiastical Latin with ten structured lessons.", spotlightElementID: nil, pillPosition: .top),
                TutorialStep(id: "learn.2", text: "Each lesson covers pronunciation, grammar, or prayer vocabulary.", spotlightElementID: nil, pillPosition: .top),
                TutorialStep(id: "learn.3", text: "Flashcards help you memorize key Latin words and phrases.", spotlightElementID: nil, pillPosition: .center),
                TutorialStep(id: "learn.4", text: "Take quizzes to test your knowledge. Score high to mark a lesson as mastered.", spotlightElementID: nil, pillPosition: .center),
                TutorialStep(id: "learn.5", text: "A daily flashcard appears on the Today screen, rotating through the vocabulary.", spotlightElementID: nil, pillPosition: .center),
                TutorialStep(id: "learn.6", text: "Your mastery progress is shown with a progress ring on the Schola tab.", spotlightElementID: nil, pillPosition: .bottom),
            ]

        case .confession:
            return [
                TutorialStep(id: "confession.1", text: "Prepare for Confession with a traditional examination of conscience.", spotlightElementID: nil, pillPosition: .top),
                TutorialStep(id: "confession.2", text: "The examination follows the Ten Commandments, each with specific questions.", spotlightElementID: nil, pillPosition: .top),
                TutorialStep(id: "confession.3", text: "Two step-by-step confession guides walk you through the sacrament.", spotlightElementID: nil, pillPosition: .center),
                TutorialStep(id: "confession.4", text: "The basic guide covers the essential form. The advanced guide follows St. Catherine of Siena.", spotlightElementID: nil, pillPosition: .center),
                TutorialStep(id: "confession.5", text: "Access the Confession guide from the devotions section on the Today screen.", spotlightElementID: nil, pillPosition: .bottom),
            ]

        case .reference:
            return [
                TutorialStep(id: "ref.1", text: "The reference library contains articles on the sacraments, the Mass, prayer, penance, and more.", spotlightElementID: nil, pillPosition: .top),
                TutorialStep(id: "ref.2", text: "Browse by category: References, Propers, History, or Latin glossary.", spotlightElementID: nil, pillPosition: .top),
                TutorialStep(id: "ref.3", text: "The Propers section lets you search all 425 daily Mass formularies by name or scripture.", spotlightElementID: nil, pillPosition: .center),
                TutorialStep(id: "ref.4", text: "The History section is a timeline of the Mass from 33 AD to the present day.", spotlightElementID: nil, pillPosition: .center),
                TutorialStep(id: "ref.5", text: "The Glossary explains 25 essential liturgical Latin terms.", spotlightElementID: nil, pillPosition: .center),
                TutorialStep(id: "ref.6", text: "Quick reference links at the bottom take you to the most important articles.", spotlightElementID: nil, pillPosition: .bottom),
            ]
        }
    }
}

// MARK: - Predefined tour sequences

extension TutorialStep {
    /// Main tour for new users (shown after onboarding).
    static let mainTour: [TutorialStep] = [
        TutorialStep(id: "home", text: "This is your daily home. Today\u{2019}s feast, today\u{2019}s Propers, today\u{2019}s penance. Tap anywhere to continue.", spotlightElementID: nil, pillPosition: .top),
        TutorialStep(id: "propers", text: "Today\u{2019}s Propers are here. Tap to open the day\u{2019}s Mass when you\u{2019}re ready.", spotlightElementID: "propersCard", pillPosition: .bottom),
        TutorialStep(id: "mass", text: "The full Mass with today\u{2019}s Propers, in the correct order. Scroll to follow along.", spotlightElementID: nil, pillPosition: .top),
        TutorialStep(id: "nav", text: "The Divine Office, the Rosary, the Stations, and more live here.", spotlightElementID: "devotionsSection", pillPosition: .bottom),
        TutorialStep(id: "settings", text: "Anytime, you can change your rite, language, and notifications in Settings.", spotlightElementID: "settingsButton", pillPosition: .bottom),
    ]

    /// Upgrade tour for returning users after an app update.
    static let upgradeTour: [TutorialStep] = [
        TutorialStep(id: "office", text: "The Divine Office has been rebuilt for accurate prayer use.", spotlightElementID: "devotionsSection", pillPosition: .bottom),
        TutorialStep(id: "mass", text: "The Roman Canon is now complete and the Mass order has been corrected throughout.", spotlightElementID: "propersCard", pillPosition: .bottom),
        TutorialStep(id: "settings", text: "You can now configure rite, penance, language, and notifications anytime in Settings.", spotlightElementID: "settingsButton", pillPosition: .bottom),
        TutorialStep(id: "tutorials", text: "Per-feature tutorials are available in Settings whenever you need a walkthrough.", spotlightElementID: nil, pillPosition: .center),
    ]
}
