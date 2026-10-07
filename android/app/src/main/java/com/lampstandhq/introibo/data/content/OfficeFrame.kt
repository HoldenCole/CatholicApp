package com.lampstandhq.introibo.data.content

import com.lampstandhq.introibo.data.model.Hour
import com.lampstandhq.introibo.storage.settings.MissalRite

/**
 * The fixed frame of every hour as Divinum Officium prints it — everything
 * around the proper texts that the templates and the rubrics left out:
 *
 *  - the Pater/Ave/Credo before the hour only in the older books (the 1955
 *    and 1960 books begin straight with Deus in adjutórium), without the Credo
 *    outside Matins and Prime, and after Compline;
 *  - the opening's Glória Patri with its Sicut erat and the Allelúja (Laus
 *    tibi from Septuagesima to Holy Week);
 *  - Glória Patri after every psalm and canticle (Réquiem ætérnam in the Office
 *    of the Dead; nothing in the Triduum; the Benedicite has none);
 *  - the invitatory woven into the Venite;
 *  - ℟. Deo grátias after the capitulum;
 *  - the short responsory said whole (the ℟. repeated after the ℟.br.);
 *  - ℣. Dómine, exáudi and Orémus before the collect, the conclusion and ℟. Amen
 *    after it (one conclusion for a run of commemorations, as DO prints it);
 *  - the Pater noster of Matins said secreto up to Et ne nos indúcas; the
 *    absolution and blessings chosen as DO does (by weekday on ferias, the
 *    saint's own at the second blessing, the Gospel's before a homily);
 *  - the ends of the little hours (Fidélium ánimæ), Prime (℣. Benedícite,
 *    the blessing with Et fidélium) and Compline (Adjutórium nostrum and the
 *    Pater noster before the Confíteor, Benedicámus and the blessing before
 *    the Marian antiphon, Divínum auxílium after it).
 *
 * Latin is DO's; English is DO's English column where the apps carry it.
 * Swift mirror: Introibo/Data/OfficeFrame.swift
 */
/** office_conclusions.json: the collect (folded) → conclusion code table. */
@kotlinx.serialization.Serializable
class OfficeConclusions(val collects: Map<String, String> = emptyMap())

object OfficeFrame {

    class Ctx(
        val hourSlug: String,
        val rite: MissalRite,
        /** 0 = Sunday … 6 = Saturday */
        val dow: Int,
        val office: OfficeRubrics.Office?,
        val lessons: Int,
        val nocturns: Int,
        /** A "Special <Hour>" script: DO's literal text, framed already. */
        val special: Boolean,
        val template: Hour,
    )

    /** The collect → conclusion table (office_conclusions.json "collects"), set by ContentStore. */
    var conclusions: Map<String, String> = emptyMap()
    /** The template's Pater noster / Ave María / Credo part (Lauds), set by ContentStore. */
    var paterAveCredo: Hour.Part? = null

    private val GLORIA = listOf(
        Hour.Part.Verse("Glória Patri, et Fílio, * et Spirítui Sancto.", "Glory be to the Father, and to the Son, * and to the Holy Ghost."),
        Hour.Part.Verse("Sicut erat in princípio, et nunc, et semper, * et in sǽcula sæculórum. Amen.", "As it was in the beginning, is now, and ever shall be, * world without end. Amen."),
    )
    private val REQUIEM = listOf(
        Hour.Part.Verse("Réquiem ætérnam * dona eis, Dómine.", "Eternal rest * grant unto them, O Lord."),
        Hour.Part.Verse("Et lux perpétua * lúceat eis.", "And let perpetual light * shine upon them."),
    )
    private const val DOMINE_EXAUDI_LAT = "℣. Dómine, exáudi oratiónem meam."
    private const val DOMINE_EXAUDI_LATR = "℟. Et clamor meus ad te véniat."
    private const val DOMINE_EXAUDI_ENG = "℣. O Lord, hear my prayer."
    private const val DOMINE_EXAUDI_ENGR = "℟. And let my cry come unto Thee."

    private val ABSOLUTIONS = listOf(
        "Exáudi, Dómine Jesu Christe, preces servórum tuórum, et miserére nobis: Qui cum Patre et Spíritu Sancto vivis et regnas in sǽcula sæculórum." to
            "O Lord Jesus Christ, graciously hear the prayers of Thy servants, and have mercy upon us, Who livest and reignest with the Father, and the Holy Ghost, ever world without end.",
        "Ipsíus píetas et misericórdia nos ádjuvet, qui cum Patre et Spíritu Sancto vivit et regnat in sǽcula sæculórum." to
            "May His loving-kindness and mercy help us, Who liveth and reigneth with the Father, and the Holy Ghost, world without end.",
        "A vínculis peccatórum nostrórum absólvat nos omnípotens et miséricors Dóminus." to
            "May the Almighty and merciful Lord loose us from the bonds of our sins.",
    )
    private val BLESSINGS = listOf(
        listOf(
            "Benedictióne perpétua benedícat nos Pater ætérnus." to "May the Eternal Father bless us with an eternal blessing.",
            "Unigénitus Dei Fílius nos benedícere et adjuváre dignétur." to "May the Son, the Sole-begotten, mercifully bless and keep us.",
            "Spíritus Sancti grátia illúminet sensus et corda nostra." to "May the grace of the Holy Spirit enlighten all our hearts and minds.",
        ),
        listOf(
            "Deus Pater omnípotens sit nobis propítius et clemens." to "May God the Father Omnipotent, be to us merciful and clement.",
            "Christus perpétuæ det nobis gáudia vitæ." to "May Christ to all His people give, for ever in His sight to live.",
            "Ignem sui amóris accéndat Deus in córdibus nostris." to "May the Spirit's fire Divine in our hearts enkindled shine.",
        ),
        listOf(
            "Ille nos benedícat, qui sine fine vivit et regnat." to "May His blessing be upon us who doth live and reign for ever.",
            "Divínum auxílium máneat semper nobíscum." to "God's most mighty strength alway be His people's staff and stay.",
            "Ad societátem cívium supernórum perdúcat nos Rex Angelórum." to "May He that is the Angels' King to that high realm His people bring.",
        ),
    )
    private val EVANGELICA = "Evangélica léctio sit nobis salus et protéctio." to "May the Gospel's holy lection be our safety and protection."
    private val EVANGELICA9 = "Per evangélica dicta, deleántur nostra delícta." to "May the Gospel's glorious word cleansing to our souls afford."
    private val CUJUS = listOf(
        "Cujus festum cólimus, ipse intercédat pro nobis ad Dóminum." to "He whose feast-day we are keeping, be our Advocate with God.",
        "Quorum festum cólimus, ipsi intercédant pro nobis ad Dóminum." to "They whose feast-day we are keeping, be our Advocates with God.",
        "Cujus festum cólimus, ipsa intercédat pro nobis ad Dóminum." to "She whose feast-day we are keeping, be our Advocate with God.",
        "Quarum festum cólimus, ipsæ intercédant pro nobis ad Dóminum." to "They whose feast-day we are keeping, be our Advocates with God.",
        "Cujus festum cólimus, ipsa Virgo vírginum intercédat pro nobis ad Dóminum." to "She whose feast-day we are keeping, Mary, blessed Maid of Maidens, be our Advocate with God.",
        "Cujus festum cólimus, ipse gloriósus Pater noster intercédat pro nobis ad Dóminum." to "May he whose feast-day we are keeping, our glorious Father, be our advocate with God.",
    )

    fun apply(parts: List<Hour.Part>, c: Ctx): List<Hour.Part> {
        if (c.hourSlug == "office-of-the-dead") return parts
        val out = ArrayList(parts)
        val o = c.office
        val dayName = o?.dayName ?: ""
        // the office's DO key ("quad6-5", "pasc0-0"; a saint's "12-08") — dayName is the week only
        val key = if (o != null && o.temporal) o.key.lowercase() else ""
        val triduum = key.startsWith("quad6-4") || key.startsWith("quad6-5") || key.startsWith("quad6-6")
        val dead = o?.communeKey == "C12"
        val lentOrSept = dayName.startsWith("Quad")

        pater(out, c)
        opening(out, lentOrSept)
        closing(out)
        if (!c.special) {
            invitatory(out, dead)
            gloria(out, triduum, dead)
            capitulum(out)
            responsoryBreve(out)
            if (c.hourSlug == "matutinum") matins(out, c)
            collects(out, c)
            when (c.hourSlug) {
                "tertia", "sexta", "nona" -> littleHour(out)
                "prima" -> { littleHour(out, fidelium = false); prime(out) }
                "completorium" -> compline(out, c)
            }
            marianTail(out)
            if (c.rite == MissalRite.PRE_1955) olderBooksEnd(out, c)
        } else {
            gloria(out, triduum, dead)
        }
        return out
    }

    // ---- Pater noster, Ave María, Credo ----

    private fun pater(out: MutableList<Hour.Part>, c: Ctx) {
        val i = out.indexOfFirst { it.type == "pater" && (it.label ?: "").startsWith("Pater Noster, Ave") }
        if (c.rite != MissalRite.PRE_1955) {
            if (i >= 0) out.removeAt(i)
            return
        }
        if (c.hourSlug == "completorium") { if (i >= 0) out.removeAt(i); return }
        val withCredo = c.hourSlug == "matutinum" || c.hourSlug == "prima"
        if (i < 0) {
            val p = paterAveCredo ?: return
            if (c.hourSlug == "matutinum") out.add(0, secreto(p, withCredo))
            return
        }
        out[i] = secreto(out[i], withCredo)
    }

    private fun secreto(p: Hour.Part, withCredo: Boolean): Hour.Part {
        fun cut(t: String?): String? {
            if (t == null) return null
            val paras = t.split("\n\n")
            return if (withCredo) t else paras.take(2).joinToString("\n\n")
        }
        return p.copy(label = if (withCredo) "Pater noster, Ave María, Credo (secréto)" else "Pater noster, Ave María (secréto)", lat = cut(p.lat), eng = cut(p.eng))
    }

    // ---- Deus in adjutórium ----

    private fun opening(out: MutableList<Hour.Part>, lentOrSept: Boolean) {
        for (i in out.indices) {
            val p = out[i]
            if (p.type != "vr" || !(p.lat ?: "").startsWith("Deus, in adjutórium") || !(p.latR ?: "").startsWith("Dómine, ad adjuvándum")) continue
            val lat = listOf(
                "℟. Dómine, ad adjuvándum me festína.",
                GLORIA[0].lat, GLORIA[1].lat,
                if (lentOrSept) "Laus tibi, Dómine, Rex ætérnæ glóriæ." else "Allelúja.",
            )
            val eng = listOf(
                "℟. O Lord, make haste to help me.",
                GLORIA[0].eng, GLORIA[1].eng,
                if (lentOrSept) "Praise be to Thee, O Lord, King of eternal glory." else "Alleluia.",
            )
            out[i] = p.copy(lat = "℣. " + p.lat, eng = p.eng?.let { "℣. $it" }, latR = lat.joinToString("\n"), engR = eng.joinToString("\n"))
        }
    }

    // ---- Benedicámus Dómino. ℟. Deo grátias. ----

    private fun twoLines(t: String?): String? {
        if (t == null || t.contains("\n")) return t
        val m = Regex("^(.*?[.!])\\s+(.+)$").find(t.trim()) ?: return t
        return "℣. " + m.groupValues[1] + "\n℟. " + m.groupValues[2]
    }

    private fun closing(out: MutableList<Hour.Part>) {
        for (i in out.indices) {
            val p = out[i]
            if (p.type != "closing" || !(p.lat ?: "").startsWith("Benedicámus Dómino. Deo grátias")) continue
            out[i] = p.copy(lat = twoLines(p.lat), eng = twoLines(p.eng))
        }
    }

    // ---- Glória Patri after the psalms ----

    private fun hasDoxology(p: Hour.Part): Boolean {
        val last = p.verses?.lastOrNull()?.lat ?: return false
        return last.startsWith("Sicut erat") || last.contains("Glória Patri") || last.startsWith("Et lux perpétua")
    }

    private fun isBenedicite(p: Hour.Part): Boolean =
        (p.label ?: "").contains("Trium Puer") || (p.verses?.firstOrNull()?.lat ?: "").startsWith("Benedícite, ómnia ópera")

    private fun gloria(out: MutableList<Hour.Part>, triduum: Boolean, dead: Boolean) {
        if (triduum) return
        for (i in out.indices) {
            val p = out[i]
            if (p.type != "psalm" && p.type != "canticle") continue
            val vs = p.verses ?: continue
            if (vs.isEmpty()) continue
            if (p.variationKey == "matutinum.psalm1" || p.variationKey == "matutinum.canticle" || (p.label ?: "").contains("Te Deum")) continue
            if (isBenedicite(p) || hasDoxology(p)) continue
            out[i] = p.copy(verses = vs + (if (dead) REQUIEM else GLORIA))
        }
    }

    // ---- The invitatory inside the Venite ----

    private fun invitatory(out: MutableList<Hour.Part>, dead: Boolean) {
        val ai = out.indexOfFirst { it.type == "antiphon" && it.variationKey == "invit" && !it.lat.isNullOrBlank() }
        if (ai < 0) return
        val pi = out.indexOfFirst { (it.type == "psalm") && it.variationKey == "matutinum.psalm1" && !it.verses.isNullOrEmpty() }
        if (pi < 0) return
        val a = out[ai]
        val full = "Ant. " + AntiphonPlacement.whole(a.lat!!)
        val half = "Ant. " + AntiphonPlacement.whole(a.lat!!.substringAfter("*", a.lat!!)).trim()
        val efull = "Ant. " + AntiphonPlacement.whole(a.eng ?: "")
        val ehalf = "Ant. " + AntiphonPlacement.whole((a.eng ?: "").let { if (it.contains("*")) it.substringAfter("*") else it }).trim()
        val starts = listOf("Præoccupémus" to true, "Quia in manu" to false, "Quia ipse est" to true, "Sicut in exacerbatióne" to false, "Quibus jurávi" to true)
        val vs = out[pi].verses!!
        if (starts.count { s -> vs.any { it.lat.startsWith(s.first) } } < 4) return
        val nv = ArrayList<Hour.Part.Verse>()
        nv.add(Hour.Part.Verse(full, efull))   // intoned, then said whole
        for (v in vs) {
            nv.add(v)
            val s = starts.firstOrNull { v.lat.startsWith(it.first) } ?: continue
            nv.add(if (s.second) Hour.Part.Verse(full, efull) else Hour.Part.Verse(half, ehalf))
        }
        val dox = if (dead) REQUIEM else GLORIA
        nv.add(Hour.Part.Verse("℣. " + dox[0].lat, "℣. " + dox[0].eng))
        nv.add(Hour.Part.Verse("℟. " + dox[1].lat, "℟. " + dox[1].eng))
        nv.add(Hour.Part.Verse(half, ehalf))
        nv.add(Hour.Part.Verse(full, efull))
        out[pi] = out[pi].copy(verses = nv)
    }

    // ---- Capitulum ----

    private fun capitulum(out: MutableList<Hour.Part>) {
        for (i in out.indices) {
            val p = out[i]
            if (p.type != "capitulum" || p.lat.isNullOrBlank() || p.lat.contains("Deo grátias")) continue
            out[i] = p.copy(lat = p.lat + "\n℟. Deo grátias.", eng = p.eng?.let { "$it\n℟. Thanks be to God." })
        }
    }

    // ---- Short responsory ----

    private fun breve(t: String): String {
        val ls = t.split("\n").toMutableList()
        if (ls.isEmpty() || !ls[0].startsWith("℟.br.")) return t
        if (ls.size < 2 || !ls[1].startsWith("℟.")) ls.add(1, "℟. " + ls[0].removePrefix("℟.br.").trim())
        for (k in ls.indices) if (ls[k].startsWith("Glória Patri") || ls[k].startsWith("Gloria al Padre") || ls[k].startsWith("Glory be")) ls[k] = "℣. " + ls[k]
        return ls.joinToString("\n")
    }

    private fun responsoryBreve(out: MutableList<Hour.Part>) {
        for (i in out.indices) {
            val p = out[i]
            if (p.type != "responsory" || !(p.lat ?: "").startsWith("℟.br.")) continue
            out[i] = p.copy(lat = breve(p.lat!!), eng = p.eng?.let { breve(it) })
        }
    }

    // ---- Collects ----

    private val SHORT_CONCLUSION = Regex("\\s*(Per Dóminum nostrum Jesum Christum\\.|Through our Lord Jesus Christ\\.|Por nuestro Señor Jesucristo\\.)\\s*(Amen|Amén)\\.\\s*$")

    /** The templates' short "Per Dóminum nostrum Jesum Christum. Amen." gives way to the whole conclusion. */
    private fun unshort(p: Hour.Part): Hour.Part {
        val lat = p.lat ?: return p
        if (!SHORT_CONCLUSION.containsMatchIn(lat)) return p
        return p.copy(lat = SHORT_CONCLUSION.replace(lat, ""), eng = p.eng?.let { SHORT_CONCLUSION.replace(it, "") })
    }

    private fun hasConclusion(lat: String): Boolean {
        val t = lat.trimEnd()
        return t.endsWith("Amen.") || Regex("Per Dóminum|Per eúndem|Qui vivis|Qui tecum|Per Christum|Per eumdem").containsMatchIn(t)
    }

    /** compare.norm of the QA tooling: accents, æ/œ, j/i, u/v and punctuation folded. */
    fun foldKey(s: String): String {
        val d = java.text.Normalizer.normalize(s, java.text.Normalizer.Form.NFD).replace(Regex("\\p{Mn}+"), "")
        val l = d.lowercase().replace("æ", "ae").replace("œ", "oe").replace('j', 'i').replace('v', 'u')
        return l.replace(Regex("[^a-z0-9 ]+"), " ").replace(Regex("\\s+"), " ").trim()
    }

    private fun conclusionCode(lat: String): String {
        conclusions[foldKey(lat)]?.let { return it }
        val e = if (Regex("Spíritu[sm]? Sanct").containsMatchIn(lat)) "e" else ""
        if (Regex("(^|[,.:;] )(Dómine Jesu Christe|Jesu Christe|Dómine Jesu)|Qui vivis|Qui cum Patre").containsMatchIn(lat)) return "QV$e"
        if (Regex("Fíli[ui]|Unigénit|Jesum Christum|Jesu Christi|Christ[oiu]m?\\b|Dómin[iu]m? nostr[iu]m?|Redemptór|Salvatór").containsMatchIn(lat)) return "PE$e"
        return "PD$e"
    }

    private fun conclusionText(code: String): Pair<String, String> {
        val e = code.endsWith("e")
        val spLat = if (e) "ejúsdem Spíritus Sancti" else "Spíritus Sancti"
        val spEng = if (e) "the same Holy Ghost" else "the Holy Ghost"
        return when (code.removeSuffix("e")) {
            "PE" -> "Per eúndem Dóminum nostrum Jesum Christum Fílium tuum, qui tecum vivit et regnat in unitáte $spLat, Deus, per ómnia sǽcula sæculórum." to
                "Through the same Jesus Christ, thy Son, our Lord, Who liveth and reigneth with thee, in the unity of $spEng, God, world without end."
            "QV" -> "Qui vivis et regnas cum Deo Patre, in unitáte $spLat, Deus, per ómnia sǽcula sæculórum." to
                "Who livest and reignest with God the Father, in the unity of $spEng, God, world without end."
            "QT" -> "Qui tecum vivit et regnat in unitáte $spLat, Deus, per ómnia sǽcula sæculórum." to
                "Who with thee liveth and reigneth in the unity of $spEng, God, world without end."
            "PC" -> "Per Christum Dóminum nostrum." to "Through Christ our Lord."
            else -> "Per Dóminum nostrum Jesum Christum, Fílium tuum: qui tecum vivit et regnat in unitáte $spLat, Deus, per ómnia sǽcula sæculórum." to
                "Through Jesus Christ, thy Son our Lord, Who liveth and reigneth with thee, in the unity of $spEng, God, world without end."
        }
    }

    private fun oremus() = Hour.Part(type = "heading", label = "Orémus.")
    private fun domineExaudi() = Hour.Part(type = "vr", label = "Versus", lat = DOMINE_EXAUDI_LAT, latR = DOMINE_EXAUDI_LATR, eng = DOMINE_EXAUDI_ENG, engR = DOMINE_EXAUDI_ENGR)

    private val MAIN_COLLECTS = setOf("oratio", "oratio_prima", "oratio_completorium")

    private fun collects(out: MutableList<Hour.Part>, c: Ctx) {
        var i = 0
        while (i < out.size) {
            if (out[i].type == "collect") out[i] = unshort(out[i])
            val p = out[i]
            if (p.type != "collect" || p.lat.isNullOrBlank() || p.variationKey == "prima2.sanctamaria") { i++; continue }
            val vk = p.variationKey
            val main = vk in MAIN_COLLECTS
            // the run of collects this one belongs to (the main collect and its commemorations)
            val commem = vk == null && (p.label == "Oratio" || p.label == "Orémus")
            // Dómine, exáudi before the main collect — not after the preces, which end with it
            if (main) {
                val prev = (i - 1 downTo 0).map { out[it] }.firstOrNull { it.type != "heading" }
                if (prev?.type != "preces" && !(prev?.lat ?: "").startsWith("℣. Dómine, exáudi")) { out.add(i, domineExaudi()); i++ }
            }
            // Orémus. before every collect that lacks it
            if (!(p.lat.startsWith("Orémus")) && (out.getOrNull(i - 1)?.label != "Orémus.")) { out.add(i, oremus()); i++ }
            if (main || commem) {
                // the main collect carries its conclusion; a run of commemorations
                // shares one, after the last of them (as DO prints it)
                var j = i + 1
                var lastOfRun = true
                while (!main && j < out.size) {
                    val q = out[j]
                    if (q.type == "collect" && q.variationKey == null && (q.label == "Oratio" || q.label == "Orémus")) { lastOfRun = false; break }
                    if (q.type == "heading" || q.type == "antiphon" || q.type == "vr") { j++; continue }
                    break
                }
                if (lastOfRun && !hasConclusion(p.lat)) {
                    val (cl, ce) = conclusionText(conclusionCode(p.lat))
                    out[i] = p.copy(lat = p.lat + "\n" + cl + "\n℟. Amen.", eng = p.eng?.let { "$it\n$ce\n℟. Amen." })
                }
            } else if (!hasConclusion(p.lat) && vk != null) {
                val (cl, ce) = conclusionText(conclusionCode(p.lat))
                out[i] = p.copy(lat = p.lat + "\n" + cl + "\n℟. Amen.", eng = p.eng?.let { "$it\n$ce\n℟. Amen." })
            }
            i++
        }
    }

    // ---- Matins: the Pater noster secreto, the absolution and blessings ----

    private fun paterSecreto(p: Hour.Part): Hour.Part {
        val lat = (p.lat ?: "").substringBefore("\n\n")
        val eng = (p.eng ?: "").substringBefore("\n\n")
        val latCut = lat.substringBefore(" Et ne nos").substringBefore("\n℣. Et ne nos").trimEnd()
        val engCut = eng.substringBefore(" And lead us not").substringBefore("\n℣. And lead us not").trimEnd()
        return p.copy(
            label = "Pater noster (secréto)",
            lat = "$latCut\n℣. Et ne nos indúcas in tentatiónem.\n℟. Sed líbera nos a malo.",
            eng = if (engCut.isBlank()) p.eng else "$engCut\n℣. And lead us not into temptation.\n℟. But deliver us from evil.",
        )
    }

    private fun matins(out: MutableList<Hour.Part>, c: Ctx) {
        // the Pater noster before the collect: DO has none (Dómine, exáudi and Orémus follow the responsory or the Te Deum)
        var i = 0
        while (i < out.size) {
            val p = out[i]
            if (p.type == "pater" && (p.label ?: "") == "Pater Noster") {
                val next = out.getOrNull(i + 1)
                if (next?.type == "collect") { out.removeAt(i); continue }
                out[i] = paterSecreto(p)
            }
            i++
        }
        // the last responsory of each nocturn ends with ℣. Glória Patri and the repeat
        // (not in Passiontide unless a saint's office; Réquiem in the Office of the Dead)
        val o = c.office ?: return
        val passion = Regex("^Quad[56]").containsMatchIn(o.dayName) && !o.sanctoral && !o.ruleHas("Gloria responsory")
        val dead = o.communeKey == "C12"
        val gl = if (dead) "℣. Réquiem ætérnam dona eis, Dómine, * et lux perpétua lúceat eis." else "℣. Glória Patri, et Fílio, * et Spirítui Sancto."
        val ge = if (dead) "℣. Eternal rest grant unto them, O Lord, * and let perpetual light shine upon them." else "℣. Glory be to the Father, and to the Son, * and to the Holy Ghost."
        val gloriaLine = Regex("^(℣\\.|V\\.)?\\s*(Glória Patri|Glory be|Gloria al Padre|Réquiem ætérnam|Eternal rest|Descanso eterno)")
        for (i in out.indices) {
            val p = out[i]
            if (p.type != "responsory") continue
            val next = out.getOrNull(i + 1)
            // the responsory closes a nocturn when a new nocturn, the collect or the end follows (the Te Deum replaces the last one)
            // (DO responsory_gloria: also the responsory before the last lesson when the Te Deum follows it)
            val teDeumIdx = out.indexOfFirst { it.type == "canticle" && (it.label ?: "").contains("Te Deum") }
            val beforeTeDeum = teDeumIdx > i && out.subList(i + 1, teDeumIdx).none { it.type == "responsory" }
            val last = next == null || next.type == "heading" || next.type == "collect" || (next.type == "vr" && (next.lat ?: "").startsWith("℣. Dómine, exáudi")) || beforeTeDeum
            val wants = last && !passion
            if (p.v1Lat != null && p.r2Lat != null) {
                if (wants && !gloriaLine.containsMatchIn(p.r2Lat)) out[i] = p.copy(r2Lat = p.r2Lat + "\n" + gl + "\n" + p.r2Lat, r2Eng = p.r2Eng?.let { "$it\n$ge\n$it" })
                continue
            }
            val lat = p.lat ?: continue
            // the lat form: drop a doxology (the assets carry the whole Glória Patri with its Sicut erat) and re-add DO's half form where it belongs
            fun strip(t: String): List<String> {
                val ls = t.split("\n").toMutableList()
                val g = ls.indexOfFirst { gloriaLine.containsMatchIn(it) }
                if (g >= 0) { ls.removeAt(g); if (g < ls.size) ls.removeAt(g) }
                return ls
            }
            val ll = strip(lat); val el = p.eng?.let { strip(it) }
            val changed = ll.size != lat.split("\n").size
            if (!wants) { if (changed) out[i] = p.copy(lat = ll.joinToString("\n"), eng = el?.joinToString("\n")); continue }
            val rep = ll.lastOrNull { it.startsWith("R. ") || it.startsWith("℟. ") } ?: continue
            val erep = el?.lastOrNull { it.startsWith("R. ") || it.startsWith("℟. ") }
            out[i] = p.copy(lat = (ll + listOf(gl, rep)).joinToString("\n"), eng = el?.let { (it + listOfNotNull(ge, erep)).joinToString("\n") })
        }
        val english = HashMap<String, String>()
        for (p in c.template.parts) if (p.type == "vr" && p.lat != null && p.eng != null) english[p.lat] = p.eng
        for ((l, e) in ABSOLUTIONS) english.putIfAbsent(l, e)
        for (set in BLESSINGS) for ((l, e) in set) english.putIfAbsent(l, e)
        english.putIfAbsent(EVANGELICA.first, EVANGELICA.second); english.putIfAbsent(EVANGELICA9.first, EVANGELICA9.second)
        for ((l, e) in CUJUS) english.putIfAbsent(l, e)

        val sancti = (o.sanctoral && Regex("\\b(Ss?|Bb?)\\.", RegexOption.IGNORE_CASE).containsMatchIn(o.rankLine)) || o.communeKey == "C11"
        val key = if (o.temporal) o.key.lowercase() else ""
        val homilyFirst = Regex("vigil|quatt|ciner", RegexOption.IGNORE_CASE).containsMatchIn(o.rankLine) ||
            Regex("^quad[1-5]-[1-6]|^quad6-1|^pasc5-1|^pasc0|^pasc7").containsMatchIn(key) ||
            (Regex("^nat(29|3[01])").containsMatchIn(key) && c.rite != MissalRite.RITE_1962)
        val absIdx = out.indices.filter { out[it].type == "vr" && out[it].label == "Absolutio" }
        val blIdx = out.indices.filter { out[it].type == "vr" && (out[it].label ?: "").startsWith("Blessing before") }
        fun set(i: Int, text: Pair<String, String>) {
            val p = out[i]
            out[i] = p.copy(lat = text.first, eng = english[text.first] ?: text.second)
        }
        if (c.lessons >= 9 && absIdx.size == 3 && blIdx.size == 9) {
            // nine lessons: the template's nocturn sets; the saint's own second blessing of the third nocturn
            if (sancti) set(blIdx[7], CUJUS[cujusQ(o)])
            return
        }
        if (absIdx.size != 1 || blIdx.size != 3) return
        var k = if (c.dow == 0) 1 else c.dow
        if (k > 3) k -= 3
        val ben: MutableList<Pair<String, String>> = when {
            homilyFirst -> BLESSINGS[2].toMutableList().also { it[0] = EVANGELICA }
            o.isSunday -> BLESSINGS[2].toMutableList().also { it[2] = EVANGELICA9 }
            sancti -> BLESSINGS[2].toMutableList().also { it[1] = CUJUS[cujusQ(o)] }
            else -> BLESSINGS[k - 1].toMutableList()
        }
        set(absIdx[0], ABSOLUTIONS[k - 1])
        for (n in 0 until 3) set(blIdx[n], ben[n])
    }

    /** DO's cujus_q: which "Cujus festum cólimus" fits the office. */
    private fun cujusQ(o: OfficeRubrics.Office): Int {
        if (o.ruleHas("Quorum Festum")) return 1
        if (o.communeKey == "C11" || Regex("08-15|09-08|12-08").containsMatchIn(o.key)) return 4
        val r = o.rankLine
        if (Regex("S\\. P\\. N\\. Benedicti Abbatis").containsMatchIn(r)) return 5
        var j = 0
        if (Regex("virgin|vidu[aæ]|poenitentis|pœnitentis|C6|C7", RegexOption.IGNORE_CASE).containsMatchIn(r) && !Regex("C[2-5]").containsMatchIn(r)) j += 2
        if (Regex("ss\\.|bb\\.|sanctorum|sociorum", RegexOption.IGNORE_CASE).containsMatchIn(r)) j += 1
        return j
    }

    // ---- The ends of the hours ----

    private fun fidelium() = Hour.Part(type = "vr", label = "Versus",
        lat = "℣. Fidélium ánimæ per misericórdiam Dei requiéscant in pace.", latR = "℟. Amen.",
        eng = "℣. May the souls of the faithful, through the mercy of God, rest in peace.", engR = "℟. Amen.")

    private fun littleHour(out: MutableList<Hour.Part>, fidelium: Boolean = true) {
        var ci = out.indexOfFirst { it.type == "closing" && (it.lat ?: "").contains("Benedicámus Dómino") }
        if (ci < 0) return
        // ℣. Dómine, exáudi before the Benedicámus
        if (!(out.getOrNull(ci - 1)?.lat ?: "").startsWith("℣. Dómine, exáudi")) { out.add(ci, domineExaudi()); ci++ }
        if (!fidelium || out.drop(ci + 1).any { (it.lat ?: "").contains("Fidélium ánimæ") }) return
        out.add(ci + 1, fidelium())
    }

    /** ℣. Divínum auxílium after the Marian antiphon's prayer (Compline; Lauds in the older books). */
    private fun marianTail(out: MutableList<Hour.Part>) {
        val mi = out.indexOfFirst { it.type == "marian" }
        if (mi < 0 || out.any { (it.lat ?: "").startsWith("℣. Divínum auxílium") }) return
        val oi = out.indexOfLast { it.type == "collect" && it.variationKey?.startsWith("completorium.marian") == true }
        val v = Hour.Part(type = "vr", label = "Versus", lat = "℣. Divínum auxílium ✠ máneat semper nobíscum.", latR = "℟. Amen.",
            eng = "℣. May the divine assistance ✠ remain always with us.", engR = "℟. Amen.")
        if (oi > mi) out.add(oi + 1, v) else out.add(v)
    }

    /** The older books: the Pater noster (secreto) after every hour; at Lauds ℣. Dóminus det nobis before the Marian antiphon. */
    private fun olderBooksEnd(out: MutableList<Hour.Part>, c: Ctx) {
        if (c.hourSlug == "completorium") return
        val pater = paterAveCredo ?: return
        val fi = out.indexOfLast { (it.lat ?: "").contains("idélium ánimæ") }
        if (fi < 0 || out.drop(fi + 1).any { it.type == "pater" }) return
        val adds = ArrayList<Hour.Part>()
        adds.add(Hour.Part(type = "pater", label = "Pater noster (secréto)", lat = pater.lat?.substringBefore("\n\n"), eng = pater.eng?.substringBefore("\n\n")))
        if (c.hourSlug == "laudes" && out.drop(fi + 1).any { it.type == "marian" }) {
            adds.add(Hour.Part(type = "vr", label = "Versus", lat = "℣. Dóminus det nobis suam pacem.", latR = "℟. Et vitam ætérnam. Amen.",
                eng = "℣. May the Lord grant us his peace.", engR = "℟. And life everlasting. Amen."))
        }
        out.addAll(fi + 1, adds)
    }

    private fun prime(out: MutableList<Hour.Part>) {
        val bi = out.indexOfFirst { it.variationKey == "prima2.benedictio2" }
        if (bi < 0) return
        val b = out[bi]
        fun merge(t: String?): String? {
            val ls = t?.split("\n") ?: return t
            if (ls.size < 4) return t
            // blessing / Amen / Et fidélium / Amen  ->  blessing + Et fidélium / Amen
            return ls[0].trimEnd() + " " + ls[2].removePrefix("℣.").trim() + "\n" + ls[1]
        }
        out[bi] = b.copy(lat = merge(b.lat), eng = merge(b.eng))
        if (!(out.getOrNull(bi - 1)?.lat ?: "").startsWith("℣. Benedícite")) {
            out.add(bi, Hour.Part(type = "vr", label = "Versus", lat = "℣. Benedícite.", latR = "℟. Deus.", eng = "℣. Pray, Lord, a blessing.", engR = "℟. God."))
        }
    }

    private fun compline(out: MutableList<Hour.Part>, c: Ctx) {
        val pater = paterAveCredo
        // Adjutórium nostrum and the Pater noster (secreto) after the short reading
        val ri = out.indexOfFirst { it.type == "vr" && (it.label ?: "").startsWith("Short Reading") }
        if (ri >= 0 && !(out.getOrNull(ri + 1)?.lat ?: "").startsWith("℣. Adjutórium")) {
            val adds = ArrayList<Hour.Part>()
            adds.add(Hour.Part(type = "vr", label = "Versus", lat = "℣. Adjutórium nostrum ✠ in nómine Dómini.", latR = "℟. Qui fecit cælum et terram.",
                eng = "℣. Our help ✠ is in the name of the Lord.", engR = "℟. Who made heaven and earth."))
            if (pater != null) adds.add(Hour.Part(type = "pater", label = "Pater noster (secréto)", lat = pater.lat?.substringBefore("\n\n"), eng = pater.eng?.substringBefore("\n\n")))
            out.addAll(ri + 1, adds)
        }
        // Dómine, exáudi; Benedicámus; the blessing — before the Marian antiphon
        val mi = out.indexOfFirst { it.type == "marian" }
        if (mi >= 0 && !(out.getOrNull(mi - 1)?.lat ?: "").startsWith("Benedíctio. Benedícat")) {
            out.addAll(mi, listOf(
                domineExaudi(),
                Hour.Part(type = "vr", label = "Versus", lat = "℣. Benedicámus Dómino.", latR = "℟. Deo grátias.", eng = "℣. Let us bless the Lord.", engR = "℟. Thanks be to God."),
                Hour.Part(type = "vr", label = "Benedíctio", lat = "Benedíctio. Benedícat et custódiat nos omnípotens et miséricors Dóminus, ✠ Pater, et Fílius, et Spíritus Sanctus.", latR = "℟. Amen.",
                    eng = "Blessing. May the almighty and merciful Lord, ✠ the Father, the Son and the Holy Ghost, bless and keep us.", engR = "℟. Amen."),
            ))
        }
        // the older books add the Pater, Ave and Credo secreto after the Marian antiphon (marianTail adds Divínum auxílium)
        if (c.rite == MissalRite.PRE_1955 && pater != null && out.none { (it.label ?: "").contains("Credo (secréto)") }) {
            out.add(pater.copy(label = "Pater noster, Ave María, Credo (secréto)"))
        }
    }
}
