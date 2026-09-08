import Foundation

// Matches Introibo/Resources/martyrology.json — the Martyrologium Romanum
// (1960 edition) read in the second part of Prime. `days` is keyed
// "MM-DD"; `mobile` holds the movable-feast announcements keyed by the
// temporal day code (e.g. "pasc0-1"). The Martyrology read at Prime on
// day D is the entry for D+1, as in choir.
struct MartyrologyEntry: Decodable, Hashable {
    let lat: String
    var eng: String
}

struct MartyrologyDay: Decodable, Hashable {
    /// The Roman date, e.g. "Octávo Kaléndas Aprílis".
    let title: String
    var entries: [MartyrologyEntry]
}

struct MartyrologyData: Decodable {
    var days: [String: MartyrologyDay]
    var mobile: [String: MartyrologyEntry]
    /// "en" or "es": which vernacular the `eng` fields currently carry.
    /// Set by ContentStore when the Spanish overlay is applied; the
    /// assembler uses it for the fixed strings (date line, Et álibi).
    var vernacular: String = "en"

    enum CodingKeys: String, CodingKey { case days, mobile }
}

/// The lunar age printed at the head of the Martyrology ("Luna sexta"),
/// after the epact tables of the Martyrologium Romanum. A direct port of
/// Divinum Officium's specprima.pl, validated against it for 2024–2028.
enum MartyrologyLuna {
    private static let letters = Array("abcdefghiklmnpqrstuABCDERFGHMNP")

    private static func isLeap(_ y: Int) -> Bool { y % 4 == 0 && (y % 100 != 0 || y % 400 == 0) }

    private static func yearDay(_ d: Int, _ m: Int, _ y: Int) -> Int {
        let c = [0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334]
        var n = c[m - 1] + d
        if isLeap(y) && m > 2 { n += 1 }
        return n
    }

    private static func table(_ yday: Int, _ letter: Character) -> Int {
        let lp = (letters.firstIndex(of: letter) ?? 0) + 1
        let m: Int
        if yday < 36 { m = 30 } else {
            var r = (yday - 35) % 59
            if r == 0 { r = 59 }
            m = r < 29 ? 29 : 30
        }
        var i = yday % 59 < 36 ? lp : lp - 1
        if yday % 59 < 36 {
            if lp > 25 { i -= 1 }
            if lp == 25 && yday % 59 == 35 { i += 1 }
        } else {
            if lp > 25 { i -= 2 }
        }
        if yday > 58 {
            if lp > 25 && yday % 59 < 5 { i -= 1 }
            if lp == 26 && yday % 59 == 5 { i -= 1 }
        }
        var v = (i - 1 + (yday % 59)) % m
        if v < 0 { v += m }
        return v + 1
    }

    /// Age of the moon (1–30) for a civil date; nil outside 1700–2299.
    static func lunarAge(month: Int, day: Int, year: Int) -> Int? {
        let tbl: String
        switch year {
        case ..<1700: return nil
        case ..<1900: tbl = "PlCcpFfsMiAamDdqGgt"
        case ..<2200: tbl = "NkBbnEerHhuPlCcpRfs"
        case ..<2300: tbl = "MiAamDdqGgtNkBbnEer"
        default: return nil
        }
        let aur = year % 19 + 1
        let letter = Array(tbl)[aur - 1]
        var yd = yearDay(day, month, year)
        if isLeap(year) && (month > 2 || (month == 2 && day > 23)) { yd -= 1 }
        var l = table(yd, letter)
        if aur == 1 && month == 1 && letter != "P" && day + table(1, letter) < 32 { l -= 1 }
        return l
    }

    static let latinOrdinals = [
        "prima", "secúnda", "tértia", "quarta", "quinta", "sexta", "séptima", "octáva", "nona", "décima",
        "undécima", "duodécima", "tértia décima", "quarta décima", "quinta décima", "sexta décima",
        "décima séptima", "duodevicésima", "undevicésima", "vicésima", "vicésima prima", "vicésima secúnda",
        "vicésima tértia", "vicésima quarta", "vicésima quinta", "vicésima sexta", "vicésima séptima",
        "vicésima octáva", "vicésima nona", "tricésima",
    ]
    static let spanishOrdinals = [
        "primera", "segunda", "tercera", "cuarta", "quinta", "sexta", "séptima", "octava", "novena", "décima",
        "undécima", "duodécima", "decimotercera", "decimocuarta", "decimoquinta", "decimosexta",
        "decimoséptima", "decimoctava", "decimonovena", "vigésima", "vigésima primera", "vigésima segunda",
        "vigésima tercera", "vigésima cuarta", "vigésima quinta", "vigésima sexta", "vigésima séptima",
        "vigésima octava", "vigésima novena", "trigésima",
    ]
    static let englishMonths = ["January", "February", "March", "April", "May", "June", "July", "August",
                                "September", "October", "November", "December"]
    static let spanishMonths = ["enero", "febrero", "marzo", "abril", "mayo", "junio", "julio", "agosto",
                                "septiembre", "octubre", "noviembre", "diciembre"]

    static func englishOrdinal(_ n: Int) -> String {
        let suffix: String
        if (11...13).contains(n % 100) { suffix = "th" }
        else { switch n % 10 { case 1: suffix = "st"; case 2: suffix = "nd"; case 3: suffix = "rd"; default: suffix = "th" } }
        return "\(n)\(suffix)"
    }
}
