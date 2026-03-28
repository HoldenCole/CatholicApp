import Foundation

/// Represents a single step in the guided Rosary.
struct RosaryStep: Identifiable {
    let id = UUID()
    let type: RosaryStepType
    let prayerSlug: String
    let title: String
    let subtitle: String?
    let repetition: Int?     // e.g. "Hail Mary 3 of 10"
    let mysteryNumber: Int?  // which mystery (1-5)
    let decadeNumber: Int?   // which decade (1-5)
}

enum RosaryStepType: String {
    case signOfCross
    case creed
    case ourFather
    case hailMary
    case gloryBe
    case fatimaPrayer
    case mysteryAnnouncement
    case hailHolyQueen
    case finalPrayer
}

/// Builds the full sequence of Rosary steps for a given mystery set.
struct RosaryStepBuilder {
    static func buildSteps(for setType: MysterySetType, mysteries: [Mystery]) -> [RosaryStep] {
        var steps: [RosaryStep] = []
        let setMysteries = mysteries
            .filter { $0.setType == setType }
            .sorted { $0.mysteryNumber < $1.mysteryNumber }

        // Opening
        steps.append(RosaryStep(
            type: .signOfCross, prayerSlug: "signum_crucis",
            title: "Signum Crucis", subtitle: "Sign of the Cross",
            repetition: nil, mysteryNumber: nil, decadeNumber: nil
        ))
        steps.append(RosaryStep(
            type: .creed, prayerSlug: "credo",
            title: "Symbolum Apostolorum", subtitle: "Apostles' Creed",
            repetition: nil, mysteryNumber: nil, decadeNumber: nil
        ))
        steps.append(RosaryStep(
            type: .ourFather, prayerSlug: "pater_noster",
            title: "Pater Noster", subtitle: "Our Father (for the Holy Father's intentions)",
            repetition: nil, mysteryNumber: nil, decadeNumber: nil
        ))

        // 3 introductory Hail Marys (for Faith, Hope, Charity)
        let virtues = ["for Faith", "for Hope", "for Charity"]
        for i in 0..<3 {
            steps.append(RosaryStep(
                type: .hailMary, prayerSlug: "ave_maria",
                title: "Ave Maria", subtitle: "Hail Mary \(virtues[i])",
                repetition: i + 1, mysteryNumber: nil, decadeNumber: nil
            ))
        }

        steps.append(RosaryStep(
            type: .gloryBe, prayerSlug: "gloria_patri",
            title: "Gloria Patri", subtitle: "Glory Be",
            repetition: nil, mysteryNumber: nil, decadeNumber: nil
        ))

        // Five Decades
        for decade in 0..<5 {
            let mystery = decade < setMysteries.count ? setMysteries[decade] : nil

            // Announce mystery
            steps.append(RosaryStep(
                type: .mysteryAnnouncement, prayerSlug: "",
                title: mystery?.latinTitle ?? "Mystery \(decade + 1)",
                subtitle: mystery?.englishTitle,
                repetition: nil, mysteryNumber: decade + 1, decadeNumber: decade + 1
            ))

            // Our Father
            steps.append(RosaryStep(
                type: .ourFather, prayerSlug: "pater_noster",
                title: "Pater Noster", subtitle: "Decade \(decade + 1) — Our Father",
                repetition: nil, mysteryNumber: decade + 1, decadeNumber: decade + 1
            ))

            // 10 Hail Marys
            for hm in 0..<10 {
                steps.append(RosaryStep(
                    type: .hailMary, prayerSlug: "ave_maria",
                    title: "Ave Maria", subtitle: "Hail Mary \(hm + 1) of 10",
                    repetition: hm + 1, mysteryNumber: decade + 1, decadeNumber: decade + 1
                ))
            }

            // Glory Be
            steps.append(RosaryStep(
                type: .gloryBe, prayerSlug: "gloria_patri",
                title: "Gloria Patri", subtitle: nil,
                repetition: nil, mysteryNumber: decade + 1, decadeNumber: decade + 1
            ))

            // Fatima Prayer
            steps.append(RosaryStep(
                type: .fatimaPrayer, prayerSlug: "fatima_prayer",
                title: "O mi Iesu", subtitle: "Fatima Prayer",
                repetition: nil, mysteryNumber: decade + 1, decadeNumber: decade + 1
            ))
        }

        // Closing
        steps.append(RosaryStep(
            type: .hailHolyQueen, prayerSlug: "salve_regina",
            title: "Salve Regina", subtitle: "Hail Holy Queen",
            repetition: nil, mysteryNumber: nil, decadeNumber: nil
        ))
        steps.append(RosaryStep(
            type: .finalPrayer, prayerSlug: "sub_tuum",
            title: "Sub Tuum Praesidium", subtitle: "Final Prayer (optional)",
            repetition: nil, mysteryNumber: nil, decadeNumber: nil
        ))

        return steps
    }
}
