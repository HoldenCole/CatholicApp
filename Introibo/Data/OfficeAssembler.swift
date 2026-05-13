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
            parts: assembledParts
        )
    }

    private func seasonString(for season: LiturgicalSeason) -> String {
        switch season {
        case .advent:    return "advent"
        case .lent:      return "lent"
        case .passion:   return "passion"
        case .easter:    return "easter"
        case .christmas: return "ordinary"
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
