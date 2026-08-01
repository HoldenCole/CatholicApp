import Foundation

struct OfficeAssembler {
    let weeklyPsalter: [String: [String: Hour.Part]]
    let seasonalHymns: [String: [String: Hour.Part]]
    let temporalPropers: [String: [String: Hour.Part]]
    let marianAntiphons: [MarianAntiphonData]
    let psalter: [String: [String: [String]]]  // key -> {lat: [verses], eng: [verses]}

    // MARK: - Temporal-propers key translation
    //
    // The hours.json variationKeys now use the same key format as the
    // DivinumOfficium import (e.g. "capitulum_laudes", "hymnus_vespera",
    // "ant_laudes").  This alias table handles variant spellings (e.g.
    // "hymnusm_*" metre variants → canonical hymn key) and provides
    // backward compatibility with legacy dotted keys that may still
    // appear in psalter_weekly or hymns_seasonal.
    //
    // Direction: source key → canonical variationKey in hours.json
    private static let temporalKeyAliases: [String: String] = [
        // Lauds — variant hymn spellings / rubric variants
        "hymnusm_laudes":           "hymnus_laudes",
        "hymnus_laudes_":           "hymnus_laudes",
        "ant_laudes_":              "ant_laudes",
        "ant_laudesc":              "ant_laudes",
        // Vespers — variant hymn spellings / rubric variants
        // (ant_vespera_3 — the 2nd-Vespers psalm-antiphon list — is handled
        // semantically in remapProperOverrides, NOT aliased onto the
        // Magnificat-antiphon slot.)
        "hymnusm_vespera":          "hymnus_vespera",
        "hymnus_vespera_3":         "hymnus_vespera",
        // Vespers — capitulum variants (sanctoral, e.g. Christmas)
        "capitulum_vespera_1":      "vesperae.capitulum",
        "capitulum_vespera_3":      "vesperae.capitulum",
        // Matins — variant hymn spelling
        "hymnusm_matutinum":        "hymnus_matutinum",
        "hymnus_matutinum_":        "hymnus_matutinum",
        // Nocturn versum variants (trailing underscore = rubrical variant)
        "nocturn_2_versum_":        "nocturn_2_versum",
        "nocturn_3_versum_":        "nocturn_3_versum",
        // Versicle variant with trailing underscore
        "versum_1_":                "versum_1",
        // Doxology rubric variant
        "doxology_":                "doxology",
        // Vespers — 2nd Vespers versicle falls back to the versum_2 slot
        // when versum_2 is absent (rare; only 1 entry has versum_3 alone)
        "versum_3":                 "versum_2",
    ]

    /// Build an expanded overrides dictionary that includes both the raw
    /// temporal-propers keys AND their translated hours.json equivalents.
    private static func expandedOverrides(_ raw: [String: Hour.Part]) -> [String: Hour.Part] {
        var result = raw
        for (tpKey, vk) in temporalKeyAliases {
            if let part = raw[tpKey], result[vk] == nil {
                result[vk] = part
            }
        }
        // Reverse direction: if hours.json-style key exists, also expose
        // under the DO key so downstream code can find it either way.
        for (tpKey, vk) in temporalKeyAliases {
            if let part = raw[vk], result[tpKey] == nil {
                result[tpKey] = part
            }
        }
        return result
    }

    // MARK: - Semantic key remapping (DivinumOfficium → template slots)
    //
    // The DO import keeps DO's own section semantics, which COLLIDE with the
    // template's variationKeys:
    //   Ant 1/2/3      = 1st-Vespers Magnificat / Benedictus / 2nd-Vespers
    //                    Magnificat antiphons (canticle antiphons) — but the
    //                    template's ant_1/2/3 are the MATINS NOCTURN slots.
    //   Ant Matutinum  = the nocturn antiphons, as a newline list.
    //   Ant Vespera / Ant Laudes = the five PSALM antiphons as a newline list
    //                    (the curated communes already carry single-line
    //                    canticle antiphons under these keys instead).
    //   Versum 1/2/3   = 1st-Vespers / Lauds / 2nd-Vespers versicles — but
    //                    the template's versum_1 is the LAUDS slot and
    //                    versum_2 the VESPERS slot.
    // This remap rebinds an override dict for ONE assembled hour so every
    // piece lands on its rubrically correct slot. Without it, Sundays put
    // canticle antiphons on Matins, feasts dump five psalm antiphons into
    // the Magnificat slot, and proper hymns never match at all.

    /// Newline-split of a part's Latin text (the DO list convention).
    private static func latLines(_ part: Hour.Part?) -> [String] {
        guard let lat = part?.lat else { return [] }
        return lat.split(separator: "\n").map(String.init).filter { !$0.isEmpty }
    }

    private static func engLines(_ part: Hour.Part?) -> [String] {
        guard let eng = part?.eng else { return [] }
        return eng.split(separator: "\n").map(String.init).filter { !$0.isEmpty }
    }

    /// A single antiphon part built from one line of a DO list (or a whole
    /// single-antiphon part), rekeyed onto a template slot.
    private static func antiphonPart(lat: String, eng: String?, label: String, vk: String) -> Hour.Part {
        var p = Hour.Part(type: "antiphon")
        p.label = label
        p.lat = lat
        p.eng = eng
        p.variationKey = vk
        return p
    }

    private static func rekeyed(_ part: Hour.Part, _ vk: String) -> Hour.Part {
        var p = part
        p.variationKey = vk
        return p
    }

    /// Distribute a multi-line antiphon list onto the per-psalm dotted keys
    /// ("<prefix>.antiphon.psalmN"), without clobbering explicit ones.
    private static func setPsalmAntiphons(prefix: String, list: Hour.Part,
                                          into o: inout [String: Hour.Part]) {
        let lats = latLines(list)
        let engs = engLines(list)
        for (i, lat) in lats.enumerated() where i < 9 {
            let key = "\(prefix).antiphon.psalm\(i + 1)"
            guard o[key] == nil else { continue }
            o[key] = antiphonPart(lat: lat, eng: i < engs.count ? engs[i] : nil,
                                  label: "Antiphon", vk: key)
        }
    }

    /// Hour-aware semantic remap of a proper/commune/temporal override dict.
    /// Also runs the spelling-alias expansion. Use this for EVERY layered
    /// override dict (temporal, sanctoral, commune, inherited, pre-1955 "o").
    static func remapProperOverrides(_ raw: [String: Hour.Part], hourSlug: String) -> [String: Hour.Part] {
        var o = expandedOverrides(raw)
        let ant1 = o["ant_1"], ant2 = o["ant_2"], ant3 = o["ant_3"]
        // Canticle antiphons must never sit on the Matins nocturn slots.
        o.removeValue(forKey: "ant_1")
        o.removeValue(forKey: "ant_2")
        o.removeValue(forKey: "ant_3")

        switch hourSlug {
        case "matutinum":
            // Pre-normalized entries (the psalm-slot generator emits explicit
            // matutinum.psalmN parts plus their nocturn antiphons/suppressions
            // under PREFIXED matutinum.ant_N keys — the plain ant_1/2/3 keys
            // hold the canticle antiphons): bind the prefixed keys.
            if raw["matutinum.psalm2"] != nil {
                for k in ["ant_1", "ant_2", "ant_3"] {
                    if let p = raw["matutinum.\(k)"] { o[k] = p }
                }
                o.removeValue(forKey: "ant_matutinum")
                break
            }
            // Nocturn antiphons from "Ant Matutinum": one chunk per nocturn.
            let lats = latLines(o["ant_matutinum"])
            if !lats.isEmpty {
                let engs = engLines(o["ant_matutinum"])
                let per = max(1, Int((Double(lats.count) / 3.0).rounded(.up)))
                for n in 0..<3 {
                    let slice = lats.dropFirst(n * per).prefix(per)
                    guard !slice.isEmpty else { continue }
                    let engSlice = engs.dropFirst(n * per).prefix(per)
                    o["ant_\(n + 1)"] = antiphonPart(
                        lat: slice.joined(separator: "\n"),
                        eng: engSlice.isEmpty ? nil : engSlice.joined(separator: "\n"),
                        label: "Antiphon", vk: "ant_\(n + 1)")
                }
            }

        case "laudes":
            // A multi-line "Ant Laudes" is the five psalm antiphons; a
            // single-line one (curated communes) is the Benedictus antiphon.
            if let al = o["ant_laudes"], latLines(al).count >= 2 {
                setPsalmAntiphons(prefix: "laudes", list: al, into: &o)
                o.removeValue(forKey: "ant_laudes")
            }
            if o["ant_laudes"] == nil, let a2 = ant2 {
                o["ant_laudes"] = rekeyed(a2, "ant_laudes")
            }
            // Lauds versicle is DO's "Versum 2" (Versum 1 is 1st Vespers').
            if let v = o["versum_2"] ?? raw["versum_2"] {
                o["versum_1"] = rekeyed(v, "versum_1")
            }
            o.removeValue(forKey: "versum_2")

        case "vesperae":
            // The 2nd-Vespers capitulum (Capitulum Vespera 3) wins over the
            // 1st-Vespers one when both exist (the alias table maps both
            // onto vesperae.capitulum unordered).
            if let cap3 = raw["capitulum_vespera_3"] {
                o["vesperae.capitulum"] = rekeyed(cap3, "vesperae.capitulum")
            }
            // Psalm antiphons: the 2nd-Vespers list (Ant Vespera 3) wins
            // over the 1st-Vespers/shared list (Ant Vespera).
            if let list = o["ant_vespera_3"] ?? o["ant_vespera_3c"] {
                setPsalmAntiphons(prefix: "vesperae", list: list, into: &o)
            } else if let av = o["ant_vespera"], latLines(av).count >= 2 {
                setPsalmAntiphons(prefix: "vesperae", list: av, into: &o)
            }
            if let av = o["ant_vespera"], latLines(av).count >= 2 {
                o.removeValue(forKey: "ant_vespera")
            }
            o.removeValue(forKey: "ant_vespera_3")
            o.removeValue(forKey: "ant_vespera_3c")
            // Magnificat antiphon: DO's Ant 3 (2nd Vespers), else Ant 1.
            if o["ant_vespera"] == nil, let a = ant3 ?? ant1 {
                o["ant_vespera"] = rekeyed(a, "ant_vespera")
            }
            // Vespers versicle: Versum 3 (2nd Vespers), else Versum 1 (1st
            // Vespers — usually identical); DO's Versum 2 is the LAUDS
            // versicle and must not land here.
            if let v = raw["versum_3"] ?? raw["versum_1"] {
                o["versum_2"] = rekeyed(v, "versum_2")
            } else {
                o.removeValue(forKey: "versum_2")
            }

        default:
            break
        }
        return o
    }

    /// "pent10-3" → "pent10-0": the Sunday whose week the feria belongs to.
    static func precedingSundayKey(_ temporalKey: String) -> String? {
        guard let dashIdx = temporalKey.lastIndex(of: "-") else { return nil }
        let daySuffix = temporalKey[temporalKey.index(after: dashIdx)...]
        guard daySuffix.count == 1, let dayNum = Int(daySuffix),
              dayNum >= 1 && dayNum <= 6 else { return nil }
        return String(temporalKey[...dashIdx]) + "0"
    }

    // MARK: - Easter/Pentecost Octave detection
    //
    // During the octaves of Easter (pasc0-*) and Pentecost (pasc7-*), all
    // days are I class. Rubric 172 requires Sunday psalms at all hours
    // (Lauds, Vespers, Little Hours) and the festal Prime set (Ps 53,
    // 118 pars I, 118 pars II — omitting Ps 117).

    /// Returns true when the current day falls within the Easter or Pentecost
    /// octave (including the Sunday itself, though Sunday already uses the
    /// Sunday psalter by default).
    private static func isEasterOrPentecostOctave(context: LiturgicalContext) -> Bool {
        guard let key = context.temporalKey else { return false }
        return key.hasPrefix("pasc0-") || key.hasPrefix("pasc7-")
    }

    // MARK: - Festal psalm keys
    // On feasts (Semiduplex and above, rank ≥ 2.0), Lauds and Vespers use the
    // festal psalm scheme baked into the hour template (Lauds: 92/99/62/
    // Benedicite/148-150; Vespers: 109-113) rather than the weekday ferial set.
    // These are the variationKeys for those psalm/canticle parts.
    private static let festalPsalmKeys: Set<String> = [
        "laudes.psalm1", "laudes.psalm2", "laudes.psalm3",
        "laudes.canticle1", "laudes.psalm4",
        "vesperae.psalm1", "vesperae.psalm2", "vesperae.psalm3",
        "vesperae.psalm4", "vesperae.psalm5",
    ]

    // Compline uses the Sunday psalms (Ps 4, 90, 133) only on Sundays and
    // feasts of I and II class (rank >= 5); ferias, Simples, and III-class
    // feasts use the day-of-the-week ferial Compline. The threshold is
    // higher than Lauds/Vespers, so it gets its own flag and key set.
    private static let festalComplineKeys: Set<String> = [
        "completorium.antiphon",
        "completorium.psalm1", "completorium.psalm2", "completorium.psalm3",
    ]

    // The Little Hours (Terce, Sext, None) take the Sunday psalms (portions
    // of Ps 118) only on Sundays and feasts of I class (rank >= 6); ferias,
    // Simples, and III/II-class feasts use the day-of-the-week ferial psalms.
    // This is a higher threshold than Compline (II class), per the 1960
    // rubrics, so it gets its own flag and key set.
    private static let festalLittleHourKeys: Set<String> = [
        "ant_tertia", "tertia.psalm1", "tertia.psalm2", "tertia.psalm3",
        "ant_sexta", "sexta.psalm1", "sexta.psalm2", "sexta.psalm3",
        "ant_nona", "nona.psalm1", "nona.psalm2", "nona.psalm3",
    ]

    /// Hours whose collect is the collect OF THE DAY. Prime and Compline are
    /// absent on purpose: their collects are invariable (keyed oratio_prima /
    /// oratio_completorium so no day override can ever reach them).
    private static let collectHours: Set<String> = [
        "matutinum", "laudes", "tertia", "sexta", "nona", "vesperae",
    ]

    /// Weekday-psalter keys that belong to the FERIAL office only; festal
    /// days keep the template defaults until the proper/commune layers apply.
    private static let ferialOnlyDayKeys: Set<String> = [
        "hymnus_laudes", "hymnus_vespera",
        "ant_laudes", "ant_vespera",
        "versum_1", "versum_2",
    ]

    /// Mapping from a psalm part's variationKey to the antiphon-override key
    /// that carries its proper antiphon. Lauds has psalm1-3, canticle1,
    /// psalm4 (5 elements); Vespers has psalm1-5; Matins' antiphon keys are
    /// offset by one because matutinum.psalm1 is the invariable Venite.
    /// Shared with ContentStore.applyProperOverrides so the temporal and
    /// sanctoral paths can never disagree.
    static let psalmToAntiphonKey: [String: String] = [
        "laudes.psalm1":    "laudes.antiphon.psalm1",
        "laudes.psalm2":    "laudes.antiphon.psalm2",
        "laudes.psalm3":    "laudes.antiphon.psalm3",
        "laudes.canticle1": "laudes.antiphon.psalm4",
        "laudes.psalm4":    "laudes.antiphon.psalm5",
        "vesperae.psalm1":  "vesperae.antiphon.psalm1",
        "vesperae.psalm2":  "vesperae.antiphon.psalm2",
        "vesperae.psalm3":  "vesperae.antiphon.psalm3",
        "vesperae.psalm4":  "vesperae.antiphon.psalm4",
        "vesperae.psalm5":  "vesperae.antiphon.psalm5",
        "matutinum.psalm2":  "matutinum.antiphon.psalm1",
        "matutinum.psalm3":  "matutinum.antiphon.psalm2",
        "matutinum.psalm4":  "matutinum.antiphon.psalm3",
        "matutinum.psalm5":  "matutinum.antiphon.psalm4",
        "matutinum.psalm6":  "matutinum.antiphon.psalm5",
        "matutinum.psalm7":  "matutinum.antiphon.psalm6",
        "matutinum.psalm8":  "matutinum.antiphon.psalm7",
        "matutinum.psalm9":  "matutinum.antiphon.psalm8",
        "matutinum.psalm10": "matutinum.antiphon.psalm9",
    ]

    func assemble(template: Hour, context: LiturgicalContext, isFestal: Bool = false, festalCompline: Bool = false, festalLittleHours: Bool = false, matinsNocturns: Int = 3, matinsTeDeum: Bool = true, rite: MissalRite = .rite1962, fallbackCollect: Hour.Part? = nil, officeIsFerial: Bool = true) -> Hour {
        var dayKey = Self.dayKeys[context.dayOfWeek]
        // Pre-Lent (Septuagesima..Quinquagesima) keeps the per-annum
        // ordinarium — the season flag may still say "christmas" (Christmas
        // cycle runs to Feb 2) but Septuagesima's hymns are the ordinary ones.
        let seasonKey = (context.temporalKey?.hasPrefix("quadp") ?? false)
            ? "ordinary"
            : seasonString(for: context.season)

        // Easter/Pentecost octave: use Sunday psalms for all hours
        let isOctave = Self.isEasterOrPentecostOctave(context: context)
        if isOctave && context.dayOfWeek != 0 {
            dayKey = "sunday"
        }

        let dayOverrides = weeklyPsalter[dayKey] ?? [:]
        let seasonOverrides = seasonalHymns[seasonKey] ?? [:]
        let rawTemporalOverrides = context.temporalKey.flatMap { temporalPropers[$0] } ?? [:]
        var temporalOverrides = Self.remapProperOverrides(rawTemporalOverrides, hourSlug: template.slug)

        // Day-collect resolution. The collect of the day belongs to Matins,
        // Lauds, the Little Hours, and Vespers (Prime's and Compline's
        // collects are invariable and keyed separately). Per-annum ferias
        // repeat the preceding Sunday's collect; Lent/Passiontide ferias
        // carry their own as DO's "oratio_2", and at Vespers a DISTINCT
        // proper collect as "oratio_3". A sanctoral winner's own collect is
        // layered on top later in hourForToday and wins.
        if Self.collectHours.contains(template.slug), temporalOverrides["oratio"] == nil {
            var candidates: [Hour.Part?] = []
            if template.slug == "vesperae" { candidates.append(rawTemporalOverrides["oratio_3"]) }
            candidates.append(rawTemporalOverrides["oratio"])
            candidates.append(rawTemporalOverrides["oratio_2"])
            if let tKey = context.temporalKey,
               let sundayKey = Self.precedingSundayKey(tKey),
               let sunday = temporalPropers[sundayKey] {
                candidates.append(sunday["oratio"])
                candidates.append(sunday["oratio_2"])
            }
            // Last resort: the day's MASS collect, resolved by the caller via
            // the Missal pipeline (which already handles resumed Sundays,
            // stub redirects, and the early-January ferias). The office and
            // Mass collect of the day coincide.
            candidates.append(fallbackCollect)
            if let collect = candidates.compactMap({ $0 }).first {
                temporalOverrides["oratio"] = Self.rekeyed(collect, "oratio")
            }
        }

        let assembledParts = template.parts.map { part -> Hour.Part in
            guard let key = part.variationKey else { return part }

            if part.type == "marian" {
                return marianPart(for: context.marian, fallback: part)
            }

            // Temporal propers (highest priority for non-psalm parts)
            if let override = temporalOverrides[key] {
                return Self.rekeyed(override, key)
            }

            // Ferial weekday hymns (per annum): the psalter's own Mon–Sat
            // hymn cycle beats the season's default (which is the SUNDAY
            // hymn) on non-festal weekdays. Seasonal hymns still win in
            // every proper season (Advent, Lent, Paschaltide, ...).
            if part.type == "hymn", seasonKey == "ordinary", !isFestal,
               let dayHymn = dayOverrides[key] {
                return Self.rekeyed(dayHymn, key)
            }

            // Seasonal overrides: hymns change every season. Seasonal antiphons
            // apply on ferias (feasts keep the commune/proper antiphon), EXCEPT
            // in Paschaltide where the "Alleluia" antiphon is used universally
            // — Sundays and feasts included.
            let isSeasonalAntiphon = part.type == "antiphon" || part.type == "canticle"
            let antiphonSeasonApplies = !isFestal || context.season == .easter || context.season == .pentecost
            if (part.type == "hymn" || (isSeasonalAntiphon && antiphonSeasonApplies)),
               let override = seasonOverrides[key] {
                // Antiphon-only override on a canticle: merge the antiphon
                // without replacing the canticle's verses.
                if override.antiphonLat != nil && override.verses == nil && part.verses != nil {
                    var merged = part
                    merged.antiphonLat = override.antiphonLat
                    merged.antiphonEng = override.antiphonEng
                    return merged
                }
                return Self.rekeyed(override, key)
            }

            // On festal days, keep the template's festal psalms for Lauds
            // and Vespers (the weekday psalter would replace them with ferial
            // psalms). All other parts (hymns, capitula, etc.) still override.
            if isFestal && Self.festalPsalmKeys.contains(key) {
                return part
            }

            // On Sundays and I/II-class feasts, keep the festal Compline
            // (Sunday psalms + "Miserere" antiphon) instead of the ferial set.
            if festalCompline && Self.festalComplineKeys.contains(key) {
                return part
            }

            // On Sundays and I-class feasts, keep the festal Little Hours
            // (Ps 118 portions) instead of the day-of-the-week ferial psalms.
            if festalLittleHours && Self.festalLittleHourKeys.contains(key) {
                return part
            }

            if let override = dayOverrides[key] {
                // The ferial hymn/canticle-antiphon/versicle cycle belongs to
                // the ferial office only — festal days keep the template's
                // (Sunday) defaults until the proper/commune layers land.
                if isFestal && Self.ferialOnlyDayKeys.contains(key) {
                    return part
                }
                return Self.rekeyed(override, key)
            }

            return part
        }

        // Prime's Lectio Brevis is, by the rubric's own rule, the day's None
        // capitulum. Fill the slot when nothing proper landed there (proper
        // feast lessons override by key in the later layers).
        let lectioBrevisApplied: [Hour.Part]
        if template.slug == "prima" {
            lectioBrevisApplied = assembledParts.map { part in
                guard part.variationKey == "lectio_prima", (part.lat ?? "").isEmpty,
                      let src = temporalOverrides["capitulum_nona"]
                          ?? seasonOverrides["capitulum_nona"]
                          ?? dayOverrides["capitulum_nona"]
                else { return part }
                var modified = part
                modified.lat = src.lat
                modified.eng = src.eng
                modified.ref = src.ref
                return modified
            }
        } else {
            lectioBrevisApplied = assembledParts
        }

        // Inline psalm text from psalter.json for any psalm part that has
        // a ref but no verses (or empty verses).
        let psalmInlined = lectioBrevisApplied.map { inlinePsalmText($0) }

        // Apply temporal per-psalm antiphon overrides.
        // Temporal keys like "laudes.antiphon.psalm1" replace the antiphon
        // on the corresponding psalm/canticle part. Uses the same mapping as
        // ContentStore.applyProperOverrides (incl. the Matins offset —
        // matutinum.psalm1 is the invariable Venite).
        let antiphonApplied = psalmInlined.map { part -> Hour.Part in
            guard let key = part.variationKey,
                  let ak = Self.psalmToAntiphonKey[key],
                  let antOverride = temporalOverrides[ak] else { return part }
            var modified = part
            modified.antiphonLat = antOverride.lat
            modified.antiphonEng = antOverride.eng
            return modified
        }

        // Septuagesima through Holy Saturday: replace trailing "Allelúja" in
        // the "Deus in adjutorium" response with "Laus tibi, Dómine, Rex
        // ætérnæ glóriæ." (1962 Breviarium Romanum rubric). This substitution
        // must NOT fire during Paschal time.
        let lausTibiApplied: [Hour.Part]
        if Self.shouldSubstituteLausTibi(context: context) {
            lausTibiApplied = antiphonApplied.map { part in
                guard part.type == "vr",
                      let latR = part.latR, latR.contains("Allelúja") else { return part }
                var modified = part
                modified.latR = latR
                    .replacingOccurrences(of: "Allelúja.", with: "Laus tibi, Dómine, Rex ætérnæ glóriæ.")
                    .replacingOccurrences(of: "Allelúja", with: "Laus tibi, Dómine, Rex ætérnæ glóriæ")
                modified.engR = part.engR?
                    .replacingOccurrences(of: "Alleluia.", with: "Praise be to Thee, O Lord, King of eternal glory.")
                    .replacingOccurrences(of: "Alleluia", with: "Praise be to Thee, O Lord, King of eternal glory")
                return modified
            }
        } else {
            lausTibiApplied = antiphonApplied
        }

        // Septuagesima through Holy Saturday: strip "Alleluia" from antiphons.
        // The per-annum Little Hours antiphons embed alleluias (e.g. "Allelúja,
        // deduc me, Dómine…, allelúja, allelúja"); during this penitential
        // window the alleluias are removed, leaving the bare antiphon text.
        let alleluiaStripped: [Hour.Part]
        if Self.shouldSubstituteLausTibi(context: context) {
            alleluiaStripped = lausTibiApplied.map { part in
                if part.type == "antiphon" {
                    var modified = part
                    if let lat = part.lat { modified.lat = Self.stripAlleluia(lat) }
                    if let eng = part.eng { modified.eng = Self.stripAlleluia(eng) }
                    return modified
                }
                // Psalm-attached antiphons carry alleluias too (the festal
                // template antiphons embed them).
                if part.antiphonLat != nil {
                    var modified = part
                    if let lat = part.antiphonLat { modified.antiphonLat = Self.stripAlleluia(lat) }
                    if let eng = part.antiphonEng { modified.antiphonEng = Self.stripAlleluia(eng) }
                    return modified
                }
                return part
            }
        } else {
            alleluiaStripped = lausTibiApplied
        }

        // Post-assembly filtering for Matins nocturn structure and Te Deum.
        let filteredParts: [Hour.Part]
        if template.slug == "matutinum" {
            // Tenebrae: Matins of Holy Thursday, Good Friday, Holy Saturday.
            let isTenebrae = ["quad6-4", "quad6-5", "quad6-6"].contains(context.temporalKey ?? "")
            filteredParts = filterMatinsParts(alleluiaStripped, nocturns: matinsNocturns, includeTeDeum: matinsTeDeum, isTenebrae: isTenebrae)
        } else if template.slug == "prima" {
            // Festal Prime (Sunday/I-class feast or Easter/Pentecost octave):
            // 4 psalms (Ps 53, 117, 118 I, 118 II). Ferial Prime: 3 psalms
            // (the weekday override replaces psalm1-3, but psalm4 has no ferial
            // override and would leak). During octave, drop Ps 117 instead.
            if isOctave && context.dayOfWeek != 0 {
                filteredParts = alleluiaStripped.filter { $0.variationKey != "prima.psalm2" }
            } else if !festalLittleHours {
                filteredParts = alleluiaStripped.filter { $0.variationKey != "prima.psalm4" }
            } else {
                filteredParts = alleluiaStripped
            }
        } else {
            filteredParts = alleluiaStripped
        }

        // Insert Preces Feriales for Lauds/Vespers on qualifying ferial days.
        // When Preces are NOT said, remove the standalone Pater Noster that
        // precedes the Collect — it is only said as part of the Preces. This
        // applies to every day-hour with a Preces Pater: Lauds, Vespers, the
        // Little Hours (Prime/Terce/Sext/None) and Compline. Matins is excluded
        // (its Pater Noster introduces the nocturn lessons and is always said),
        // as is the Office of the Dead (its own proper structure). The opening
        // "Pater Noster, Ave María, Credo" is preserved by the "Ave" check.
        let precesHours: Set<String> = [
            "laudes", "vesperae", "prima", "tertia", "sexta", "nona", "completorium",
        ]
        var precesApplied = filteredParts
        if precesHours.contains(template.slug) {
            // The standalone Pater before the collect is not said at the day
            // hours under the 1960 rubrics; when the Preces fire they carry
            // their own Pater. (The opening "Pater, Ave" is kept.)
            precesApplied = precesApplied.filter { part in
                !(part.type == "pater" && (part.variationKey ?? "").isEmpty
                  && !(part.label ?? "").contains("Ave"))
            }
            if officeIsFerial && shouldIncludePreces(context: context, rite: rite, hourSlug: template.slug) {
                precesApplied = insertPreces(into: precesApplied, hour: template.slug)
            }
        }

        // Suppress Gloria Patri at the end of psalms during Passiontide
        // and in the Office of the Dead.
        let finalParts: [Hour.Part]
        if shouldOmitGloriaPatri(context: context, hourSlug: template.slug) {
            finalParts = precesApplied.map { stripGloriaPatriFromPsalm($0) }
        } else {
            finalParts = precesApplied
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

    // MARK: - Matins structure (1960/1962 rubrics)
    //
    // Under the 1960 rubrics every Matins has 9 psalms. The structure splits:
    //   3 nocturns / 9 lessons / Te Deum: I- and II-class feasts only.
    //   1 nocturn  / 9 psalms / 3 lessons: everything else — all Sundays,
    //     III-class feasts, ferias, octave days.
    // The nocturn count and Te Deum decision are computed in ContentStore
    // (which has the ordo rank/winner) and passed in.
    private func filterMatinsParts(_ parts: [Hour.Part], nocturns: Int, includeTeDeum: Bool, isTenebrae: Bool = false) -> [Hour.Part] {
        var structured: [Hour.Part]
        if nocturns >= 3 {
            // 3-Nocturn Matins: keep all nocturns; include the Te Deum only
            // when the day calls for it.
            structured = includeTeDeum ? parts : parts.filter { !isTeDeum($0) }
        } else {
            structured = buildOneNocturn(parts, includeTeDeum: includeTeDeum)
        }
        // When the Te Deum stands in place of the ninth responsory, drop the
        // bare "Responsorium IX" slot if nothing filled it.
        if includeTeDeum {
            structured = structured.filter {
                !($0.variationKey == "responsory9"
                  && ($0.lat ?? "").isEmpty && ($0.v1Lat ?? "").isEmpty
                  && ($0.verses ?? []).isEmpty)
            }
        }
        return isTenebrae ? applyTenebrae(structured) : structured
    }

    /// Tenebrae (Matins of the Sacred Triduum) omits the Incipit, Invitatory,
    /// hymn, Te Deum, and Conclusion: it begins directly with the antiphon of
    /// the first psalm and ends after the collect. Drops everything before the
    /// first nocturn heading and the closing conclusion.
    private func applyTenebrae(_ parts: [Hour.Part]) -> [Hour.Part] {
        var result = parts
        // Drop the Incipit / Invitatory / Hymn: everything before Nocturn I.
        if let firstHeading = result.firstIndex(where: {
            $0.type == "heading" && ($0.label ?? "").contains("Noct")
        }) {
            result = Array(result[firstHeading...])
        }
        // Drop the Te Deum and the final Conclusion (Benedicámus Dómino, etc.).
        result = result.filter { $0.type != "closing" && !isTeDeum($0) }
        return result
    }

    /// Build a 1-nocturn Matins: all 9 psalms (pulled from the three template
    /// nocturns into a single nocturn), the first versicle, the three lessons
    /// and responsories of Nocturn I, an optional Te Deum, then the closing.
    private func buildOneNocturn(_ parts: [Hour.Part], includeTeDeum: Bool) -> [Hour.Part] {
        // Locate the three nocturn headings.
        let headingIdxs = parts.indices.filter {
            parts[$0].type == "heading" && (parts[$0].label ?? "").contains("Noct")
        }
        guard let firstHeading = headingIdxs.first else { return parts }

        // Everything before the first nocturn heading: invitatory + hymn.
        var result = Array(parts[..<firstHeading])

        // From each nocturn, take the antiphon + psalms (the run between the
        // heading and that nocturn's versicle), dropping the nocturn heading.
        for h in headingIdxs {
            var i = h + 1
            while i < parts.count && parts[i].type != "vr" {
                result.append(parts[i])
                i += 1
            }
        }

        // The single versicle (the first nocturn's "nocturn_1_versum").
        if let versicleIdx = parts.indices.first(where: {
            parts[$0].variationKey == "nocturn_1_versum"
        }) {
            result.append(parts[versicleIdx])

            // Nocturn I's lesson block: everything from after that versicle up
            // to the second nocturn heading (Pater, absolution, blessings, the
            // three lessons + responsories).
            let secondHeading = headingIdxs.count > 1 ? headingIdxs[1] : parts.count
            if versicleIdx + 1 < secondHeading {
                result.append(contentsOf: parts[(versicleIdx + 1)..<secondHeading])
            }
        }

        // Te Deum (optional), then the closing material that follows it.
        if let teDeumIdx = parts.firstIndex(where: { isTeDeum($0) }) {
            if includeTeDeum { result.append(parts[teDeumIdx]) }
            if teDeumIdx + 1 < parts.count {
                result.append(contentsOf: parts[(teDeumIdx + 1)...])
            }
        }

        return result
    }

    private func isTeDeum(_ part: Hour.Part) -> Bool {
        part.type == "canticle" && (part.label ?? "").contains("Te Deum")
    }

    // MARK: - Laus tibi substitution (Septuagesima–Holy Saturday)
    //
    // From First Vespers of Septuagesima Sunday through Holy Saturday, the
    // "Alleluia" at the end of the "Deus in adjutorium" versicle response is
    // replaced by "Laus tibi, Dómine, Rex ætérnæ glóriæ."
    // This covers: pre-Lent (temporalKey starts with "quadp"), Lent, and
    // Passion. It must NOT fire during Paschal time (season == .easter).

    static func shouldSubstituteLausTibi(context: LiturgicalContext) -> Bool {
        // Explicit penitential seasons
        if context.season == .lent || context.season == .passion {
            return true
        }
        // Pre-Lent (Septuagesima through Saturday before Ash Wednesday):
        // temporalKey is "quadp1-0" through "quadp3-6"
        if let key = context.temporalKey, key.hasPrefix("quadp") {
            return true
        }
        return false
    }

    /// Remove leading/trailing "Alleluia" words from an antiphon (Septuagesima
    /// through Lent). E.g. "Allelúja, * deduc me, Dómine…, allelúja, allelúja."
    /// → "Deduc me, Dómine…". Leaves the text unchanged if stripping would
    /// empty it (a purely-alleluiatic antiphon).
    static func stripAlleluia(_ text: String) -> String {
        var s = text
        // Trailing alleluias: ", allelúja, allelúja." / ", alleluia." etc.
        // (Latin "Allelúja" ends in -ja, English "Alleluia" in -ia.)
        s = s.replacingOccurrences(
            of: "[,;]?\\s*[Aa]llel[úu][ji]a[,.]?(\\s*[Aa]llel[úu][ji]a[,.]?)*\\s*$",
            with: "", options: .regularExpression)
        // Leading alleluia + optional antiphon mediant marker: "Allelúja, * "
        s = s.replacingOccurrences(
            of: "^[Aa]llel[úu][ji]a[,.]?\\s*\\*?\\s*",
            with: "", options: .regularExpression)
        s = s.trimmingCharacters(in: .whitespaces)
        guard !s.isEmpty else { return text }
        // Capitalise the new first letter.
        return s.prefix(1).uppercased() + s.dropFirst()
    }

    // MARK: - Gloria Patri suppression (Passiontide & Office of the Dead)
    //
    // In the 1962 Breviary the Gloria Patri doxology at the end of psalms
    // is omitted from Passion Sunday through Holy Saturday and throughout
    // the Office of the Dead.

    /// Returns true when the Gloria Patri should be stripped from psalm endings.
    private func shouldOmitGloriaPatri(context: LiturgicalContext, hourSlug: String) -> Bool {
        if context.season == .passion {
            return true
        }
        if hourSlug == "office-of-the-dead" {
            return true
        }
        return false
    }

    /// If the part is a psalm or canticle whose ending contains the Gloria Patri
    /// doxology, return a copy with those verses removed.
    ///
    /// The doxology may appear as:
    ///   (a) A single final verse: "Glória Patri, et Fílio, et Spirítui Sancto. Sicut erat …"
    ///   (b) Two verses: "Glória Patri …" followed by "Sicut erat …"
    private func stripGloriaPatriFromPsalm(_ part: Hour.Part) -> Hour.Part {
        guard part.type == "psalm" || part.type == "canticle" else { return part }
        guard var verses = part.verses, !verses.isEmpty else { return part }

        let lastVerse = verses[verses.count - 1]

        // Case (a): single combined verse starting with "Glória Patri"
        if lastVerse.lat.hasPrefix("Glória Patri") {
            verses.removeLast()
            var modified = part
            modified.verses = verses
            return modified
        }

        // Case (b): "Sicut erat" is the last verse, "Glória Patri" is second-to-last
        if verses.count >= 2
            && lastVerse.lat.hasPrefix("Sicut erat")
            && verses[verses.count - 2].lat.hasPrefix("Glória Patri") {
            verses.removeLast(2)
            var modified = part
            modified.verses = verses
            return modified
        }

        return part
    }

    // MARK: - Preces Feriales (Lauds & Vespers)
    //
    // Rite-specific scope (the preces are said KNEELING, before the collect):
    //   1962:      at LAUDS only, on Wednesdays and Fridays of Advent, Lent
    //              and Passiontide, and on Ember days.
    //   1955:      at Lauds AND Vespers on those same days (Cum nostra kept
    //              the ferial preces at both hours).
    //   pre-1955:  at Lauds and Vespers on all ferias of Advent, Lent and
    //              Passiontide, and on Ember days.
    // Never on Sundays or on feasts.

    /// Determines whether Preces Feriales should be included in the Hour.
    private func shouldIncludePreces(context: LiturgicalContext, rite: MissalRite, hourSlug: String) -> Bool {
        // Never on Sundays
        guard context.dayOfWeek != 0 else { return false }

        // Not on high-rank weekday feasts (equivalent to Double rank or higher)
        if let slug = context.properSlug, Self.highRankWeekdayFeasts.contains(slug) {
            return false
        }

        let penitential = context.season == .advent || context.season == .lent
            || context.season == .passion
        let wedOrFri = context.dayOfWeek == 3 || context.dayOfWeek == 5

        switch rite {
        case .rite1962:
            guard hourSlug == "laudes" else { return false }
            return context.isEmberDay || (penitential && wedOrFri)
        case .rite1955:
            guard hourSlug == "laudes" || hourSlug == "vesperae" else { return false }
            return context.isEmberDay || (penitential && wedOrFri)
        case .pre1955:
            guard hourSlug == "laudes" || hourSlug == "vesperae" else { return false }
            return penitential || context.isEmberDay
        }
    }

    /// Inserts the Preces Feriales parts into the assembled hour, placed
    /// BEFORE the Collect (they are said kneeling, and conclude with the
    /// "Dómine, exáudi" that introduces the collect).
    private func insertPreces(into parts: [Hour.Part], hour: String) -> [Hour.Part] {
        guard let collectIndex = parts.firstIndex(where: { $0.type == "collect" }) else {
            return parts
        }
        let precesParts = Self.makePrecesParts(hour: hour)
        var result = Array(parts[..<collectIndex])
        result.append(contentsOf: precesParts)
        result.append(contentsOf: parts[collectIndex...])
        return result
    }

    /// Builds the Preces Feriales parts for the given hour (Lauds or Vespers).
    /// Vespers uses Psalm 50 (Miserere) instead of Psalm 129 (De profundis).
    private static func makePrecesParts(hour: String) -> [Hour.Part] {
        var parts: [Hour.Part] = []

        // Heading
        parts.append(Hour.Part(
            type: "heading",
            label: "Preces Feriales"
        ))

        // Kyrie
        parts.append(Hour.Part(
            type: "preces",
            label: "Kyrie",
            lat: "Kýrie, eléison. Christe, eléison. Kýrie, eléison.",
            eng: "Lord, have mercy. Christ, have mercy. Lord, have mercy."
        ))

        // Pater noster (said silently through "et ne nos inducas in tentationem")
        parts.append(Hour.Part(
            type: "preces",
            label: "Pater Noster",
            lat: "Pater noster, qui es in cælis, sanctificétur nomen tuum. Advéniat regnum tuum. Fiat volúntas tua, sicut in cælo et in terra. Panem nostrum quotidiánum da nobis hódie, et dimítte nobis débita nostra, sicut et nos dimíttimus debitóribus nostris.\n℣. Et ne nos indúcas in tentatiónem.\n℟. Sed líbera nos a malo.",
            eng: "Our Father, who art in heaven, hallowed be Thy name. Thy kingdom come. Thy will be done on earth, as it is in heaven. Give us this day our daily bread, and forgive us our trespasses, as we forgive those who trespass against us.\n℣. And lead us not into temptation.\n℟. But deliver us from evil."
        ))

        // Intercession versicles
        parts.append(Hour.Part(
            type: "preces",
            label: "Versicles",
            verses: precesVersicles
        ))

        // Psalm — De profundis (129) at Lauds, Miserere (50) at Vespers
        if hour == "laudes" {
            parts.append(Hour.Part(
                type: "preces",
                label: "Psalmus 129; De profúndis",
                lat: "De profúndis clamávi ad te, Dómine: * Dómine, exáudi vocem meam.\nFiant aures tuæ intendéntes * in vocem deprecatiónis meæ.\nSi iniquitátes observáveris, Dómine: * Dómine, quis sustinébit?\nQuia apud te propitiátio est: * et propter legem tuam sustínui te, Dómine.\nSustínuit ánima mea in verbo ejus: * sperávit ánima mea in Dómino.\nA custódia matutína usque ad noctem, * speret Israël in Dómino.\nQuia apud Dóminum misericórdia, * et copiósa apud eum redémptio.\nEt ipse rédimet Israël * ex ómnibus iniquitátibus ejus.\nGlória Patri, et Fílio, * et Spirítui Sancto.\nSicut erat in princípio, et nunc, et semper, * et in sǽcula sæculórum. Amen.",
                eng: "Out of the depths I have cried to Thee, O Lord: * Lord, hear my voice.\nLet Thine ears be attentive * to the voice of my supplication.\nIf Thou, O Lord, wilt mark iniquities: * Lord, who shall stand it?\nFor with Thee there is merciful forgiveness: * and by reason of Thy law I have waited for Thee, O Lord.\nMy soul hath relied on His word: * my soul hath hoped in the Lord.\nFrom the morning watch even until night, * let Israel hope in the Lord.\nBecause with the Lord there is mercy, * and with Him plentiful redemption.\nAnd He shall redeem Israel * from all his iniquities.\nGlory be to the Father, and to the Son, * and to the Holy Ghost.\nAs it was in the beginning, is now, and ever shall be, * world without end. Amen."
            ))
        } else {
            parts.append(Hour.Part(
                type: "preces",
                label: "Psalmus 50; Miserére",
                lat: "Miserére mei, Deus, * secúndum magnam misericórdiam tuam.\nEt secúndum multitúdinem miseratiónum tuárum, * dele iniquitátem meam.\nAmplius lava me ab iniquitáte mea, * et a peccáto meo munda me.\nQuóniam iniquitátem meam ego cognósco, * et peccátum meum contra me est semper.\nTibi soli peccávi, et malum coram te feci: * ut justificéris in sermónibus tuis, et vincas cum judicáris.\nEcce enim in iniquitátibus concéptus sum, * et in peccátis concépit me mater mea.\nEcce enim veritátem dilexísti: * incérta et occúlta sapiéntiæ tuæ manifestásti mihi.\nAspérges me hyssópo, et mundábor: * lavábis me, et super nivem dealbábor.\nAudítui meo dabis gáudium et lætítiam, * et exsultábunt ossa humiliáta.\nAvérte fáciem tuam a peccátis meis, * et omnes iniquitátes meas dele.\nCor mundum crea in me, Deus, * et spíritum rectum ínnova in viscéribus meis.\nNe projícias me a fácie tua, * et Spíritum Sanctum tuum ne áuferas a me.\nRedde mihi lætítiam salutáris tui, * et spíritu principáli confírma me.\nDocébo iníquos vias tuas, * et ímpii ad te converténtur.\nLíbera me de sanguínibus, Deus, Deus salútis meæ, * et exsultábit lingua mea justítiam tuam.\nDómine, lábia mea apéries, * et os meum annuntiábit laudem tuam.\nQuóniam si voluísses sacrifícium, dedíssem útique: * holocáustis non delectáberis.\nSacrificium Deo spíritus contribulátus: * cor contrítum et humiliátum, Deus, non despícies.\nBenígne fac, Dómine, in bona voluntáte tua Sion, * ut ædificéntur muri Jerúsalem.\nTunc acceptábis sacrifícium justítiæ, oblatiónes et holocáusta: * tunc impónent super altáre tuum vítulos.\nGlória Patri, et Fílio, * et Spirítui Sancto.\nSicut erat in princípio, et nunc, et semper, * et in sǽcula sæculórum. Amen.",
                eng: "Have mercy on me, O God, * according to Thy great mercy.\nAnd according to the multitude of Thy tender mercies, * blot out my iniquity.\nWash me yet more from my iniquity, * and cleanse me from my sin.\nFor I know my iniquity, * and my sin is always before me.\nTo Thee only have I sinned, and have done evil before Thee: * that Thou mayest be justified in Thy words, and mayest overcome when Thou art judged.\nFor behold I was conceived in iniquities, * and in sins did my mother conceive me.\nFor behold Thou hast loved truth: * the uncertain and hidden things of Thy wisdom Thou hast made manifest to me.\nThou shalt sprinkle me with hyssop, and I shall be cleansed: * Thou shalt wash me, and I shall be made whiter than snow.\nTo my hearing Thou shalt give joy and gladness, * and the bones that have been humbled shall rejoice.\nTurn away Thy face from my sins, * and blot out all my iniquities.\nCreate a clean heart in me, O God, * and renew a right spirit within my bowels.\nCast me not away from Thy face, * and take not Thy Holy Spirit from me.\nRestore unto me the joy of Thy salvation, * and strengthen me with a perfect spirit.\nI will teach the unjust Thy ways, * and the wicked shall be converted to Thee.\nDeliver me from blood, O God, Thou God of my salvation, * and my tongue shall extol Thy justice.\nO Lord, Thou wilt open my lips, * and my mouth shall declare Thy praise.\nFor if Thou hadst desired sacrifice, I would indeed have given it: * with burnt offerings Thou wilt not be delighted.\nA sacrifice to God is an afflicted spirit: * a contrite and humbled heart, O God, Thou wilt not despise.\nDeal favorably, O Lord, in Thy good will with Sion, * that the walls of Jerusalem may be built up.\nThen shalt Thou accept the sacrifice of justice, oblations and whole burnt offerings: * then shall they lay calves upon Thine altar.\nGlory be to the Father, and to the Son, * and to the Holy Ghost.\nAs it was in the beginning, is now, and ever shall be, * world without end. Amen."
            ))
        }

        // Concluding versicles
        parts.append(Hour.Part(
            type: "preces",
            label: "Concluding Versicles",
            verses: concludingVersicles
        ))

        return parts
    }

    /// The intercession versicles of the Preces Feriales (common to Lauds and Vespers).
    private static let precesVersicles: [Hour.Part.Verse] = [
        Hour.Part.Verse(
            lat: "℣. Ego dixi: Dómine, miserére mei.\n℟. Sana ánimam meam quia peccávi tibi.",
            eng: "℣. I said: Lord, be merciful unto me.\n℟. Heal my soul, for I have sinned against Thee."
        ),
        Hour.Part.Verse(
            lat: "℣. Convértere, Dómine, úsquequo?\n℟. Et deprecábilis esto super servos tuos.",
            eng: "℣. Turn Thee again, O Lord; how long will it be?\n℟. And be gracious unto Thy servants."
        ),
        Hour.Part.Verse(
            lat: "℣. Fiat misericórdia tua, Dómine, super nos.\n℟. Quemádmodum sperávimus in te.",
            eng: "℣. Let Thy mercy, O Lord, be upon us.\n℟. As we have hoped in Thee."
        ),
        Hour.Part.Verse(
            lat: "℣. Sacerdótes tui induántur justítiam.\n℟. Et sancti tui exsúltent.",
            eng: "℣. Let Thy priests be clothed with justice.\n℟. And may Thy saints rejoice."
        ),
        Hour.Part.Verse(
            lat: "℣. Orémus pro beatíssimo Papa nostro N.\n℟. Dóminus consérvet eum, et vivíficet eum, et beátum fáciat eum in terra, et non tradat eum in ánimam inimicórum ejus.",
            eng: "℣. Let us pray for our most blessed Pope N.\n℟. The Lord preserve him and give him life, and make him blessed upon the earth: and deliver him not up to the will of his enemies."
        ),
        Hour.Part.Verse(
            lat: "℣. Orémus et pro Antístite nostro N.\n℟. Stet et pascat in fortitúdine tua, Dómine, in sublimitáte nóminis tui.",
            eng: "℣. Let us pray for our Bishop N.\n℟. May he stand firm and care for us in the strength of the Lord, in the might of Thy name."
        ),
        Hour.Part.Verse(
            lat: "℣. Salvum fac pópulum tuum, Dómine, et bénedic hereditáti tuæ.\n℟. Et rege eos, et extólle illos usque in ætérnum.",
            eng: "℣. O Lord, save Thy people, and bless Thine inheritance.\n℟. Govern them and lift them up for ever."
        ),
        Hour.Part.Verse(
            lat: "℣. Meménto Congregatiónis tuæ.\n℟. Quam possedísti ab inítio.",
            eng: "℣. Remember Thy congregation.\n℟. Which Thou hast possessed from the beginning."
        ),
        Hour.Part.Verse(
            lat: "℣. Fiat pax in virtúte tua.\n℟. Et abundántia in túrribus tuis.",
            eng: "℣. Let peace be in Thy strength.\n℟. And abundance in Thy towers."
        ),
        Hour.Part.Verse(
            lat: "℣. Orémus pro benefactóribus nostris.\n℟. Retribúere dignáre, Dómine, ómnibus, nobis bona faciéntibus propter nomen tuum, vitam ætérnam. Amen.",
            eng: "℣. Let us pray for our benefactors.\n℟. O Lord, for Thy name's sake, deign to reward with eternal life all who do us good. Amen."
        ),
        Hour.Part.Verse(
            lat: "℣. Orémus pro fidélibus defúnctis.\n℟. Réquiem ætérnam dona eis, Dómine, et lux perpétua lúceat eis.",
            eng: "℣. Let us pray for the faithful departed.\n℟. Eternal rest grant unto them, O Lord, and let perpetual light shine upon them."
        ),
        Hour.Part.Verse(
            lat: "℣. Requiéscant in pace.\n℟. Amen.",
            eng: "℣. May they rest in peace.\n℟. Amen."
        ),
        Hour.Part.Verse(
            lat: "℣. Pro frátribus nostris abséntibus.\n℟. Salvos fac servos tuos, Deus meus, sperántes in te.",
            eng: "℣. Let us pray for our absent brothers.\n℟. Save Thy servants, O God, who put their trust in Thee."
        ),
        Hour.Part.Verse(
            lat: "℣. Pro afflíctis et captívis.\n℟. Líbera eos, Deus Israël, ex ómnibus tribulatiónibus suis.",
            eng: "℣. Let us pray for the afflicted and imprisoned.\n℟. Deliver them, God of Israel, from all their tribulations."
        ),
        Hour.Part.Verse(
            lat: "℣. Mitte eis, Dómine, auxílium de sancto.\n℟. Et de Sion tuére eos.",
            eng: "℣. O Lord, send them help from Thy sanctuary.\n℟. And defend them out of Sion."
        ),
        Hour.Part.Verse(
            lat: "℣. Dómine, exáudi oratiónem meam.\n℟. Et clamor meus ad te véniat.",
            eng: "℣. O Lord, hear my prayer.\n℟. And let my cry come unto Thee."
        ),
    ]

    /// Concluding versicles after the psalm in Preces Feriales.
    private static let concludingVersicles: [Hour.Part.Verse] = [
        Hour.Part.Verse(
            lat: "℣. Dómine, Deus virtútum, convérte nos.\n℟. Et osténde fáciem tuam, et salvi érimus.",
            eng: "℣. Turn us again, O Lord, God of Hosts.\n℟. Show us Thy face, and we shall be whole."
        ),
        Hour.Part.Verse(
            lat: "℣. Exsúrge, Christe, ádjuva nos.\n℟. Et líbera nos propter nomen tuum.",
            eng: "℣. Arise, O Christ, and help us.\n℟. And redeem us for Thy name's sake."
        ),
    ]

    // MARK: - Psalm text inlining from psalter.json
    //
    // When a psalm part carries a `ref` like "Ps 109" but has no verses (or
    // empty verses), look up the text in the loaded psalter dictionary and
    // build a Verse array from it.

    /// Convert a part's `ref` field to a psalter.json key, e.g. "Ps 109" → "psalm109".
    /// Returns nil for refs that don't map to a single psalm (canticles, ranges, etc.).
    private static func psalterKey(from ref: String) -> String? {
        let trimmed = ref.trimmingCharacters(in: .whitespaces)
        // Match "Ps N" or "Psalm N" (no sub-verse ranges like "Ps 118:25-32")
        if trimmed.hasPrefix("Ps ") {
            let numPart = trimmed.dropFirst(3).trimmingCharacters(in: .whitespaces)
            // Must be a pure integer (no colon, no dash)
            if let num = Int(numPart), num >= 1, num <= 150 {
                return "psalm\(num)"
            }
        }
        if trimmed.hasPrefix("Psalm ") {
            let numPart = trimmed.dropFirst(6).trimmingCharacters(in: .whitespaces)
            if let num = Int(numPart), num >= 1, num <= 150 {
                return "psalm\(num)"
            }
        }
        return nil
    }

    /// If `part` is a psalm/canticle with a psalter-matching ref and no verse
    /// text, return a copy with verses inlined from the psalter.
    private func inlinePsalmText(_ part: Hour.Part) -> Hour.Part {
        guard part.type == "psalm" || part.type == "canticle" else { return part }
        // Only inline when verses are missing or empty
        if let existing = part.verses, !existing.isEmpty { return part }
        guard let ref = part.ref,
              let key = Self.psalterKey(from: ref),
              let entry = psalter[key] else { return part }
        let latVerses = entry["lat"] ?? []
        let engVerses = entry["eng"] ?? []
        let count = max(latVerses.count, engVerses.count)
        guard count > 0 else { return part }
        var verses: [Hour.Part.Verse] = []
        for i in 0..<count {
            let lat = i < latVerses.count ? latVerses[i] : ""
            let eng = i < engVerses.count ? engVerses[i] : ""
            verses.append(Hour.Part.Verse(lat: lat, eng: eng))
        }
        var modified = part
        modified.verses = verses
        return modified
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
