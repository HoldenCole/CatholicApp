import Foundation

struct MysteryScheduleService {
    /// Returns the mystery set type(s) for a given date based on traditional assignment.
    ///
    /// | Day       | Mystery Set  |
    /// |-----------|-------------|
    /// | Sunday    | Glorious    |
    /// | Monday    | Joyful      |
    /// | Tuesday   | Sorrowful   |
    /// | Wednesday | Glorious    |
    /// | Thursday  | Joyful      |
    /// | Friday    | Sorrowful   |
    /// | Saturday  | Joyful (with note about Glorious) |
    static func mysterySetTypes(for date: Date) -> [MysterySetType] {
        let weekday = Calendar.current.component(.weekday, from: date)
        switch weekday {
        case 1: return [.glorious]           // Sunday
        case 2: return [.joyful]             // Monday
        case 3: return [.sorrowful]          // Tuesday
        case 4: return [.glorious]           // Wednesday
        case 5: return [.joyful]             // Thursday
        case 6: return [.sorrowful]          // Friday
        case 7: return [.joyful, .glorious]  // Saturday — both traditional options
        default: return [.joyful]
        }
    }

    /// Returns the primary mystery set for today.
    static func todaysPrimarySet() -> MysterySetType {
        mysterySetTypes(for: Date()).first ?? .joyful
    }

    /// Returns true if Saturday, where tradition varies.
    static func isSaturdayAmbiguous(for date: Date = Date()) -> Bool {
        Calendar.current.component(.weekday, from: date) == 7
    }

    /// Saturday note explaining the tradition.
    static let saturdayNote = "Traditional practice varies for Saturday. Some sources assign the Joyful Mysteries, while others assign the Glorious. Both are shown here."
}
