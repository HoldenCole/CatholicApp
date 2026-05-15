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
    case office    = "office"
    case missal    = "missal"
    case prayers   = "prayers"
    case rosary    = "rosary"
    case stations  = "stations"
    case learn     = "learn"
    case confession = "confession"

    var id: String { rawValue }

    var label: String {
        switch self {
        case .office:     return "The Divine Office"
        case .missal:     return "The Missal"
        case .prayers:    return "Prayers & Prayer Rule"
        case .rosary:     return "The Rosary"
        case .stations:   return "Stations of the Cross"
        case .learn:      return "Latin Learning"
        case .confession: return "Confession Guide"
        }
    }

    var latinLabel: String {
        switch self {
        case .office:     return "Officium Divinum"
        case .missal:     return "Missale Romanum"
        case .prayers:    return "Oratio"
        case .rosary:     return "Rosarium"
        case .stations:   return "Via Crucis"
        case .learn:      return "Schola"
        case .confession: return "Confessio"
        }
    }

    var systemImage: String {
        switch self {
        case .office:     return "clock"
        case .missal:     return "book.closed"
        case .prayers:    return "book.pages"
        case .rosary:     return "circle.grid.cross"
        case .stations:   return "cross"
        case .learn:      return "graduationcap"
        case .confession: return "heart"
        }
    }

    var steps: [TutorialStep] {
        switch self {
        case .office:
            return [
                TutorialStep(id: "office.intro", text: "The Divine Office contains all eight canonical hours of the 1962 Roman Breviary.", spotlightElementID: nil, pillPosition: .top),
                TutorialStep(id: "office.hours", text: "Tap any hour to open its psalms, antiphons, and readings for today.", spotlightElementID: "devotionsSection", pillPosition: .bottom),
                TutorialStep(id: "office.nav", text: "Scroll through each hour. The text follows the traditional order.", spotlightElementID: nil, pillPosition: .center),
            ]
        case .missal:
            return [
                TutorialStep(id: "missal.intro", text: "The complete 1962 Missale Romanum with all daily Propers.", spotlightElementID: nil, pillPosition: .top),
                TutorialStep(id: "missal.propers", text: "Today\u{2019}s Propers are shown here. Tap to read the Epistle and Gospel.", spotlightElementID: "propersCard", pillPosition: .bottom),
                TutorialStep(id: "missal.order", text: "The Ordinary and Propers are interleaved in correct liturgical order.", spotlightElementID: nil, pillPosition: .center),
            ]
        case .prayers:
            return [
                TutorialStep(id: "prayers.intro", text: "Build a personal prayer rule for morning, midday, and evening.", spotlightElementID: nil, pillPosition: .top),
                TutorialStep(id: "prayers.bell", text: "Tap the bell icon on any prayer to set a reminder notification.", spotlightElementID: nil, pillPosition: .center),
                TutorialStep(id: "prayers.rule", text: "Your prayer rule progress appears on the Today screen.", spotlightElementID: nil, pillPosition: .bottom),
            ]
        case .rosary:
            return [
                TutorialStep(id: "rosary.intro", text: "An interactive bead-by-bead Rosary with three traditional mystery sets.", spotlightElementID: nil, pillPosition: .top),
                TutorialStep(id: "rosary.mysteries", text: "Today\u{2019}s mysteries are chosen automatically based on the day of the week.", spotlightElementID: nil, pillPosition: .center),
            ]
        case .stations:
            return [
                TutorialStep(id: "stations.intro", text: "The fourteen Stations of the Cross with meditations and the Stabat Mater.", spotlightElementID: nil, pillPosition: .top),
                TutorialStep(id: "stations.nav", text: "Swipe or tap to move between stations.", spotlightElementID: nil, pillPosition: .center),
            ]
        case .learn:
            return [
                TutorialStep(id: "learn.intro", text: "Learn Ecclesiastical Latin with lessons, flashcards, and quizzes.", spotlightElementID: nil, pillPosition: .top),
                TutorialStep(id: "learn.progress", text: "Your mastery progress is tracked and shown on the Today screen.", spotlightElementID: nil, pillPosition: .center),
            ]
        case .confession:
            return [
                TutorialStep(id: "confession.intro", text: "A traditional examination of conscience and confession guide.", spotlightElementID: nil, pillPosition: .top),
                TutorialStep(id: "confession.guide", text: "Follow the step-by-step guide for a thorough confession.", spotlightElementID: nil, pillPosition: .center),
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
        TutorialStep(id: "tutorials", text: "Per-feature tutorials are also available in Settings if you\u{2019}d like a deeper tour of any section.", spotlightElementID: nil, pillPosition: .center),
    ]
}
