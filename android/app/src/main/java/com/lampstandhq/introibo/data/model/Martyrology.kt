package com.lampstandhq.introibo.data.model

import kotlinx.serialization.Serializable

/**
 * Matches martyrology.json — the Martyrologium Romanum (1960 edition) read
 * in the second part of Prime. [days] is keyed "MM-DD"; [mobile] holds the
 * movable-feast announcements keyed by the temporal day code (e.g.
 * "pasc0-1"). The Martyrology read at Prime on day D is the entry for D+1,
 * as in choir.
 */
@Serializable
data class MartyrologyEntry(
    val lat: String,
    val eng: String,
)

@Serializable
data class MartyrologyDay(
    /** The Roman date, e.g. "Octávo Kaléndas Aprílis". */
    val title: String,
    val entries: List<MartyrologyEntry>,
)

@Serializable
data class MartyrologyData(
    val days: Map<String, MartyrologyDay>,
    val mobile: Map<String, MartyrologyEntry>,
    /** "en" or "es": which vernacular the eng fields currently carry. */
    val vernacular: String = "en",
)

/**
 * The lunar age printed at the head of the Martyrology ("Luna sexta"),
 * after the epact tables of the Martyrologium Romanum. A direct port of
 * Divinum Officium's specprima.pl, validated against it for 2024–2028.
 */
object MartyrologyLuna {
    private const val LETTERS = "abcdefghiklmnpqrstuABCDERFGHMNP"

    private fun isLeap(y: Int) = y % 4 == 0 && (y % 100 != 0 || y % 400 == 0)

    private fun yearDay(d: Int, m: Int, y: Int): Int {
        val c = intArrayOf(0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334)
        var n = c[m - 1] + d
        if (isLeap(y) && m > 2) n += 1
        return n
    }

    private fun table(yday: Int, letter: Char): Int {
        val lp = LETTERS.indexOf(letter) + 1
        val m = if (yday < 36) 30 else {
            var r = (yday - 35) % 59
            if (r == 0) r = 59
            if (r < 29) 29 else 30
        }
        var i = if (yday % 59 < 36) lp else lp - 1
        if (yday % 59 < 36) {
            if (lp > 25) i -= 1
            if (lp == 25 && yday % 59 == 35) i += 1
        } else {
            if (lp > 25) i -= 2
        }
        if (yday > 58) {
            if (lp > 25 && yday % 59 < 5) i -= 1
            if (lp == 26 && yday % 59 == 5) i -= 1
        }
        var v = (i - 1 + (yday % 59)) % m
        if (v < 0) v += m
        return v + 1
    }

    /** Age of the moon (1–30) for a civil date; null outside 1700–2299. */
    fun lunarAge(month: Int, day: Int, year: Int): Int? {
        val tbl = when {
            year < 1700 -> return null
            year < 1900 -> "PlCcpFfsMiAamDdqGgt"
            year < 2200 -> "NkBbnEerHhuPlCcpRfs"
            year < 2300 -> "MiAamDdqGgtNkBbnEer"
            else -> return null
        }
        val aur = year % 19 + 1
        val letter = tbl[aur - 1]
        var yd = yearDay(day, month, year)
        if (isLeap(year) && (month > 2 || (month == 2 && day > 23))) yd -= 1
        var l = table(yd, letter)
        if (aur == 1 && month == 1 && letter != 'P' && day + table(1, letter) < 32) l -= 1
        return l
    }

    val latinOrdinals = listOf(
        "prima", "secúnda", "tértia", "quarta", "quinta", "sexta", "séptima", "octáva", "nona", "décima",
        "undécima", "duodécima", "tértia décima", "quarta décima", "quinta décima", "sexta décima",
        "décima séptima", "duodevicésima", "undevicésima", "vicésima", "vicésima prima", "vicésima secúnda",
        "vicésima tértia", "vicésima quarta", "vicésima quinta", "vicésima sexta", "vicésima séptima",
        "vicésima octáva", "vicésima nona", "tricésima",
    )
    val spanishOrdinals = listOf(
        "primera", "segunda", "tercera", "cuarta", "quinta", "sexta", "séptima", "octava", "novena", "décima",
        "undécima", "duodécima", "decimotercera", "decimocuarta", "decimoquinta", "decimosexta",
        "decimoséptima", "decimoctava", "decimonovena", "vigésima", "vigésima primera", "vigésima segunda",
        "vigésima tercera", "vigésima cuarta", "vigésima quinta", "vigésima sexta", "vigésima séptima",
        "vigésima octava", "vigésima novena", "trigésima",
    )
    val englishMonths = listOf("January", "February", "March", "April", "May", "June", "July", "August",
        "September", "October", "November", "December")
    val spanishMonths = listOf("enero", "febrero", "marzo", "abril", "mayo", "junio", "julio", "agosto",
        "septiembre", "octubre", "noviembre", "diciembre")

    fun englishOrdinal(n: Int): String {
        val suffix = if (n % 100 in 11..13) "th" else when (n % 10) { 1 -> "st"; 2 -> "nd"; 3 -> "rd"; else -> "th" }
        return "$n$suffix"
    }
}
