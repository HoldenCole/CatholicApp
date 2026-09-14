package com.lampstandhq.introibo.data.content

import com.lampstandhq.introibo.data.model.Hour
import com.lampstandhq.introibo.storage.settings.MissalRite
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonArray
import kotlinx.serialization.json.JsonElement
import kotlinx.serialization.json.JsonNull
import kotlinx.serialization.json.JsonObject
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.boolean
import kotlinx.serialization.json.contentOrNull
import kotlinx.serialization.json.int
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import org.junit.Assert.assertTrue
import org.junit.Test
import java.io.File
import java.text.Normalizer
import java.time.LocalDate
import java.util.zip.GZIPInputStream

/**
 * The Divine Office against Divinum Officium, for every hour of every day
 * of a liturgical year (Advent 2025 - Advent 2026), in all three rites.
 *
 * src/test/resources/office_golden/<rite>.json.gz holds what Divinum
 * Officium prints for each hour, reduced to the features
 * scripts/office_qa/compare.py checks (psalms, antiphons, hymn, capitulum,
 * versicles, short responsory, collects, lessons, the Marian antiphon, the
 * preces) and normalised the same way; this test reduces the app's own
 * assembly identically and demands equality. Regenerate the golden with
 * compare.py --golden after re-extracting DO (scripts/office_qa/README).
 */
class OfficeDivinumOfficiumGoldenTest {

    private val assets: File by lazy {
        listOf("src/main/assets", "app/src/main/assets", "android/app/src/main/assets")
            .map { File(it) }
            .firstOrNull { it.isDirectory } ?: error("cannot locate assets dir")
    }

    private val hours = listOf("matutinum", "laudes", "prima", "tertia", "sexta", "nona", "vesperae", "completorium")

    @Test fun rite1962MatchesDivinumOfficium() = check(MissalRite.RITE_1962)
    @Test fun rite1955MatchesDivinumOfficium() = check(MissalRite.RITE_1955)
    @Test fun ritePre1955MatchesDivinumOfficium() = check(MissalRite.PRE_1955)

    private fun check(rite: MissalRite) {
        ContentStore.initFromDirectory(assets)
        val stream = javaClass.classLoader!!.getResourceAsStream("office_golden/${rite.rawValue}.json.gz")
            ?: error("golden missing for ${rite.rawValue}")
        val golden = Json.parseToJsonElement(GZIPInputStream(stream).bufferedReader().readText()).jsonObject
        val mismatches = ArrayList<String>()
        var compared = 0
        for ((dateStr, byHour) in golden) {
            val date = LocalDate.parse(dateStr)
            for (slug in hours) {
                val g = byHour.jsonObject[slug]?.jsonObject ?: continue
                val hour = ContentStore.hourForDate(slug, date, rite) ?: run { mismatches += "$dateStr $slug: null hour"; null } ?: continue
                compared++
                val parts = hour.parts
                fun diff(cat: String, app: Any?, expected: Any?) {
                    if (app != expected) mismatches += "$dateStr $slug $cat: app=$app expected=$expected"
                }
                g["ps"]?.takeIf { it !is JsonNull }?.let { diff("psalms", appPsalms(parts).map { psalmKey(it) }, strings(it)) }
                g["an"]?.takeIf { it !is JsonNull }?.let {
                    var aa = appAntiphons(parts)
                    if (slug == "completorium") aa = aa.sorted()
                    diff("antiphons", aa, strings(it))
                }
                diff("hymn", appHymn(parts), str(g["hy"]))
                if (slug != "matutinum") diff("capitulum", appCapitulum(parts), str(g["ca"]))
                if (slug !in listOf("prima", "completorium")) diff("versicle", appVersicles(parts, slug), strings(g["ve"]))
                if (slug != "matutinum") diff("responsory", appResponsory(parts), str(g["re"]))
                g["co"]?.takeIf { it !is JsonNull }?.let { diff("collect", appCollects(parts), strings(it)) }
                if (slug == "matutinum") g["le"]?.jsonArray?.let { le ->
                    val (n, td) = appLessons(parts)
                    diff("lessons", listOf(n, td), listOf(le[0].jsonPrimitive.int, le[1].jsonPrimitive.boolean))
                }
                if (slug == "completorium") diff("marian", appMarian(parts), str(g["ma"]))
                if (slug in listOf("laudes", "vesperae", "prima", "completorium")) diff("preces", appPreces(parts), g["pr"]?.jsonPrimitive?.boolean)
            }
        }
        assertTrue("too few hours compared for ${rite.rawValue}: $compared", compared > 2800)
        if (mismatches.isNotEmpty()) {
            throw AssertionError("${rite.rawValue}: ${mismatches.size} hours differ from Divinum Officium (first 40):\n" +
                mismatches.take(40).joinToString("\n"))
        }
    }

    // ---------------------------------------------------------------- golden helpers

    private fun str(e: JsonElement?): String? = e?.takeIf { it !is JsonNull }?.jsonPrimitive?.contentOrNull
    private fun strings(e: JsonElement?): List<String>? = e?.takeIf { it !is JsonNull }?.jsonArray?.map { it.jsonPrimitive.content }

    // ---------------------------------------------------------------- normalisation (compare.py)

    private val gloria = listOf("gloria patri", "sicut erat")
    private val fixedVersicles = listOf("deus in adiutorium", "gloria patri", "domine exaudi", "benedicamus domino",
        "fidelium animae", "domine labia", "iube domine", "iube domne", "tu autem",
        "adiutorium nostrum", "respice in seruos",
        "et ne nos inducas", "sed libera nos", "dominus uobiscum", "exsurge christe",
        "diuinum auxilium", "domine miserere", "conuerte nos", "dignare domine",
        "kyrie eleison", "christe eleison", "pater noster", "ostende nobis",
        "sancta maria", "exaudi domine", "in manus tuas")

    private fun norm(s: String?): String {
        var t = Normalizer.normalize(s ?: "", Normalizer.Form.NFD).replace(Regex("\\p{Mn}+"), "")
        t = t.lowercase().replace("æ", "ae").replace("œ", "oe").replace("j", "i").replace("v", "u")
        t = t.replace(Regex("[^a-z0-9 ]+"), " ").replace(Regex("\\s+"), " ").trim()
        t = t.replace("symbolum athanasium", "quicumque uult saluus")
        return t.replace("genitri", "genetri")
    }

    private fun words(s: String?, n: Int): String = norm(s).split(" ").filter { it.isNotEmpty() }.take(n).joinToString(" ")

    private fun stripNum(l: String): String {
        var t = l.replace(Regex("^\\d+:\\d+[ab]?\\s+"), "")
        t = t.replace(Regex("^\\(\\w+\\)\\s+"), "")
        return t.replace(Regex("^\\(fit reverentia\\)\\s+"), "")
    }

    private fun isGloria(l: String): Boolean { val n = norm(l); return gloria.any { n.startsWith(it) } }
    private fun properVersicle(t: String): Boolean { val n = norm(t); return fixedVersicles.none { n.startsWith(it) } }
    private fun firstLine(s: String?): String = (s ?: "").split(Regex("<br\\s*/?>|\\n"))[0]

    // ---------------------------------------------------------------- app-side features (compare.py app_*)

    private class Ps(val label: String, val first: String)

    private fun appPsalms(parts: List<Hour.Part>): List<Ps> {
        val out = ArrayList<Ps>()
        for (p in parts) {
            if (p.type != "psalm" && p.type != "canticle") continue
            val label = p.label ?: ""
            val vk = p.variationKey ?: ""
            if (label.startsWith("Psalm 94") || vk == "matutinum.canticle" || vk.startsWith("litania.")) continue
            val verses = (p.verses ?: emptyList()).map { it.lat }.filter { !isGloria(it) && !it.startsWith("(") }.map { stripNum(it) }
            val first = verses.firstOrNull() ?: ""
            val m = Regex("Psalm(?:us|i)?\\s+(\\d+)(?:\\s*[:(]\\s*(\\d+)[ab]?\\s*-\\s*(\\d+)[ab]?)?").find(label)
            if (m != null && label.contains("Psalmi 148")) out += Ps("Psalmus 148-150", first)
            else if (m != null) {
                var lab = "Psalmus " + m.groupValues[1] + (if (m.groupValues[2].isNotEmpty()) "(${m.groupValues[2]}-${m.groupValues[3]})" else "")
                lab = lab.replace(Regex("[ab](?=[-)])"), "")
                out += Ps(lab, first)
            } else out += Ps("Canticum $label", first)
        }
        return out
    }

    private fun psalmKey(x: Ps): String {
        val m = Regex("Psalmus (\\d+)").find(x.label)
        return (if (m != null) "Ps${m.groupValues[1]}:" else "Cant:") + words(x.first, 3)
    }

    private fun appAntiphons(parts: List<Hour.Part>): List<String> {
        val out = ArrayList<String>()
        for (p in parts) {
            val a = if (p.type == "psalm" || p.type == "canticle") p.antiphonLat else if (p.type == "antiphon") p.lat else null
            if (!a.isNullOrEmpty()) out += words(a, 5)
        }
        return out
    }

    private fun appHymn(parts: List<Hour.Part>): String? =
        parts.firstOrNull { it.type == "hymn" && !it.lat.isNullOrEmpty() }?.let { words(firstLine(it.lat), 5) }

    private fun appCapitulum(parts: List<Hour.Part>): String? {
        parts.firstOrNull { it.type == "capitulum" && !it.lat.isNullOrEmpty() }?.let { return words(firstLine(it.lat), 6) }
        parts.firstOrNull { it.type == "reading" && (it.variationKey ?: "").startsWith("lectio") && it.variationKey != "lectio_prima" && !it.lat.isNullOrEmpty() }
            ?.let { return words(firstLine(it.lat), 6) }
        return null
    }

    private fun appVersicles(parts: List<Hour.Part>, hour: String): List<String> {
        val out = ArrayList<String>()
        for (p in parts) {
            if (p.type != "vr") continue
            val vk = p.variationKey ?: ""
            if (hour in listOf("laudes", "vesperae") && !vk.startsWith("versum_") && vk != "capitulum_$hour" && vk != "vesperae.capitulum") continue
            if (hour in listOf("tertia", "sexta", "nona") && vk != "versum_$hour") continue
            if (hour == "matutinum" && !vk.startsWith("nocturn_")) continue
            if (hour in listOf("prima", "completorium")) continue
            for (v in listOf(p.v1Lat, p.lat)) {
                if (v.isNullOrEmpty()) continue
                var line = v.split(Regex("<br\\s*/?>|\\n"))[0].trim()
                line = line.replace(Regex("^(℣\\.|V\\.)\\s*"), "")
                if (properVersicle(line)) out += words(line, 5)
                break
            }
        }
        return out
    }

    private fun appResponsory(parts: List<Hour.Part>): String? {
        val p = parts.firstOrNull { it.type == "responsory" && (!it.lat.isNullOrEmpty() || !it.v1Lat.isNullOrEmpty() || !it.r1Lat.isNullOrEmpty()) } ?: return null
        val t = firstLine(p.lat?.ifEmpty { null } ?: p.v1Lat?.ifEmpty { null } ?: p.r1Lat).trim().replace(Regex("^(℟|R)\\.?\\s*br\\.?\\s*"), "")
        return words(t, 6)
    }

    private fun appCollects(parts: List<Hour.Part>): List<String> =
        parts.filter { it.type == "collect" && !it.lat.isNullOrEmpty() && (it.variationKey ?: "") != "prima2.sanctamaria" }
            .map { words(firstLine(it.lat), 6) }

    private fun appLessons(parts: List<Hour.Part>): Pair<Int, Boolean> {
        val n = parts.count { it.type == "reading" && Regex("^lectio\\d").containsMatchIn(it.variationKey ?: "") }
        val td = parts.any { (it.variationKey ?: "") == "matutinum.canticle" || (it.label ?: "").contains("Te Deum") }
        return n to td
    }

    private fun appMarian(parts: List<Hour.Part>): String? =
        parts.firstOrNull { ((it.variationKey ?: "").startsWith("completorium.marian") || it.type == "marian") && !it.lat.isNullOrEmpty() }
            ?.let { words(firstLine(it.lat), 3) }

    private fun appPreces(parts: List<Hour.Part>): Boolean =
        parts.any { norm(firstLine(it.lat ?: "")).startsWith("kyrie eleison") || it.type == "preces" || (it.variationKey ?: "").startsWith("preces") }
}
