import SwiftUI

// Multiple-choice quiz generated from a lesson's flashcard data.
// Shows a Latin word and 4 English choices (or vice versa).

struct QuizView: View {
    let cards: [Course.Section.Card]
    let lessonTitle: String
    @Environment(\.dismiss) private var dismiss
    @AppStorage(SettingsKey.theme) private var themeRaw = AppTheme.parchment.rawValue

    @State private var questionIndex = 0
    @State private var score = 0
    @State private var selectedAnswer: String?
    @State private var showResult = false
    @State private var questions: [Question] = []
    @State private var isFinished = false

    struct Question {
        let prompt: String
        let promptLabel: String   // "Latin" or "English"
        let correct: String
        let choices: [String]
    }

    private let totalQuestions = 5

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if isFinished {
                    finishedView
                } else if !questions.isEmpty {
                    questionView
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color.pageBackground.ignoresSafeArea())
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") { dismiss() }
                        .foregroundStyle(Color.sanctuaryRed)
                }
            }
            .onAppear { generateQuestions() }
        }
    }

    // MARK: - Question view

    private var questionView: some View {
        let q = questions[questionIndex]
        return ScrollView {
            VStack(spacing: 24) {
                Text("Question \(questionIndex + 1) of \(questions.count)")
                    .smallLabel(color: Color.sanctuaryRed)
                    .padding(.top, 24)

                Text("Score: \(score)")
                    .font(.captionSm)
                    .foregroundStyle(Color.goldLeaf)

                VStack(spacing: 8) {
                    Text(q.promptLabel)
                        .smallLabel(color: Color.goldLeaf)
                    Text(q.prompt)
                        .font(.pageTitle)
                        .foregroundStyle(Color.primaryText)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 28)
                }
                .padding(.vertical, 20)

                VStack(spacing: 10) {
                    ForEach(Array(q.choices.enumerated()), id: \.offset) { _, choice in
                        choiceButton(choice, correct: q.correct)
                    }
                }
                .padding(.horizontal, 28)

                if selectedAnswer != nil {
                    Button {
                        if questionIndex + 1 < questions.count {
                            questionIndex += 1
                            selectedAnswer = nil
                        } else {
                            isFinished = true
                        }
                    } label: {
                        Text(questionIndex + 1 < questions.count ? "Next" : "See Results")
                            .smallLabel(color: Color.sanctuaryRed, tracking: 3)
                            .padding(.vertical, 14)
                            .frame(maxWidth: .infinity)
                            .overlay(Rectangle().stroke(Color.sanctuaryRed.opacity(0.6), lineWidth: 0.5))
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 28)
                    .padding(.top, 12)
                }
            }
            .padding(.bottom, 40)
        }
        .id(questionIndex)
    }

    private func choiceButton(_ choice: String, correct: String) -> some View {
        let isSelected = selectedAnswer == choice
        let isCorrect = choice == correct
        let hasAnswered = selectedAnswer != nil

        let bgColor: Color = {
            if !hasAnswered { return Color.pageBackground }
            if isCorrect { return Color.green.opacity(0.1) }
            if isSelected && !isCorrect { return Color.sanctuaryRed.opacity(0.1) }
            return Color.pageBackground
        }()

        let borderColor: Color = {
            if !hasAnswered { return Color.frameLine }
            if isCorrect { return Color.green.opacity(0.6) }
            if isSelected && !isCorrect { return Color.sanctuaryRed.opacity(0.6) }
            return Color.frameLine
        }()

        return Button {
            guard selectedAnswer == nil else { return }
            selectedAnswer = choice
            if choice == correct { score += 1 }
        } label: {
            HStack {
                Text(choice)
                    .font(.body)
                    .foregroundStyle(Color.primaryText)
                    .frame(maxWidth: .infinity, alignment: .leading)
                if hasAnswered && isCorrect {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.green)
                } else if hasAnswered && isSelected && !isCorrect {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(Color.sanctuaryRed)
                }
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 16)
            .background(bgColor)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(borderColor, lineWidth: 0.5)
            )
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
        .disabled(hasAnswered)
    }

    // MARK: - Finished

    private var finishedView: some View {
        VStack(spacing: 16) {
            Spacer()
            Text("✠")
                .font(.system(size: 48))
                .foregroundStyle(Color.sanctuaryRed)
            Text("\(score) / \(questions.count)")
                .font(.system(size: 48, weight: .semibold, design: .serif))
                .foregroundStyle(Color.primaryText)
            Text(score == questions.count ? "Perfect!" : score >= questions.count / 2 ? "Well done" : "Keep practising")
                .font(.titleM)
                .italic()
                .foregroundStyle(Color.secondaryText)
            Text(lessonTitle)
                .font(.captionSm)
                .italic()
                .foregroundStyle(Color.tertiaryText)
                .textCase(.uppercase)
                .tracking(2)

            Button {
                questionIndex = 0
                score = 0
                selectedAnswer = nil
                isFinished = false
                generateQuestions()
            } label: {
                Text("Try Again")
                    .smallLabel(color: Color.sanctuaryRed, tracking: 3)
                    .padding(.vertical, 14)
                    .frame(maxWidth: .infinity)
                    .overlay(Rectangle().stroke(Color.sanctuaryRed.opacity(0.6), lineWidth: 0.5))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 28)
            .padding(.top, 20)

            Button { dismiss() } label: {
                Text("Done")
                    .font(.captionSm)
                    .italic()
                    .foregroundStyle(Color.tertiaryText)
            }
            .buttonStyle(.plain)
            .padding(.top, 8)
            Spacer()
        }
    }

    // MARK: - Question generation

    private func generateQuestions() {
        let usable = cards.filter { $0.lat != nil && $0.eng != nil }
        guard usable.count >= 4 else { return }

        var qs: [Question] = []
        let shuffled = usable.shuffled()
        let count = min(totalQuestions, usable.count)

        for i in 0..<count {
            let card = shuffled[i]
            let latinToEnglish = Bool.random()

            if latinToEnglish {
                let correct = card.eng!
                var wrongs = usable.filter { $0.eng != correct }.shuffled().prefix(3).map { $0.eng! }
                var choices = wrongs + [correct]
                choices.shuffle()
                qs.append(Question(prompt: card.lat!, promptLabel: "What does this mean?", correct: correct, choices: choices))
            } else {
                let correct = card.lat!
                var wrongs = usable.filter { $0.lat != correct }.shuffled().prefix(3).map { $0.lat! }
                var choices = wrongs + [correct]
                choices.shuffle()
                qs.append(Question(prompt: card.eng!, promptLabel: "What is the Latin?", correct: correct, choices: choices))
            }
        }

        questions = qs
    }
}
