import Foundation

// The iOS side of the Office parity dump: the same JSON the Android
// OfficeJsonDump test writes with OFFICE_JSON_FULL=1.
let env = ProcessInfo.processInfo.environment
let outDir = env["OFFICE_JSON_DIR"] ?? "/tmp/iosqa"
let fmt = DateFormatter()
fmt.calendar = Calendar.liturgical
fmt.locale = Locale(identifier: "en_US_POSIX")
fmt.timeZone = TimeZone.current
fmt.dateFormat = "yyyy-MM-dd"
let start = fmt.date(from: env["OFFICE_JSON_START"] ?? "2025-11-30")!
let end = fmt.date(from: env["OFFICE_JSON_END"] ?? "2026-11-28")!
let rites = (env["OFFICE_JSON_RITES"] ?? "1962,1955,pre1955").split(separator: ",").map { MissalRite(rawValue: String($0))! }
let hours = ["matutinum", "laudes", "prima", "tertia", "sexta", "nona", "vesperae", "completorium"]
// OFFICE_JSON_LANG=es dumps the Spanish office (the overlay is applied at load).
UserDefaults.standard.set(env["OFFICE_JSON_LANG"] ?? "en", forKey: SettingsKey.vernacularLang)
let store = ContentStore.shared

func put(_ d: inout [String: Any], _ k: String, _ v: Any?) { if let v { d[k] = v } }
func partJSON(_ p: Hour.Part) -> [String: Any] {
    var d: [String: Any] = ["type": p.type]
    put(&d, "label", p.label); put(&d, "title", p.title); put(&d, "vk", p.variationKey); put(&d, "ref", p.ref)
    put(&d, "lat", p.lat); put(&d, "latR", p.latR)
    put(&d, "v1", p.v1Lat); put(&d, "r1", p.r1Lat); put(&d, "v2", p.v2Lat); put(&d, "r2", p.r2Lat)
    put(&d, "ant", p.antiphonLat)
    put(&d, "verses", p.verses?.map { $0.lat })
    put(&d, "eng", p.eng); put(&d, "engR", p.engR)
    put(&d, "v1e", p.v1Eng); put(&d, "r1e", p.r1Eng); put(&d, "v2e", p.v2Eng); put(&d, "r2e", p.r2Eng)
    put(&d, "ante", p.antiphonEng); put(&d, "engBody", p.engBody)
    put(&d, "versesE", p.verses?.map { $0.eng })
    put(&d, "intoned", p.antiphonIntoned); put(&d, "season", p.season)
    return d
}
func textJSON(_ t: ProperText?) -> Any? { t.map { ["lat": $0.lat, "eng": $0.eng] as [String: Any] } }

var d = start
var n = 0
while d <= end {
    let ds = fmt.string(from: d)
    for rite in rites {
        var doc: [String: Any] = ["date": ds, "rite": rite.rawValue]
        if let o = store.ordoForDate(d, rite: rite) {
            var od: [String: Any] = ["name": o.name, "winner": o.winner, "winnerKey": o.winnerKey, "rank": o.rank, "season": o.season]
            put(&od, "commemoration", o.commemoration)
            doc["ordo"] = od
        }
        var hs: [String: Any] = [:]
        for slug in hours {
            if let h = store.hourForDate(slug: slug, date: d, rite: rite) { hs[slug] = h.parts.map(partJSON) }
        }
        doc["hours"] = hs
        if let m = store.properForDate(d, rite: rite) {
            var md: [String: Any] = ["slug": m.slug, "title": m.title, "rank": m.rank, "color": m.color]
            put(&md, "introit", textJSON(m.introit)); put(&md, "collect", textJSON(m.collect))
            put(&md, "epistle", ["ref": m.epistle.ref, "lat": m.epistle.lat, "eng": m.epistle.eng])
            put(&md, "gradual", textJSON(m.gradual)); put(&md, "alleluia", textJSON(m.alleluia)); put(&md, "tract", textJSON(m.tract))
            put(&md, "sequence", textJSON(m.sequence))
            put(&md, "gospel", ["ref": m.gospel.ref, "lat": m.gospel.lat, "eng": m.gospel.eng])
            put(&md, "offertory", textJSON(m.offertory)); put(&md, "secret", textJSON(m.secret))
            put(&md, "communion", textJSON(m.communion)); put(&md, "postcommunion", textJSON(m.postcommunion))
            put(&md, "preface", m.preface); put(&md, "glor", m.glorOverride); put(&md, "credo", m.credoOverride)
            doc["mass"] = md
        }
        let dir = "\(outDir)/\(rite.rawValue)"
        try? FileManager.default.createDirectory(atPath: dir, withIntermediateDirectories: true)
        let data = try! JSONSerialization.data(withJSONObject: doc, options: [.sortedKeys])
        try! data.write(to: URL(fileURLWithPath: "\(dir)/\(ds).json"))
    }
    d = d.addingDays(1)
    n += 1
}
print("dumped \(n) days")
