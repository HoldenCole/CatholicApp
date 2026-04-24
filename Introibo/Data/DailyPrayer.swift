import Foundation

// Picks today's featured prayer. If the user follows a saint, the
// prayer is chosen from that saint's tradition. Otherwise falls back
// to the default weekday + season rotation.

enum DailyPrayer {
    // Saint-specific prayer mappings (slug of a prayer from prayers.json)
    private static let saintPrayers: [String: [String]] = [
        "pio":     ["morning", "actusContr", "michael", "anima", "memorare", "pater", "ave"],
        "therese": ["ave", "memorare", "morning", "gloriaPatri", "salve", "pater", "actusContr"],
        "aquinas": ["adoroTe", "tantumErgo", "anima", "pater", "ave", "suscipe", "morning"],
        "benedict": ["pater", "ave", "gloriaPatri", "morning", "actusContr", "salve", "memorare"],
        "teresa":  ["suscipe", "anima", "morning", "memorare", "ave", "pater", "actusContr"],
        "escriva": ["morning", "suscipe", "anima", "adoroTe", "pater", "ave", "actusContr"],
        "desales": ["morning", "salve", "memorare", "ave", "pater", "actusContr", "gloriaPatri"],
    ]

    static func slug(for ctx: LiturgicalContext) -> String {
        // If following a saint, use their prayer rotation by day of week
        if let saintSlug = UserProgress.followedSaint(),
           let prayers = saintPrayers[saintSlug] {
            return prayers[ctx.dayOfWeek % prayers.count]
        }

        // Season overrides
        switch ctx.season {
        case .advent:  return "memorare"
        case .lent:    return "confiteor"
        case .passion: return "actusContr"
        case .easter:  return "gloriaExcelsis"
        default: break
        }

        // Default weekday rotation
        let byDow = ["credoApost", "pater", "michael", "anima", "adoroTe", "crucifix", "salve"]
        return byDow[ctx.dayOfWeek]
    }
}
