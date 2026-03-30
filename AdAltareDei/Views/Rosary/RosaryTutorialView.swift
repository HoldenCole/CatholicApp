import SwiftUI

/// Step-by-step visual guide for beginners learning to pray the Rosary.
struct RosaryTutorialView: View {
    @State private var tutorial: RosaryTutorialData?

    var body: some View {
        ScrollView {
            if let tut = tutorial {
                VStack(alignment: .leading, spacing: 0) {
                    // Dark header
                    VStack(alignment: .leading, spacing: 4) {
                        Text(tut.title)
                            .font(.custom("Palatino", size: 26).weight(.bold))
                            .foregroundStyle(.white)
                        Text(tut.latinTitle)
                            .font(.custom("Palatino-Italic", size: 14))
                            .foregroundStyle(.goldLeaf)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 20)
                    .background(
                        LinearGradient(
                            colors: [Color(hex: "1C1410"), Color(hex: "2a2118")],
                            startPoint: .top, endPoint: .bottom
                        )
                    )

                    VStack(alignment: .leading, spacing: 0) {
                        // Introduction
                        ornamentalDivider
                        Text(tut.introduction)
                            .font(.custom("Georgia-Italic", size: 16))
                            .foregroundStyle(.secondary)
                            .lineSpacing(6)
                            .padding(.vertical, 12)

                        ornamentalDivider

                        // Steps as a timeline
                        Text("THE STEPS")
                            .font(.custom("Palatino-Italic", size: 12).weight(.semibold))
                            .foregroundStyle(.sanctuaryRed)
                            .tracking(3)
                            .padding(.bottom, 12)

                        // Timeline
                        VStack(alignment: .leading, spacing: 0) {
                            ForEach(tut.steps, id: \.step) { step in
                                stepView(step)
                            }
                        }

                        ornamentalDivider

                        // Tips
                        Text("TIPS FOR BEGINNERS")
                            .font(.custom("Palatino-Italic", size: 12).weight(.semibold))
                            .foregroundStyle(.sanctuaryRed)
                            .tracking(3)
                            .padding(.bottom, 12)

                        ForEach(Array(tut.tips.enumerated()), id: \.offset) { _, tip in
                            HStack(alignment: .top, spacing: 0) {
                                Rectangle()
                                    .fill(Color.goldLeaf.opacity(0.3))
                                    .frame(width: 2)
                                    .padding(.trailing, 14)
                                Text(tip)
                                    .font(.custom("Georgia", size: 15))
                                    .foregroundStyle(.ink)
                                    .lineSpacing(5)
                            }
                            .padding(.vertical, 8)
                        }

                        // Mystery schedule
                        ornamentalDivider
                        Text("MYSTERY SCHEDULE")
                            .font(.custom("Palatino-Italic", size: 12).weight(.semibold))
                            .foregroundStyle(.sanctuaryRed)
                            .tracking(3)
                            .padding(.bottom, 12)

                        mysteryScheduleView(tut.mysterySchedule)

                        Text("✿ · ✿")
                            .frame(maxWidth: .infinity)
                            .font(.system(size: 12))
                            .foregroundStyle(.goldLeaf.opacity(0.4))
                            .tracking(8)
                            .padding(.vertical, 32)
                    }
                    .padding(.horizontal, 24)
                }
            } else {
                LoadingView(message: "Loading tutorial...")
            }
        }
        .background(Color.parchment)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { loadTutorial() }
    }

    // MARK: - Step View (Timeline style)

    private func stepView(_ step: RosaryTutorialStep) -> some View {
        HStack(alignment: .top, spacing: 14) {
            // Step number circle
            VStack {
                ZStack {
                    Circle()
                        .fill(Color.sanctuaryRed.opacity(0.1))
                        .frame(width: 32, height: 32)
                    Text("\(step.step)")
                        .font(.custom("Palatino", size: 14).weight(.semibold))
                        .foregroundStyle(.sanctuaryRed)
                }
                Rectangle()
                    .fill(Color.goldLeaf.opacity(0.12))
                    .frame(width: 2)
            }
            .frame(width: 32)

            VStack(alignment: .leading, spacing: 4) {
                Text(step.title)
                    .font(.custom("Palatino", size: 17).weight(.semibold))
                    .foregroundStyle(.ink)

                if let bead = step.beadType {
                    Text(beadLabel(bead))
                        .font(.custom("Palatino-Italic", size: 12))
                        .foregroundStyle(.goldLeaf)
                }

                Text(step.description)
                    .font(.custom("Georgia", size: 15))
                    .foregroundStyle(.secondary)
                    .lineSpacing(5)
                    .padding(.top, 2)

                if let note = step.note {
                    Text(note)
                        .font(.custom("Georgia-Italic", size: 13))
                        .foregroundStyle(.goldLeaf)
                        .padding(.top, 2)
                }
            }
            .padding(.bottom, 16)
        }
    }

    private func beadLabel(_ type: String) -> String {
        switch type {
        case "crucifix": return "At the crucifix"
        case "large": return "Large bead (Our Father)"
        case "small": return "Small beads (Hail Mary)"
        case "none": return ""
        default: return type
        }
    }

    // MARK: - Mystery Schedule

    private func mysteryScheduleView(_ schedule: MysteryScheduleData) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            scheduleRow("Sunday", schedule.sunday)
            scheduleRow("Monday", schedule.monday)
            scheduleRow("Tuesday", schedule.tuesday)
            scheduleRow("Wednesday", schedule.wednesday)
            scheduleRow("Thursday", schedule.thursday)
            scheduleRow("Friday", schedule.friday)
            scheduleRow("Saturday", schedule.saturday)
            if let note = schedule.saturdayNote {
                Text(note)
                    .font(.custom("Georgia-Italic", size: 12))
                    .foregroundStyle(.goldLeaf)
                    .padding(.top, 8)
            }
        }
    }

    private func scheduleRow(_ day: String, _ mystery: String) -> some View {
        HStack {
            Text(day)
                .font(.custom("Palatino", size: 15))
                .foregroundStyle(.ink)
                .frame(width: 100, alignment: .leading)
            Text(mystery.capitalized + " Mysteries")
                .font(.custom("Palatino-Italic", size: 15))
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 6)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.goldLeaf.opacity(0.08))
                .frame(height: 1)
        }
    }

    // MARK: - Helpers

    private var ornamentalDivider: some View {
        HStack {
            Spacer()
            Rectangle()
                .frame(height: 1)
                .foregroundStyle(.clear)
                .background(
                    LinearGradient(
                        colors: [.clear, .goldLeaf.opacity(0.25), .clear],
                        startPoint: .leading, endPoint: .trailing
                    )
                )
            Spacer()
        }
        .padding(.vertical, 8)
    }

    private func loadTutorial() {
        guard let url = Bundle.main.url(forResource: "rosary_tutorial", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode(RosaryTutorialData.self, from: data) else {
            return
        }
        tutorial = decoded
    }
}

// MARK: - Data Models

struct RosaryTutorialData: Codable {
    let title: String
    let latinTitle: String
    let introduction: String
    let steps: [RosaryTutorialStep]
    let mysterySchedule: MysteryScheduleData
    let tips: [String]
}

struct RosaryTutorialStep: Codable {
    let step: Int
    let title: String
    let description: String
    let prayer: String?
    let beadType: String?
    let repetitions: Int?
    let note: String?
    let secondPrayer: String?
}

struct MysteryScheduleData: Codable {
    let sunday: String
    let monday: String
    let tuesday: String
    let wednesday: String
    let thursday: String
    let friday: String
    let saturday: String
    let saturdayNote: String?
}
