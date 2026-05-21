package com.lampstandhq.introibo.ui.missal

import android.content.Intent
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Share
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.unit.dp
import com.lampstandhq.introibo.data.content.ContentStore
import com.lampstandhq.introibo.data.liturgical.LiturgicalContext
import com.lampstandhq.introibo.data.liturgical.LiturgicalSeason
import com.lampstandhq.introibo.data.model.MassProper
import com.lampstandhq.introibo.data.model.MissalSection
import com.lampstandhq.introibo.data.model.ProperReading
import com.lampstandhq.introibo.data.model.ProperText
import com.lampstandhq.introibo.storage.settings.MissalRite
import com.lampstandhq.introibo.storage.settings.SettingsRepository
import com.lampstandhq.introibo.ui.components.BilingualLine
import com.lampstandhq.introibo.ui.components.SmallLabel
import com.lampstandhq.introibo.ui.theme.IntroiboTheme
import com.lampstandhq.introibo.ui.theme.IntroiboType

/**
 * Missal (Missa) tab screen. Displays the interleaved Ordinary + Propers
 * of the Mass. Ported from iOS MissalView.swift.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun MissalScreen() {
    val context = LocalContext.current
    val colors = IntroiboTheme.colors
    val type = IntroiboType.current

    val settingsRepo = remember { SettingsRepository(context) }
    val rite by settingsRepo.missalRite.collectAsState(initial = MissalRite.RITE_1962)

    var showProperDetail by rememberSaveable { mutableStateOf(false) }

    val ctx = remember { LiturgicalContext.current() }
    val todayProper = remember {
        ContentStore.properForDate(ctx.date) ?: ctx.properSlug?.let { ContentStore.proper(it) }
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(colors.pageBackground),
    ) {
        // Top app bar
        TopAppBar(
            title = {
                Column(
                    horizontalAlignment = Alignment.CenterHorizontally,
                    modifier = Modifier.fillMaxWidth(),
                ) {
                    Text(
                        text = todayProper?.english ?: "Ordo Missae",
                        style = type.titleM.copy(fontStyle = FontStyle.Italic),
                        color = colors.primaryText,
                    )
                    Row(
                        horizontalArrangement = Arrangement.Center,
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        SmallLabel(text = rite.short, color = colors.goldLeaf)
                        if (todayProper != null) {
                            Text(
                                text = "  ·  ",
                                style = type.captionSm,
                                color = colors.tertiaryText,
                            )
                            Text(
                                text = "View Propers",
                                style = type.captionSm.copy(fontStyle = FontStyle.Italic),
                                color = colors.sanctuaryRed,
                                modifier = Modifier.clickable { showProperDetail = true },
                            )
                        }
                    }
                }
            },
            actions = {
                IconButton(onClick = {
                    val shareText = buildFullMassText(todayProper, rite, ctx)
                    val shareIntent = Intent(Intent.ACTION_SEND).apply {
                        this.type = "text/plain"
                        putExtra(Intent.EXTRA_TEXT, shareText)
                    }
                    context.startActivity(Intent.createChooser(shareIntent, "Share Mass text"))
                }) {
                    Icon(
                        imageVector = Icons.Filled.Share,
                        contentDescription = "Share",
                        tint = colors.sanctuaryRed,
                    )
                }
            },
            colors = TopAppBarDefaults.topAppBarColors(
                containerColor = colors.pageBackground,
            ),
        )

        // Mass content
        LazyColumn(
            modifier = Modifier
                .fillMaxSize()
                .padding(horizontal = 20.dp),
            verticalArrangement = Arrangement.spacedBy(24.dp),
        ) {
            item { Spacer(Modifier.height(4.dp)) }

            if (todayProper != null) {
                // Interleaved Mass: Ordinary + Propers
                interleavedMassItems(todayProper, ctx, rite)
            } else {
                // Ordinary only
                items(
                    items = ContentStore.missal,
                    key = { it.slug },
                ) { section ->
                    OrdinarySectionBlock(section = section)
                }
            }

            item { Spacer(Modifier.height(40.dp)) }
        }
    }

    // Proper detail dialog
    if (showProperDetail && todayProper != null) {
        androidx.compose.ui.window.Dialog(
            onDismissRequest = { showProperDetail = false },
            properties = androidx.compose.ui.window.DialogProperties(usePlatformDefaultWidth = false),
        ) {
            ProperScreen(
                proper = todayProper,
                onDismiss = { showProperDetail = false },
            )
        }
    }
}

// ---------------------------------------------------------------------------
// Interleaved Mass content
// ---------------------------------------------------------------------------

private fun androidx.compose.foundation.lazy.LazyListScope.interleavedMassItems(
    proper: MassProper,
    ctx: LiturgicalContext,
    rite: MissalRite,
) {
    // Prayers at the Foot of the Altar
    // Omitted in Passiontide and Requiem Masses
    if (ctx.season != LiturgicalSeason.PASSION && proper.color != "black") {
        ordinaryItem("preces")
    }
    ordinaryItem("confiteor")

    // Introit
    item { ProperSection(latin = "Introitus", subtitle = "Introit", text = proper.introit) }

    // Kyrie
    ordinaryItem("kyrie")

    // Gloria — omitted in Advent, Lent, Passion, pre-Lent, violet/black
    if (showGloria(proper, ctx)) {
        ordinaryItem("gloria")
    }

    // Collect
    item { ProperSection(latin = "Oratio", subtitle = "Collect", text = proper.collect) }

    // Epistle
    item { ReadingSection(latin = "Lectio", subtitle = "Epistle", reading = proper.epistle) }

    // Gradual, Alleluia, Tract, Sequence
    proper.gradual?.let { item { ProperSection(latin = "Graduale", subtitle = "Gradual", text = it) } }
    proper.alleluia?.let { item { ProperSection(latin = "Alleluia", subtitle = "Alleluia", text = it) } }
    proper.tract?.let { item { ProperSection(latin = "Tractus", subtitle = "Tract", text = it) } }
    proper.sequence?.let { item { ProperSection(latin = "Sequentia", subtitle = "Sequence", text = it) } }

    // Gospel
    item { ReadingSection(latin = "Evangelium", subtitle = "Gospel", reading = proper.gospel) }

    // Credo — Sundays and rank-1 feasts only
    if (showCredo(proper, ctx)) {
        ordinaryItem("credo")
    }

    // Offertory
    item { ProperSection(latin = "Offertorium", subtitle = "Offertory", text = proper.offertory) }

    // Offertory prayers
    ordinaryItem("offertory_prayers")

    // Secret
    item { ProperSection(latin = "Secreta", subtitle = "Secret", text = proper.secret) }

    // Proper Preface selection
    val prefaceSlug = prefaceSlug(proper, ctx)
    if (ContentStore.missal.any { it.slug == prefaceSlug }) {
        ordinaryItem(prefaceSlug)
    } else {
        ordinaryItem("preface")
    }
    ordinaryItem("sanctus")
    canonWithProperInsertions(ctx, rite)
    ordinaryItem("pater")

    // Agnus Dei (Requiem form when color is black)
    if (proper.color == "black") {
        ordinaryItem("agnus-requiem")
    } else {
        ordinaryItem("agnus")
    }

    // Confiteor before Communion (pre-1955 rite; suppressed in 1962 and 1955)
    if (rite == MissalRite.PRE_1955) {
        ordinaryItem("confiteor-communion")
    }

    ordinaryItem("domine")

    // Communion
    item { ProperSection(latin = "Communio", subtitle = "Communion", text = proper.communion) }

    // Postcommunion
    item { ProperSection(latin = "Postcommunio", subtitle = "Postcommunion", text = proper.postcommunion) }

    // Placeat + Blessing (omitted in Requiem)
    if (proper.color != "black") {
        ordinaryItem("placeat")
    }

    // Dismissal
    if (proper.color == "black") {
        ordinaryItem("requiescant")
    } else if (showGloria(proper, ctx)) {
        ordinaryItem("ite")
    } else {
        ordinaryItem("benedicamus")
    }

    // Last Gospel — Palm Sunday in the pre-1955 rite substitutes Matt 21:1-9
    // for the standard Prologue of St. John.
    val lastGospelSlug = lastGospelOverride(ctx, rite) ?: "ultimum"
    ordinaryItem(lastGospelSlug)

    // Leonine Prayers
    ordinaryItem("leonine")
}

/**
 * Returns an alternate Last Gospel slug when the rubrics call for substitution.
 * Currently: Palm Sunday in the pre-1955 rite uses Matt 21 (the blessing-of-palms
 * gospel) as the Last Gospel of the principal Mass.
 */
private fun lastGospelOverride(ctx: LiturgicalContext, rite: MissalRite): String? {
    val slug = ctx.properSlug ?: ""
    if (rite == MissalRite.PRE_1955 && (slug == "palm-sunday" || slug == "quad6-0")) {
        return if (ContentStore.missal.any { it.slug == "ultimum-palm-sunday" }) {
            "ultimum-palm-sunday"
        } else null
    }
    return null
}

private fun prefaceSlug(proper: MassProper, ctx: LiturgicalContext): String {
    val explicit = proper.preface
    if (!explicit.isNullOrEmpty()) return "preface-$explicit"
    return when (ctx.season) {
        LiturgicalSeason.ADVENT -> "preface-advent"
        LiturgicalSeason.CHRISTMAS -> "preface-nativity"
        LiturgicalSeason.LENT -> "preface-lent"
        LiturgicalSeason.PASSION -> "preface-cross"
        LiturgicalSeason.EASTER -> "preface-easter"
        LiturgicalSeason.PENTECOST -> "preface-pentecost"
        LiturgicalSeason.PER_ANNUM -> "preface"
    }
}

private fun showGloria(proper: MassProper, ctx: LiturgicalContext): Boolean {
    // Honor explicit DO rubric rule when present.
    proper.glorOverride?.let { return it }
    if (ctx.season == LiturgicalSeason.EASTER || ctx.season == LiturgicalSeason.CHRISTMAS) return true
    if (proper.color == "violet" || proper.color == "black") return false
    if (ctx.isSunday) {
        val preLent = listOf("septuagesima", "sexagesima", "quinquagesima")
        if (ctx.properSlug in preLent) return false
        return ctx.season != LiturgicalSeason.ADVENT &&
               ctx.season != LiturgicalSeason.LENT &&
               ctx.season != LiturgicalSeason.PASSION
    }
    return proper.rank == 1
}

/**
 * Credo is said on all Sundays and on major feasts (rank 1 in data). Also
 * fires on feasts of Apostles, Evangelists, and Doctors regardless of legacy
 * rank, since these classes always have Credo per the rubrics (Ritus
 * servandus VI; cf. 1962 Rubricæ Generales nos. 475–477). Detected from the
 * officium string (preserved as the proper's title) to remain conservative —
 * only triggers on a clear textual signal.
 */
private fun showCredo(proper: MassProper, ctx: LiturgicalContext): Boolean {
    proper.credoOverride?.let { return it }
    if (ctx.isSunday) return true
    if (proper.rank == 1) return true
    if (isApostleEvangelistOrDoctor(proper)) return true
    return false
}

/**
 * Returns true when the officium (proper.title) names an Apostle,
 * Evangelist, or Doctor of the Church. Case-insensitive Latin match.
 */
private fun isApostleEvangelistOrDoctor(proper: MassProper): Boolean {
    val officium = proper.title.lowercase()
    val needles = listOf(
        "apostoli", "apostolorum",
        "evangelistæ", "evangelistae", "evangelistarum",
        "doctoris", "doctorum", "doctores",
    )
    return needles.any { officium.contains(it) }
}

/**
 * Returns the Communicantes/Hanc igitur variant key (if any) for the
 * current day, gated by rite.
 *
 * Rite scope:
 * - **PRE_1955** retains the full octaves of Easter and Pentecost: the proper
 *   Communicantes (and, for the two paschal octaves, the proper Hanc igitur)
 *   fires on every day of the octave (feast + six weekdays through Saturday).
 * - **RITE_1955** keeps the Easter and Pentecost octaves intact for Canon
 *   purposes — same behavior as pre-1955 for this gating.
 * - **RITE_1962** (Codex Rubricarum 1960) abolished the octaves of Easter and
 *   Pentecost as such. Only the feast day itself (Easter/Pentecost Sunday) and
 *   the Monday keep the proper insertion. From Tuesday onward the standard
 *   Communicantes is used.
 * - Christmas, Epiphany, and Ascension behave identically across all three rites.
 */
private fun canonVariantKey(slug: String?, rite: MissalRite): String? {
    if (slug == null) return null

    // Christmas (Dec 25 + octave days named "christmas-...")
    if (slug == "christmas" || slug.startsWith("christmas-")) return "christmas"

    // Epiphany (Jan 6)
    if (slug == "epiphany") return "epiphany"

    // Ascension Thursday
    if (slug == "ascension") return "ascension"

    // Easter octave: easter-sunday + easter-0-1..6 (Mon..Sat in albis)
    if (slug == "easter-sunday") return "easter"
    if (slug.startsWith("easter-0-")) {
        return when (rite) {
            MissalRite.PRE_1955, MissalRite.RITE_1955 -> "easter"
            MissalRite.RITE_1962 ->
                // Only Easter Monday keeps the proper insertion.
                if (slug == "easter-0-1") "easter" else null
        }
    }

    // Pentecost octave: pentecost-sunday + easter-7-1..6
    if (slug == "pentecost-sunday") return "pentecost"
    if (slug.startsWith("easter-7-")) {
        return when (rite) {
            MissalRite.PRE_1955, MissalRite.RITE_1955 -> "pentecost"
            MissalRite.RITE_1962 ->
                // Only Pentecost Monday keeps the proper insertion.
                if (slug == "easter-7-1") "pentecost" else null
        }
    }

    return null
}

/**
 * Emit the Canon section with proper Communicantes/Hanc igitur insertions
 * for Christmas, Epiphany, Easter, Ascension, and Pentecost. Falls back to
 * the plain Canon when no variant applies.
 */
private fun androidx.compose.foundation.lazy.LazyListScope.canonWithProperInsertions(
    ctx: LiturgicalContext,
    rite: MissalRite,
) {
    val variantKey = canonVariantKey(ctx.properSlug, rite)
    val section = ContentStore.missal.firstOrNull { it.slug == "canon" }

    if (variantKey != null && section != null) {
        val modifiedBody = section.body.map { line ->
            var lat = line.lat
            var eng = line.eng
            if (line.lat.startsWith("Commúnicántes")) {
                val variant = ContentStore.canonVariant("communicantes", variantKey)
                if (variant != null) {
                    lat = variant.first
                    eng = variant.second
                }
            }
            if (line.lat.startsWith("Hanc ígitur")) {
                val variant = ContentStore.canonVariant("hanc_igitur", variantKey)
                if (variant != null) {
                    lat = variant.first
                    eng = variant.second
                }
            }
            MissalSection.Line(lat = lat, eng = eng, rubric = line.rubric)
        }
        val modifiedSection = MissalSection(
            slug = section.slug,
            label = section.label,
            title = section.title,
            english = section.english,
            body = modifiedBody,
        )
        item(key = "ordinary_canon") {
            OrdinarySectionBlock(section = modifiedSection)
        }
    } else {
        ordinaryItem("canon")
    }
}

private fun androidx.compose.foundation.lazy.LazyListScope.ordinaryItem(slug: String) {
    val section = ContentStore.missal.firstOrNull { it.slug == slug }
    if (section != null) {
        item(key = "ordinary_$slug") {
            OrdinarySectionBlock(section = section)
        }
    }
}

// ---------------------------------------------------------------------------
// Ordinary section
// ---------------------------------------------------------------------------

@Composable
fun OrdinarySectionBlock(section: MissalSection) {
    val colors = IntroiboTheme.colors
    val type = IntroiboType.current

    Column(
        modifier = Modifier.fillMaxWidth(),
    ) {
        // Section label with gold dividers
        section.label?.let { label ->
            Row(
                verticalAlignment = Alignment.CenterVertically,
                modifier = Modifier.fillMaxWidth(),
            ) {
                Box(
                    modifier = Modifier
                        .weight(1f)
                        .height(0.5.dp)
                        .background(colors.goldLeaf.copy(alpha = 0.4f)),
                )
                SmallLabel(
                    text = label,
                    color = colors.sanctuaryRed,
                    modifier = Modifier.padding(horizontal = 10.dp),
                )
                Box(
                    modifier = Modifier
                        .weight(1f)
                        .height(0.5.dp)
                        .background(colors.goldLeaf.copy(alpha = 0.4f)),
                )
            }
            Spacer(Modifier.height(12.dp))
        }

        // Title + English subtitle
        Text(
            text = section.title,
            style = type.titleL.copy(fontStyle = FontStyle.Italic),
            color = colors.primaryText,
        )
        section.english?.let { eng ->
            Text(
                text = eng,
                style = type.captionSm.copy(fontStyle = FontStyle.Italic),
                color = colors.secondaryText,
                modifier = Modifier.padding(top = 2.dp),
            )
        }

        Spacer(Modifier.height(8.dp))

        // Body lines
        section.body.forEach { line ->
            Column(modifier = Modifier.padding(bottom = 16.dp)) {
                // Rubric in red italic
                line.rubric?.let { rubric ->
                    Text(
                        text = rubric,
                        style = type.captionSm.copy(fontStyle = FontStyle.Italic),
                        color = colors.sanctuaryRed,
                        modifier = Modifier.padding(bottom = 4.dp),
                    )
                }
                BilingualLine(lat = line.lat, eng = line.eng, sideBySide = true)
            }
        }
    }
}

// ---------------------------------------------------------------------------
// Proper section
// ---------------------------------------------------------------------------

@Composable
fun ProperSection(
    latin: String,
    subtitle: String,
    text: ProperText,
) {
    val colors = IntroiboTheme.colors

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 4.dp)
            .padding(start = 4.dp),
    ) {
        // Header with red dividers
        Row(
            verticalAlignment = Alignment.CenterVertically,
            modifier = Modifier.fillMaxWidth(),
        ) {
            Box(
                modifier = Modifier
                    .weight(1f)
                    .height(1.dp)
                    .background(colors.sanctuaryRed.copy(alpha = 0.5f)),
            )
            SmallLabel(
                text = "$latin  ·  $subtitle",
                color = colors.sanctuaryRed,
                modifier = Modifier.padding(horizontal = 10.dp),
            )
            Box(
                modifier = Modifier
                    .weight(1f)
                    .height(1.dp)
                    .background(colors.sanctuaryRed.copy(alpha = 0.5f)),
            )
        }

        Spacer(Modifier.height(8.dp))

        // Red left bar accent
        Row(modifier = Modifier.fillMaxWidth()) {
            Box(
                modifier = Modifier
                    .width(2.dp)
                    .background(colors.sanctuaryRed.copy(alpha = 0.15f)),
            )
            Column(modifier = Modifier.padding(start = 8.dp)) {
                BilingualLine(lat = text.lat, eng = text.eng, sideBySide = true)
            }
        }
    }
}

// ---------------------------------------------------------------------------
// Reading section (has a scripture reference)
// ---------------------------------------------------------------------------

@Composable
fun ReadingSection(
    latin: String,
    subtitle: String,
    reading: ProperReading,
) {
    val colors = IntroiboTheme.colors
    val type = IntroiboType.current

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 4.dp)
            .padding(start = 4.dp),
    ) {
        // Header with red dividers
        Row(
            verticalAlignment = Alignment.CenterVertically,
            modifier = Modifier.fillMaxWidth(),
        ) {
            Box(
                modifier = Modifier
                    .weight(1f)
                    .height(1.dp)
                    .background(colors.sanctuaryRed.copy(alpha = 0.5f)),
            )
            SmallLabel(
                text = "$latin  ·  $subtitle",
                color = colors.sanctuaryRed,
                modifier = Modifier.padding(horizontal = 10.dp),
            )
            Box(
                modifier = Modifier
                    .weight(1f)
                    .height(1.dp)
                    .background(colors.sanctuaryRed.copy(alpha = 0.5f)),
            )
        }

        Spacer(Modifier.height(8.dp))

        // Red left bar accent
        Row(modifier = Modifier.fillMaxWidth()) {
            Box(
                modifier = Modifier
                    .width(2.dp)
                    .background(colors.sanctuaryRed.copy(alpha = 0.15f)),
            )
            Column(modifier = Modifier.padding(start = 8.dp)) {
                if (reading.ref.isNotEmpty()) {
                    Text(
                        text = reading.ref,
                        style = type.captionSm,
                        color = colors.goldLeaf,
                        modifier = Modifier.padding(bottom = 4.dp),
                    )
                }
                BilingualLine(lat = reading.lat, eng = reading.eng, sideBySide = true)
            }
        }
    }
}

// ---------------------------------------------------------------------------
// Full Mass text export
// ---------------------------------------------------------------------------

private fun buildFullMassText(
    proper: MassProper?,
    rite: MissalRite,
    ctx: LiturgicalContext,
): String {
    val lines = mutableListOf<String>()

    if (proper != null) {
        lines.add(proper.title)
        lines.add(proper.english)
        lines.add(rite.short)
        lines.add("")
    } else {
        lines.add("Ordo Missae")
        lines.add(rite.short)
        lines.add("")
    }

    fun addOrdinary(slug: String) {
        val section = ContentStore.missal.firstOrNull { it.slug == slug } ?: return
        lines.add("=== ${section.title} ===")
        section.english?.let { lines.add(it) }
        lines.add("")
        section.body.forEach { line ->
            lines.add(line.lat)
            lines.add(line.eng)
            lines.add("")
        }
    }

    fun addProper(label: String, lat: String, eng: String) {
        lines.add("--- $label ---")
        lines.add(lat)
        lines.add(eng)
        lines.add("")
    }

    fun addReading(label: String, ref: String, lat: String, eng: String) {
        lines.add("--- $label ---")
        if (ref.isNotEmpty()) lines.add(ref)
        lines.add(lat)
        lines.add(eng)
        lines.add("")
    }

    // Psalm 42 omitted in Passiontide and Requiem Masses
    if (proper != null) {
        if (ctx.season != LiturgicalSeason.PASSION && proper.color != "black") {
            addOrdinary("preces")
        }
    } else {
        addOrdinary("preces")
    }
    addOrdinary("confiteor")

    proper?.let { p ->
        addProper("Introitus · Introit", p.introit.lat, p.introit.eng)
    }

    addOrdinary("kyrie")
    // Gloria — conditional via showGloria when proper is present
    if (proper != null) {
        if (showGloria(proper, ctx)) addOrdinary("gloria")
    } else {
        addOrdinary("gloria")
    }

    proper?.let { p ->
        addProper("Oratio · Collect", p.collect.lat, p.collect.eng)
        addReading("Lectio · Epistle", p.epistle.ref, p.epistle.lat, p.epistle.eng)
        p.gradual?.let { addProper("Graduale · Gradual", it.lat, it.eng) }
        p.alleluia?.let { addProper("Alleluia", it.lat, it.eng) }
        p.tract?.let { addProper("Tractus · Tract", it.lat, it.eng) }
        p.sequence?.let { addProper("Sequentia · Sequence", it.lat, it.eng) }
        addReading("Evangelium · Gospel", p.gospel.ref, p.gospel.lat, p.gospel.eng)
    }

    // Credo — conditional when proper is present (Sundays, rank-1, Apostles/Doctors/Evangelists)
    if (proper != null) {
        if (showCredo(proper, ctx)) addOrdinary("credo")
    } else {
        addOrdinary("credo")
    }

    proper?.let { p ->
        addProper("Offertorium · Offertory", p.offertory.lat, p.offertory.eng)
    }

    addOrdinary("offertory_prayers")

    proper?.let { p ->
        addProper("Secreta · Secret", p.secret.lat, p.secret.eng)
    }

    // Preface — select proper preface for the season/feast
    val resolvedPreface = if (proper != null) {
        prefaceSlug(proper, ctx)
    } else {
        "preface"
    }
    if (ContentStore.missal.any { it.slug == resolvedPreface }) {
        addOrdinary(resolvedPreface)
    } else {
        addOrdinary("preface")
    }
    addOrdinary("sanctus")

    // Canon — with proper Communicantes/Hanc igitur insertions when applicable
    val variantKey = canonVariantKey(ctx.properSlug, rite)
    val canonSection = ContentStore.missal.firstOrNull { it.slug == "canon" }
    if (variantKey != null && canonSection != null) {
        lines.add("=== ${canonSection.title} ===")
        canonSection.english?.let { lines.add(it) }
        lines.add("")
        canonSection.body.forEach { line ->
            var lat = line.lat
            var eng = line.eng
            if (line.lat.startsWith("Commúnicántes")) {
                val variant = ContentStore.canonVariant("communicantes", variantKey)
                if (variant != null) { lat = variant.first; eng = variant.second }
            }
            if (line.lat.startsWith("Hanc ígitur")) {
                val variant = ContentStore.canonVariant("hanc_igitur", variantKey)
                if (variant != null) { lat = variant.first; eng = variant.second }
            }
            lines.add(lat)
            lines.add(eng)
            lines.add("")
        }
    } else {
        addOrdinary("canon")
    }

    addOrdinary("pater")
    // Agnus Dei — Requiem form for black-color Masses
    if (proper?.color == "black") {
        addOrdinary("agnus-requiem")
    } else {
        addOrdinary("agnus")
    }
    addOrdinary("domine")

    proper?.let { p ->
        addProper("Communio · Communion", p.communion.lat, p.communion.eng)
    }

    proper?.let { p ->
        addProper("Postcommunio · Postcommunion", p.postcommunion.lat, p.postcommunion.eng)
    }

    // Placeat + Blessing — omitted in Requiem Masses
    if (proper?.color != "black") {
        addOrdinary("placeat")
    }

    // Dismissal: Requiescant for black, Ite when Gloria was said, Benedicamus otherwise.
    if (proper != null) {
        when {
            proper.color == "black" -> addOrdinary("requiescant")
            showGloria(proper, ctx) -> addOrdinary("ite")
            else -> addOrdinary("benedicamus")
        }
    } else {
        addOrdinary("ite")
    }

    addOrdinary("ultimum")
    addOrdinary("leonine")

    return lines.joinToString("\n")
}
