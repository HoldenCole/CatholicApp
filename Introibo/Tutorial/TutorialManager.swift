import SwiftUI

// MARK: - TutorialManager

/// Observable singleton that drives the tutorial overlay system.
/// Tracks tutorial state, current steps, and persists completion flags.
@Observable
final class TutorialManager {
    static let shared = TutorialManager()

    // MARK: - Persisted state

    /// True once the main (new-user) tutorial has been completed or skipped.
    var mainTutorialCompleted: Bool {
        get { UserDefaults.standard.bool(forKey: "tutorial.mainCompleted") }
        set { UserDefaults.standard.set(newValue, forKey: "tutorial.mainCompleted") }
    }

    /// True once the upgrade tour prompt has been shown (regardless of choice).
    var upgradeTutorialPrompted: Bool {
        get { UserDefaults.standard.bool(forKey: "tutorial.upgradePrompted") }
        set { UserDefaults.standard.set(newValue, forKey: "tutorial.upgradePrompted") }
    }

    /// Persisted step index for resume on force-quit.
    private var persistedStepIndex: Int {
        get { UserDefaults.standard.integer(forKey: "tutorial.currentStep") }
        set { UserDefaults.standard.set(newValue, forKey: "tutorial.currentStep") }
    }

    // MARK: - Runtime state

    var isShowingTutorial = false
    var currentSteps: [TutorialStep] = []
    var currentStepIndex = 0

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
