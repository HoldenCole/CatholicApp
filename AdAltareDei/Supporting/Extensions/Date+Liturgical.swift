import Foundation

extension Date {
    /// Returns the Latin feria name for the current weekday.
    var latinFeriaName: String {
        let weekday = Calendar.current.component(.weekday, from: self)
        switch weekday {
        case 1: return "Dominica"          // Sunday
        case 2: return "Feria Secunda"     // Monday
        case 3: return "Feria Tertia"      // Tuesday
        case 4: return "Feria Quarta"      // Wednesday
        case 5: return "Feria Quinta"      // Thursday
        case 6: return "Feria Sexta"       // Friday
        case 7: return "Sabbato"           // Saturday
        default: return ""
        }
    }

    /// Returns the English weekday name.
    var englishWeekdayName: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE"
        return formatter.string(from: self)
    }

    /// Returns a formatted date string like "March 26, 2026"
    var liturgicalDateString: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        return formatter.string(from: self)
    }

    /// Returns true if today is the same calendar day as the given date string (yyyy-MM-dd).
    func isSameDay(as dateString: String) -> Bool {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        guard let otherDate = formatter.date(from: dateString) else { return false }
        return Calendar.current.isDate(self, inSameDayAs: otherDate)
    }

    /// Returns today's date as a yyyy-MM-dd string.
    var dateKey: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: self)
    }
}
