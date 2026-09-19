package com.lampstandhq.introibo.data.content

import com.lampstandhq.introibo.data.model.Hour
import com.lampstandhq.introibo.data.model.OrdoEntry
import com.lampstandhq.introibo.storage.settings.MissalRite
import kotlinx.serialization.Serializable
import java.time.LocalDate

/** One office file's rank line and Rule, per rite (office_rules.json). */
@Serializable
data class OfficeRule(
    val rankName: String? = null,
    val rankLine: String? = null,
    val rank: Double? = null,
    val communeType: String? = null,
    val commune: String? = null,
    val rule: String? = null,
)

/** One line of a Divinum Officium psalm list: an antiphon with its psalms,
 *  or a ℣/℟ pair (office_psalterium.json, office_ants.json, office_commune.json). */
@Serializable
data class PsalmiLine(
    val name: String? = null,
    val ant: String? = null,
    val antEng: String? = null,
    val psalms: List<String>? = null,
    val v: String? = null,
    val r: String? = null,
    val vEng: String? = null,
    val rEng: String? = null,
)

/** DO's precedence for one hour of one day (office_ordo_<rite>.json):
 *  w = winner office key, r = rank, d = week name, n = title + class,
 *  c/t = commune key/type, ls = Lauds scheme, dx = duplex class,
 *  vs = which Vespers (1 = of the following), cv = the concurrent office
 *  commemorated at Vespers, cm = the hour's commemorations (DO's own
 *  filtered list), cm1 = tomorrow's, printed at I Vespers. */
@Serializable
data class DoOffice(
    val w: String,
    val r: Double = 0.0,
    val d: String = "",
    val n: String = "",
    val c: String? = null,
    val t: String? = null,
    val ls: Int = 1,
    val dx: Int = 3,
    val vs: Int = 3,
    val cv: String? = null,
    val cm: List<String> = emptyList(),
    val cm1: List<String> = emptyList(),
    val md: String? = null,
    /** "A capitulo de sequenti": the preceding office's Vespers antiphons and psalms. */
    val ac: List<PsalmiLine>? = null,
    val ac5: String? = null,
    /** DO's hymn transfer for the day: 1 merge, 2 shift (Vespers hymn at Matins), 3 shift and merge. */
    val hy: Int = 0,
    /** A vigil transferred from Sunday, commemorated at Lauds (DO $transfervigil). */
    val tv: String? = null,
    /** DO $octvespera: the Vespers (1 or 3) an octave's commemoration is taken from. */
    val ov: Int = 0,
    /** The September Ember Saturday (no vigil commemoration in the older books). */
    val qt: Boolean = false,
    /** DO $commemoratio: the first commemorated office of the hour. */
    val co: String? = null,
)

@Serializable
data class DoOrdoDay(val l: DoOffice? = null, val v: DoOffice? = null, val m0: String? = null, val m1: String? = null)

/** Parts keyed by DO section name, plus antiphon/psalm lists. */
@Serializable
data class OfficePsalterium(
    val parts: Map<String, Hour.Part> = emptyMap(),
    val psalmi: Map<String, List<PsalmiLine>> = emptyMap(),
)

/**
 * The rubrics of the Roman Office as Divinum Officium applies them: which
 * psalms, antiphons, capitulum, hymn, versicle, responsory and structure a
 * given hour takes on a given day, in a given rite. Every decision here
 * mirrors a DO routine (psalmi_minor, psalmi_major, psalmi_matutinum,
 * capitulum_minor/major, hymnusmajor/matutinum, invitatorium, concurrence,
 * preces, tedeum_required, capitulum_prima) — the names are kept so the
 * two can be read side by side. Mirrored by OfficeRubrics.swift.
 */
class OfficeRubrics(
    private val rules: Map<String, Map<String, OfficeRule>>,
    private val psalterium: OfficePsalterium,
    private val ants: Map<String, Map<String, List<PsalmiLine>>>,
    private val communes: Map<String, OfficePsalterium>,
    /** DO-resolved Office sections of every proper, per rite (office_propers_<rite>.json). */
    private val propersFor: (MissalRite) -> Map<String, OfficePsalterium>,
    /** DO's precedence per date (office_ordo_<rite>.json), null outside the bundled years. */
    private val ordoFor: (MissalRite, LocalDate) -> DoOrdoDay?,
    private val temporalPropers: Map<String, Map<String, Hour.Part>>,
    private val sanctoralPropers: Map<String, Map<String, Hour.Part>>,
    private val saintCommune: Map<String, String>,
    private val saintOfficeInherit: Map<String, String>,
) {

    /** A source of office texts: a proper (raw app keys) or a commune (DO
     *  section names), with its DO antiphon lists when known. */
    class Src(
        val parts: Map<String, Hour.Part>,
        val doKeyed: Boolean,
        val psalmi: Map<String, List<PsalmiLine>>?,
    ) {
        fun sec(name: String): Hour.Part? =
            if (doKeyed) parts[name] else parts[name.lowercase().replace(' ', '_')]
        val rule: String get() = parts["Rule"]?.lat ?: ""
    }

    /** An office (the day's winner, or the one Vespers belongs to). */
    class Office(
        val sanctoral: Boolean,
        val key: String,
        val rank: Double,
        val rankLine: String,
        val rule: String,
        val communeType: String?,
        val communeKey: String?,
        val communeRule: String,
        val communeRuleAny: String,
        val proper: Src,
        val commune: Src?,
        val temporalKey: String?,
        val dayName: String,
        val name: String,
        val date: LocalDate,
        val rite: MissalRite,
        val laudesDO: Int? = null,
        val duplexDO: Int? = null,
        val commemorations: List<String> = emptyList(),
        val commemorations1: List<String> = emptyList(),
        val mdKey: String? = null,
        val anteCapitulum: List<PsalmiLine>? = null,
        val anteCapitulum5: String? = null,
        val hymnShift: Int = 0,
        val transferVigil: String? = null,
        val octVespera: Int = 0,
        val emberSept: Boolean = false,
        val commemoratioKey: String? = null,
    ) {
        /** "sancti:01-14" / "tempora:adv2-1": the office as a DO key. */
        val keyRef: String get() = (if (sanctoral) "sancti:" else "tempora:") + key
        fun rankHas(re: String) = Regex(re, RegexOption.IGNORE_CASE).containsMatchIn(rankLine)
        fun ruleHas(re: String) = Regex(re, RegexOption.IGNORE_CASE).containsMatchIn(rule)
        fun communeRuleHas(re: String) = Regex(re, RegexOption.IGNORE_CASE).containsMatchIn(communeRule)
        fun communeRuleAnyHas(re: String) = Regex(re, RegexOption.IGNORE_CASE).containsMatchIn(communeRuleAny)
        val isSunday: Boolean get() = rankHas("Dominica")
        val temporal: Boolean get() = !sanctoral
        /** DO $duplex: 1 simplex/feria, 2 semiduplex, 3 duplex and above. */
        val duplex: Int get() = duplexDO ?: when {
            !rankHas("duplex") -> 1
            rankHas("semiduplex") -> 2
            else -> 3
        }
        val isC10: Boolean get() = communeKey == "C10" || key.startsWith("bvm-sab")
    }

    class Resolution(
        val overrides: Map<String, Hour.Part>,
        val drop: Set<String>,
        val office: Office,
        val vespera: Int,
        val nocturns: Int,
        val lessons: Int,
        val teDeum: Boolean,
        val precesFeriales: Boolean,
        val precesDominicales: Boolean,
        val commemoration: Office?,
        val commemorationVespera: Int,
        val laudes: Int,
        val marianOverride: String? = null,
        val commemorations: List<String> = emptyList(),
        val fromDO: Boolean = false,
        /** "Omit ... Incipit": no Pater/Ave and no Deus in adjutorium. */
        val omitIncipit: Boolean = false,
        /** "Omit ... Conclusion": the hour ends with the collect. */
        val omitConclusion: Boolean = false,
        /** "Special Conclusio": the office's own ending (Requiem æternam). */
        val conclusio: List<Hour.Part>? = null,
        /** A "Special <Hour>" script: the whole hour as DO renders it. */
        val special: List<Hour.Part>? = null,
        /** Parts added after the hour (the Litany of the Saints). */
        val append: List<Hour.Part> = emptyList(),
        /** The preces of Prime, the little hours and Compline (older books). */
        val preces: List<Hour.Part>? = null,
        /** The suffrage of the saints before the conclusion (Divino Afflatu). */
        val beforeConclusion: List<Hour.Part> = emptyList(),
        /** Parts said before the collect (the Triduum's Miserere in the older books). */
        val beforeCollect: List<Hour.Part> = emptyList(),
        /** The Marian antiphon after Lauds (the Divino Afflatu books). */
        val marianAfterLauds: Boolean = false,
    )

    private class AntLine(val ant: String?, val antEng: String?, val psalms: List<String>?)

    // ------------------------------------------------------------ helpers

    private fun riteRules(rite: MissalRite) = rules[rite.rawValue] ?: emptyMap()

    private fun lines(p: Hour.Part?): List<String> =
        p?.lat?.split("\n")?.map { it.trim() }?.filter { it.isNotEmpty() } ?: emptyList()

    private fun engLines(p: Hour.Part?): List<String> =
        p?.eng?.split("\n")?.map { it.trim() }?.filter { it.isNotEmpty() } ?: emptyList()

    /** DO psalm-list lines, ℣/℟ pairs expanded to two lines (DO's 15-line
     *  Matins layout: 3 antiphons, ℣, ℟ per nocturn). */
    private fun expand(l: List<PsalmiLine>): List<AntLine> {
        val out = ArrayList<AntLine>()
        for (x in l) {
            if (x.v != null) {
                out += AntLine(x.v, x.vEng, null)
                out += AntLine(x.r, x.rEng, null)
            } else {
                out += AntLine(x.ant, x.antEng, x.psalms)
            }
        }
        return out
    }

    /** An antiphon list of a source: DO's own list when the source is
     *  known to DO (then a missing section is genuinely absent), else the
     *  proper's multi-line part. */
    private fun antList(src: Src?, name: String): List<AntLine>? {
        if (src == null) return null
        src.psalmi?.let { ps -> return ps[name]?.let { expand(it) } }
        val p = src.sec(name) ?: return null
        val ls = lines(p)
        if (ls.isEmpty()) return null
        val es = engLines(p)
        return ls.mapIndexed { i, s -> AntLine(s, es.getOrNull(i), null) }
    }

    private fun hasSection(src: Src?, name: String): Boolean {
        if (src == null) return false
        src.psalmi?.let { ps -> if (name.startsWith("Ant ")) return ps.containsKey(name) || (src.sec(name) != null && !name.startsWith("Ant Laudes") && !name.startsWith("Ant Vespera") && !name.startsWith("Ant Matutinum")) }
        return src.sec(name) != null
    }

    /** A single antiphon section ("Ant 1", "Ant Tertia", "Invit"). */
    private fun antSec(src: Src?, name: String): Hour.Part? {
        if (src == null) return null
        if (name.startsWith("Ant ") && name !in listOf("Ant 1", "Ant 2", "Ant 3")) {
            src.psalmi?.let { ps ->
                // DO-known source: the section exists only if DO has it.
                val l = ps[name]
                if (l != null) return l.firstOrNull()?.let { Hour.Part(type = "antiphon", lat = it.ant, eng = it.antEng) }
                if (!src.doKeyed) return null
            }
        }
        return src.sec(name)
    }

    /** DO getproprium: the proper's section, else the commune's when the
     *  commune is used "ex" (or [flag] forces it, as for capitula, hymns,
     *  versicles and canticle antiphons). */
    private fun proprium(o: Office, name: String, flag: Boolean): Hour.Part? {
        // The Saturday office of the BVM: "(sed tempore paschali) Ant 1_Pasch".
        if ((name == "Ant 1" || name == "Ant 2") && alleluiaRequired(o.dayName) &&
            (o.isC10 || o.communeKey?.startsWith("C10") == true || o.communeKey == "C12")) {
            (o.proper.sec("Ant 1_Pasch") ?: o.commune?.sec("Ant 1_Pasch"))?.let { return it }
        }
        (if (name.startsWith("Ant ")) antSec(o.proper, name) else o.proper.sec(name))?.let { return it }
        if (!(o.communeType == "ex" || flag)) return null
        val c = o.commune ?: return null
        (if (name.startsWith("Ant ")) antSec(c, name) else c.sec(name))?.let { return it }
        val sub = when (name) {
            "Nocturn 1 Versum" -> "Versum 1"
            "Versum Tertia" -> "Nocturn 2 Versum"
            "Versum Sexta" -> "Nocturn 3 Versum"
            "Versum Nona" -> "Versum 2"
            else -> null
        }
        if (sub != null && o.communeKey?.startsWith("C") == true) c.sec(sub)?.let { return it }
        // A pseudo-commune (ex Sancti/..) chains to its own commune.
        if (o.communeKey != null && !o.communeKey.startsWith("C")) {
            val r = riteRules(o.rite)[o.communeKey.substringAfter(':')]
            val chained = r?.commune?.let { srcFor(it, o.rite) }
            if (chained != null) {
                chained.sec(name)?.let { return it }
                if (sub != null) chained.sec(sub)?.let { return it }
            }
        }
        return null
    }

    private fun srcFor(ref: String, rite: MissalRite, date: LocalDate? = null, paschal: Boolean = false): Src? = when {
        ref.startsWith("sancti:") -> {
            val k = ref.substringAfter(':')
            // A pseudo-commune read on another day resolves its conditionals
            // then; a file with "(tempore paschali)" sections has a Paschaltide form.
            val dated = date?.let { propersFor(rite)["$ref@%02d-%02d".format(it.monthValue, it.dayOfMonth)] }
            val byDow = date?.let { propersFor(rite)["$ref@dow${it.dayOfWeek.value % 7}"] }
            val pasch = if (paschal) propersFor(rite)["$ref@pasch"] else null
            (dated ?: byDow ?: pasch ?: propersFor(rite)[ref])?.let { Src(it.parts, true, it.psalmi) }
                ?: sanctoralPropers[k]?.let { Src(it, false, ants["sancti:$k"]) }
        }
        ref.startsWith("tempora:") -> {
            val k = ref.substringAfter(':')
            propersFor(rite)[ref]?.let { Src(it.parts, true, it.psalmi) }
                ?: temporalPropers[k]?.let { Src(it, false, ants["tempora:$k"]) }
        }
        else -> (communes[ref] ?: communes[ref.substringBefore('-')] ?: communes[ref.takeWhile { it == 'C' || it.isDigit() }])
            ?.let { Src(it.parts, true, it.psalmi) }
    }

    private fun psalmiLines(name: String): List<AntLine>? = psalmiRaw(name)?.let { expand(it) }

    private fun psalmiRaw(name: String): List<PsalmiLine>? =
        riteKey()?.let { psalterium.psalmi["$name|$it"] } ?: psalterium.psalmi[name]

    /** The rite being resolved: the psalter keeps a few sections per rite ("key|1955"). */
    private val riteCtx = ThreadLocal<MissalRite>()
    private fun riteKey(): String? = riteCtx.get()?.rawValue

    private fun psalt(name: String): Hour.Part? =
        riteKey()?.let { psalterium.parts["$name|$it"] } ?: psalterium.parts[name]

    private fun rekey(p: Hour.Part, vk: String, label: String? = null): Hour.Part =
        p.copy(variationKey = vk, label = label ?: p.label)

    private fun vrFrom(p: Hour.Part, vk: String): Hour.Part {
        if (p.latR != null) return p.copy(variationKey = vk, type = "vr")
        val ls = lines(p)
        val es = engLines(p)
        val v = ls.firstOrNull { it.startsWith("℣") || it.startsWith("V.") } ?: ls.firstOrNull()
        val r = ls.firstOrNull { it.startsWith("℟") || it.startsWith("R.") }
        val ve = es.firstOrNull { it.startsWith("℣") || it.startsWith("V.") } ?: es.firstOrNull()
        val re = es.firstOrNull { it.startsWith("℟") || it.startsWith("R.") }
        return p.copy(type = "vr", variationKey = vk, lat = v, latR = r, eng = ve, engR = re)
    }

    private fun vrParts(v: AntLine?, r: AntLine?, vk: String): Hour.Part =
        Hour.Part(type = "vr", label = "Versicle", lat = "℣. ${v?.ant ?: ""}", latR = "℟. ${r?.ant ?: ""}",
            eng = v?.antEng?.let { "℣. $it" }, engR = r?.antEng?.let { "℟. $it" }, variationKey = vk)

    private fun vrLines(p: Hour.Part?): Pair<AntLine, AntLine>? {
        p ?: return null
        val n = vrFrom(p, "x")
        return AntLine(n.lat?.removePrefix("℣. ")?.removePrefix("V. "), n.eng?.removePrefix("℣. ")?.removePrefix("V. "), null) to
            AntLine(n.latR?.removePrefix("℟. ")?.removePrefix("R. "), n.engR?.removePrefix("℟. ")?.removePrefix("R. "), null)
    }

    private fun antPart(lat: String?, eng: String?, vk: String, label: String): Hour.Part =
        Hour.Part(type = "antiphon", label = label, lat = lat, eng = eng, variationKey = vk)

    private val alleluiaAnt = "Allelúja, * allelúja, allelúja."
    private val alleluiaAntEng = "Alleluia, * alleluia, alleluia."

    private fun alleluiaRequired(dn: String) = dn.startsWith("Pasc")

    private val alleluiaRe = Regex("allel[uú]j?[ia]", RegexOption.IGNORE_CASE)

    /** DO ensure_single_alleluia: append ", allelúja." unless present. */
    private fun single(text: String?, eng: Boolean): String? {
        val t = text ?: return null
        if (t.isBlank()) return t
        if (alleluiaRe.containsMatchIn(t.takeLast(14))) return t
        val a = if (eng) "alleluia" else "allelúja"
        return t.trimEnd().trimEnd('.', ',', ';', ':') + ", $a."
    }

    /** DO ensure_double_alleluia: "A * B." -> "A b, * Allelúja, allelúja." */
    private fun double(text: String?, eng: Boolean): String? {
        val t = text ?: return null
        val a = if (eng) "Alleluia" else "Allelúja"
        if (Regex("$alleluiaRe[,.] $alleluiaRe\\p{P}?\\s*$", RegexOption.IGNORE_CASE).containsMatchIn(t)) return t
        val noStar = t.replace(Regex("\\s*\\*\\s*(\\S)")) { m -> " " + m.groupValues[1].lowercase() }
        return noStar.trimEnd().trimEnd('.', ',', ';', ':') + ", * $a, ${a.lowercase()}."
    }

    private fun alleluiaVersicle(p: Hour.Part): Hour.Part =
        p.copy(lat = single(p.lat, false), latR = single(p.latR, false), eng = single(p.eng, true), engR = single(p.engR, true))

    private fun alleluiaResponsory(p: Hour.Part): Hour.Part {
        fun conv(text: String?, eng: Boolean): String? {
            val ls = text?.split("\n") ?: return null
            val out = ArrayList<String>()
            var afterV = false
            for (l in ls) {
                when {
                    l.startsWith("℟.br.") -> { out += "℟.br. " + (double(l.removePrefix("℟.br.").trim(), eng) ?: ""); afterV = false }
                    l.startsWith("℣.") -> { out += "℣. " + (single(l.removePrefix("℣.").trim(), eng) ?: ""); afterV = true }
                    l.startsWith("℟.") && afterV -> { out += "℟. " + (if (eng) "Alleluia, alleluia." else "Allelúja, allelúja."); afterV = false }
                    l.startsWith("℟.") -> out += "℟. " + (double(l.removePrefix("℟.").trim(), eng) ?: "")
                    else -> out += l
                }
            }
            return out.joinToString("\n")
        }
        return p.copy(lat = conv(p.lat, false), eng = conv(p.eng, true))
    }

    private fun emberDay(o: Office, dow: Int): Boolean =
        dow in listOf(3, 5, 6) && (o.dayName in listOf("Adv3", "Quad1", "Pasc7") ||
            o.name.contains("Quattuor Temporum", ignoreCase = true) ||
            o.name.contains("Quatuor Temporum", ignoreCase = true))

    private fun is1960(rite: MissalRite) = rite == MissalRite.RITE_1962
    private fun is1955or1960(rite: MissalRite) = rite == MissalRite.RITE_1962 || rite == MissalRite.RITE_1955

    private fun psalmPart(vk: String, refs: List<String>, ant: String?, antEng: String?): Hour.Part {
        val first = refs.first()
        val num = first.substringBefore(':').toIntOrNull() ?: 0
        val isCant = num >= 210
        val ref = when {
            refs.size > 1 -> "Ps " + refs.joinToString(",")
            isCant -> "Cant $first"
            else -> "Ps $first"
        }
        val label = when {
            isCant -> "Canticum"
            refs.size > 1 -> "Psalmi " + refs.joinToString(", ")
            first.contains(':') -> "Psalmus ${first.substringBefore(':')} (${first.substringAfter(':')})"
            else -> "Psalmus $first"
        }
        val a = ant?.takeIf { it.isNotBlank() }
        return Hour.Part(
            type = if (isCant) "canticle" else "psalm", label = label, ref = ref, variationKey = vk,
            antiphonLat = a, antiphonEng = if (a != null) antEng else null,
        )
    }

    /** DO gettempora. */
    private fun tempora(caller: String, o: Office, dow: Int, rite: MissalRite): String {
        val dn = o.dayName
        val day = o.date.dayOfMonth
        var t = when {
            Regex("^Adv[34]$").matches(dn) && caller == "Invitatorium" -> "Adv3"
            dn.startsWith("Adv") && caller != "Doxology" && caller != "Nunc dimittis" -> "Adv"
            Regex("^Quad[56]").containsMatchIn(dn) && caller != "Doxology" -> "Quad5"
            dn.startsWith("Quad") && !dn.startsWith("Quadp") && caller != "Doxology" -> "Quad"
            dn.startsWith("Pasc6") || (dn.startsWith("Pasc5") && dow > 3 && !o.isSunday) -> "Asc"
            Regex("^Pasc[0-5]").containsMatchIn(dn) -> "Pasch"
            dn.startsWith("Pasc7") -> "Pent"
            else -> ""
        }
        if ((caller == "Psalmi minor" || caller == "Invitatorium" || caller == "Hymnus matutinum") &&
            (t == "Asc" || t == "Pent")) t = "Pasch"
        if (caller == "Lectio brevis Prima" && t.isEmpty()) t = "Per Annum"
        if (caller == "Hymnus major" && t.isEmpty()) t = "Day$dow"
        if ((caller.startsWith("Capitulum") || caller.endsWith("major")) && t.isEmpty()) {
            t = if (dow == 0 || (caller == "Capitulum minor" && o.rankHas("Duplex") && !o.rankHas("Dominica|Vigilia")))
                "Dominica" else "Feria"
        }
        if (caller == "Doxology" || caller == "Prima responsory" ||
            (is1960(rite) && caller != "Psalmi minor" && caller != "Nunc dimittis")) {
            if (dn.startsWith("Nat")) {
                t = if (day in 6..12) "Epi" else "Nat"
            } else if (Regex("^Epi[01]").containsMatchIn(dn) && day < 14) {
                t = "Epi"
            }
        }
        return t
    }

    /** DO dayofweek2i. */
    private fun dow2i(dow: Int) = when (dow) { 1, 4, 0 -> 1; 2, 5 -> 2; else -> 3 }

    // ------------------------------------------------------------ offices

    companion object {
        fun dayNameOf(temporalKey: String?): String {
            val k = temporalKey ?: return ""
            val m = Regex("^([a-z]+)(\\d*)").find(k) ?: return ""
            val prefix = m.groupValues[1]
            val num = m.groupValues[2]
            return when (prefix) {
                "adv" -> "Adv$num"
                "quadp" -> "Quadp$num"
                "quad" -> "Quad$num"
                "pasc" -> "Pasc$num"
                "pent" -> "Pent$num"
                "epi" -> "Epi$num"
                "nat" -> if ((num.toIntOrNull() ?: 0) < 7) "Nat1" else "Nat2"
                else -> ""
            }
        }

        /** Variation keys the rubrics own; the older proper/commune layering
         *  must not override them. */
        fun ownedKey(key: String): Boolean =
            key == "invit" || key.startsWith("hymnus_") || key.endsWith(".hymn") ||
                key.startsWith("ant_") || key.startsWith("matutinum.") ||
                key.startsWith("laudes.") || key.startsWith("vesperae.") ||
                key.startsWith("prima.psalm") || key == "prima.capitulum" || key == "prima.responsory" ||
                key == "versum_prima" || key == "lectio_prima" ||
                key.startsWith("tertia.") || key.startsWith("sexta.") || key.startsWith("nona.") ||
                key.startsWith("capitulum_") || key.startsWith("responsory_breve_") ||
                key.startsWith("versum_") || key.startsWith("nocturn_") ||
                key == "completorium.antiphon" || key.startsWith("completorium.psalm") ||
                key == "completorium.hymn" || key == "completorium.capitulum" || key == "completorium.responsory" ||
                key == "completorium.canticle" ||
                // DO scripts (rendered by the rubrics, never as raw text)
                key.startsWith("special_") || key == "initial" || key == "conclusio" || key.startsWith("oratio_mortuorum")
    }

    fun officeFor(ordo: OrdoEntry, date: LocalDate, rite: MissalRite): Office {
        val rr = riteRules(rite)
        val sanctoral = ordo.winner == "sanctoral"
        val key = ordo.winnerKey
        val dateKey = "%02d-%02d".format(date.monthValue, date.dayOfMonth)
        val rule: OfficeRule? = when {
            key.startsWith("bvm-sab") -> rr["C10"]
            sanctoral -> rr[key] ?: rr[key.take(5)]
            key.startsWith("nat") -> rr[dateKey] ?: rr[key]
            else -> rr[key] ?: rr[key.removeSuffix("o")]
        }
        val proper = LinkedHashMap<String, Hour.Part>()
        if (sanctoral) {
            sanctoralPropers[key]?.let { proper.putAll(it) }
            if (rite == MissalRite.PRE_1955) sanctoralPropers[key + "o"]?.let { proper.putAll(it) }
        } else {
            temporalPropers[key]?.let { proper.putAll(it) }
            if (rite == MissalRite.PRE_1955) temporalPropers[key + "o"]?.let { proper.putAll(it) }
        }
        var communeKey: String? = rule?.commune
        var communeType: String? = rule?.communeType
        if (communeKey == null && sanctoral) {
            val inh = saintOfficeInherit[key]
            if (inh != null) { communeKey = "sancti:$inh"; communeType = "ex" }
            else (saintCommune[key] ?: saintCommune[key.take(5)])?.let { communeKey = it; communeType = communeType ?: "vide" }
        }
        if (key.startsWith("bvm-sab")) { communeKey = "C10"; communeType = "ex" }
        val commune = communeKey?.let { srcFor(it, rite) }
        // DO: the commune's Rule applies only when the office is "ex" its commune.
        val communeRuleAny = communeKey?.let { ck ->
            val fk = if (ck.contains(':')) ck.substringAfter(':') else ck
            rr[fk]?.rule ?: commune?.rule
        } ?: ""
        val communeRule = if (communeType == "ex") communeRuleAny else ""
        val antsKey = if (sanctoral) (if (key.startsWith("bvm-sab")) "C10" else "sancti:$key") else "tempora:$key"
        val doProper = when {
            key.startsWith("bvm-sab") -> communes["C10"]
            sanctoral -> propersFor(rite)["sancti:$key"] ?: propersFor(rite)["sancti:" + key.take(5)]
            key.startsWith("nat") -> propersFor(rite)["sancti:$dateKey"]
            else -> propersFor(rite)["tempora:$key"] ?: propersFor(rite)["tempora:" + key.removeSuffix("o")]
        }
        val properSrc = if (doProper != null) Src(doProper.parts, true, doProper.psalmi)
        else Src(proper, false, ants[antsKey])
        val dow = date.dayOfWeek.value % 7
        val rankLine = rule?.rankLine
            ?: (ordo.name + ";;" + (if (sanctoral) "Duplex" else if (dow == 0) "Dominica" else "Feria") + ";;" + ordo.rank)
        return Office(
            sanctoral = sanctoral, key = key,
            rank = rule?.rank ?: ordo.rank, rankLine = rankLine, rule = rule?.rule ?: "",
            communeType = if (commune != null) communeType else null,
            communeKey = if (commune != null) communeKey else null,
            communeRule = communeRule, communeRuleAny = communeRuleAny,
            proper = properSrc, commune = commune,
            temporalKey = ordo.temporal, dayName = dayNameOf(ordo.temporal), name = ordo.name, date = date, rite = rite,
        )
    }

    /** The app's proper for a DO office key (sancti:01-21 / tempora:pent02-0r). */
    private fun appProper(key: String): Map<String, Hour.Part>? {
        val k = key.substringAfter(':')
        return if (key.startsWith("sancti:")) sanctoralPropers[k] ?: sanctoralPropers[k.take(5)]
        else temporalPropers[k] ?: temporalPropers[k.removeSuffix("feria").removeSuffix("r")]
    }

    /** An office from DO's own precedence. */
    fun officeFrom(d: DoOffice, date: LocalDate, rite: MissalRite): Office {
        val rr = riteRules(rite)
        val sanctoral = !d.w.startsWith("tempora:")
        val key = d.w.substringAfter(':')
        val rule = rr[key] ?: rr[key.take(5)]
        var doProper = propersFor(rite)["${d.w}@dow${date.dayOfWeek.value % 7}"]
            ?: (if (alleluiaRequired(d.d)) propersFor(rite)["${d.w}@pasch"] else null) ?: propersFor(rite)[d.w]
            ?: (if (!d.w.contains(':')) communes[d.w] ?: communes[d.w.removeSuffix("Pasc")] else null)
        // The scripture-cycle file of the week (Aug-Nov) overlays the Sunday's
        // own sections (DO officestring: every key but the Rank).
        val mdKey = d.md?.takeIf { Regex("^tempora:(pent|epi)").containsMatchIn(d.w) && !Regex("^tempora:pent0[1-5]").containsMatchIn(d.w) }
        val md = mdKey?.let { propersFor(rite)[it] }
        if (md != null) {
            doProper = OfficePsalterium(
                parts = (doProper?.parts ?: emptyMap()) + md.parts,
                psalmi = (doProper?.psalmi ?: emptyMap()) + md.psalmi,
            )
        }
        val proper = doProper?.let { Src(it.parts, true, it.psalmi) }
            ?: Src(appProper(d.w) ?: emptyMap(), false, ants[d.w])
        val commune = d.c?.let { srcFor(it, rite, date, alleluiaRequired(d.d)) }
        val communeRuleAny = d.c?.let { ck ->
            val fk = if (ck.contains(':')) ck.substringAfter(':') else ck
            rr[fk]?.rule ?: commune?.rule
        } ?: ""
        val communeRule = if (d.t == "ex") communeRuleAny else ""
        val rankLine = d.n.ifBlank { rule?.rankLine ?: "" }
        return Office(
            sanctoral = sanctoral, key = key,
            rank = d.r, rankLine = rankLine, rule = md?.parts?.get("Rule")?.lat ?: rule?.rule ?: proper.rule,
            communeType = if (commune != null) d.t else null,
            communeKey = if (commune != null) d.c else null,
            communeRule = communeRule, communeRuleAny = communeRuleAny,
            proper = proper, commune = commune,
            temporalKey = null, dayName = d.d, name = d.n.substringBefore(";;").substringBefore(" Duplex").substringBefore(" Semiduplex").substringBefore(" Feria"),
            date = date, rite = rite, laudesDO = d.ls, duplexDO = d.dx, commemorations = d.cm, commemorations1 = d.cm1,
            mdKey = mdKey, anteCapitulum = d.ac, anteCapitulum5 = d.ac5, hymnShift = d.hy, transferVigil = d.tv,
            octVespera = d.ov, emberSept = d.qt, commemoratioKey = d.co,
        )
    }

    /** The collect of the day for an hour (DO oratio()): the office's own
     *  (a Sunday's for the ferias that repeat it, "Oratio Dominica"; the
     *  OratioW of the week after Pentecost; Oratio Matutinum at Matins;
     *  Oratio 1/2/3 by Vespers), else the commune's, else the Sunday's. */
    private fun oratioOf(o: Office, hourSlug: String, vespera: Int, dow: Int = o.date.dayOfWeek.value % 7): Hour.Part? {
        val ind = if (hourSlug == "vesperae") vespera else 2
        var rule = o.rule
        if (o.dayName.startsWith("Epi1") && rule.contains("Infra octavam Epiphaniæ Domini", ignoreCase = true) && is1955or1960(o.rite)) {
            rule += "\nOratio Dominica"
        }
        val win = o.proper
        var w: Src = win
        if (Regex("Oratio Dominica", RegexOption.IGNORE_CASE).containsMatchIn(rule) ||
            (o.rankHas("Quattuor") && !o.dayName.startsWith("Pasc7") && !is1960(o.rite) && hourSlug == "vesperae")) {
            var name = "${o.dayName}-0"
            if (Regex("Epi1|Nat", RegexOption.IGNORE_CASE).containsMatchIn(name)) name = "Epi1-0a"
            srcFor("tempora:" + name.lowercase(), o.rite)?.let { w = it }
        }
        // "(nisi ad vesperam aut rubrica 196)": the September Ember days'
        // own collect is not said at Vespers in the older books.
        val emberVespers = hourSlug == "vesperae" && !is1960(o.rite) && o.mdKey?.matches(Regex("tempora:09\\d-[356]")) == true
        var p: Hour.Part? = if (emberVespers) null else if (dow > 0 && win.sec("OratioW") != null && o.rank < 5) w.sec("OratioW") else w.sec("Oratio")
        if (hourSlug == "matutinum" && win.sec("Oratio Matutinum") != null) p = w.sec("Oratio Matutinum")
        else if (p == null || win.sec("Oratio $ind") != null) p = w.sec("Oratio $ind")
        val c = o.commune
        if (p == null && c != null) p = c.sec("Oratio $ind") ?: c.sec("Oratio ${4 - ind}") ?: c.sec("Oratio")
        if (p == null) {
            var i = ind
            if (i == 2) { i = 3; p = w.sec("Oratio 3") } else p = w.sec("Oratio 2")
            if (p == null) { i = 4 - i; p = w.sec("Oratio $i") }
        }
        if (p == null && c != null) p = c.sec("Oratio") ?: c.sec("Oratio $ind")
        if (p == null && o.temporal) {
            srcFor("tempora:${o.dayName.lowercase()}-0", o.rite)?.let { sd -> p = sd.sec("Oratio") ?: sd.sec("Oratio 2") }
        }
        return p?.let { withName(it, w.sec("Name")?.let { w } ?: win) }
    }

    // ------------------------------------------------------------ names, inline alleluias

    /** DO replaceNdot: the name the proper's [Name] gives for "N." in a
     *  text (the Doctor antiphon and the widows' invitatory keep their
     *  own case: "Ant=" / "Invit=" lines; the collect "Oratio="). */
    private fun nameFor(src: Src?, text: String, eng: Boolean): String? {
        val np = src?.sec("Name") ?: return null
        val raw = (if (eng) (np.eng ?: np.lat) else np.lat) ?: return null
        var ls = raw.split("\n").map { it.trim() }.filter { it.isNotEmpty() }
        if (ls.isEmpty()) return null
        ls = when {
            Regex("^[OÓ],?\\s|O Doctor optime").containsMatchIn(text) && ls.any { it.startsWith("Ant=") } -> ls.filter { it.startsWith("Ant=") }
            Regex("^L..*N\\.\\.").containsMatchIn(text) && ls.any { it.startsWith("Invit=") } -> ls.filter { it.startsWith("Invit=") }
            ls.any { it.startsWith("Oratio=") } -> ls.filter { it.startsWith("Oratio=") }
            else -> ls
        }
        return ls[0].substringAfter('=').trim().ifEmpty { null }
    }

    private fun replaceNdot(text: String?, name: String?): String? {
        if (text == null || name == null || !text.contains("N.")) return text
        return text.replaceFirst(Regex("N\\. .*? N\\."), name).replace("N.", name)
    }

    /** Spanish for a templated Latin text (the "N." still in it), and the
     *  Spanish form of a proper's [Name] value; null in English. Set by the
     *  ContentStore when the vernacular is Spanish. */
    var spanishText: ((String) -> String?)? = null
    var spanishName: ((String) -> String?)? = null

    /** The office's [Name] filled into every "N." of a part. In Spanish the
     *  vernacular is taken from the template before the name goes in, with
     *  the name in its Spanish form; the English is never touched. */
    private fun withName(p: Hour.Part, src: Src?): Hour.Part {
        if (src?.sec("Name") == null) return p
        fun f(t: String?, eng: Boolean): String? = if (t == null || !t.contains("N.")) t else replaceNdot(t, nameFor(src, t, eng))
        fun es(latT: String?): String? {
            val lookup = spanishText ?: return null
            if (latT == null || !latT.contains("N.")) return null
            val template = lookup(latT) ?: return null
            val nameLat = nameFor(src, latT, false) ?: return null
            val nameEs = spanishName?.invoke(nameLat) ?: nameFor(src, latT, true) ?: return null
            return replaceNdot(template, nameEs)
        }
        return p.copy(lat = f(p.lat, false), latR = f(p.latR, false),
            eng = es(p.lat) ?: f(p.eng, true), engR = es(p.latR) ?: f(p.engR, true),
            antiphonLat = f(p.antiphonLat, false), antiphonEng = es(p.antiphonLat) ?: f(p.antiphonEng, true))
    }

    private val parenAlleluia = Regex("\\s*\\((allel[uú]j?[ia][^)]*)\\)", RegexOption.IGNORE_CASE)
    private val anyAlleluia = Regex("[,.]?\\s*allel[uú][ij]a", RegexOption.IGNORE_CASE)

    /** Whether the hour falls in the alleluia-less season (Septuagesima to
     *  Holy Saturday), the Saturday Vespers before Septuagesima excepted. */
    fun lentSuppressed(o: Office, hourSlug: String, dow: Int, vespera: Int): Boolean {
        if (!Regex("Quadp|Quad[1-5]|Quad6-[0-5]").containsMatchIn(o.dayName)) return false
        val septVesp = dow == 6 && (hourSlug == "vesperae" || hourSlug == "completorium") && vespera == 1 && o.dayName.startsWith("Quadp1")
        return !septVesp
    }

    private fun withoutAlleluia(p: Hour.Part): Hour.Part {
        fun f(t: String?): String? = t?.let { if (anyAlleluia.containsMatchIn(it)) it.replace(anyAlleluia, "") else it }
        if (listOf(p.lat, p.latR, p.eng, p.engR, p.antiphonLat, p.antiphonEng).none { it != null && anyAlleluia.containsMatchIn(it) }) return p
        return p.copy(lat = f(p.lat), latR = f(p.latR), eng = f(p.eng), engR = f(p.engR), antiphonLat = f(p.antiphonLat), antiphonEng = f(p.antiphonEng))
    }

    /** DO process_inline_alleluias: a bracketed "(Allelúja.)" is said in
     *  Paschaltide and dropped outside it. */
    private fun inlineAlleluia(t: String?, paschal: Boolean): String? {
        if (t == null || !t.contains('(')) return t
        return if (paschal) t.replace(parenAlleluia) { " " + it.groupValues[1] }.replace(Regex(" {2,}"), " ")
        else t.replace(parenAlleluia, "").trimEnd()
    }

    private fun withInlineAlleluia(p: Hour.Part, paschal: Boolean): Hour.Part {
        fun has(t: String?) = t != null && t.contains('(')
        if (!has(p.lat) && !has(p.latR) && !has(p.eng) && !has(p.engR) && !has(p.antiphonLat) && !has(p.antiphonEng)) return p
        return p.copy(lat = inlineAlleluia(p.lat, paschal), latR = inlineAlleluia(p.latR, paschal),
            eng = inlineAlleluia(p.eng, paschal), engR = inlineAlleluia(p.engR, paschal),
            antiphonLat = inlineAlleluia(p.antiphonLat, paschal), antiphonEng = inlineAlleluia(p.antiphonEng, paschal))
    }

    /** The pieces of a commemoration (DO getcommemoratio): its canticle
     *  antiphon, versicle and collect, keyed for insertCommemoration
     *  (ant_N / versum_N / oratio, N = 2 at Lauds, the Vespers kind
     *  [vesperaOf] otherwise). Empty when the rubrics make none. */
    fun commemorationData(key: String, hourSlug: String, date: LocalDate, rite: MissalRite, vesperaOf: Int = 3,
                          winner: Office? = null, vespera: Int = 3): Map<String, Hour.Part> {
        val ind = if (hourSlug == "laudes") 2 else vesperaOf
        val w = officeFromKey(key, date, rite, tomorrow = ind == 1, dayName = winner?.dayName ?: "")
        val wr = winner?.rank ?: 0.0
        val dn = winner?.dayName ?: w.dayName
        if (winner != null && winner.ruleHas("no\\s+(\\w+)?\\s*commemoratio")) {
            val m = Regex("no\\s+(\\w+)?\\s*commemoratio", RegexOption.IGNORE_CASE).find(winner.rule)
            val which = m?.groupValues?.get(1) ?: ""
            if ((which.isEmpty() || key.contains(which, ignoreCase = true)) && !(hourSlug == "vesperae" && vespera == 3 && ind == 1)) return emptyMap()
        }
        if (is1960(rite) && hourSlug == "vesperae" && ind == 3 && wr >= 6 &&
            !w.rankHas("Adv|Quad|Passio|Epi|Corp|Nat|Cord|Asc|Dominica|;;6")) return emptyMap()
        val rp = w.rankLine.split(";;").map { it.trim() }
        val r2 = rp.getOrNull(2)?.toDoubleOrNull() ?: w.rank
        if (r2 < 2.1 && r2 != 1.15 && ((rp.getOrNull(1) ?: "").contains("Feria") ||
                ((rp.getOrNull(0) ?: "").contains("Infra Octav", ignoreCase = true) && wr >= 5 && winner?.sanctoral == true))) return emptyMap()
        // The commune the commemoration draws on ("ex" or "vide" alike).
        var c: Src? = null
        Regex("(ex|vide)\\s+(.*?)\\s*$", RegexOption.IGNORE_CASE).find(rp.getOrNull(3) ?: "")?.let { m ->
            var file = m.groupValues[2].trim()
            Regex("Comex=(.*?);", RegexOption.IGNORE_CASE).find(w.rule)?.let { if (wr < 5) file = it.groupValues[1].trim() }
            file = paschalCommune(file, dn)
            var src = srcFor(communeRef(file), rite)
            // A daisy-chained commune reference, one level down.
            val chain = riteRules(rite)[file]?.rankLine?.let { Regex(";;(ex|vide)\\s+(.*?)\\s*$", RegexOption.IGNORE_CASE).find(it) }
            if (src != null && chain != null) {
                val f2 = paschalCommune(chain.groupValues[2].trim(), dn)
                srcFor(communeRef(f2), rite)?.let { s2 ->
                    val keep = setOf("Oratio", "Ant 1", "Ant 2", "Ant 3", "Versum 1", "Versum 2", "Versum 3")
                    src = Src(s2.parts.filterKeys { it in keep } + src!!.parts, true, src!!.psalmi)
                }
            }
            c = src
        }
        // The collect.
        var o: Hour.Part? = w.proper.sec("Oratio")?.let { withName(it, w.proper) }
        if (o == null && w.ruleHas("Oratio Dominica")) {
            var wday = w.key.replace(Regex("-[0-9]"), "-0")
            if (wday.contains("epi1-0")) wday = wday.replace("epi1-0", "epi1-0a")
            srcFor("tempora:$wday", rite)?.let { sd -> o = sd.sec("OratioW") ?: sd.sec("Oratio") }
        }
        if (o == null) o = w.proper.sec("Oratio $ind") ?: w.proper.sec("Oratio ${4 - ind}") ?: c?.sec("Oratio")
        o = o?.let { withName(it, w.proper) }
        if (o == null || o!!.lat.isNullOrBlank()) return emptyMap()
        // The antiphon.
        var a: Hour.Part? = antSec(w.proper, "Ant $ind")
        val epi1Special = winner != null && (winner.key == "epi1-0a" || winner.key == "01-12t") && hourSlug == "vesperae" && vespera == 3
        if (a == null || epi1Special) {
            a = if (!Regex("epi[2-6]-0").containsMatchIn(w.key)) antSec(w.proper, "Ant ${4 - ind}") else psalt("Feria Ant 3")
        }
        if (a == null) a = c?.let { antSec(it, "Ant $ind") }
        a = a?.let { withName(it, w.proper) }
        if (w.temporal && date.monthValue == 12 &&
            ((hourSlug == "vesperae" && date.dayOfMonth in 17..23) || (hourSlug == "laudes" && (date.dayOfMonth == 21 || date.dayOfMonth == 23)))) {
            a = psalt(if (hourSlug == "vesperae") "Adv Ant ${date.dayOfMonth}" else "Adv Ant ${date.dayOfMonth}L") ?: a
        }
        if (a == null || lines(a).isEmpty()) {
            // DO: a vigil without antiphon of its own takes the ferial form at Lauds.
            return if (hourSlug == "laudes" && w.rankHas("Vigilia")) vigilCommemoration(w, winner, date, rite, false) else emptyMap()
        }
        // The versicle.
        var v: Hour.Part? = w.proper.sec("Versum $ind")
        if (winner != null && (winner.key == "epi1-0a" || winner.key == "01-12t")) {
            v = if (vespera == 1 && date.dayOfMonth == 10) c?.sec("Versum 2") else c?.sec("Versum Tertia")
        }
        if (v == null) v = w.proper.sec("Versum ${4 - ind}") ?: c?.sec("Versum $ind") ?: c?.sec("Versum ${4 - ind}")
        if (v == null) {
            // DO getfrompsalterium('Versum', ind): the season's psalter versicle.
            val name = tempora("getfrompsalterium major", winner ?: w, date.dayOfWeek.value % 7, rite) + " Versum"
            v = psalt("$name $ind") ?: psalt("$name 1") ?: psalt("$name 3") ?: psalt("$name 2")
        }
        val paschal = alleluiaRequired(dn)
        val out = HashMap<String, Hour.Part>()
        out["name"] = Hour.Part(type = "rubric", lat = rp.getOrNull(0) ?: w.name)
        out["ant_$ind"] = withInlineAlleluia(a.copy(type = "antiphon", lat = lines(a)[0], eng = engLines(a).firstOrNull(), variationKey = null), paschal)
        v?.let {
            var vr = withInlineAlleluia(vrFrom(it, "versum_$ind"), paschal)
            if (paschal && !w.ruleHas("C9|C12")) vr = alleluiaVersicle(vr)
            out["versum_$ind"] = vr
        }
        out["oratio"] = withInlineAlleluia(o!!.copy(type = "collect", label = "Oratio", variationKey = "oratio"), paschal)
        return out
    }

    /** DO vigilia_commemoratio: a vigil commemorated at Lauds with the
     *  ferial Benedictus antiphon and versicle and its own collect
     *  ([useVigilia]: the "Oratio Vigilia" a feast carries for its vigil). */
    private fun vigilCommemoration(w: Office, winner: Office?, date: LocalDate, rite: MissalRite, useVigilia: Boolean): Map<String, Hour.Part> {
        val dn = winner?.dayName ?: w.dayName
        val dow = date.dayOfWeek.value % 7
        if (is1955or1960(rite)) {
            if (!Regex("^(08-14|06-23|06-28|08-09)").containsMatchIn(w.key)) return emptyMap()
        } else if (Regex("Adv|Quad[0-6]").containsMatchIn(dn) || (dn.startsWith("Quadp3") && dow >= 4) || winner?.emberSept == true) return emptyMap()
        var o: Hour.Part? = if (useVigilia) w.proper.sec("Oratio Vigilia") else w.proper.sec("Oratio")
        if (o == null && !useVigilia && w.rankHas("(ex|vide) C1v")) o = srcFor("C1v", rite)?.sec("Oratio")?.let { withName(it, w.proper) }
        if (o == null && useVigilia) o = w.proper.sec("Oratio Vigilia")
        if (o == null || o.lat.isNullOrBlank()) return emptyMap()
        // The ferial Benedictus antiphon of the weekday (none on a Sunday).
        val a = if (dow == 0) null else psalt("Feria${dow + 1} Ant 2") ?: psalt("Feria Ant 2")
        val v = psalt("Feria Versum 2")
        val out = HashMap<String, Hour.Part>()
        out["name"] = Hour.Part(type = "rubric", lat = if (w.rankHas("Vigilia")) w.rankLine.substringBefore(";;") else "Vigilia")
        a?.let { out["ant_2"] = it.copy(type = "antiphon", lat = (it.lat ?: "").replace(Regex("\\s*\\*\\s*"), " "), variationKey = null) }
        v?.let { out["versum_2"] = vrFrom(it, "versum_2") }
        out["oratio"] = withName(o, w.proper).copy(type = "collect", label = "Oratio", variationKey = "oratio")
        return out
    }

    /** DO: the martyrs' communes (C1-C3) take their Paschaltide form. */
    private fun paschalCommune(file: String, dayName: String): String =
        if (Regex("^C[1-3](?![v\\d])").containsMatchIn(file) && dayName.startsWith("Pasc")) file.removeSuffix("p") + "p" else file

    private fun communeRef(file: String): String = when {
        file.startsWith("Sancti/") -> "sancti:" + file.removePrefix("Sancti/").removeSuffix(".txt")
        file.startsWith("Tempora/") -> "tempora:" + file.removePrefix("Tempora/").removeSuffix(".txt").lowercase()
        else -> file.removePrefix("Commune/").removeSuffix(".txt")
    }

    /** The commemorations of an hour in DO's order: the concurrent office
     *  first at Vespers, then the Sundays, then by rank; each as the map
     *  insertCommemoration takes. */
    fun commemorationsFor(hourSlug: String, date: LocalDate, rite: MissalRite, res: Resolution): List<Map<String, Hour.Part>> {
        riteCtx.set(rite)
        val o = res.office
        // DO: no commemorations at all on a Duplex I classis of the first rank (rank 7).
        if (o.rank >= 7) return emptyList()
        val entries = ArrayList<Pair<Double, Map<String, Hour.Part>>>()
        var ccind = 0
        val vespers = hourSlug == "vesperae"
        val sunday = Regex("Dominic[aæ]", RegexOption.IGNORE_CASE)
        val octaveRe = Regex("O[ckt]t[aá]|Octava", RegexOption.IGNORE_CASE)
        // DO $octvespera: the Vespers (1 or 3) an octave's commemoration is
        // taken from at the Saturday/Sunday boundary (the older books).
        val ov = if (vespers && !is1960(rite)) o.octVespera else 0
        // The office's own [Commemoratio] sections.
        for (d in ownCommemorations(o, hourSlug, res.vespera, date, rite, ov)) {
            ccind++
            val t = d["name"]?.lat ?: ""
            val key = if (sunday.containsMatchIn(t)) 3000.0
                else if (octaveRe.containsMatchIn(t)) (if (res.commemoration == null && ov != 0) 1000.0 else (ccind + 7900).toDouble())
                else (ccind + 9900).toDouble()
            entries += key to d
        }
        if (vespers && res.commemoration != null) {
            val cw = res.commemoration
            var d = commemorationData(cw.keyRef, hourSlug, date, rite, res.commemorationVespera, o, res.vespera)
            // "Substitute Commemoratio of Octave to Vesp-$octvespera".
            if (d.isNotEmpty() && ov != 0 && ov != res.commemorationVespera && octaveRe.containsMatchIn(d["name"]?.lat ?: "")) {
                d = commemorationData(cw.keyRef, hourSlug, date, rite, ov, o, res.vespera)
            }
            if (d.isNotEmpty()) {
                ccind++
                val key = if (cw.ruleHas("infra Octavam Epi")) 5600.0 else 9000.0
                entries += (10000 - key) to d
                for ((i, e) in embeddedCommemorations(cw, res.commemorationVespera, o, hourSlug).withIndex()) entries += (10000 - key + 0.1 * (i + 1)) to e
            }
        }
        // A commemoration the collect carries itself ("@File:CommemoratioN"
        // after the collect): printed with it at Lauds and Vespers.
        val ind = if (vespers) res.vespera else 2
        for (name in listOf("Oratio $ind Commemoratio", "Oratio Commemoratio")) {
            val sec = o.proper.sec(name) ?: continue
            for (block in (sec.lat ?: "").split(Regex("\\n(?=!)")).filter { it.isNotBlank() }) {
                if (hourSlug == "laudes" && Regex("precedenti|sequenti", RegexOption.IGNORE_CASE).containsMatchIn(block)) continue
                val d = parseCommemorationBlock(block, null, ind, o) ?: continue
                entries += 0.0 to d
            }
            break
        }
        if (vespers && res.commemoration != null) {
            for (d in fileCommemorations(res.commemoration, o, hourSlug, res.commemorationVespera, date, rite, ov)) {
                ccind++
                entries += (if (sunday.containsMatchIn(d["name"]?.lat ?: "")) 3000.0 else (ccind + 9900).toDouble()) to d
            }
        }
        // A vigil falling on a Sunday, commemorated the day before (DO $transfervigil).
        if (!vespers) o.transferVigil?.let { tv ->
            val dv = vigilCommemoration(officeFromKey(tv, date, rite, dayName = o.dayName), o, date, rite, false)
            if (dv.isNotEmpty()) { ccind++; entries += (ccind + 8500).toDouble() to dv }
        }
        val lists = if (vespers) listOf(1 to o.commemorations1, 3 to o.commemorations) else listOf(2 to o.commemorations)
        for ((cv, list) in lists) {
            for (ck in list) {
                val w = officeFromKey(ck, date, rite, tomorrow = cv == 1, dayName = o.dayName)
                // An octave's day commemorated at the Saturday/Sunday boundary takes DO's $octvespera.
                val cvUse = if (ov != 0 && w.rankHas("in.*octavam|post Octavam Asc")) ov else cv
                val d = commemorationData(ck, hourSlug, date, rite, cvUse, o, res.vespera)
                if (d.isEmpty()) continue
                val rp = w.rankLine.split(";;").map { it.trim() }
                val r2 = rp.getOrNull(2)?.toDoubleOrNull() ?: w.rank
                val key = if (sunday.containsMatchIn(rp.getOrNull(0) ?: "") || ck.endsWith("01-05")) 7000.0 else r2 * 1000
                ccind++
                entries += (10000 - key + ccind) to d
                for ((i, e) in embeddedCommemorations(w, cv, o, hourSlug).withIndex()) entries += (10000 - key + ccind + 0.1 * (i + 1)) to e
                if (cv == 2 && date.dayOfWeek.value % 7 != 0 && w.proper.sec("Oratio Vigilia") != null) {
                    val dv = vigilCommemoration(w, o, date, rite, true)
                    if (dv.isNotEmpty()) { ccind++; entries += (ccind + 8500).toDouble() to dv }
                }
                // The commemorations that office carries in its own file (an octave's).
                for (d2 in fileCommemorations(w, o, hourSlug, cv, date, rite, ov)) {
                    ccind++
                    val t = d2["name"]?.lat ?: ""
                    entries += (if (sunday.containsMatchIn(t)) 3000.0 else if (Regex("O[ckt]t[aá]|Octava", RegexOption.IGNORE_CASE).containsMatchIn(t)) (ccind + 7900).toDouble() else (ccind + 9900).toDouble()) to d2
                }
            }
        }
        var ordered = entries.sortedBy { it.first }.map { it.second }
        // DO $octavam: an octave commemorated once only, whichever file names it.
        val seenOctaves = HashSet<String>()
        ordered = ordered.filter { m ->
            val t = m["name"]?.lat ?: ""
            !octaveRe.containsMatchIn(t) || seenOctaves.add(t.lowercase().replace(Regex("\\s+"), " "))
        }
        if (lentSuppressed(o, hourSlug, date.dayOfWeek.value % 7, res.vespera)) ordered = ordered.map { m -> m.mapValues { withoutAlleluia(it.value) } }
        // Under the 1960 rubrics a II-class day (or a II-class feria) keeps
        // only the first commemoration.
        if (is1960(rite) && ordered.size > 1 && (o.rank >= 5 || (o.rankLine.contains("Feria", ignoreCase = true) && o.rank >= 4))) ordered = ordered.take(1)
        return ordered
    }

    /** The commemoration a commemorated office's collect carries with it
     *  ("@File:CommemoratioN" after its Oratio: St Peter's on St Paul's). */
    private fun embeddedCommemorations(w: Office, ind: Int, winner: Office, hourSlug: String): List<Map<String, Hour.Part>> {
        val sec = w.proper.sec("Oratio $ind Commemoratio") ?: w.proper.sec("Oratio Commemoratio") ?: return emptyList()
        val out = ArrayList<Map<String, Hour.Part>>()
        for (block in (sec.lat ?: "").split(Regex("\\n(?=!)")).filter { it.isNotBlank() }) {
            if (hourSlug == "laudes" && Regex("precedenti|sequenti", RegexOption.IGNORE_CASE).containsMatchIn(block)) continue
            parseCommemorationBlock(block, null, ind, winner)?.let { out += it }
        }
        return out
    }

    /** DO "add commemorated from commemo/cwinner": the commemorations a
     *  commemorated office carries in its own file (an octave's day). */
    private fun fileCommemorations(w: Office, winner: Office, hourSlug: String, cv: Int, date: LocalDate, rite: MissalRite, ov: Int = 0): List<Map<String, Hour.Part>> {
        if ((winner.rank >= 6 && !Regex("Pasc[07]").containsMatchIn(winner.dayName)) || winner.ruleHas("no commemoratio") ||
            (is1960(rite) && w.ruleHas("nocomm1960"))) return emptyList()
        var ind = cv
        var sec = w.proper.sec("Commemoratio $cv")
            ?: (if (ov != 0) w.proper.sec("Commemoratio $ov")?.also { ind = ov } else null)
            ?: w.proper.sec("Commemoratio")?.takeIf {
                cv != 3 || w.temporal || Regex("(O[ckt]t[aá]|Octava)", RegexOption.IGNORE_CASE).containsMatchIn(it.lat ?: "")
            } ?: return emptyList()
        // "Substitute Commemorated Octave to Vesp-$octvespera".
        if (ov != 0 && Regex("!.*?(O[ckt]t[aá]|Octava)", RegexOption.IGNORE_CASE).containsMatchIn(sec.lat ?: "")) {
            sec = w.proper.sec("Commemoratio $ov") ?: w.proper.sec("Commemoratio ${4 - ov}") ?: w.proper.sec("Commemoratio") ?: sec
            ind = ov
        }
        return commemorationBlocks(sec, w, winner, hourSlug, ind, date, rite)
    }

    /** DO "add commemorated from winner": commemorations the office file
     *  carries itself ([Commemoratio], [Commemoratio 1/2/3]). */
    private fun ownCommemorations(o: Office, hourSlug: String, vespera: Int, date: LocalDate, rite: MissalRite, ov: Int = 0): List<Map<String, Hour.Part>> {
        var ind = if (hourSlug == "laudes") 2 else vespera
        if ((o.rank >= 6 && !Regex("Pasc[07]|Pent01").containsMatchIn(o.dayName)) || (is1960(rite) && o.ruleHas("nocomm1960"))) return emptyList()
        var sec = o.proper.sec("Commemoratio $ind") ?: o.proper.sec("Commemoratio")?.takeIf {
            ind != 3 || o.temporal || Regex("!.*O[ckt]ta", RegexOption.IGNORE_CASE).containsMatchIn(it.lat ?: "")
        } ?: return emptyList()
        // "Substitute Commemorated Octave to Vesp-$octvespera".
        if (ov != 0 && Regex("!.*?(O[ckt]t[aá]|Octava)", RegexOption.IGNORE_CASE).containsMatchIn(sec.lat ?: "")) {
            sec = o.proper.sec("Commemoratio $ov") ?: o.proper.sec("Commemoratio ${4 - ov}") ?: o.proper.sec("Commemoratio") ?: sec
            ind = ov
        }
        return commemorationBlocks(sec, o, o, hourSlug, ind, date, rite)
    }

    /** The "!Commemoratio ..." blocks of a section, filtered as DO does. */
    private fun commemorationBlocks(sec: Hour.Part, w: Office, winner: Office, hourSlug: String, ind: Int, date: LocalDate, rite: MissalRite): List<Map<String, Hour.Part>> {
        val o = w
        val octave = Regex("^!.*?(O[ckt]t[aá]|Octava)", RegexOption.IGNORE_CASE)
        val sunday = Regex("^!.*?Dominic[aæ]", RegexOption.IGNORE_CASE)
        val nooctnat = is1955or1960(rite) && (date.monthValue < 12 || date.dayOfMonth < 25)
        val out = ArrayList<Map<String, Hour.Part>>()
        val latBlocks = (sec.lat ?: "").split(Regex("\\n(?=!)")).filter { it.isNotBlank() }
        val engBlocks = (sec.eng ?: "").split(Regex("\\n(?=!)"))
        for ((i, block) in latBlocks.withIndex()) {
            var refTitle = ""
            Regex("^@([^:\\n]+):Oratio", RegexOption.MULTILINE).find(block)?.let { m ->
                refTitle = "!" + (officeFromKey(communeRef(m.groupValues[1]), date, rite).rankLine.substringBefore(";;"))
            }
            if ((octave.containsMatchIn(block) || sunday.containsMatchIn(block) || octave.containsMatchIn(refTitle) || sunday.containsMatchIn(refTitle)) && nooctnat) continue
            if (is1955or1960(rite) && Regex("^!.*?Vigil", RegexOption.IGNORE_CASE).containsMatchIn(block) && o.sanctoral &&
                !Regex("08-14|06-23|06-28|08-09").containsMatchIn(o.key)) continue
            val d = parseCommemorationBlock(block, engBlocks.getOrNull(i), ind, winner)
            if (d != null) out += d
        }
        return out
    }

    /** DO getrefs "@File:Oratio": the commemoration of that office built
     *  from its file and commune (antiphon, versicle, collect). */
    private fun refCommemoration(file: String, ind: Int, o: Office): Map<String, Hour.Part>? {
        val rite = o.rite
        val key = communeRef(file)
        val w = officeFromKey(key, o.date, rite, dayName = o.dayName)
        var c: Src? = null
        val rp = w.rankLine.split(";;").map { it.trim() }
        Regex("(ex|vide)\\s+(.*?)\\s*$", RegexOption.IGNORE_CASE).find(rp.getOrNull(3) ?: "")?.let { m ->
            var f = m.groupValues[2].trim()
            if (Regex("^C[1-3]a?$").containsMatchIn(f) && o.dayName.startsWith("Pasc")) f += "p"
            var src = srcFor(communeRef(f), rite)
            val chain = riteRules(rite)[f]?.rankLine?.let { Regex(";;(ex|vide)\\s+(.*?)\\s*$", RegexOption.IGNORE_CASE).find(it) }
            if (src != null && chain != null) {
                var f2 = chain.groupValues[2].trim()
                if (Regex("^C[1-3]a?$").containsMatchIn(f2) && o.dayName.startsWith("Pasc")) f2 += "p"
                srcFor(communeRef(f2), rite)?.let { s2 ->
                    val keep = setOf("Oratio", "Ant 1", "Ant 2", "Ant 3", "Versum 1", "Versum 2", "Versum 3")
                    src = Src(s2.parts.filterKeys { it in keep } + src!!.parts, true, src!!.psalmi)
                }
            }
            c = src
        }
        val a = antSec(w.proper, "Ant $ind") ?: c?.let { antSec(it, "Ant $ind") }
        var v = w.proper.sec("Versum $ind") ?: c?.sec("Versum $ind")
        if (v == null && w.temporal) {
            val name = tempora("getfrompsalterium major", o, o.date.dayOfWeek.value % 7, rite) + " Versum"
            v = psalt("$name $ind") ?: psalt("$name 1") ?: psalt("$name 3") ?: psalt("$name 2")
        }
        val or = (w.proper.sec("Oratio") ?: c?.sec("Oratio"))?.let { withName(it, w.proper) } ?: return null
        val out = HashMap<String, Hour.Part>()
        out["name"] = Hour.Part(type = "rubric", lat = rp.getOrNull(0) ?: w.name)
        a?.let { out["ant_$ind"] = withName(it.copy(type = "antiphon", lat = lines(it).firstOrNull(), eng = engLines(it).firstOrNull(), variationKey = null), w.proper) }
        v?.let { out["versum_$ind"] = vrFrom(it, "versum_$ind") }
        out["oratio"] = or.copy(type = "collect", label = "Oratio", variationKey = "oratio")
        return out
    }

    /** "!Title / Ant. … / _ / V. … / R. … / _ / \$Oremus / collect". */
    private fun parseCommemorationBlock(lat: String, eng: String?, ind: Int, o: Office): Map<String, Hour.Part>? {
        val ll = lat.split("\n").map { it.trim() }.filter { it.isNotEmpty() }
        val el = (eng ?: "").split("\n").map { it.trim() }.filter { it.isNotEmpty() }
        val title = ll.firstOrNull { it.startsWith("!") }?.removePrefix("!")?.trim() ?: ""
        ll.firstOrNull { Regex("^@[^:]+:Oratio").containsMatchIn(it) }?.let { ref ->
            val file = ref.substringAfter("@").substringBefore(":")
            val d = refCommemoration(file, ind, o) ?: return null
            val m = HashMap(d)
            if (title.isNotEmpty()) m["name"] = Hour.Part(type = "rubric", lat = title.removePrefix("Commemoratio").trim())
            return m
        }
        // DO getrefs "@File:Octava": the octave's own commemoration block
        // ([Octava], else [Octava N] by the Vespers, else the other one).
        ll.firstOrNull { Regex("^@[^:]+:Octava", RegexOption.IGNORE_CASE).containsMatchIn(it) }?.let { ref ->
            val file = ref.substringAfter("@").substringBefore(":")
            val src = srcFor(communeRef(file), o.rite) ?: return null
            val sec = src.sec("Octava") ?: src.sec("Octava $ind") ?: src.sec("Octava ${if (ind == 2) 1 else 2}") ?: return null
            val d = parseCommemorationBlock(sec.lat ?: "", sec.eng, ind, o) ?: return null
            val m = HashMap(d)
            if (title.isNotEmpty()) m["name"] = Hour.Part(type = "rubric", lat = title.removePrefix("Commemoratio").trim())
            return m
        }
        val ant = ll.firstOrNull { it.startsWith("Ant.") }?.removePrefix("Ant.")?.trim()
        val antE = el.firstOrNull { it.startsWith("Ant.") }?.removePrefix("Ant.")?.trim()
        val v = ll.firstOrNull { it.startsWith("V.") || it.startsWith("℣.") }?.let { "℣. " + it.drop(2).trim() }
        val r = ll.firstOrNull { it.startsWith("R.") || it.startsWith("℟.") }?.let { "℟. " + it.drop(2).trim() }
        val vE = el.firstOrNull { it.startsWith("V.") || it.startsWith("℣.") }?.let { "℣. " + it.drop(2).trim() }
        val rE = el.firstOrNull { it.startsWith("R.") || it.startsWith("℟.") }?.let { "℟. " + it.drop(2).trim() }
        fun collect(lines: List<String>): String {
            val i = lines.indexOfFirst { it.startsWith("\$Oremus") }
            return lines.drop(if (i >= 0) i + 1 else 0).filter { !it.startsWith("$") && !it.startsWith("!") && !it.startsWith("_") && !it.startsWith("Ant.") && !it.startsWith("V.") && !it.startsWith("R.") }
                .joinToString("\n") { it.removePrefix("v. ") }
        }
        val oratio = collect(ll)
        if (oratio.isBlank()) return null
        val paschal = alleluiaRequired(o.dayName)
        val out = HashMap<String, Hour.Part>()
        out["name"] = Hour.Part(type = "rubric", lat = title.removePrefix("Commemoratio").trim())
        if (ant != null) out["ant_$ind"] = withInlineAlleluia(withName(Hour.Part(type = "antiphon", lat = ant, eng = antE), o.proper), paschal)
        if (v != null) out["versum_$ind"] = withInlineAlleluia(Hour.Part(type = "vr", label = "Versicle", lat = v, latR = r, eng = vE, engR = rE, variationKey = "versum_$ind"), paschal)
        out["oratio"] = withInlineAlleluia(withName(Hour.Part(type = "collect", label = "Oratio", lat = oratio, eng = collect(el).ifBlank { null }, variationKey = "oratio"), o.proper), paschal)
        return out
    }

    /** An office known only by its DO key (a commemoration). */
    fun officeFromKey(key: String, date: LocalDate, rite: MissalRite, tomorrow: Boolean = false, dayName: String = ""): Office {
        val rr = riteRules(rite)
        val k = key.substringAfter(':')
        val rule = rr[k] ?: rr[k.take(5)]
        // DO officestring: a Pent/Epi office (not Pent01-05) takes the
        // scripture-cycle file of the date (the following day's at I Vespers).
        val md = if (Regex("^tempora:(pent|epi)").containsMatchIn(key) && !Regex("^tempora:pent0[1-5]").containsMatchIn(key))
            ordoFor(rite, date)?.let { if (tomorrow) it.m1 else it.m0 } else null
        // The scripture-cycle file carries the day's rank too (an Ember day).
        val mdRule = md?.let { rr[it.substringAfter(':')] }
        return officeFrom(DoOffice(w = key, r = mdRule?.rank ?: rule?.rank ?: 0.0, d = dayName, n = mdRule?.rankLine ?: rule?.rankLine ?: "",
            c = rule?.commune, t = rule?.communeType, md = md), if (tomorrow) date.plusDays(1) else date, rite)
    }

    /** DO's Lauds scheme: 2 (Ps 50) on penitential ferias, else 1. */
    private fun laudesScheme(o: Office, dow: Int, rite: MissalRite): Int {
        o.laudesDO?.let { return it }
        val dn = o.dayName
        val penitential = ((dn.startsWith("Adv") && dow != 0) || dn.startsWith("Quad") ||
            (emberDay(o, dow) && !dn.startsWith("Pasc"))) && o.temporal && !o.rankHas("(Beatæ|Sanctæ) Mariæ")
        return if (penitential || o.ruleHas("Laudes 2") ||
            (o.rankHas("vigil") && !is1955or1960(rite) && !o.ruleHas("Psalmi Dominica"))) 2 else 1
    }

    class Concurrence(val office: Office, val vespera: Int, val commemoration: Office?, val commemorationVespera: Int)

    /** DO concurrence (1960 rules, with the older branches where they
     *  differ): whether Vespers is of the following office. */
    fun concurrence(today: Office, tomorrow: Office?, dow: Int, rite: MissalRite): Concurrence {
        if (tomorrow == null) return Concurrence(today, 3, null, 0)
        val crank = tomorrow.rank
        val rank = today.rank
        val cw = tomorrow
        val noFirst = cw.ruleHas("No prima vespera") ||
            (rite == MissalRite.RITE_1955 && crank < 5) ||
            (is1960(rite) && crank < (if (cw.isSunday || (cw.ruleHas("Festum Domini") && dow == 6)) 5.0 else 6.0)) ||
            (cw.rankHas("Feria|Sabbato|Vigilia|Quat[t]*uor") && !cw.rankHas("in Vigilia Epi|in octava|infra octavam|Dominica|C10")) ||
            (cw.rankHas("infra octavam|Vigilia Pent") && !cw.rankHas("Dominica") &&
                today.rankHas("infra octavam|post Octavam Asc|Quat.*Pent|Dominica (Resurrectionis|Pentecostes)")) ||
            ((today.dayName.startsWith("Pasc0") || today.dayName.startsWith("Pasc7")) && !cw.isSunday) ||
            (cw.isC10 && today.rankHas("C1[01]")) ||
            (is1955or1960(rite) && cw.rankHas("Dominica Resurrectionis|Patrocinii S. Joseph")) ||
            (is1955or1960(rite) && cw.rankHas("octav") && !cw.rankHas("dominica|cum Octava") && crank < 6)
        if (noFirst) return Concurrence(today, 3, null, 0)
        if (today.temporal && tomorrow.temporal && !cw.isC10) {
            return if (crank >= rank || today.ruleHas("No secunda vespera")) Concurrence(tomorrow, 1, null, 0)
            else Concurrence(today, 3, null, 0)
        }
        val precTodayWins = (rank >= (if (is1955or1960(rite) && dow < 6) 6.0 else 7.0) && crank < 6) ||
            (is1960(rite) && cw.isSunday && !today.dayName.startsWith("Nat1") && crank <= 5 && rank >= 5 && today.ruleHas("Festum Domini")) ||
            (rank >= 5 && !today.rankHas("feria|in.*octava") && crank < 2.1)
        if (precTodayWins) return Concurrence(today, 3, null, 0)
        val privileged = rank == 1.15 || rank == 2.1 || rank == 2.99 || rank == 3.9
        val tomorrowWins = (rank < 2 && !(rank == 1.15 && today.temporal)) ||
            (is1960(rite) && (cw.isSunday || cw.ruleHas("Festum Domini")) &&
                (rank < (if (crank >= 6) 6.0 else 5.0) || today.isSunday || today.ruleHas("Festum Domini"))) ||
            (crank >= 6 && !(privileged || rank >= 4.2) && !cw.rankHas("Dominica|feria|in.*octava")) ||
            (cw.key == "12-25" || cw.key == "01-01") ||
            (crank >= 5 && !(rank == 1.15 || rank == 2.1 || rank >= 2.99) && !cw.rankHas("Dominica|feria|in.*octava"))
        if (tomorrowWins) {
            val commem = if (privileged && cw.key != "12-25" && cw.key != "01-01") today else null
            return Concurrence(tomorrow, 1, commem, 3)
        }
        if (is1960(rite) && rank >= crank) return Concurrence(today, 3, tomorrow, 1)
        if (crank > rank) return Concurrence(tomorrow, 1, today, 3)
        return Concurrence(today, 3, tomorrow, 1)
    }

    // ------------------------------------------------------------ resolve

    fun resolve(
        hourSlug: String,
        date: LocalDate,
        dow: Int,
        ordo: OrdoEntry?,
        tomorrow: OrdoEntry?,
        rite: MissalRite,
    ): Resolution? {
        riteCtx.set(rite)
        val doDay = ordoFor(rite, date)
        if (ordo == null && doDay?.l == null) return null
        val today = doDay?.l?.let { officeFrom(it, date, rite) } ?: officeFor(ordo!!, date, rite)
        var office = today
        var vespera = 3
        var commem: Office? = null
        var commemVespera = 0
        if (hourSlug == "vesperae" || hourSlug == "completorium") {
            val dv = doDay?.v
            if (dv != null) {
                vespera = dv.vs
                office = officeFrom(dv, if (vespera == 1) date.plusDays(1) else date, rite)
                dv.cv?.let { commem = officeFromKey(it, if (vespera == 1) date else date.plusDays(1), rite) }
                commemVespera = if (vespera == 1) 3 else 1
            } else {
                val tom = tomorrow?.let { officeFor(it, date.plusDays(1), rite) }
                val c = concurrence(today, tom, dow, rite)
                office = c.office
                vespera = c.vespera
                commem = c.commemoration
                commemVespera = c.commemorationVespera
            }
        }
        val o = office
        val laudes = laudesScheme(today, dow, rite)
        val out = LinkedHashMap<String, Hour.Part>()
        val drop = HashSet<String>()
        var nocturns = 1
        var lessons = 3
        var teDeum = false

        when (hourSlug) {
            "laudes", "vesperae" -> psalmiMajor(hourSlug, o, dow, laudes, vespera, rite, out)
            "prima", "tertia", "sexta", "nona", "completorium" -> psalmiMinor(hourSlug, o, dow, laudes, rite, out, drop)
            "matutinum" -> {
                val r = psalmiMatutinum(o, dow, laudes, rite, out, drop)
                nocturns = r.first; lessons = r.second
                teDeum = teDeumRequired(o, dow, lessons, rite)
            }
        }
        if (hourSlug in listOf("laudes", "vesperae")) {
            capitulumMajor(hourSlug, o, dow, vespera, rite, out)
            hymnusMajor(hourSlug, o, dow, vespera, rite, out)
            versumMajor(hourSlug, o, dow, vespera, rite, out)
            canticleAntiphon(hourSlug, o, dow, vespera, rite, out, date)
        }
        if (hourSlug in listOf("tertia", "sexta", "nona")) {
            capitulumMinor(hourSlug, o, dow, rite, out)
            hymnusMinor(hourSlug, o, out)
        }
        if (hourSlug == "prima") primaPieces(o, dow, rite, out)
        if (hourSlug == "completorium") complinePieces(o, dow, vespera, rite, out)
        if (hourSlug == "matutinum") {
            invitatorium(o, dow, rite, out)
            hymnusMatutinum(o, dow, rite, out)
        }
        // "Omit ... Hymnus" (the Easter and Pentecost octaves, the Triduum).
        if (o.ruleHas("Omit ad Matutinum[^\n]*Hymnus")) {
            out.remove("hymnus_matutinum"); drop += "hymnus_matutinum"
        } else if (o.ruleHas("Omit(?! ad )[^\n]*Hymnus")) {
            for (k in listOf("hymnus_matutinum", "hymnus_laudes", "hymnus_vespera", "prima.hymn", "tertia.hymn", "sexta.hymn", "nona.hymn", "completorium.hymn")) {
                out.remove(k); drop += k
            }
        }
        if (hourSlug == "matutinum" && (o.ruleHas("Omit ad Matutinum[^\n]*Invitatorium") || o.ruleHas("Omit(?! ad )[^\n]*Invitatorium"))) {
            out.remove("invit"); drop += "invit"
        }
        // "Omit ... Capitulum" (the Triduum): no capitulum, responsory or versicle.
        if (o.ruleHas("Omit(?! ad )[^\n]*Capitulum")) {
            for (k in listOf("capitulum_laudes", "vesperae.capitulum", "tertia.capitulum", "capitulum_sexta", "capitulum_nona", "prima.capitulum",
                "completorium.capitulum", "responsory_breve_tertia", "responsory_breve_sexta", "responsory_breve_nona", "prima.responsory",
                "completorium.responsory", "versum_1", "versum_2", "versum_tertia", "versum_sexta", "versum_nona", "versum_prima")) {
                out.remove(k); drop += k
            }
        }
        // "Capitulum Versum 2": the proper's Versum 2 ("Hæc dies") stands in
        // place of the capitulum, and the short responsory and versicle go.
        val cv2 = Regex("Capitulum Versum 2( ad Laudes tantum| ad Laudes et Vesperas)?", RegexOption.IGNORE_CASE).find(o.rule)
        val cv2Applies = cv2 != null && hourSlug != "matutinum" && when (cv2.groupValues[1].trim().lowercase()) {
            "ad laudes tantum" -> hourSlug == "laudes"
            "ad laudes et vesperas" -> hourSlug == "laudes" || hourSlug == "vesperae"
            else -> true
        }
        if (cv2Applies && hourSlug == "completorium") {
            // DO: at Compline the capitulum (with its short responsory and
            // versicle) is simply omitted; the verse comes with the canticle.
            if (out["completorium.capitulum"]?.label != "In loco Capituli") { out.remove("completorium.capitulum"); drop += "completorium.capitulum" }
            for (k in listOf("completorium.responsory", "versum_completorium")) { out.remove(k); drop += k }
        } else if (cv2Applies) {
            val v2 = proprium(o, "Versum 2", true)
            val capKey = when (hourSlug) {
                "laudes" -> "capitulum_laudes"; "vesperae" -> "vesperae.capitulum"; "tertia" -> "tertia.capitulum"
                "sexta" -> "capitulum_sexta"; "nona" -> "capitulum_nona"; "prima" -> "prima.capitulum"
                else -> "completorium.capitulum"
            }
            drop.remove(capKey)
            if (v2 != null) {
                if (v2.latR != null || lines(v2).firstOrNull()?.startsWith("℣") == true) {
                    out[capKey] = vrFrom(v2, capKey).copy(label = "In loco Capituli")
                } else {
                    val text = lines(v2).joinToString("\n").removePrefix("Ant. ")
                    val eng = engLines(v2).joinToString("\n").removePrefix("Ant. ")
                    out[capKey] = Hour.Part(type = "antiphon", label = "In loco Capituli", lat = text, eng = eng.ifBlank { null }, variationKey = capKey)
                }
            }
            for (k in listOf("responsory_breve_$hourSlug", "versum_$hourSlug", "prima.responsory", "versum_prima",
                "completorium.responsory", "versum_1", "versum_2").filter { it.startsWith("versum_") && (hourSlug == "laudes" && it == "versum_1" || hourSlug == "vesperae" && it == "versum_2" || it == "versum_$hourSlug") ||
                it == "responsory_breve_$hourSlug" || (hourSlug == "prima" && it.startsWith("prima.") || hourSlug == "prima" && it == "versum_prima") || (hourSlug == "completorium" && it == "completorium.responsory") }) {
                out.remove(k); drop += k
            }
        }
        // The collect of the day, when the office carries its own.
        if (hourSlug in listOf("matutinum", "laudes", "tertia", "sexta", "nona", "vesperae")) {
            oratioOf(o, hourSlug, vespera, dow)?.let { c ->
                if (!c.lat.isNullOrBlank()) out["oratio"] = c.copy(type = "collect", label = "Oratio", variationKey = "oratio")
            }
        }
        // The Triduum's Prime: psalms, then "Christus factus est", the Pater
        // noster and the collect; no capitulum, chapter office or blessing.
        if (hourSlug == "prima" && o.ruleHas("Omit(?! ad )[^\n]*Capitulum") && o.ruleHas("Omit(?! ad )[^\n]*Martyrologium")) {
            for (k in listOf("prima2.heading", "prima2.martyrologium", "prima2.pretiosa", "prima2.sanctamaria", "prima2.deusinadjutorium",
                "prima2.pater", "prima2.respice", "prima2.oratio", "prima2.benedictio1", "lectio_prima", "prima2.tuautem",
                "prima2.adjutorium", "prima2.benedictio2", "versum_prima", "prima.hymn", "ant_prima")) {
                out.remove(k); drop += k
            }
            oratioOf(o, "prima", vespera, dow)?.let { c ->
                if (!c.lat.isNullOrBlank()) out["oratio_prima"] = c.copy(type = "collect", label = "Oratio", variationKey = "oratio_prima")
            }
        }
        // The office's name for its "N.", and the bracketed alleluias.
        val paschalNow = alleluiaRequired(o.dayName)
        for ((k, v) in out.entries.toList()) out[k] = withInlineAlleluia(withName(v, o.proper), paschalNow)
        // Septuagesima to Holy Saturday: every alleluia goes (DO suppress_alleluia).
        if (lentSuppressed(o, hourSlug, dow, vespera)) for ((k, v) in out.entries.toList()) out[k] = withoutAlleluia(v)
        // Paschaltide: the alleluias DO appends to versicles and short responsories.
        if (alleluiaRequired(o.dayName) && !o.ruleHas("C9|C12")) {
            for ((k, v) in out.entries.toList()) {
                if (k.startsWith("versum_") || k.startsWith("nocturn_")) out[k] = alleluiaVersicle(v)
                else if (k.startsWith("responsory_breve_") || k == "prima.responsory" || k == "completorium.responsory") out[k] = alleluiaResponsory(v)
            }
        }
        val precesOffice = if (hourSlug == "vesperae" || hourSlug == "completorium") o else today
        val pfAll = precesFeriales(precesOffice, dow, hourSlug, rite)
        // The 1955 and 1960 books keep the ferial preces at Lauds and Vespers only.
        val pf = pfAll && (rite == MissalRite.PRE_1955 || hourSlug == "laudes" || hourSlug == "vesperae")
        val pd = rite == MissalRite.PRE_1955 && (hourSlug == "prima" || hourSlug == "completorium") && precesDominicales(precesOffice, commem, rite)
        val precesParts = if (rite == MissalRite.PRE_1955) precesScript(o, hourSlug, pf, pd, dow) else null
        // The Vigil of Pentecost closes Paschaltide at None: Compline already takes the Salve Regina.
        val marian = if (hourSlug == "completorium" && today.dayName == "Pasc7" && dow == 6) "salve-regina" else null
        // DO's own commemoration list for the hour (already filtered by its rubrics).
        val cms = if (hourSlug == "vesperae" || hourSlug == "completorium") (doDay?.v?.cm ?: emptyList()) else today.commemorations
        val omitRe = if (hourSlug == "matutinum") "Omit (ad Matutinum )?[^\n]*" else "Omit(?! ad )[^\n]*"
        val omitIncipit = o.ruleHas("${omitRe}Incipit")
        val omitConclusion = o.ruleHas("${omitRe}Conclusion")
        var special = specialHour(o, hourSlug, vespera, dow)?.map { withInlineAlleluia(withName(it, o.proper), paschalNow) }
        // All Saints' evening in the older books: Compline of the Dead (DO "die Omnium Defunctorum").
        if (special == null && rite == MissalRite.PRE_1955 && hourSlug == "completorium" && date.monthValue == 11 && date.dayOfMonth == 1 && dow != 6) {
            propersFor(rite)["sancti:11-02"]?.parts?.get("Special Completorium")?.let { sec ->
                val dead = officeFromKey("sancti:11-02", date, rite)
                special = renderScript(sec, dead, hourSlug, dow)
            }
        }
        if (lentSuppressed(o, hourSlug, dow, vespera)) special = special?.map { withoutAlleluia(it) }
        val conclusio = if (special == null && o.ruleHas("Special Conclusio")) o.proper.sec("Conclusio")?.let { renderScript(it, o, hourSlug, dow) } else null
        val append = litania(o, hourSlug, date, rite, dow)
        // A psalm inside the collect script (the Triduum's Miserere) goes before it.
        val beforeCollect = ArrayList<Hour.Part>()
        for (ck in listOf("oratio", "oratio_prima")) {
            val c = out[ck] ?: continue
            val ls = (c.lat ?: "").split("\n")
            if (ls.none { it.startsWith("&psalm(") }) continue
            for (l in ls.filter { it.startsWith("&psalm(") }) {
                val n = l.substringAfter("(").substringBefore(")").substringBefore(",").trim().toIntOrNull() ?: continue
                beforeCollect += Hour.Part(type = "psalm", label = "Psalmus $n", ref = "Ps $n")
            }
            out[ck] = c.copy(lat = ls.filter { !it.startsWith("&psalm(") }.joinToString("\n"),
                eng = c.eng?.split("\n")?.filter { !it.startsWith("&psalm(") }?.joinToString("\n"))
        }
        val suffragium = suffragium(o, hourSlug, dow, rite, commem)
        return Resolution(out, drop, o, vespera, nocturns, lessons, teDeum, pf, pd, commem, commemVespera, laudes, marian, cms, doDay?.l != null,
            omitIncipit = omitIncipit, omitConclusion = omitConclusion, conclusio = conclusio, special = special, append = append,
            preces = precesParts, beforeConclusion = suffragium, beforeCollect = beforeCollect,
            marianAfterLauds = rite == MissalRite.PRE_1955 && hourSlug == "laudes" && special == null && append.isEmpty() && conclusio == null)
    }

    // ------------------------------------------------------------ DO scripts (Special hours, conclusions, the Litany)

    /** The "Special <Hour>" script of the office, if it carries one (All
     *  Souls' little hours and Compline, the Triduum's Compline, the Easter
     *  Vigil's Vespers). */
    private fun specialHour(o: Office, hourSlug: String, vespera: Int, dow: Int): List<Hour.Part>? {
        val h = when (hourSlug) {
            "prima" -> "Prima"; "tertia" -> "Tertia"; "sexta" -> "Sexta"; "nona" -> "Nona"
            "completorium" -> "Completorium"; "vesperae" -> "Vespera"; "laudes" -> "Laudes"; else -> return null
        }
        val sec = (if (hourSlug == "vesperae") o.proper.sec("Special Vespera $vespera") else null) ?: o.proper.sec("Special $h") ?: return null
        val parts = renderScript(sec, o, hourSlug, dow)
        return if (parts.isEmpty()) null else parts
    }

    /** DO checksuffragium + getsuffragium: the suffrage of all the saints
     *  after the collects at Lauds and Vespers (the Divino Afflatu books). */
    /** DO checksuffragium. */
    private fun suffragiumApplies(o: Office, commem: Office?): Boolean {
        val dn = o.dayName
        if (o.ruleHas("no suffragium") || dn.isEmpty()) return false
        if (Regex("Nat05|Quad6|Pasc[067]").containsMatchIn(dn)) return false
        if (Regex("Adv|Nat|Quad5").containsMatchIn(dn)) return false
        if (o.sanctoral && o.rank >= 3) return false
        if (o.temporal && o.duplex > 2) return false
        if (o.rankHas("octav") && !o.rankHas("post Octavam")) return false
        fun checkCommemoratio(w: Office): String = w.proper.sec("Commemoratio")?.lat?.ifBlank { null }
            ?: w.proper.sec("Commemoratio 1")?.lat?.ifBlank { null } ?: w.proper.sec("Commemoratio 2")?.lat?.ifBlank { null }
            ?: w.proper.sec("Commemoratio 3")?.lat ?: ""
        fun blocks(w: Office): Boolean = w.rank >= 3 || w.rankHas("in.*Octav") || checkCommemoratio(w).contains("octav", ignoreCase = true)
        val first = commem ?: o.commemoratioKey?.let { officeFromKey(it, o.date, o.rite) }
        if (first != null) {
            if (blocks(first)) return false
            for (ck in o.commemorations + o.commemorations1) if (blocks(officeFromKey(ck, o.date, o.rite))) return false
        }
        return true
    }

    private fun suffragium(o: Office, hourSlug: String, dow: Int, rite: MissalRite, commem: Office?): List<Hour.Part> {
        if (rite != MissalRite.PRE_1955 || (hourSlug != "laudes" && hourSlug != "vesperae")) return emptyList()
        if (!suffragiumApplies(o, commem)) return emptyList()
        val dn = o.dayName
        val bvm = o.isC10 || o.communeKey?.let { Regex("^C1[012]").containsMatchIn(it) } == true
        val sec = psalt(if (dn.startsWith("Pasc")) "Suffragium Paschale" else if (bvm) "Suffragium Divino1" else "Suffragium") ?: return emptyList()
        val parts = renderScript(sec, o, hourSlug, dow)
        return if (parts.isEmpty()) emptyList() else listOf(Hour.Part(type = "heading", label = "Suffragium")) + parts
    }

    /** The Litany of the Saints after Lauds (St Mark's day; the Rogation
     *  days in the older books), as DO appends it. */
    private fun litania(o: Office, hourSlug: String, date: LocalDate, rite: MissalRite, dow: Int): List<Hour.Part> {
        if (hourSlug != "laudes") return emptyList()
        val rr = riteRules(rite)
        val has = o.ruleHas("Laudes Litania") ||
            (rr["${o.dayName.lowercase()}-$dow"]?.rule?.contains("Laudes Litania", ignoreCase = true) == true) ||
            o.commemorations.any { rr[it.substringAfter(':')]?.rule?.contains("Laudes Litania", ignoreCase = true) == true } ||
            (o.mdKey?.let { propersFor(rite)[it]?.parts?.get("Rule")?.lat?.contains("Laudes Litania", ignoreCase = true) } == true)
        if (!has || !(date.monthValue == 4 || !is1960(rite))) return emptyList()
        val lit = psalt("Litania") ?: return emptyList()
        val out = ArrayList<Hour.Part>()
        psalt("Prayer Domine exaudi")?.let { out += vrPairs(it) }
        psalt("Prayer Benedicamus Domino")?.let { out += vrPairs(it) }
        out += renderScript(lit, o, hourSlug, dow).map { if (it.type == "psalm") it.copy(variationKey = "litania.psalm") else it }
        return out
    }

    private fun stripPrefix(l: String): String = l.replace(Regex("^(v\\.|r\\.|V\\.|R\\.|℣\\.|℟\\.)\\s*"), "").trim()

    /** "V. … / R. …" lines of a prayer as ℣/℟ parts. */
    private fun vrPairs(p: Hour.Part, label: String = "Versus"): List<Hour.Part> {
        val ll = lines(p).filter { !it.startsWith("/:") && !it.startsWith("&") && !it.startsWith("$") }
        val el = engLines(p).filter { !it.startsWith("/:") && !it.startsWith("&") && !it.startsWith("$") }
        val out = ArrayList<Hour.Part>()
        var i = 0
        var j = 0
        while (i < ll.size) {
            val v = ll[i]; i++
            val r = if (i < ll.size && Regex("^(R\\.|℟\\.)").containsMatchIn(ll[i])) ll[i++] else null
            val ve = el.getOrNull(j); if (ve != null) j++
            val re = if (r != null) el.getOrNull(j)?.also { j++ } else null
            out += Hour.Part(type = "vr", label = label, lat = "℣. " + stripPrefix(v), latR = r?.let { "℟. " + stripPrefix(it) },
                eng = ve?.let { "℣. " + stripPrefix(it) }, engR = re?.let { "℟. " + stripPrefix(it) })
        }
        return out
    }

    /** A "\$Name" prayer of a script: the psalterium's common prayer. */
    private fun prayerParts(name: String, o: Office, last: Hour.Part?): Pair<List<Hour.Part>, Boolean> {
        when (name) {
            "Oremus" -> return listOf(Hour.Part(type = "heading", label = "Orémus.")) to false
            "Amen" -> return emptyList<Hour.Part>() to false
        }
        if (name.startsWith("rubrica ")) return listOf(Hour.Part(type = "heading", label = name.removePrefix("rubrica ").trim())) to false
        val p = psalt("Prayer $name") ?: return emptyList<Hour.Part>() to false
        val ll = lines(p).filter { !it.startsWith("/:") && !it.startsWith("!") && !it.startsWith("&") && !it.startsWith("$") }
        if (ll.isEmpty()) return emptyList<Hour.Part>() to false
        if (ll.all { Regex("^(V\\.|R\\.|℣\\.|℟\\.)").containsMatchIn(it) }) return vrPairs(p) to false
        // A conclusion ("Per Dóminum …") joins the collect before it.
        if (name.startsWith("Per ") || name.startsWith("Qui ")) {
            if (last != null && last.type == "collect") {
                val lat = (last.lat ?: "") + "\n" + ll.joinToString("\n") { stripPrefix(it) }
                val eng = engLines(p).filter { !it.startsWith("/:") }.joinToString("\n") { stripPrefix(it) }
                return listOf(last.copy(lat = lat, eng = last.eng?.let { if (eng.isBlank()) it else it + "\n" + eng })) to true
            }
        }
        val label = when (name) {
            "Pater noster", "Pater noster Et", "pater secreto", "Pater totum secreto" -> "Pater noster"
            "Ave Maria" -> "Ave María"; "Credo" -> "Credo"; "Confiteor" -> "Confíteor"; "Misereatur" -> "Misereátur"; "Indulgentiam" -> "Indulgéntiam"
            else -> name
        }
        val lat = ll.joinToString("\n") { stripPrefix(it) }
        val eng = engLines(p).filter { !it.startsWith("/:") && !it.startsWith("!") }.joinToString("\n") { stripPrefix(it) }.ifBlank { null }
        return listOf(Hour.Part(type = "reading", label = label, lat = lat, eng = eng)) to false
    }

    /** A DO script (a "Special <Hour>" section, a Conclusio, the Litany)
     *  as parts: &psalm(N[,a,b]) psalms, \$Prayer common prayers, Ant./V./R.
     *  lines, "v." collect lines, &special('X') pieces, headings and rubrics. */
    private fun renderScript(sec: Hour.Part, o: Office, hourSlug: String, dow: Int, depth: Int = 0): List<Hour.Part> {
        if (depth > 3) return emptyList()
        val ll = (sec.lat ?: "").split("\n").map { it.trim() }
        val el = (sec.eng ?: "").split("\n").map { it.trim() }
        val engAnt = ArrayDeque(el.filter { it.startsWith("Ant.") })
        val engV = ArrayDeque(el.filter { Regex("^(V\\.|℣\\.)").containsMatchIn(it) })
        val engR = ArrayDeque(el.filter { Regex("^(R\\.|℟\\.)").containsMatchIn(it) })
        val engPrayer = ArrayDeque(el.filter { it.startsWith("v. ") })
        val engPlain = ArrayDeque(el.filter { it.isNotEmpty() && !Regex("^(Ant\\.|V\\.|R\\.|℣\\.|℟\\.|v\\.|r\\.|[#!\$&_(])").containsMatchIn(it) })
        val out = ArrayList<Hour.Part>()
        val plain = ArrayList<String>()
        fun flushPlain() {
            if (plain.isEmpty()) return
            val e = ArrayList<String>()
            repeat(plain.size) { engPlain.removeFirstOrNull()?.let { e += it } }
            out += Hour.Part(type = "reading", lat = plain.joinToString("\n"), eng = e.joinToString("\n").ifBlank { null })
            plain.clear()
        }
        var i = 0
        while (i < ll.size) {
            val l = ll[i]; i++
            if (l.isEmpty() || l == "_") { if (plain.isNotEmpty()) plain += ""; continue }
            if (!(l.isNotEmpty() && !Regex("^(Ant\\.|V\\.|R\\.|℣\\.|℟\\.|v\\.|r\\.|[#!\$&(])").containsMatchIn(l))) flushPlain()
            when {
                l.startsWith("#") || l.startsWith("!") -> out += Hour.Part(type = "heading", label = l.drop(1).trim())
                l.startsWith("$") -> {
                    val (ps, replaces) = prayerParts(l.drop(1).trim(), o, out.lastOrNull())
                    if (replaces) { out.removeAt(out.size - 1) }
                    out += ps
                }
                l.startsWith("&psalm(") -> {
                    val args = l.substringAfter("(").substringBefore(")").split(",").map { it.trim() }
                    val n = args[0].toIntOrNull() ?: continue
                    val range = if (args.size >= 3) ":${args[1]}-${args[2]}" else ""
                    out += if (n >= 210) Hour.Part(type = "canticle", label = "Canticum", ref = "Cant $n")
                    else Hour.Part(type = "psalm", label = "Psalmus $n" + (if (range.isNotEmpty()) " (${args[1]}-${args[2]})" else ""), ref = "Ps $n$range")
                }
                l.startsWith("&special(") -> {
                    val name = l.substringAfter("'").substringBefore("'")
                    if (name.startsWith("#")) {
                        out += Hour.Part(type = "heading", label = "Martyrológium", variationKey = "prima2.heading")
                        out += Hour.Part(type = "reading", label = "Martyrológium", variationKey = "prima2.martyrologium")
                    } else {
                        o.proper.sec(name)?.let { out += renderScript(it, o, hourSlug, dow, depth + 1) }
                    }
                }
                l.startsWith("&Dominus_vobiscum") -> psalt("Prayer Domine exaudi")?.let { out += vrPairs(it) }
                l.startsWith("&Gloria") -> psalt(if (o.ruleHas("Requiem gloria")) "Prayer Requiem" else "Prayer Gloria")?.let { out += vrPairs(it) }
                l.startsWith("&") || l.startsWith("(") -> {}
                l.startsWith("Ant.") -> out += Hour.Part(type = "antiphon", label = "Antíphona", lat = l.removePrefix("Ant.").trim(),
                    eng = engAnt.removeFirstOrNull()?.removePrefix("Ant.")?.trim())
                Regex("^(V\\.|℣\\.)").containsMatchIn(l) -> {
                    val r = if (i < ll.size && Regex("^(R\\.|℟\\.)").containsMatchIn(ll[i])) ll[i++] else null
                    out += Hour.Part(type = "vr", label = "Versus", lat = "℣. " + stripPrefix(l), latR = r?.let { "℟. " + stripPrefix(it) },
                        eng = engV.removeFirstOrNull()?.let { "℣. " + stripPrefix(it) }, engR = if (r != null) engR.removeFirstOrNull()?.let { "℟. " + stripPrefix(it) } else null)
                }
                Regex("^(R\\.|℟\\.)").containsMatchIn(l) -> out += Hour.Part(type = "vr", label = "Responsum", lat = "℟. " + stripPrefix(l), eng = engR.removeFirstOrNull()?.let { "℟. " + stripPrefix(it) })
                l.startsWith("r. N.") && out.lastOrNull()?.type == "collect" -> {
                    // the titular's name ("atque beáto N.") continues the collect
                    val last = out.removeAt(out.size - 1)
                    out += last.copy(lat = (last.lat ?: "") + " " + l.removePrefix("r.").trim())
                }
                l.startsWith("v. ") || l.startsWith("r. ") -> {
                    val prev = out.lastOrNull()
                    val isOratio = prev != null && prev.type == "heading" && (prev.label == "Orémus." || prev.label?.contains("altius") == true)
                    out += if (isOratio) Hour.Part(type = "collect", label = "Oratio", lat = stripPrefix(l), eng = engPrayer.removeFirstOrNull()?.let { stripPrefix(it) })
                    else Hour.Part(type = "reading", lat = stripPrefix(l), eng = engPrayer.removeFirstOrNull()?.let { stripPrefix(it) })
                }
                else -> plain += l
            }
        }
        flushPlain()
        return out
    }

    // ------------------------------------------------------------ Lauds / Vespers psalms

    private fun psalmiMajor(hour: String, o: Office, dow: Int, laudes: Int, vespera: Int, rite: MissalRite,
                            out: MutableMap<String, Hour.Part>) {
        val isLauds = hour == "laudes"
        val name = if (isLauds) "Laudes$laudes" else "Vespera"
        val base = psalmiLines("Day$dow $name") ?: return
        var antiphones: List<AntLine>? = null
        val day = o.date.dayOfMonth
        val month = o.date.monthValue
        if (isLauds && month == 12 && day in 17..23 && dow > 0) {
            antiphones = psalmiLines("Day$dow Laudes3")
        }
        var w: List<AntLine>? = null
        var fromCommune = false
        val secHora = if (isLauds) "Ant Laudes" else "Ant Vespera"
        // "A capitulo de sequenti": the preceding office's antiphons and psalms.
        if (!isLauds && o.anteCapitulum != null) w = expand(o.anteCapitulum)
        if (w == null && !isLauds && vespera == 3) {
            w = antList(o.proper, "Ant Vespera 3")
            if (w == null && !hasSection(o.proper, "Ant Vespera") && o.communeType == "ex") {
                w = antList(o.commune, "Ant Vespera 3"); fromCommune = w != null
            }
        }
        if (w == null) w = antList(o.proper, secHora)
        if (w == null && o.communeType == "ex") {
            w = antList(o.commune, secHora); fromCommune = w != null
        }
        if (w != null) antiphones = w
        val psalmiDominica = antiphones != null &&
            (o.ruleHas("Psalmi Dominica") || o.communeRuleAnyHas("Psalmi Dominica")) &&
            antiphones.firstOrNull()?.psalms.isNullOrEmpty() && !o.ruleHas("Psalmi Feria")
        val p = if (psalmiDominica) (psalmiLines("Day0 " + (if (isLauds) "Laudes1" else "Vespera")) ?: base) else base
        val slots = if (isLauds) listOf("$hour.psalm1", "$hour.psalm2", "$hour.psalm3", "$hour.canticle1", "$hour.psalm4")
        else (1..5).map { "$hour.psalm$it" }
        val result = ArrayList<AntLine>()
        for (i in 0 until 5) {
            val pl = p.getOrNull(i)
            val al = antiphones?.getOrNull(i)
            var psalms = al?.psalms?.takeIf { it.isNotEmpty() } ?: pl?.psalms ?: emptyList()
            val ant = if (antiphones != null) al?.ant else pl?.ant
            val antEng = if (antiphones != null) al?.antEng else pl?.antEng
            if (i == 4 && !isLauds && !o.ruleHas("no Psalm5")) {
                val re3 = Regex("Psalm5 ?Vespera3=(\\d+)", RegexOption.IGNORE_CASE)
                val re = Regex("Psalm5 ?Vespera=(\\d+)", RegexOption.IGNORE_CASE)
                val n = o.anteCapitulum5 ?: (if (vespera == 3) (re3.find(o.rule)?.groupValues?.get(1)
                    ?: (if (fromCommune) re3.find(o.communeRule)?.groupValues?.get(1) else null)) else null)
                    ?: re.find(o.rule)?.groupValues?.get(1)
                    ?: (if (fromCommune) re.find(o.communeRule)?.groupValues?.get(1) else null)
                if (n != null) psalms = listOf(n)
            }
            result += AntLine(ant, antEng, psalms)
        }
        // Paschaltide: the psalms under one "Alleluia" antiphon.
        if (alleluiaRequired(o.dayName) && (!hasSection(o.proper, secHora) || o.isC10) && o.communeType != "ex") {
            for (i in result.indices) {
                result[i] = if (i == 0) AntLine(alleluiaAnt, alleluiaAntEng, result[i].psalms) else AntLine(null, null, result[i].psalms)
            }
        }
        for (i in 0 until 5) {
            val l = result[i]
            if (l.psalms.isNullOrEmpty()) continue
            out[slots[i]] = psalmPart(slots[i], l.psalms, l.ant, l.antEng)
        }
    }

    // ------------------------------------------------------------ Little hours

    private val hourTitles = mapOf("prima" to "Prima", "tertia" to "Tertia", "sexta" to "Sexta", "nona" to "Nona", "completorium" to "Completorium")

    private fun psalmiMinor(hour: String, o: Office, dow: Int, laudes: Int, rite: MissalRite,
                            out: MutableMap<String, Hour.Part>, drop: MutableSet<String>) {
        val hora = hourTitles[hour] ?: return
        val list = psalmiRaw("Minor $hora") ?: return
        var i = dow
        val psalmiDominicaRule = o.ruleHas("Psalmi\\s*(minores)*\\s*Dominica") ||
            (o.communeRuleHas("Psalmi\\s*(minores)*\\s*Dominica") && !o.ruleHas("Psalmi\\s*(?:minores)*\\s*ex Psalterio"))
        if (psalmiDominicaRule) i = 0
        if (is1955or1960(rite) && (o.ruleHas("horas1960 feria") || (o.sanctoral && o.rank < 5) ||
                ((o.sanctoral || Regex("^Nat[23]").containsMatchIn(o.dayName)) && o.rank < 6 && hour != "completorium"))) {
            i = dow
        }
        if (hour == "completorium" && dow == 6 && o.isSunday && !o.dayName.startsWith("Nat")) i = 6
        var ant: String? = list[i].ant
        var antEng: String? = list[i].antEng
        var psalms = (list[i].psalms ?: emptyList()).toMutableList()
        if ((is1960(rite) && psalms.contains("117") && laudes == 2) || o.ruleHas("Prima=53")) {
            psalms = psalms.map { if (it == "117") "53" else it }.toMutableList()
        }
        if (hour == "completorium") {
            if (o.temporal && dow > 0 && o.isSunday && o.rank < 6) {
                // A Sunday office on a weekday keeps the ferial Compline.
            } else if ((o.ruleHas("Psalmi\\s*(minores)*\\s*Dominica") || o.communeRuleHas("Psalmi\\s*(minores)*\\s*Dominica")) &&
                (!is1960(rite) || o.rank >= 6)) {
                ant = list[0].ant; antEng = list[0].antEng; psalms = (list[0].psalms ?: emptyList()).toMutableList()
            }
            antSec(o.proper, "Ant Completorium")?.let { ant = it.lat; antEng = it.eng }
        }
        // Seasonal antiphons (temporal office, or Paschaltide).
        if (o.temporal || o.dayName.startsWith("Pasc")) {
            var ind = when (hour) { "prima" -> 0; "tertia" -> 1; "sexta" -> 2; "nona" -> 4; else -> -1 }
            var name = tempora("Psalmi minor", o, dow, rite)
            if (name == "Adv") {
                name = o.dayName
                val day = o.date.dayOfMonth
                if (day in 17..23 && dow > 0) name = "Adv4${dow + 1}"
            }
            if (name == "Pasch" && (!o.dayName.startsWith("Pasc7") || hour == "completorium")) ind = 0
            if (name.isNotEmpty() && ind >= 0) {
                psalmiRaw("Minor $name")?.getOrNull(ind)?.let { l ->
                    if (!l.ant.isNullOrBlank()) { ant = l.ant; antEng = l.antEng }
                }
            }
        }
        var feastflag = 0
        if (hour != "completorium") {
            var w: Hour.Part? = antSec(o.proper, "Ant $hora")
            if (w == null && !o.ruleHas("Psalmi\\s*(?:minores)*\\s*ex Psalterio") &&
                !(is1955or1960(rite) && o.rank < 6 && dow > 0)) {
                w = antHoras(o, hour, rite)
            }
            if (w != null) { ant = w.lat; antEng = w.eng }
            if ((o.ruleHas("Psalmi\\s*(?:minores)*\\s*Dominica") || o.communeRuleHas("Psalmi\\s*(?:minores)*\\s*Dominica")) &&
                !o.ruleHas("Psalmi\\s*(?:minores)*\\s*ex Psalterio") && !(is1955or1960(rite) && o.rank < 6 && dow > 0)) {
                feastflag = 1
            }
            if (is1955or1960(rite) && o.rank < 6) feastflag = 0
            if (o.isSunday && !Regex("Nat|Pasc6").containsMatchIn(o.dayName)) feastflag = 0
        }
        if (o.ruleHas("Minores sine Antiphona")) { ant = null; antEng = null }
        if (hour == "prima") {
            psalms = if (laudes != 2 || is1960(rite)) psalms.filter { !it.startsWith("[") }.toMutableList()
            else psalms.map { it.trim('[', ']') }.toMutableList()
            if (feastflag != 0 && psalms.isNotEmpty()) psalms[0] = "53"
            if (laudes == 2 && o.isSunday && !is1960(rite) && psalms.isNotEmpty()) {
                psalms[0] = "99"; psalms.add(0, "92")
            }
        }
        if (hour == "prima" && dow == 0 && !o.ruleHas("Non dicitur Quicumque") &&
            ((is1955or1960(rite) && o.dayName == "Pent01") ||
                (!is1955or1960(rite) && (Regex("^(Epi|Pent)").containsMatchIn(o.dayName)) &&
                    (Regex("^(Adv|Pent01|Pasc1)").containsMatchIn(o.dayName) || suffragiumApplies(o, null))))) {
            psalms.add("234")
        }
        val antKey = if (hour == "completorium") "completorium.antiphon" else "ant_$hour"
        out[antKey] = antPart(ant, antEng, antKey, "Antiphon")
        val maxSlots = if (hour == "prima") 4 else 3
        for (k in 1..maxSlots) {
            val vk = "$hour.psalm$k"
            val ref = psalms.getOrNull(k - 1)
            if (ref == null) { drop += vk; continue }
            out[vk] = psalmPart(vk, listOf(ref), null, null)
        }
        if (psalms.size > maxSlots) {
            val vk = "$hour.psalm$maxSlots"
            out[vk] = psalmPart(vk, psalms.drop(maxSlots - 1), null, null)
        }
    }

    /** DO getanthoras: the little-hours antiphons taken from the Lauds
     *  antiphons on feasts with "Antiphonas horas". */
    private fun antHoras(o: Office, hour: String, rite: MissalRite): Hour.Part? {
        if (!(o.ruleHas("Antiphonas horas") || o.communeRuleHas("Antiphonas horas"))) return null
        if (is1960(rite) && o.rank < 6) return null
        if (rite == MissalRite.RITE_1955 && o.rank < 6 && o.date.dayOfWeek.value % 7 > 0) return null
        var w = antList(o.proper, "Ant Laudes")
        if (w == null && o.communeType == "ex") w = antList(o.commune, "Ant Laudes")
        if (w == null || w.size <= 3) return null
        val ind = when (hour) { "prima" -> 0; "tertia" -> 1; "sexta" -> 2; else -> 4 }
        val l = w.getOrNull(ind) ?: return null
        return Hour.Part(type = "antiphon", lat = l.ant, eng = l.antEng)
    }

    // ------------------------------------------------------------ Matins psalms

    private fun psalmiMatutinum(o: Office, dow: Int, laudes: Int, rite: MissalRite,
                                out: MutableMap<String, Hour.Part>, drop: MutableSet<String>): Pair<Int, Int> {
        var lines: MutableList<AntLine> = (psalmiLines("Day$dow") ?: return 1 to 3).toMutableList()
        if (dow == 0 && o.dayName.startsWith("Adv")) psalmiLines("Adv 0 Ant Matutinum")?.let { lines = it.toMutableList() }
        if (laudes == 2 && dow == 3 && o.key != "12-24") psalmiLines("Day31")?.let { lines = it.toMutableList() }
        val name = tempora("Psalmi Matutinum", o, dow, rite)
        fun setVers(idx: Int, sec: String) {
            val v = vrLines(psalt(sec)) ?: return
            if (idx + 1 < lines.size) {
                lines[idx] = v.first
                lines[idx + 1] = v.second
            }
        }
        if (name.isNotEmpty() && (o.temporal || name == "Nat" || name == "Epi")) {
            if (dow == 0) {
                for (i in 1..3) setVers((i - 1) * 5 + 3, "$name $i Versum")
                if (is1960(rite) && lines.size > 14) { lines[13] = lines[3]; lines[14] = lines[4] }
            } else {
                var i = dow
                if (i > 3) i -= 3
                setVers(13, "$name $i Versum")
            }
        }
        // Proper antiphons (getantmatutinum).
        var w = antList(o.proper, "Ant Matutinum")
        if (w == null && o.communeType == "ex") w = antList(o.commune, "Ant Matutinum")
        val proper = w != null
        if (w != null) {
            if (w.size < 15) {
                // Intersperse the nocturn versicles (DO getantmatutinum): a
                // missing versicle adds nothing, so a 5-line proper keeps its
                // own ℣/℟ at lines 3-4.
                val res = ArrayList<AntLine>()
                val rest = w.toMutableList()
                for (n in 1..3) {
                    val ppN = minOf(3, rest.size)
                    repeat(ppN) { res += rest.removeAt(0) }
                    val v = vrLines(proprium(o, "Nocturn $n Versum", true))
                    if (v != null) { res += v.first; res += v.second }
                }
                lines = res
            } else lines = w.toMutableList()
        }
        if (Regex("^Pasc[1-6]").containsMatchIn(o.dayName) && !o.ruleHas("C9|C12")) {
            lines = antMatutinumPaschal(lines, o, dow, rite, proper).toMutableList()
        }
        val type1960 = type1960(o, rite)
        val nine = o.ruleHas("9 lectio") && type1960 == 0 && o.rank >= 2
        val nocturns: Int
        val lessons: Int
        val psalmIdx: List<Int>
        if (nine) {
            if (!hasSection(o.proper, "Ant Matutinum")) {
                if ((name == "Pasch" || name == "Asc") && o.rank < 5 && !o.rankHas("(?:in|post).*octava.*Ascensio")) {
                    val dname = if (o.isSunday) "Dominica" else "Feria"
                    psalmiLines("Pasch Ant $dname")?.let { spec ->
                        for (i in listOf(3, 4, 8, 9, 13, 14)) if (i < spec.size && i < lines.size) lines[i] = spec[i]
                    }
                } else if (o.temporal && name in listOf("Adv", "Quad", "Pasch")) {
                    for (i in 1..3) setVers((i - 1) * 5 + 3, "$name $i Versum")
                }
            }
            nocturns = 3; lessons = 9
            psalmIdx = listOf(0, 1, 2, 5, 6, 7, 10, 11, 12)
            for (n in 1..3) {
                val vi = (n - 1) * 5 + 3
                out["nocturn_${n}_versum"] = vrParts(lines.getOrNull(vi), lines.getOrNull(vi + 1), "nocturn_${n}_versum")
            }
        } else {
            nocturns = 1; lessons = 3
            val vn = dow2i(dow)
            var v: Pair<AntLine, AntLine>? = null
            if (Regex("^Pasc[1-6]").containsMatchIn(o.dayName) && !o.ruleHas("C9|C12")) {
                v = if (is1960(rite) && name == "Asc") vrLines(temporalPropers["pasc5-4"]?.get("nocturn_${vn}_versum"))
                else vrLines(psalt("Pasch $vn Versum"))
            }
            psalmIdx = if (lines.size > 9) listOf(0, 1, 2, 5, 6, 7, 10, 11, 12) else listOf(0, 1, 2)
            if (v == null) {
                val a = lines.getOrNull(13); val b = lines.getOrNull(14)
                if (a != null && b != null) v = a to b
            }
            if (o.date.monthValue == 12 && o.date.dayOfMonth == 24) vrLines(psalt("Nat24 Versum"))?.let { v = it }
            if (Regex("^Pasc[07]").containsMatchIn(o.dayName)) {
                val a = lines.getOrNull(3); val b = lines.getOrNull(4)
                if (a != null && b != null) v = a to b
            }
            out["nocturn_1_versum"] = vrParts(v?.first, v?.second, "nocturn_1_versum")
        }
        // "Ant Matutinum N special": one antiphon of the list replaced by the
        // proper's own (the Annunciation's ninth).
        Regex("Ant Matutinum (\\d+) special", RegexOption.IGNORE_CASE).find(o.rule)?.let { m ->
            var idx = m.groupValues[1].toInt()
            if (idx == 12 && o.dayName.startsWith("Pasc")) idx = 10
            val wa = o.proper.sec("Ant Matutinum ${m.groupValues[1]}")
            val old = lines.getOrNull(idx)
            if (wa != null && old != null) lines[idx] = AntLine(lines(wa).firstOrNull() ?: old.ant, engLines(wa).firstOrNull() ?: old.antEng, old.psalms)
        }
        for ((slot, li) in psalmIdx.withIndex()) {
            val vk = "matutinum.psalm${slot + 2}"
            val l = lines.getOrNull(li)
            if (l?.psalms.isNullOrEmpty()) { drop += vk; continue }
            out[vk] = psalmPart(vk, l!!.psalms!!, l.ant, l.antEng)
        }
        if (psalmIdx.size == 3) for (k in 5..10) drop += "matutinum.psalm$k"
        drop += listOf("ant_1", "ant_2", "ant_3")
        return nocturns to lessons
    }

    private fun antMatutinumPaschal(psalmi: List<AntLine>, o: Office, dow: Int, rite: MissalRite, proper: Boolean): List<AntLine> {
        val res = psalmi.toMutableList()
        if (dow != 0 || (o.dayName.startsWith("Pasc6") && is1960(rite))) {
            if (!proper || o.isC10) {
                for (i in res.indices) if (res[i].psalms != null) res[i] = AntLine(null, null, res[i].psalms)
                if (res.isNotEmpty()) res[0] = AntLine(alleluiaAnt, alleluiaAntEng, res[0].psalms)
                if (dow != 0 && o.ruleHas("9 lectio") && (!is1960(rite) || o.rank > 3) && o.rank >= 2) {
                    if (res.size > 5) res[5] = AntLine(alleluiaAnt, alleluiaAntEng, res[5].psalms)
                    if (res.size > 10) res[10] = AntLine(alleluiaAnt, alleluiaAntEng, res[10].psalms)
                }
            } else if (o.sanctoral) {
                for (i in 0..3) {
                    for (j in listOf(1, 2)) {
                        val idx = i * 5 + j
                        if (idx < res.size && res[idx].psalms != null) res[idx] = AntLine(null, null, res[idx].psalms)
                    }
                }
            }
        } else if (Regex("^Pasc[1-5]").containsMatchIn(o.dayName) && o.isSunday) {
            psalmiLines("Pasch0")?.let { a ->
                for (i in res.indices) if (i < a.size) res[i] = AntLine(a[i].ant, a[i].antEng, res[i].psalms)
            }
            if (is1960(rite)) for (i in 1 until res.size) if (res[i].psalms != null) res[i] = AntLine(null, null, res[i].psalms)
        }
        return res
    }

    /** DO gettype1960: 0 default, 1 ferial, 2 Sunday, 3 sanctoral, 4 octave II. */
    private fun type1960(o: Office, rite: MissalRite): Int {
        var type = 0
        if (is1960(rite) && !o.ruleHas("C9|Defunctorum")) {
            type = when {
                o.rankHas("post Nativitatem") -> 4
                o.rank < 2 || o.rankHas("(feria|vigilia|die)") -> 1
                (o.rankHas("dominica.*?semiduplex") || o.key == "pasc1-0") -> 2
                o.rank < 5 -> 3
                else -> 0
            }
        }
        if (o.ruleHas("9 lectiones 1960|12 lectiones")) type = 0
        return type
    }

    /** DO tedeum_required. */
    private fun teDeumRequired(o: Office, dow: Int, lessons: Int, rite: MissalRite): Boolean {
        val nine = o.ruleHas("9 lectiones")
        val last = (lessons == 9 && nine) || (lessons == 3 && (!nine || o.duplex == 1 || (is1955or1960(rite) && type1960(o, rite) != 0)))
        if (!last) return false
        if (o.ruleHas("no Te Deum") && !(o.key == "12-28" && dow == 0)) return false
        if (o.communeKey == "C9") return false
        if (o.temporal && Regex("^(Adv|Quad)").containsMatchIn(o.dayName)) return false
        return (dow == 0 && !o.rankHas("Vigilia")) ||
            (o.sanctoral && !o.rankHas("Vigilia")) ||
            o.ruleHas("Feria Te Deum") ||
            Regex("^(Pasc|Nat)").containsMatchIn(o.dayName) || o.isC10 ||
            (o.temporal && o.rank > 5 && dow != 0) ||
            (!is1955or1960(rite) && (o.key.matches(Regex("pent01-[56]")) || o.key.matches(Regex("pent02-[1-4]")))) ||
            (rite == MissalRite.PRE_1955 && (o.key == "pent02-6" || o.key.matches(Regex("pent03-[1-5]"))))
    }

    // ------------------------------------------------------------ capitula, hymns, versicles

    private fun capitulumMajor(hour: String, o: Office, dow: Int, vespera: Int, rite: MissalRite, out: MutableMap<String, Hour.Part>) {
        var name = "Capitulum Laudes"
        if (o.key == "12-25" && vespera == 1) name = "Capitulum Vespera 1"
        if (o.communeKey == "C12" && hour == "vesperae") name = "Capitulum Vespera"
        val vk = if (hour == "laudes") "capitulum_laudes" else "vesperae.capitulum"
        var capit = proprium(o, name, true)
        if (capit == null && name != "Capitulum Laudes") capit = proprium(o, "Capitulum Laudes", true)
        if (capit == null) {
            var t = tempora("Capitulum major", o, dow, rite)
            val h = if (hour == "laudes") "Laudes" else "Vespera"
            if ((t == "Asc" || t == "Pent") && psalt("$t $h") == null) t = "Pasch"
            if ((t == "Nat" || t == "Epi") && psalt("$t $h") == null) t = if (dow == 0) "Dominica" else "Feria"
            capit = if (hour == "vesperae" && dow == 6 && t == "Feria") psalt("Feria Vespera (feria 7)") ?: psalt("$t $h")
            else psalt("$t $h") ?: psalt("Feria $h")
        }
        capit?.let { out[vk] = rekey(it.copy(type = "capitulum"), vk, "Capitulum") }
    }

    private fun capitulumMinor(hour: String, o: Office, dow: Int, rite: MissalRite, out: MutableMap<String, Hour.Part>) {
        val hora = hourTitles[hour] ?: return
        var t = tempora("Capitulum minor", o, dow, rite)
        if ((t == "Asc" || t == "Pent") && psalt("$t $hora") == null) t = "Pasch"
        if ((t == "Nat" || t == "Epi") && psalt("$t $hora") == null) t = if (dow == 0 || (o.rankHas("Duplex") && !o.rankHas("Dominica|Vigilia"))) "Dominica" else "Feria"
        val vk = if (hour == "tertia") "tertia.capitulum" else "capitulum_$hour"
        var capit: Hour.Part? = psalt("$t $hora") ?: psalt("Feria $hora")
        val secName = if (hour == "tertia" && o.communeKey != "C12") "Capitulum Laudes" else "Capitulum $hora"
        proprium(o, secName, true)?.let { capit = it }
        capit?.let { out[vk] = rekey(it.copy(type = "capitulum"), vk, "Capitulum") }
        val rvk = "responsory_breve_$hour"
        val vvk = "versum_$hour"
        var resp: Hour.Part? = psalt("Responsory breve $t $hora") ?: psalt("Responsory breve Feria $hora")
        var vers: Hour.Part? = psalt("Versum $t $hora") ?: psalt("Versum Feria $hora")
        val wr = proprium(o, "Responsory Breve $hora", true)
        val wv = proprium(o, "Versum $hora", true)
        if (wr != null) resp = wr
        if (wv != null) vers = wv
        resp?.let { out[rvk] = rekey(it.copy(type = "responsory"), rvk, "Responsorium Breve") }
        vers?.let { out[vvk] = vrFrom(it, vvk).copy(label = "Versiculus") }
    }

    private fun hymnusMinor(hour: String, o: Office, out: MutableMap<String, Hour.Part>) {
        val hora = hourTitles[hour] ?: return
        var name = "Hymnus $hora"
        if (hour == "tertia" && o.dayName.startsWith("Pasc7")) name = "Hymnus Pasc7 Tertia"
        val vk = "$hour.hymn"
        (psalt(name) ?: psalt("Hymnus $hora"))?.let { out[vk] = rekey(it, vk) }
    }

    private fun checkmtv(o: Office, rite: MissalRite): String =
        if ((is1955or1960(rite) || o.ruleHas(";mtv")) && o.ruleHas("C[45]")) "1" else ""

    private fun hymnusMajor(hour: String, o: Office, dow: Int, vespera: Int, rite: MissalRite, out: MutableMap<String, Hour.Part>) {
        val hora = if (hour == "laudes") "Laudes" else "Vespera"
        val vk = if (hour == "laudes") "hymnus_laudes" else "hymnus_vespera"
        var name = "Hymnus"
        if (hour == "vesperae") name += checkmtv(o, rite)
        if (name != "Hymnus" && o.proper.sec("$name $hora") == null && o.proper.sec("Hymnus $hora") != null) name = "Hymnus"
        var hymn: Hour.Part? = null
        // DO hymnshift: Vespers hymn at Matins, Matins hymn at Lauds, Lauds hymn at Vespers;
        // hymnshiftmerge: Lauds takes the Matins hymn ending with the Lauds hymn.
        if (o.hymnShift == 2 && proprium(o, "$name $hora", true) != null) {
            hymn = proprium(o, if (hour == "laudes") "$name Matutinum" else "$name Laudes", true)
        } else if (o.hymnShift == 3 && hour == "laudes") {
            val hl = proprium(o, "$name Laudes", true)
            val hm = proprium(o, "$name Matutinum", true)
            if (hl != null && hm != null) {
                val stanzas = (hm.lat ?: "").split("\n\n")
                hymn = hm.copy(lat = (stanzas.dropLast(1) + (hl.lat ?: "").removePrefix("v. ")).joinToString("\n\n"),
                    eng = listOfNotNull(hm.eng, hl.eng).joinToString("\n\n").ifBlank { null })
            }
        }
        if (hymn == null && hour == "vesperae" && vespera == 3) hymn = proprium(o, "$name Vespera 3", true) ?: proprium(o, "Hymnus Vespera 3", true)
        if (hymn == null) hymn = proprium(o, "$name $hora", true)
        if (hymn == null && name != "Hymnus") hymn = proprium(o, "Hymnus $hora", true)
        if (hymn == null) {
            val t = tempora("Hymnus major", o, dow, rite)
            var key = "Hymnus $t $hora"
            if (t == "Day0" && hour == "laudes" &&
                (Regex("^Epi[2-6]").containsMatchIn(o.dayName) || o.dayName.startsWith("Quadp") ||
                    o.rankHas("Novembris|Octobris") || (o.date.monthValue in listOf(10, 11) && o.temporal && dow == 0))) {
                key += " hiemalis"
            }
            if ((t == "Asc" || t == "Pent" || t == "Nat" || t == "Epi") && psalt(key) == null) {
                key = "Hymnus " + (if (t == "Asc" || t == "Pent") "Pasch" else "Day$dow") + " $hora"
            }
            hymn = psalt(key) ?: psalt("Hymnus Day$dow $hora")
        }
        hymn?.let { out[vk] = rekey(it.copy(type = "hymn"), vk, "Hymn") }
    }

    private fun versumMajor(hour: String, o: Office, dow: Int, vespera: Int, rite: MissalRite, out: MutableMap<String, Hour.Part>) {
        val ind = if (hour == "laudes") 2 else vespera
        val vk = if (hour == "laudes") "versum_1" else "versum_2"
        var w = proprium(o, "Versum $ind", true)
        if (w == null && ind > 1) w = proprium(o, "Versum ${4 - ind}", true)
        if (w == null) {
            var t = tempora("getfrompsalterium major", o, dow, rite)
            if ((t == "Asc" || t == "Pent") && psalt("$t Versum $ind") == null) t = "Pasch"
            if (t == "Nat" || t == "Epi") t = if (dow == 0) "Dominica" else "Feria"
            w = if (hour == "vesperae" && dow == 6 && t == "Feria") psalt("Feria Versum 3 (feria 7)") else null
            if (w == null) w = psalt("$t Versum $ind") ?: psalt("$t Versum 1") ?: psalt("$t Versum 3") ?: psalt("$t Versum 2")
        }
        w?.let { out[vk] = vrFrom(it, vk).copy(label = "Versicle") }
    }

    private fun canticleAntiphon(hour: String, o: Office, dow: Int, vespera: Int, rite: MissalRite, out: MutableMap<String, Hour.Part>, today: LocalDate = o.date) {
        val ind = if (hour == "laudes") 2 else vespera
        val vk = if (hour == "laudes") "ant_laudes" else "ant_vespera"
        val label = if (hour == "laudes") "Antiphon ad Benedictus" else "Antiphon ad Magnificat"
        var w = proprium(o, "Ant $ind", true)
        if (w == null && ind > 1) w = proprium(o, "Ant ${4 - ind}", true)
        // The O antiphons (DO ant123_special): Vespers Dec 17-23, and the
        // Lauds of Dec 21 and 23, when the office is of the season.
        if (o.temporal && today.monthValue == 12 && today.dayOfMonth in 17..23) {
            if (hour == "laudes" && (today.dayOfMonth == 21 || today.dayOfMonth == 23)) psalt("Adv Ant ${today.dayOfMonth}L")?.let { w = it }
            else if (hour == "vesperae") psalt("Adv Ant ${today.dayOfMonth}")?.let { w = it }
        }
        if (w == null) {
            var t = tempora("getfrompsalterium major", o, dow, rite)
            if (t != "Dominica") t = if (dow == 0) "Dominica" else "Feria"
            if (t == "Feria") {
                val fk = if (hour == "vesperae" && dow == 6) "Feria Ant $ind (feria 7)" else "Feria${dow + 1} Ant $ind"
                w = psalt(fk) ?: psalt("Feria${dow + 1} Ant $ind") ?: psalt("Feria${dow + 1} Ant ${4 - ind}")
            }
        }
        if (w != null && lines(w).size == 1) out[vk] = antPart(lines(w)[0], engLines(w).firstOrNull(), vk, label)
    }

    private fun primaPieces(o: Office, dow: Int, rite: MissalRite, out: MutableMap<String, Hour.Part>) {
        // DO capitulum_prima: "Regi sæculórum" on every day under the 1960
        // rubrics; the ferial "Pacem et veritátem" only in the older books.
        val feriaKey = dow > 0 && !is1960(rite) && o.rankHas("Feria|Vigilia") && !o.rankHas("Vigilia Epi") &&
            !o.isC10 && (o.rank < 3 || o.dayName.startsWith("Quad6") || o.key == "quadp3-3") && !o.dayName.startsWith("Pasc")
        val cap = psalt(if (feriaKey) "Prima Feria" else "Prima Dominica")
        cap?.let { out["prima.capitulum"] = rekey(it, "prima.capitulum", "Capitulum") }
        // Responsory: the ℣ changes with the season.
        var tr = tempora("Prima responsory", o, dow, rite)
        Regex("Doxology=(Nat|Epi|Pasch|Asc|Corp|Heart)", RegexOption.IGNORE_CASE).find(o.rule)?.let { tr = it.groupValues[1] }
        if (!is1960(rite) && o.date.monthValue == 8 && o.date.dayOfMonth in 16..22) tr = "Nat"
        if (is1960(rite) && o.date.monthValue == 12 && o.date.dayOfMonth in 9..15 && o.date.dayOfMonth != 12) tr = "Adv"
        if (is1960(rite) && (tr == "Corp" || tr == "Heart")) tr = ""
        val base = psalt("Prima Responsory")
        if (base != null) {
            var lat = base.lat ?: ""
            var eng = base.eng
            val variant = if (tr.isNotEmpty()) psalt("Prima Responsory $tr") else null
            if (variant != null) {
                lat = lat.replace(Regex("℣\\. [^\n]*"), "℣. " + (variant.lat ?: ""))
                if (eng != null && variant.eng != null) eng = eng.replace(Regex("℣\\. [^\n]*"), "℣. " + variant.eng)
            }
            out["prima.responsory"] = base.copy(lat = lat, eng = eng, variationKey = "prima.responsory", label = "Responsorium Breve")
        }
        psalt("Prima Versum")?.let { out["versum_prima"] = vrFrom(it, "versum_prima").copy(label = "Versiculus") }
        psalt("Prima Hymnus Prima")?.let { out["prima.hymn"] = rekey(it, "prima.hymn") }
        // Lectio brevis: seasonal / per annum; the proper's own only in the older books.
        var brevis: Hour.Part? = psalt("Prima " + tempora("Lectio brevis Prima", o, dow, rite))
        if (!is1955or1960(rite)) proprium(o, "Lectio Prima", true)?.let { brevis = it }
        brevis?.let { out["lectio_prima"] = it.copy(type = "reading", label = "Lectio brevis", variationKey = "lectio_prima") }
    }

    private fun complinePieces(o: Office, dow: Int, vespera: Int, rite: MissalRite, out: MutableMap<String, Hour.Part>) {
        psalt("Hymnus Completorium")?.let { out["completorium.hymn"] = rekey(it, "completorium.hymn") }
        psalt("Completorium")?.let { out["completorium.capitulum"] = rekey(it, "completorium.capitulum", "Capitulum") }
        psalt("Responsory Completorium")?.let { out["completorium.responsory"] = rekey(it, "completorium.responsory", "Responsorium Breve") }
        val a4 = if (o.ruleHas("Minores sine Antiphona") && o.dayName.startsWith("Quad6")) Hour.Part(type = "antiphon", lat = "", eng = "")
        else proprium(o, "Ant 4$vespera", false) ?: proprium(o, "Ant 4", false) ?: psalt("Ant 4")
        a4?.let { a ->
            // Antiphon only: the assembler merges it onto the canticle. A
            // second line (Easter week's "Hæc dies") stands in place of the
            // capitulum, hymn and versicle (DO prints it after the canticle).
            val al = lines(a); val ae = engLines(a)
            out["completorium.canticle"] = Hour.Part(type = "canticle", variationKey = "completorium.canticle",
                antiphonLat = al.firstOrNull() ?: a.lat, antiphonEng = ae.firstOrNull() ?: a.eng)
            if (al.size > 1) {
                out["completorium.capitulum"] = Hour.Part(type = "antiphon", label = "In loco Capituli", lat = al[1].removePrefix("Ant. "),
                    eng = ae.getOrNull(1)?.removePrefix("Ant. "), variationKey = "completorium.capitulum")
            }
        }
    }

    private fun invitatorium(o: Office, dow: Int, rite: MissalRite, out: MutableMap<String, Hour.Part>) {
        val name = tempora("Invitatorium", o, dow, rite)
        var ant: Hour.Part? = null
        if (name.isNotEmpty()) ant = psalt("Invit $name")
        if (ant == null) {
            val names = listOf("Dominica", "Feria II", "Feria III", "Feria IV", "Feria V", "Feria VI", "Sabbato")
            var n = names[dow]
            val m = o.date.monthValue
            if (dow == 0 && (m < 4 || m in listOf(10, 11))) n = "Invit 1"
            ant = psalt("Invit $n") ?: psalt("Invit Dominica")
        }
        proprium(o, "Invit", true)?.let { ant = it }
        ant?.let { out["invit"] = antPart(it.lat, it.eng, "invit", "Invitatory Antiphon") }
    }

    private fun hymnusMatutinum(o: Office, dow: Int, rite: MissalRite, out: MutableMap<String, Hour.Part>) {
        var name = "Hymnus"
        if (o.proper.sec("Hymnus Matutinum") == null) name += checkmtv(o, rite)
        var h = proprium(o, "$name Matutinum", true)
        if (h == null && name != "Hymnus") h = proprium(o, "Hymnus Matutinum", true)
        // DO hymnshift / hymnmerge: a I Vespers hymn omitted by concurrence
        // moves to Matins; if II Vespers went too, the two hymns merge.
        if (h != null && (o.hymnShift == 2 || o.hymnShift == 3)) {
            proprium(o, "$name Vespera", true)?.let { h = it }
        } else if (h != null && o.hymnShift == 1) {
            proprium(o, "$name Vespera", true)?.let { hv ->
                val mat = (h!!.lat ?: "").removePrefix("v. ")
                val stanzas = (hv.lat ?: "").split("\n\n")
                val merged = (stanzas.dropLast(1) + mat).joinToString("\n\n")
                h = hv.copy(lat = merged, eng = listOfNotNull(hv.eng, h!!.eng).joinToString("\n\n").ifBlank { null })
            }
        }
        if (h == null) {
            val t = tempora("Hymnus matutinum", o, dow, rite)
            var key = if (t.isNotEmpty() && t != "Nat" && t != "Epi") "Hymnus $t" else "Day$dow Hymnus"
            val m = o.date.monthValue
            if (key == "Day0 Hymnus" && (m < 4 || m in listOf(10, 11))) key = "Day0 Hymnus1"
            h = psalt(key) ?: psalt("Day$dow Hymnus")
        }
        h?.let { out["hymnus_matutinum"] = rekey(it.copy(type = "hymn"), "hymnus_matutinum", "Hymn") }
    }

    // ------------------------------------------------------------ preces

    private fun precesFeriales(o: Office, dow: Int, hour: String, rite: MissalRite): Boolean {
        if (o.communeKey == "C12" || o.ruleHas("Omit.*? Preces") || o.duplex > 2 || Regex("^Pasc[67]").containsMatchIn(o.dayName)) return false
        if (hour !in listOf("laudes", "vesperae", "prima", "tertia", "sexta", "nona", "completorium")) return false
        if (dow == 0) return false
        if (dow == 6 && hour == "vesperae") return false
        val ferial = (o.temporal && (o.ruleHas("Preces") || o.dayName.startsWith("Adv") ||
            (o.dayName.startsWith("Quad") && !o.dayName.startsWith("Quadp")) || emberDay(o, dow))) ||
            (!is1955or1960(rite) && o.rankHas("vigil") && !o.rankHas("Epi|Pasc"))
        if (!ferial) return false
        return !is1955or1960(rite) || dow == 3 || dow == 5 || emberDay(o, dow)
    }

    /** DO preces('Dominicales'): the Sunday preces of Prime and Compline
     *  (the older books), unless a Duplex or an octave is commemorated. */
    private fun precesDominicales(o: Office, commem: Office?, rite: MissalRite): Boolean {
        if (o.communeKey == "C12" || o.ruleHas("Omit.*? Preces") || o.duplex > 2 || Regex("^Pasc[67]").containsMatchIn(o.dayName)) return false
        if (o.rankHas("octav") && !o.rankHas("post octav")) return false
        val octaveRe = Regex("octav", RegexOption.IGNORE_CASE)
        fun blocks(w: Office): Boolean = w.rank >= 3 || octaveRe.containsMatchIn(w.rankLine)
        if (commem != null && blocks(commem)) return false
        for (ck in o.commemorations) if (blocks(officeFromKey(ck, o.date, rite))) return false
        return true
    }

    /** The preces DO says at Prime, the little hours and Compline (its
     *  Psalterium scripts), when they apply. */
    private fun precesScript(o: Office, hourSlug: String, feriales: Boolean, dominicales: Boolean, dow: Int): List<Hour.Part>? {
        val key = when (hourSlug) {
            "tertia", "sexta", "nona" -> if (feriales) "Preces Feriales" else return null
            "completorium" -> if (feriales || dominicales) "Preces Dominicales" else return null
            "prima" -> if (feriales) "Preces feriales Prima" else if (dominicales) "Preces Dominicales Prima 1" else return null
            else -> return null
        }
        val sec = psalt(key) ?: return null
        val parts = renderScript(sec, o, hourSlug, dow)
        return if (parts.isEmpty()) null else listOf(Hour.Part(type = "heading", label = if (feriales) "Preces Feriales" else "Preces Dominicales")) + parts
    }
}
