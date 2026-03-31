import SwiftUI
import SwiftData

struct RosaryFlowView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var appSettings: AppSettings
    @StateObject private var viewModel: RosaryViewModel
    @Environment(\.dismiss) private var dismiss

    init(mysterySetType: MysterySetType) {
        _viewModel = StateObject(wrappedValue: RosaryViewModel(mysterySetType: mysterySetType))
    }

    var body: some View {
        VStack(spacing: 0) {
            if viewModel.isComplete {
                rosaryCompleteView
            } else if let step = viewModel.currentStep {
                // Progress bar
                rosaryProgressBar

                ScrollView {
                    VStack(spacing: 20) {
                        // Step indicator
                        stepHeader(step)

                        // Bead visualization
                        beadIndicator(step)

                        // Prayer text
                        if let prayer = viewModel.currentPrayer {
                            prayerContent(prayer, step: step)
                        } else if step.type == .mysteryAnnouncement {
                            mysteryAnnouncementView(step)
                        }
                    }
                    .padding()
                }

                // Navigation buttons
                navigationButtons
            }
        }
        .background(Color.parchment)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("End") {
                    dismiss()
                }
                .foregroundStyle(.sanctuaryRed)
            }
        }
        .onAppear {
            viewModel.textMode = appSettings.defaultTextMode
            viewModel.loadData(context: modelContext)
        }
    }

    // MARK: - Progress Bar

    private var rosaryProgressBar: some View {
        VStack(spacing: 6) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.goldLeaf.opacity(0.15))
                        .frame(height: 4)

                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.sanctuaryRed)
                        .frame(width: geo.size.width * viewModel.progress, height: 4)
                        .animation(.easeInOut(duration: 0.3), value: viewModel.progress)
                }
            }
            .frame(height: 4)

            HStack {
                if let label = viewModel.currentDecadeLabel {
                    Text(label)
                        .font(.uiCaption)
                        .foregroundStyle(.goldLeaf)
                }
                Spacer()
                Text("\(viewModel.currentStepIndex + 1) of \(viewModel.steps.count)")
                    .font(.uiCaption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal)
        .padding(.top, 8)
    }

    // MARK: - Step Header

    private func stepHeader(_ step: RosaryStep) -> some View {
        VStack(spacing: 6) {
            Text(step.title)
                .font(.latinTitle)
                .foregroundStyle(.ink)
                .multilineTextAlignment(.center)

            if let subtitle = step.subtitle {
                Text(subtitle)
                    .font(.englishCaption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
    }

    // MARK: - Bead Indicator

    private func beadIndicator(_ step: RosaryStep) -> some View {
        HStack(spacing: 6) {
            if step.type == .hailMary, let rep = step.repetition, step.decadeNumber != nil {
                // Show 10 beads for decade
                ForEach(1...10, id: \.self) { i in
                    Circle()
                        .fill(i <= rep ? Color.sanctuaryRed : Color.sanctuaryRed.opacity(0.15))
                        .frame(width: i == rep ? 12 : 8, height: i == rep ? 12 : 8)
                        .animation(.spring(response: 0.3), value: rep)
                }
            } else if step.type == .hailMary, let rep = step.repetition {
                // Introductory 3 Hail Marys
                ForEach(1...3, id: \.self) { i in
                    Circle()
                        .fill(i <= rep ? Color.sanctuaryRed : Color.sanctuaryRed.opacity(0.15))
                        .frame(width: i == rep ? 12 : 8, height: i == rep ? 12 : 8)
                }
            } else if step.type == .ourFather {
                // Single large bead
                Circle()
                    .fill(Color.goldLeaf)
                    .frame(width: 14, height: 14)
            } else if step.type == .mysteryAnnouncement, let num = step.mysteryNumber {
                // 5 mystery markers
                ForEach(1...5, id: \.self) { i in
                    RoundedRectangle(cornerRadius: 4)
                        .fill(i <= num ? Color.sanctuaryRed : Color.sanctuaryRed.opacity(0.15))
                        .frame(width: 24, height: 8)
                }
            }
        }
        .padding(.vertical, 4)
    }

    // MARK: - Prayer Content

    private func prayerContent(_ prayer: Prayer, step: RosaryStep) -> some View {
        VStack(spacing: 16) {
            // Text mode toggle (compact)
            if !prayer.latinText.isEmpty {
                HStack(spacing: 0) {
                    ForEach(TextMode.allCases) { mode in
                        Button {
                            withAnimation { viewModel.textMode = mode }
                        } label: {
                            Text(mode.displayName)
                                .font(.uiCaption)
                                .foregroundStyle(viewModel.textMode == mode ? .white : .ink)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background {
                                    if viewModel.textMode == mode {
                                        Capsule().fill(Color.sanctuaryRed)
                                    }
                                }
                        }
                    }
                }
                .padding(2)
                .background(Capsule().fill(Color.ink.opacity(0.06)))
            }

            // Prayer text
            Group {
                switch viewModel.textMode {
                case .missal:
                    if !prayer.latinText.isEmpty {
                        MissalTextView(latinText: prayer.latinText, englishText: prayer.englishText)
                    } else {
                        englishText(prayer)
                    }
                case .english:
                    englishText(prayer)
                case .latin:
                    Text(prayer.latinText.isEmpty ? prayer.englishText : prayer.latinText)
                        .font(prayer.latinText.isEmpty ? .englishBody : .latinBody)
                        .foregroundStyle(.ink)
                        .lineSpacing(6)
                case .phonetic:
                    if !prayer.phoneticText.isEmpty {
                        PhoneticTextView(phoneticText: prayer.phoneticText)
                    } else {
                        englishText(prayer)
                    }
                }
            }
            .padding(.vertical, 8)
        }
    }

    private func englishText(_ prayer: Prayer) -> some View {
        Text(prayer.englishText)
            .font(.englishBody)
            .foregroundStyle(.ink)
            .lineSpacing(6)
    }

    // MARK: - Mystery Announcement

    private func mysteryAnnouncementView(_ step: RosaryStep) -> some View {
        VStack(spacing: 16) {
            if let num = step.mysteryNumber {
                ZStack {
                    Circle()
                        .fill(Color.sanctuaryRed.opacity(0.1))
                        .frame(width: 64, height: 64)
                    Text("\(num)")
                        .font(.latinDisplay)
                        .foregroundStyle(.sanctuaryRed)
                }
            }

            // Find the mystery for meditation text
            if let mystery = viewModel.mysteries.first(where: {
                $0.setType == viewModel.mysterySetType && $0.mysteryNumber == step.mysteryNumber
            }) {
                VStack(spacing: 8) {
                    Text(mystery.scriptureRef)
                        .font(.uiCaption)
                        .foregroundStyle(.goldLeaf)

                    Text(mystery.meditationText)
                        .font(.englishBody)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .lineSpacing(4)
                }
                .padding(.vertical, 8)
            }
        }
    }

    // MARK: - Navigation Buttons

    private var navigationButtons: some View {
        HStack(spacing: 16) {
            Button {
                withAnimation { viewModel.previousStep() }
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(viewModel.currentStepIndex > 0 ? .ink : .clear)
                    .frame(width: 50, height: 50)
                    .overlay(
                        Circle().stroke(Color.goldLeaf.opacity(0.2), lineWidth: 1)
                    )
            }
            .disabled(viewModel.currentStepIndex == 0)

            Button {
                withAnimation { viewModel.nextStep() }
            } label: {
                HStack {
                    Text(viewModel.currentStepIndex < viewModel.steps.count - 1 ? "Next" : "Finish")
                        .font(.uiLabelLarge)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                }
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color.sanctuaryRed)
                .clipShape(RoundedRectangle(cornerRadius: 14))
            }
        }
        .padding()
        .background(Color.parchment)
    }

    // MARK: - Complete

    private var rosaryCompleteView: some View {
        VStack(spacing: 24) {
            Spacer()

            ZStack {
                Circle()
                    .fill(Color.goldLeaf.opacity(0.12))
                    .frame(width: 100, height: 100)
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.goldLeaf)
            }

            Text("Deo Grátias")
                .font(.latinDisplay)
                .foregroundStyle(.ink)

            Text("You have completed the \(viewModel.mysterySetType.englishName).")
                .font(.englishBody)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Spacer()

            Button {
                appSettings.recordPractice()
                dismiss()
            } label: {
                Text("Return Home")
                    .font(.uiLabelLarge)
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.sanctuaryRed)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
            .padding()
        }
        .background(Color.parchment)
    }
}
