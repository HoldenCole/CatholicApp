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

// MARK: - Memberwise initializers for assembly

extension Hour {
    init(slug: String, name: String, eng: String, time: String,
         hour: Int, minute: Int, glyph: String, order: Int,
         intro: String, parts: [Part]) {
        self.slug = slug; self.name = name; self.eng = eng
        self.time = time; self.hour = hour; self.minute = minute
        self.glyph = glyph; self.order = order; self.intro = intro
        self.parts = parts
    }
}

extension Hour.Part {
    init(type: String, label: String? = nil, title: String? = nil,
         ref: String? = nil, lat: String? = nil, eng: String? = nil,
         latR: String? = nil, engR: String? = nil,
         v1Lat: String? = nil, v1Eng: String? = nil,
         r1Lat: String? = nil, r1Eng: String? = nil,
         v2Lat: String? = nil, v2Eng: String? = nil,
         r2Lat: String? = nil, r2Eng: String? = nil,
         verses: [Verse]? = nil, season: String? = nil,
         engBody: String? = nil, variationKey: String? = nil) {
        self.type = type; self.label = label; self.title = title
        self.ref = ref; self.lat = lat; self.eng = eng
        self.latR = latR; self.engR = engR
        self.v1Lat = v1Lat; self.v1Eng = v1Eng
        self.r1Lat = r1Lat; self.r1Eng = r1Eng
        self.v2Lat = v2Lat; self.v2Eng = v2Eng
        self.r2Lat = r2Lat; self.r2Eng = r2Eng
        self.verses = verses; self.season = season
        self.engBody = engBody; self.variationKey = variationKey
    }
}
