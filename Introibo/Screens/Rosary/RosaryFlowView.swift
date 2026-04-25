import SwiftUI

// Interactive bead-by-bead Rosary flow. Each screen shows one prayer
// step with Latin+English text, the current mystery context, and a
// bead progress indicator. User taps "Next" to advance through the
// entire Rosary.

struct RosaryFlowView: View {
    let set: MysterySetData
    @Environment(\.dismiss) private var dismiss
    @State private var stepIndex = 0
    @State private var steps: [RosaryStep] = []
    @State private var didMark = false
    @AppStorage(SettingsKey.theme) private var themeRaw = AppTheme.parchment.rawValue
    @AppStorage(SettingsKey.fontSize) private var fontSizeRaw = FontSizeOption.medium.rawValue

    private let store = ContentStore.shared

    var body: some View {
        NavigationStack {
            if steps.isEmpty {
                ProgressView()
                    .onAppear { buildSteps() }
            } else if stepIndex < steps.count {
                stepView(steps[stepIndex])
            } else {
                completionView
            }
        }
    }

    // MARK: - Step view

    private func stepView(_ step: RosaryStep) -> some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(spacing: 16) {
                    // Progress
                    beadProgress
                        .padding(.top, 12)

                    // Mystery context (persistent throughout decade)
                    if let mystery = step.mystery {
                        VStack(spacing: 6) {
                            Text(mystery.title)
                                .font(.titleL)
                                .italic()
                                .foregroundStyle(Color.primaryText)
                                .multilineTextAlignment(.center)
                            Text(mystery.eng)
                                .font(.captionSm)
                                .italic()
                                .foregroundStyle(Color.secondaryText)
                            Text("Fruit: \(mystery.fruit)")
                                .font(.captionSm)
                                .italic()
                                .foregroundStyle(Color.goldLeaf)
                                .padding(.top, 2)
                        }
                        .padding(.horizontal, 28)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity)
                        .background(Color.frameLine.opacity(0.3))
                    }

                    // Step label
                    Text(step.label)
                        .smallLabel(color: Color.goldLeaf)
                        .padding(.top, 8)

                    // Prayer text
                    VStack(alignment: .leading, spacing: 10) {
                        Text(step.latin)
                            .font(.body)
                            .foregroundStyle(Color.primaryText)
                            .lineSpacing(4)
                        Text(step.english)
                            .font(.bodySm)
                            .italic()
                            .foregroundStyle(Color.secondaryText)
                            .lineSpacing(3)
                    }
                    .padding(.horizontal, 28)
                    .padding(.top, 8)

                    // Meditation (for mystery announcements)
                    if let meditation = step.meditation {
                        VStack(alignment: .leading, spacing: 6) {
                            Rectangle()
                                .fill(Color.goldLeaf.opacity(0.3))
                                .frame(height: 0.5)
                            Text(meditation)
                                .font(.bodySm)
                                .italic()
                                .foregroundStyle(Color.tertiaryText)
                                .lineSpacing(3)
                        }
                        .padding(.horizontal, 28)
                        .padding(.top, 8)
                    }

                    // Bead count within decade
                    if step.beadInDecade > 0 {
                        HStack(spacing: 4) {
                            ForEach(1...10, id: \.self) { i in
                                Circle()
                                    .fill(i <= step.beadInDecade ? Color.sanctuaryRed : Color.frameLine)
                                    .frame(width: 8, height: 8)
                            }
                        }
                        .padding(.top, 12)
                    }
                }
                .padding(.bottom, 100)
            }

            navBar
        }
        .background(Color.pageBackground.ignoresSafeArea())
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button("Done") { dismiss() }
                    .foregroundStyle(Color.sanctuaryRed)
            }
            ToolbarItem(placement: .principal) {
                Text("\(stepIndex + 1) / \(steps.count)")
                    .font(.captionSm)
                    .foregroundStyle(Color.tertiaryText)
            }
        }
    }

    // MARK: - Bead progress

    private var beadProgress: some View {
        let currentDecade = steps[stepIndex].decade
        return HStack(spacing: 6) {
            ForEach(0..<5, id: \.self) { d in
                Circle()
                    .fill(d < currentDecade ? Color.sanctuaryRed : d == currentDecade ? Color.goldLeaf : Color.frameLine)
                    .frame(width: 12, height: 12)
            }
        }
    }

    // MARK: - Nav bar

    private var navBar: some View {
        HStack(spacing: 18) {
            Button {
                if stepIndex > 0 { stepIndex -= 1 }
            } label: {
                Text("‹")
                    .font(.system(size: 22, design: .serif))
                    .foregroundStyle(Color.sanctuaryRed)
                    .frame(width: 52, height: 52)
                    .overlay(Rectangle().stroke(Color.sanctuaryRed.opacity(0.4), lineWidth: 0.5))
            }
            .buttonStyle(.plain)
            .disabled(stepIndex == 0)
            .opacity(stepIndex == 0 ? 0.4 : 1)

            Button {
                if stepIndex + 1 < steps.count {
                    stepIndex += 1
                } else {
                    UserProgress.markRosaryPrayed(set: set.slug)
                    didMark = true
                    stepIndex = steps.count
                }
            } label: {
                Text(stepIndex + 1 < steps.count ? "Next  ✠" : "Finish  ✠")
                    .smallLabel(color: Color.ivory, tracking: 3)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 17)
                    .background(Color.sanctuaryRed.opacity(0.85))
                    .overlay(Rectangle().stroke(Color.sanctuaryRed, lineWidth: 0.5))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 28)
        .padding(.top, 12)
        .padding(.bottom, 36)
        .background(
            LinearGradient(colors: [Color.pageBackground.opacity(0), Color.pageBackground], startPoint: .top, endPoint: .bottom)
        )
    }

    // MARK: - Completion

    private var completionView: some View {
        VStack(spacing: 16) {
            Spacer()
            Text("✠")
                .font(.system(size: 64))
                .foregroundStyle(Color.sanctuaryRed)
            Text("Rosary Complete")
                .font(.pageTitle)
                .foregroundStyle(Color.primaryText)
            Text(set.english)
                .font(.captionSm)
                .italic()
                .foregroundStyle(Color.secondaryText)
                .textCase(.uppercase)
                .tracking(2)
            Text("Marked as prayed today")
                .font(.captionSm)
                .foregroundStyle(Color.goldLeaf)
                .padding(.top, 8)
            Button { dismiss() } label: {
                Text("Done")
                    .smallLabel(color: Color.sanctuaryRed, tracking: 3)
                    .padding(.vertical, 14)
                    .frame(maxWidth: .infinity)
                    .overlay(Rectangle().stroke(Color.sanctuaryRed.opacity(0.6), lineWidth: 0.5))
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 28)
            .padding(.top, 20)
            Spacer()
        }
        .background(Color.pageBackground.ignoresSafeArea())
    }

    // MARK: - Build steps

    private func buildSteps() {
        var s: [RosaryStep] = []

        let signum = prayer("signum")
        let credo = prayer("credo")
        let pater = prayer("pater")
        let ave = prayer("ave")
        let gloria = prayer("gloria")
        let fatima = prayer("fatima")
        let salve = prayer("salve")

        // Opening
        s.append(RosaryStep(label: "Signum Crucis", latin: signum.0, english: signum.1, decade: 0))
        s.append(RosaryStep(label: "Credo", latin: credo.0, english: credo.1, decade: 0))
        s.append(RosaryStep(label: "Pater Noster", latin: pater.0, english: pater.1, decade: 0))
        for i in 1...3 {
            let virtue = ["Faith", "Hope", "Charity"][i - 1]
            s.append(RosaryStep(label: "Ave María (\(virtue))", latin: ave.0, english: ave.1, decade: 0, beadInDecade: i))
        }
        s.append(RosaryStep(label: "Glória Patri", latin: gloria.0, english: gloria.1, decade: 0))

        // 5 Decades
        for (dIdx, mystery) in set.mysteries.enumerated() {
            // Announce mystery
            s.append(RosaryStep(
                label: mystery.num,
                latin: mystery.title, english: mystery.eng,
                decade: dIdx, mystery: mystery,
                meditation: mystery.body + "\n\nFruit: " + mystery.fruit
            ))

            // Our Father
            s.append(RosaryStep(label: "Pater Noster", latin: pater.0, english: pater.1, decade: dIdx, mystery: mystery))

            // 10 Hail Marys
            for bead in 1...10 {
                s.append(RosaryStep(label: "Ave María  ·  \(bead) of 10", latin: ave.0, english: ave.1, decade: dIdx, mystery: mystery, beadInDecade: bead))
            }

            // Glory Be
            s.append(RosaryStep(label: "Glória Patri", latin: gloria.0, english: gloria.1, decade: dIdx, mystery: mystery))

            // Fatima Prayer
            s.append(RosaryStep(label: "Orátio Fátimæ", latin: fatima.0, english: fatima.1, decade: dIdx, mystery: mystery))
        }

        // Closing
        s.append(RosaryStep(label: "Salve Regína", latin: salve.0, english: salve.1, decade: 4))
        s.append(RosaryStep(label: "Signum Crucis", latin: signum.0, english: signum.1, decade: 4))

        steps = s
    }

    private func prayer(_ slug: String) -> (String, String) {
        guard let p = store.rosaryPrayers.first(where: { $0.slug == slug }),
              let line = p.lines.first else {
            return ("", "")
        }
        return (line.lat, line.eng)
    }
}

// MARK: - Step model

struct RosaryStep {
    let label: String
    let latin: String
    let english: String
    var decade: Int = 0
    var mystery: Mystery? = nil
    var meditation: String? = nil
    var beadInDecade: Int = 0
}
