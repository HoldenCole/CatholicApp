import Foundation

struct OfficeAssembler {
    let weeklyPsalter: [String: [String: Hour.Part]]
    let seasonalHymns: [String: [String: Hour.Part]]
    let marianAntiphons: [MarianAntiphonData]

    func assemble(template: Hour, context: LiturgicalContext) -> Hour {
        let dayKey = Self.dayKeys[context.dayOfWeek]
        let seasonKey = seasonString(for: context.season)
        let dayOverrides = weeklyPsalter[dayKey] ?? [:]
        let seasonOverrides = seasonalHymns[seasonKey] ?? [:]

        let assembledParts = template.parts.map { part -> Hour.Part in
            guard let key = part.variationKey else { return part }

            if part.type == "marian" {
                return marianPart(for: context.marian, fallback: part)
            }

            if part.type == "hymn", let override = seasonOverrides[key] {
                return override
            }

            if let override = dayOverrides[key] {
                return override
            }

            return part
        }

        // Post-assembly filtering for Matins nocturn structure and Te Deum.
        let finalParts: [Hour.Part]
        if template.slug == "matutinum" {
            finalParts = filterMatinsParts(assembledParts, context: context)
        } else {
            finalParts = assembledParts
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
    // TODO (Item 7): Feast-day psalm overrides are a future enhancement.
    // The current day-of-week psalter system is correct for the ferial office.
    // When a feast-rank system is added, feasts of rank 1-3 on weekdays should
    // restore 3 nocturns and substitute proper feast psalms/readings.

    private func filterMatinsParts(_ parts: [Hour.Part], context: LiturgicalContext) -> [Hour.Part] {
        let isWeekday = context.dayOfWeek != 0  // 0 = Sunday

        if isWeekday {
            // 1-Nocturn Matins: keep everything before "In II Nocturno",
            // skip Nocturns II & III and the Te Deum, keep the closing
            // elements (capitulum, collect, conclusion).
            return filterToOneNocturn(parts)
        } else {
            // 3-Nocturn Matins (Sunday): keep all nocturns but check
            // whether the Te Deum should be omitted for this Sunday.
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
