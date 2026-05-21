import Foundation

struct OfficeAssembler {
    let weeklyPsalter: [String: [String: Hour.Part]]
    let seasonalHymns: [String: [String: Hour.Part]]
    let temporalPropers: [String: [String: Hour.Part]]
    let marianAntiphons: [MarianAntiphonData]

    func assemble(template: Hour, context: LiturgicalContext) -> Hour {
        let dayKey = Self.dayKeys[context.dayOfWeek]
        let seasonKey = seasonString(for: context.season)
        let dayOverrides = weeklyPsalter[dayKey] ?? [:]
        let seasonOverrides = seasonalHymns[seasonKey] ?? [:]
        let temporalOverrides = context.temporalKey.flatMap { temporalPropers[$0] } ?? [:]

        let assembledParts = template.parts.map { part -> Hour.Part in
            guard let key = part.variationKey else { return part }

            if part.type == "marian" {
                return marianPart(for: context.marian, fallback: part)
            }

            // Temporal propers (highest priority for non-psalm parts)
            if let override = temporalOverrides[key] {
                return override
            }

            if part.type == "hymn", let override = seasonOverrides[key] {
                return override
            }

            if let override = dayOverrides[key] {
                return override
            }

            return part
        }

        // Apply temporal per-psalm antiphon overrides.
        // Temporal keys like "laudes.antiphon.psalm1" replace the antiphon
        // on the corresponding psalm/canticle part.
        let antiphonApplied = assembledParts.map { part -> Hour.Part in
            guard let key = part.variationKey else { return part }
            // Build the antiphon override key for this part's position
            // e.g., "laudes.psalm1" → check "laudes.antiphon.psalm1"
            let hourPrefix = key.components(separatedBy: ".").first ?? ""
            // Lauds has: psalm1, psalm2, psalm3, canticle1, psalm4 (canticle in middle)
            // Vespers has: psalm1-psalm5 (all psalms)
            // Antiphon slots are always 1-5 in order. Map accordingly.
            let antKey: String?
            if key.hasSuffix(".psalm1") { antKey = "\(hourPrefix).antiphon.psalm1" }
            else if key.hasSuffix(".psalm2") { antKey = "\(hourPrefix).antiphon.psalm2" }
            else if key.hasSuffix(".psalm3") { antKey = "\(hourPrefix).antiphon.psalm3" }
            else if key.hasSuffix(".canticle1") { antKey = "\(hourPrefix).antiphon.psalm4" }
            else if key.hasSuffix(".psalm4") {
                // Lauds psalm4 is the 5th element (after canticle1)
                // Vespers psalm4 is the 4th element
                antKey = hourPrefix == "laudes" ? "\(hourPrefix).antiphon.psalm5" : "\(hourPrefix).antiphon.psalm4"
            }
            else if key.hasSuffix(".psalm5") { antKey = "\(hourPrefix).antiphon.psalm5" }
            else { antKey = nil }

            if let ak = antKey, let antOverride = temporalOverrides[ak] {
                var modified = part
                modified.antiphonLat = antOverride.lat
                modified.antiphonEng = antOverride.eng
                return modified
            }
            return part
        }

        // Post-assembly filtering for Matins nocturn structure and Te Deum.
        let finalParts: [Hour.Part]
        if template.slug == "matutinum" {
            finalParts = filterMatinsParts(antiphonApplied, context: context)
        } else {
            finalParts = antiphonApplied
        }

        return Hour(
            slug: template.slug,
            name: template.name,
            eng: template.eng,
            time: template.time,
            hour: template.hour,
            minute: template.minute,
            glyph: template.glyph,
            order: template.order,
            intro: template.intro,
            parts: finalParts
        )
    }

    // MARK: - Matins: 1-Nocturn vs 3-Nocturn filtering (Item 1 & Item 4)
    //
    // 1962 Breviary rules:
    //   3 Nocturns (9 psalms, 9 readings, Te Deum): Sundays, feasts rank 1-3
    //   1 Nocturn  (3 psalms, 3 readings, NO Te Deum): Ferial days (weekdays without a feast)
    //
    // Simplified logic (no full feast-rank system yet):
    //   Sunday (dayOfWeek == 0): always 3 nocturns
    //   Weekday (dayOfWeek 1-6): 1 nocturn (keep only Nocturn I material)
    //
    // Te Deum is also omitted on Sundays during:
    //   - Septuagesima, Sexagesima, Quinquagesima (pre-Lent Sundays)
    //   - Sundays in Lent
    //   - Passion Sunday and Palm Sunday
    //
    // Class I and II weekday feasts: when these fall on a weekday they have
    // 3-nocturn Matins with Te Deum, just like a Sunday. The current data
    // ranks Sundays + these feasts as rank 1 in propers.json.
    private static let highRankWeekdayFeasts: Set<String> = [
        // Christmas cycle
        "christmas", "circumcision", "epiphany", "purification",
        "st-stephen", "st-john-evangelist", "holy-innocents",
        // Easter octave (Mon–Sat)
        "easter-0-1", "easter-0-2", "easter-0-3", "easter-0-4", "easter-0-5", "easter-0-6",
        // Pentecost octave (Mon–Sat)
        "easter-7-1", "easter-7-2", "easter-7-3", "easter-7-4", "easter-7-5", "easter-7-6",
        // Major moveable feasts on weekdays
        "ascension", "corpus-christi", "sacred-heart",
        // Sanctorale Class I/II that often fall on weekdays
        "st-joseph", "annunciation", "st-joseph-worker",
        "sts-peter-paul", "nativity-john-baptist",
        "assumption", "nativity-bvm", "holy-rosary",
        "all-saints", "all-souls", "immaculate-conception",
        // Holy Week / Triduum
        "holy-thursday", "good-friday", "holy-saturday",
    ]

    private func filterMatinsParts(_ parts: [Hour.Part], context: LiturgicalContext) -> [Hour.Part] {
        let isWeekday = context.dayOfWeek != 0  // 0 = Sunday
        let isHighRankFeast = isWeekday
            && (context.properSlug.map { Self.highRankWeekdayFeasts.contains($0) } ?? false)
        let useThreeNocturns = !isWeekday || isHighRankFeast

        if !useThreeNocturns {
            // 1-Nocturn Matins: keep everything before "In II Nocturno",
            // skip Nocturns II & III and the Te Deum, keep the closing
            // elements (capitulum, collect, conclusion).
            return filterToOneNocturn(parts)
        } else {
            // 3-Nocturn Matins (Sunday or Class I/II weekday feast): keep
            // all nocturns but omit Te Deum on penitential Sundays.
            if shouldOmitTeDeum(context: context) {
                return parts.filter { !isTeDeum($0) }
            }
            return parts
        }
    }

    /// Reduce Matins to 1 nocturn by removing everything from the
    /// "In II Nocturno" heading through the Te Deum (inclusive).
    /// Keeps: Invitatory, Hymn, Nocturn I, Capitulum, Collect, Closing.
    private func filterToOneNocturn(_ parts: [Hour.Part]) -> [Hour.Part] {
        // Find the index of "In II Nocturno" heading.
        guard let nocturn2Index = parts.firstIndex(where: {
            $0.type == "heading" && ($0.label ?? "").contains("II Noct")
        }) else {
            // Template doesn't have Nocturn II — nothing to remove.
            return parts
        }

        // Find the Te Deum (canticle with "Te Deum" in label).
        // Everything after Te Deum is closing material we want to keep.
        let teDaumIndex = parts.firstIndex(where: { isTeDeum($0) })

        // Keep parts before Nocturn II.
        var kept = Array(parts[..<nocturn2Index])

        // Append parts after Te Deum (or after Nocturn III's last element
        // if Te Deum is somehow missing). The Te Deum itself is omitted
        // in 1-nocturn Matins.
        if let teDeumIdx = teDaumIndex {
            // Everything after the Te Deum line
            if teDeumIdx + 1 < parts.count {
                kept.append(contentsOf: parts[(teDeumIdx + 1)...])
            }
        } else {
            // Fallback: find the end of Nocturn III by looking for the
            // capitulum, collect, or closing elements.
            if let capIndex = parts.firstIndex(where: {
                $0.type == "capitulum" || $0.type == "collect" || $0.type == "closing"
            }), capIndex >= nocturn2Index {
                kept.append(contentsOf: parts[capIndex...])
            }
        }

        return kept
    }

    /// Te Deum is omitted on Sundays during Septuagesima-tide, Lent, and Passiontide.
    /// Septuagesima/Sexagesima/Quinquagesima Sundays are detected via properSlug.
    private func shouldOmitTeDeum(context: LiturgicalContext) -> Bool {
        // Lent and Passion Sundays: always omit
        if context.season == .lent || context.season == .passion {
            return true
        }

        // Pre-Lent Sundays (Septuagesima, Sexagesima, Quinquagesima)
        // are in perAnnum by the season detector but have distinctive
        // properSlug values.
        if let slug = context.properSlug {
            let preLentSlugs = ["septuagesima", "sexagesima", "quinquagesima"]
            if preLentSlugs.contains(slug) {
                return true
            }
        }

        return false
    }

    private func isTeDeum(_ part: Hour.Part) -> Bool {
        part.type == "canticle" && (part.label ?? "").contains("Te Deum")
    }

    // MARK: - Season string mapping

    private func seasonString(for season: LiturgicalSeason) -> String {
        switch season {
        case .advent:    return "advent"
        case .lent:      return "lent"
        case .passion:   return "passion"
        case .easter:    return "easter"
        case .christmas: return "christmas"
        case .pentecost: return "ordinary"
        case .perAnnum:  return "ordinary"
        }
    }

    private func marianPart(for antiphon: MarianAntiphon, fallback: Hour.Part) -> Hour.Part {
        // During Triduum the Marian antiphon is suppressed entirely.
        if antiphon.isSuppressed {
            return Hour.Part(
                type: "suppressed",
                variationKey: "completorium.marian"
            )
        }
        guard let data = marianAntiphons.first(where: { $0.slug == antiphon.rawValue }) else {
            return fallback
        }
        return Hour.Part(
            type: "marian",
            label: "Marian Antiphon; \(data.title)",
            title: data.title,
            lat: data.lat,
            eng: data.eng,
            season: data.season,
            engBody: data.engBody,
            variationKey: "completorium.marian"
        )
    }

    private static let dayKeys = [
        "sunday", "monday", "tuesday", "wednesday",
        "thursday", "friday", "saturday"
    ]
}
