import SwiftUI

// MARK: - TutorialManager

/// Observable singleton that drives the tutorial overlay system.
/// Tracks tutorial state, current steps, and persists completion flags.
@Observable
final class TutorialManager {
    static let shared = TutorialManager()

    // MARK: - Persisted state (backed by UserDefaults, synced on read/write)

    var mainTutorialCompleted = UserDefaults.standard.bool(forKey: "tutorial.mainCompleted") {
        didSet { UserDefaults.standard.set(mainTutorialCompleted, forKey: "tutorial.mainCompleted") }
    }

    var upgradeTutorialPrompted = UserDefaults.standard.bool(forKey: "tutorial.upgradePrompted") {
        didSet { UserDefaults.standard.set(upgradeTutorialPrompted, forKey: "tutorial.upgradePrompted") }
    }

    private var persistedStepIndex = UserDefaults.standard.integer(forKey: "tutorial.currentStep") {
        didSet { UserDefaults.standard.set(persistedStepIndex, forKey: "tutorial.currentStep") }
    }

    // MARK: - Runtime state

    var isShowingTutorial = false
    var currentSteps: [TutorialStep] = []
    var currentStepIndex = 0

    /// Which tab to navigate to when a feature tutorial starts (nil = stay)
    var targetTabIndex: Int? = nil
    /// Which sub-screen to navigate to from Today (nil = stay on Today)
    var targetSubScreen: String? = nil

    /// Identifier for the current tour type, used to determine which
    /// completion flag to set when the tour finishes.
    private var activeTourType: TourType = .main

    private enum TourType {
        case main
        case upgrade
        case feature
    }

    var currentStep: TutorialStep? {
        guard isShowingTutorial,
              currentStepIndex >= 0,
              currentStepIndex < currentSteps.count else { return nil }
        return currentSteps[currentStepIndex]
    }

    private init() {}

    // MARK: - Public API

    /// Start the main tutorial for new users (after onboarding).
    func startMainTutorial() {
        guard !mainTutorialCompleted else { return }
        activeTourType = .main
        currentSteps = TutorialStep.mainTour
        // Resume from persisted step if valid
        let saved = persistedStepIndex
        currentStepIndex = (saved >= 0 && saved < currentSteps.count) ? saved : 0
        isShowingTutorial = true
    }

    /// Start the upgrade tutorial for returning users.
    func startUpgradeTutorial() {
        activeTourType = .upgrade
        currentSteps = TutorialStep.upgradeTour
        currentStepIndex = 0
        persistedStepIndex = 0
        isShowingTutorial = true
    }

    /// Start a per-feature tutorial (can be re-run anytime from Settings).
    func startFeatureTutorial(_ feature: FeatureTutorial) {
        activeTourType = .feature
        currentSteps = feature.steps
        currentStepIndex = 0
        persistedStepIndex = 0

        // Navigate to the correct screen
        switch feature {
        case .homeNavigation:
            targetTabIndex = 0
            targetSubScreen = nil
        case .office:
            targetTabIndex = 0
            targetSubScreen = "office"
        case .missal:
            targetTabIndex = 1
            targetSubScreen = nil
        case .prayers:
            targetTabIndex = 2
            targetSubScreen = nil
        case .rosary:
            targetTabIndex = 0
            targetSubScreen = "rosary"
        case .stations:
            targetTabIndex = 0
            targetSubScreen = "stations"
        case .saints:
            targetTabIndex = 0
            targetSubScreen = "saints"
        case .learn:
            targetTabIndex = 3
            targetSubScreen = nil
        case .confession:
            targetTabIndex = 0
            targetSubScreen = "confession"
        case .reference:
            targetTabIndex = 4
            targetSubScreen = nil
        }

        isShowingTutorial = true
    }

    /// Advance to the next step, or finish if at the last step.
    func advance() {
        guard isShowingTutorial else { return }
        if currentStepIndex < currentSteps.count - 1 {
            currentStepIndex += 1
            persistedStepIndex = currentStepIndex
        } else {
            finish()
        }
    }

    /// Skip the tutorial immediately and mark it complete.
    func skip() {
        finish()
    }

    // MARK: - Private

    private func finish() {
        isShowingTutorial = false
        currentSteps = []
        currentStepIndex = 0
        persistedStepIndex = 0
        targetTabIndex = nil
        targetSubScreen = nil

        switch activeTourType {
        case .main:
            mainTutorialCompleted = true
        case .upgrade:
            upgradeTutorialPrompted = true
        case .feature:
            break // Per-feature tutorials have no completion tracking
        }
    }
}
