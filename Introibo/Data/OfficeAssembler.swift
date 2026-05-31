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
        "hymnusm_vespera":          "hymnus_vespera",
        "hymnus_vespera_3":         "hymnus_vespera",
        "ant_vespera_3":            "ant_vespera",
        "ant_vespera_3c":           "ant_vespera",
        // Vespers — capitulum variants (sanctoral, e.g. Christmas)
        "capitulum_vespera_1":      "vesperae.capitulum",
        "capitulum_vespera_3":      "vesperae.capitulum",
        // Matins — variant hymn spelling & antiphon
        "hymnusm_matutinum":        "hymnus_matutinum",
        "hymnus_matutinum_":        "hymnus_matutinum",
        "ant_matutinum":            "ant_1",
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

    func assemble(template: Hour, context: LiturgicalContext) -> Hour {
        var dayKey = Self.dayKeys[context.dayOfWeek]
        let seasonKey = seasonString(for: context.season)

        // Easter/Pentecost octave: use Sunday psalms for all hours
        let isOctave = Self.isEasterOrPentecostOctave(context: context)
        if isOctave && context.dayOfWeek != 0 {
            dayKey = "sunday"
        }

        let dayOverrides = weeklyPsalter[dayKey] ?? [:]
        let seasonOverrides = seasonalHymns[seasonKey] ?? [:]
        let rawTemporalOverrides = context.temporalKey.flatMap { temporalPropers[$0] } ?? [:]
        let temporalOverrides = Self.expandedOverrides(rawTemporalOverrides)

        let assembledParts = template.parts.map { part -> Hour.Part in
            guard let key = part.variationKey else { return part }

            if part.type == "marian" {
                return marianPart(for: context.marian, fallback: part)
            }

            // Temporal propers (highest priority for non-psalm parts)
            if let override = temporalOverrides[key] {
                return override
            }

            if part.type == "hymn", let override = seasonOverrides[key] {
                return override
            }

            if let override = dayOverrides[key] {
                return override
            }

            return part
        }

        // Inline psalm text from psalter.json for any psalm part that has
        // a ref but no verses (or empty verses).
        let psalmInlined = assembledParts.map { inlinePsalmText($0) }

        // Apply temporal per-psalm antiphon overrides.
        // Temporal keys like "laudes.antiphon.psalm1" replace the antiphon
        // on the corresponding psalm/canticle part.
        let antiphonApplied = psalmInlined.map { part -> Hour.Part in
            guard let key = part.variationKey else { return part }
            // Build the antiphon override key for this part's position
            // e.g., "laudes.psalm1" → check "laudes.antiphon.psalm1"
            let hourPrefix = key.components(separatedBy: ".").first ?? ""
            // Lauds has: psalm1, psalm2, psalm3, canticle1, psalm4 (canticle in middle)
            // Vespers has: psalm1-psalm5 (all psalms)
            // Antiphon slots are always 1-5 in order. Map accordingly.
            let antKey: String?
            if key.hasSuffix(".psalm1") { antKey = "\(hourPrefix).antiphon.psalm1" }
            else if key.hasSuffix(".psalm2") { antKey = "\(hourPrefix).antiphon.psalm2" }
            else if key.hasSuffix(".psalm3") { antKey = "\(hourPrefix).antiphon.psalm3" }
            else if key.hasSuffix(".canticle1") { antKey = "\(hourPrefix).antiphon.psalm4" }
            else if key.hasSuffix(".psalm4") {
                // Lauds psalm4 is the 5th element (after canticle1)
                // Vespers psalm4 is the 4th element
                antKey = hourPrefix == "laudes" ? "\(hourPrefix).antiphon.psalm5" : "\(hourPrefix).antiphon.psalm4"
            }
            else if key.hasSuffix(".psalm5") { antKey = "\(hourPrefix).antiphon.psalm5" }
            else { antKey = nil }

            if let ak = antKey, let antOverride = temporalOverrides[ak] {
                var modified = part
                modified.antiphonLat = antOverride.lat
                modified.antiphonEng = antOverride.eng
                return modified
            }
            return part
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

        // Post-assembly filtering for Matins nocturn structure and Te Deum.
        let filteredParts: [Hour.Part]
        if template.slug == "matutinum" {
            filteredParts = filterMatinsParts(lausTibiApplied, context: context)
        } else if template.slug == "prima" && isOctave && context.dayOfWeek != 0 {
            // Easter/Pentecost octave festal Prime: Ps 53, 118 pars I,
            // 118 pars II — drop Psalm 117 (prima.psalm2 in the template).
            filteredParts = lausTibiApplied.filter { part in
                part.variationKey != "prima.psalm2"
            }
        } else {
            filteredParts = lausTibiApplied
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
        let precesApplied: [Hour.Part]
        if (template.slug == "laudes" || template.slug == "vesperae")
            && shouldIncludePreces(context: context) {
            precesApplied = insertPreces(into: filteredParts, hour: template.slug)
        } else if precesHours.contains(template.slug)
            && !shouldIncludePreces(context: context) {
            precesApplied = filteredParts.filter { part in
                !(part.type == "pater" && (part.variationKey ?? "").isEmpty
                  && !(part.label ?? "").contains("Ave"))
            }
        } else {
            precesApplied = filteredParts
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

    private func filterMatinsParts(_ parts: [Hour.Part], context: LiturgicalContext) -> [Hour.Part] {
        let isWeekday = context.dayOfWeek != 0  // 0 = Sunday
        let isHighRankFeast = isWeekday
            && (context.properSlug.map { Self.highRankWeekdayFeasts.contains($0) } ?? false)
        let useThreeNocturns = !isWeekday || isHighRankFeast

        if !useThreeNocturns {
            // 1-Nocturn Matins: keep everything before "In II Nocturno",
            // skip Nocturns II & III and the Te Deum, keep the closing
            // elements (capitulum, collect, conclusion).
            return filterToOneNocturn(parts)
        } else {
            // 3-Nocturn Matins (Sunday or Class I/II weekday feast): keep
            // all nocturns but omit Te Deum on penitential Sundays.
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
    // 1962 Breviary rubric: Preces are said at Lauds and Vespers on ferial
    // days (Mon-Sat) during Advent and Lent/Passiontide, provided no feast
    // of Double rank or higher is celebrated. They are NOT said on Sundays,
    // feast days (rank >= 3 / high-rank weekday feasts), during the Easter
    // or Pentecost octaves, or on days of obligation.

    /// Determines whether Preces Feriales should be included in the Hour.
    private func shouldIncludePreces(context: LiturgicalContext) -> Bool {
        // Never on Sundays
        guard context.dayOfWeek != 0 else { return false }

        // Only during Advent, Lent, or Passiontide
        guard context.season == .advent || context.season == .lent || context.season == .passion else {
            return false
        }

        // Not on high-rank weekday feasts (equivalent to Double rank or higher)
        if let slug = context.properSlug, Self.highRankWeekdayFeasts.contains(slug) {
            return false
        }

        return true
    }

    /// Inserts the Preces Feriales parts into the assembled hour, placed
    /// after the Collect and before the concluding "Dómine, exáudi" versicle.
    private func insertPreces(into parts: [Hour.Part], hour: String) -> [Hour.Part] {
        // Find insertion point: after the collect part.
        guard let collectIndex = parts.lastIndex(where: { $0.type == "collect" }) else {
            return parts
        }

        let insertionIndex = collectIndex + 1
        let precesParts = Self.makePrecesParts(hour: hour)

        var result = Array(parts[..<insertionIndex])
        result.append(contentsOf: precesParts)
        result.append(contentsOf: parts[insertionIndex...])
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
