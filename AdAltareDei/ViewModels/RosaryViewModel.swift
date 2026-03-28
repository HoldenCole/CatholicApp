import Foundation
import SwiftData

@MainActor
class RosaryViewModel: ObservableObject {
    @Published var steps: [RosaryStep] = []
    @Published var currentStepIndex = 0
    @Published var textMode: TextMode = .missal
    @Published var mysterySetType: MysterySetType
    @Published var prayers: [String: Prayer] = [:]  // slug → Prayer
    @Published var mysteries: [Mystery] = []
    @Published var isComplete = false

    var currentStep: RosaryStep? {
        guard currentStepIndex < steps.count else { return nil }
        return steps[currentStepIndex]
    }

    var currentPrayer: Prayer? {
        guard let step = currentStep else { return nil }
        return prayers[step.prayerSlug]
    }

    var progress: Double {
        guard !steps.isEmpty else { return 0 }
        return Double(currentStepIndex) / Double(steps.count)
    }

    var currentDecadeLabel: String? {
        guard let step = currentStep, let decade = step.decadeNumber else { return nil }
        return "Decade \(decade) of 5"
    }

    init(mysterySetType: MysterySetType) {
        self.mysterySetType = mysterySetType
    }

    func loadData(context: ModelContext) {
        // Load all prayers into dictionary
        let prayerDescriptor = FetchDescriptor<Prayer>()
        let allPrayers = (try? context.fetch(prayerDescriptor)) ?? []
        prayers = Dictionary(uniqueKeysWithValues: allPrayers.map { ($0.slug, $0) })

        // Load mysteries
        let mysteryDescriptor = FetchDescriptor<Mystery>(sortBy: [SortDescriptor(\.sortOrder)])
        mysteries = (try? context.fetch(mysteryDescriptor)) ?? []

        // Build step sequence
        steps = RosaryStepBuilder.buildSteps(for: mysterySetType, mysteries: mysteries)
    }

    func nextStep() {
        if currentStepIndex < steps.count - 1 {
            currentStepIndex += 1
        } else {
            isComplete = true
        }
    }

    func previousStep() {
        if currentStepIndex > 0 {
            currentStepIndex -= 1
        }
    }
}
