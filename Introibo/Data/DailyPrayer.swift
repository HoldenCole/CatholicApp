import Foundation

// Picks today's featured prayer. Mirrors the rotation logic from
// prototype/prayers.html's pickDailyPrayer():
//   Sun Credo · Mon Pater · Tue Michael · Wed Anima · Thu Adoro Te ·
//   Fri Crucifix (En Ego) · Sat Salve Regina.
// Season overrides take precedence:
//   Advent    → Memorare
//   Lent      → Confiteor
//   Passion   → Actus Contritionis
//   Eastertide → Gloria in Excelsis

enum DailyPrayer {
    static func slug(for ctx: LiturgicalContext) -> String {
        switch ctx.season {
        case .advent:  return "memorare"
        case .lent:    return "confiteor"
        case .passion: return "actusContr"
        case .easter:  return "gloriaExcelsis"
        default: break
        }
        let byDow = ["credoApost", "pater", "michael", "anima", "adoroTe", "crucifix", "salve"]
        return byDow[ctx.dayOfWeek]
    }
}
