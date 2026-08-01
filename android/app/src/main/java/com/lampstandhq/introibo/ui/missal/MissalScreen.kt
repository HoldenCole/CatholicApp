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
import androidx.compose.material3.DropdownMenu
import androidx.compose.material3.DropdownMenuItem
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
import com.lampstandhq.introibo.export.MassHTMLExporter
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
    val showLeonine by settingsRepo.showLeoninePrayers.collectAsState(initial = true)

    var showProperDetail by rememberSaveable { mutableStateOf(false) }

    // Rebuild context and proper whenever the rite setting changes so a
    // 1955/pre-1955 user sees their rite's Mass (iOS parity).
    val ctx = remember(rite) { LiturgicalContext.forDate(java.time.LocalDate.now(), rite = rite) }
    val todayProper = remember(rite) {
        ContentStore.properForDate(ctx.date, rite) ?: ctx.properSlug?.let { ContentStore.proper(it) }
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
                        text = todayProper?.englishTitle ?: "Ordo Missae",
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
                var showShareMenu by remember { mutableStateOf(false) }
                Box {
                    IconButton(onClick = { showShareMenu = true }) {
                        Icon(
                            imageVector = Icons.Filled.Share,
                            contentDescription = "Share",
                            tint = colors.sanctuaryRed,
                        )
                    }
                    DropdownMenu(expanded = showShareMenu, onDismissRequest = { showShareMenu = false }) {
                        DropdownMenuItem(
                            text = { Text("Share as PDF") },
                            onClick = {
                                showShareMenu = false
                                val items = buildFullMassItems(todayProper, rite, ctx, showLeonine)
                                val html = com.lampstandhq.introibo.export.MassHTMLExporter.massHTML(
                                    title = todayProper?.title ?: "Ordo Miss\u00e6",
                                    englishTitle = todayProper?.englishTitle ?: rite.short,
                                    sections = items.map { it.toHtmlSection() },
                                )
                                com.lampstandhq.introibo.export.PDFExporter.sharePDF(
                                    context, html,
                                    fileName = todayProper?.title ?: "Ordo Missae",
                                    title = "Share Mass",
                                )
                            },
                        )
                        DropdownMenuItem(
                            text = { Text("Share as Text") },
                            onClick = {
                                showShareMenu = false
                                val shareText = buildFullMassText(todayProper, rite, ctx, showLeonine)
                                val shareIntent = Intent(Intent.ACTION_SEND).apply {
                                    this.type = "text/plain"
                                    putExtra(Intent.EXTRA_TEXT, shareText)
                                }
                                context.startActivity(Intent.createChooser(shareIntent, "Share Mass text"))
                            },
                        )
                    }
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
                interleavedMassItems(todayProper, ctx, rite, showLeonine)
            } else {
                // Ordinary only — hide sections that appear only when selected
                // for a specific season/feast/rite (iOS parity).
                items(
                    items = ContentStore.missal.filter { it.slug !in properPrefaceSlugs },
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
    showLeonine: Boolean = true,
) {
    // Prayers at the Foot of the Altar
    // Omitted in Passiontide and Requiem Masses
    if (ctx.season != LiturgicalSeason.PASSION && proper.color != "black") {
        ordinaryItem("preces")
    }
    ordinaryItem("confiteor")

    // Introit
    item {
        // Gloria Patri suppressed from the Introit in Passiontide (iOS parity).
        val introit = if (ctx.season == LiturgicalSeason.PASSION) stripGloriaPatri(proper.introit) else proper.introit
        ProperSection(latin = "Introitus", subtitle = "Introit", text = introit)
    }

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
    ordinaryItem("libera")

    // Agnus Dei (Requiem form when color is black)
    if (proper.color == "black") {
        ordinaryItem("agnus-requiem")
    } else {
        ordinaryItem("agnus")
    }

    // The priest's communion prayers and communion, then the Confiteor and
    // communion of the faithful (retained in preconciliar practice;
    // suppressed by Inter Oecumenici 1964).
    ordinaryItem("orationes-ante-communionem")
    ordinaryItem("panem-caelestem")
    ordinaryItem("domine")
    ordinaryItem("communio-sacerdotis")
    ordinaryItem("confiteor-communion")

    // Communion
    item { ProperSection(latin = "Communio", subtitle = "Communion", text = proper.communion) }

    ordinaryItem("ablutiones")

    // Postcommunion
    item { ProperSection(latin = "Postcommunio", subtitle = "Postcommunion", text = proper.postcommunion) }

    // Dismissal precedes the Placeat: doubled-Alleluia form during the
    // EASTER Octave only; the 1960 rubrics say Ite missa est even when the
    // Gloria is not said.
    if (proper.color == "black") {
        ordinaryItem("requiescant")
    } else if (isEasterOctave(ctx)) {
        ordinaryItem("ite-alleluia")
    } else if (showGloria(proper, ctx) || rite == MissalRite.RITE_1962) {
        ordinaryItem("ite")
    } else {
        ordinaryItem("benedicamus")
    }

    // Placeat is said at every Mass; the blessing alone is omitted at Requiems.
    ordinaryItem("placeat")
    if (proper.color != "black") {
        ordinaryItem("benedictio")
    }

    // Last Gospel — Palm Sunday in the pre-1955 rite substitutes Matt 21:1-9
    // for the standard Prologue of St. John.
    val lastGospelSlug = lastGospelOverride(ctx, rite) ?: "ultimum"
    ordinaryItem(lastGospelSlug)

    // Leonine Prayers — gated by user setting (default: shown for strict 1962 observance)
    if (showLeonine) {
        ordinaryItem("leonine")
    }
}

/**
 * Returns an alternate Last Gospel slug when the rubrics call for substitution.
 * Currently: Palm Sunday in the pre-1955 rite uses Matt 21 (the blessing-of-palms
 * gospel) as the Last Gospel of the principal Mass.
 */
/** Sections shown only when selected for a season/feast/rite (iOS parity). */
private val properPrefaceSlugs = setOf(
    "preface-advent", "preface-nativity", "preface-epiphany",
    "preface-lent", "preface-cross", "preface-easter",
    "preface-ascension", "preface-pentecost", "preface-trinity",
    "preface-bvm", "preface-joseph", "preface-apostles",
    "preface-requiem",
    "agnus-requiem",
    "ite-alleluia",
)

/**
 * Strips the Gloria Patri doxology from a proper text (the Introit during
 * Passiontide — the Gloria Patri is suppressed from Passion Sunday until
 * the Easter Vigil). Port of iOS MissalView.stripGloriaPatri.
 */
private fun stripGloriaPatri(text: ProperText): ProperText {
    val lat = text.lat
        .replace(Regex("""\s*℣\.?\s*Glória Patri[^℣]*$"""), "")
        .replace(Regex("""\s*Glória Patri,\s*et Fílio.*?(Amen\.|Sancto\.)"""), "")
    val eng = text.eng
        .replace(Regex("""\s*℣\.?\s*Glory be to the Father[^℣]*$"""), "")
        .replace(Regex("""\s*Glory be to the Father,?\s*and to the Son.*?(Amen\.|Ghost\.)"""), "")
    return ProperText(lat = lat, eng = eng, ref = text.ref)
}

private fun lastGospelOverride(ctx: LiturgicalContext, rite: MissalRite): String? {
    val slug = ctx.properSlug ?: ""
    if (rite == MissalRite.PRE_1955 && (slug == "palm-sunday" || slug == "quad6-0")) {
        return if (ContentStore.missal.any { it.slug == "ultimum-palm-sunday" }) {
            "ultimum-palm-sunday"
        } else null
    }
    return null
}

/**
 * The doubled "Ite, missa est, alleluia" belongs to the EASTER octave only
 * (Pentecost's octave keeps the ordinary dismissal).
 */
private fun isEasterOctave(ctx: LiturgicalContext): Boolean {
    val key = ctx.temporalKey ?: return false
    return key.startsWith("pasc0-")
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
    if (proper.color == "violet" || proper.color == "black") return false
    if (ctx.season == LiturgicalSeason.EASTER || ctx.season == LiturgicalSeason.CHRISTMAS) return true
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
 * The 1962 Canon (decree of 13 Nov 1962) adds "sed et beati Joseph, ejusdem
 * Virginis Sponsi" to the Communicantes; the older rites do not.
 */
private fun withJosephClause(line: MissalSection.Line, rite: MissalRite): MissalSection.Line {
    if (rite != MissalRite.RITE_1962) return line
    if (!(line.lat.startsWith("Commúnicántes") || line.lat.startsWith("Communicántes"))) return line
    if ("beáti Joseph" in line.lat) return line
    var lat = line.lat.replace(
        "Jesu Christi: sed et",
        "Jesu Christi: sed et beáti Joseph, ejúsdem Vírginis Sponsi: sed et",
    )
    var eng = line.eng.replaceFirst(
        ": and also of the blessed Apostles",
        ": and also of blessed Joseph, spouse of the same Virgin: and also of the blessed Apostles",
    )
    return MissalSection.Line(lat = lat, eng = eng, rubric = line.rubric)
}

/**
 * Returns the Communicantes/Hanc igitur variant key (if any) for the current
 * day. Identical across all three rites: the 1960 Codex Rubricarum retained
 * the octaves of Easter and Pentecost (abolishing all the others except
 * Christmas), so the proper texts run the whole octave everywhere; Christmas
 * runs through its octave day (Jan 1), and Epiphany/Ascension fire on the
 * feast itself.
 */
private fun canonVariantKey(slug: String?, temporalKey: String?, rite: MissalRite): String? {
    // Nativity: Christmas through its octave day (the Circumcision, Jan 1)
    // and the Sunday within the octave. NOT the Holy Name Sunday
    // (christmas-2, Jan 2-5) and NOT the Jan 2-5 ferias — the octave ended.
    if (temporalKey != null && temporalKey.startsWith("nat") &&
        !temporalKey.startsWith("nat2") &&
        temporalKey !in setOf("nat08", "nat09", "nat10", "nat11")
    ) {
        return "christmas"
    }
    if (slug == null) return null

    if (slug == "christmas" || slug == "christmas-1" || slug == "circumcision") return "christmas"
    if (slug == "st-stephen" || slug == "holy-innocents") return "christmas"
    if (slug.startsWith("sancti-12-2") || slug.startsWith("sancti-12-3")) return "christmas"

    if (slug == "epiphany") return "epiphany"
    if (slug == "ascension") return "ascension"

    // The 1960 Codex Rubricarum RETAINED the octaves of Easter and
    // Pentecost (it abolished all the others): the proper Communicantes and
    // Hanc igitur run the whole octave in all three rites, vigils included.
    if (slug == "easter-sunday" || slug == "holy-saturday" || slug.startsWith("easter-0-")) {
        return "easter"
    }
    if (slug == "pentecost-sunday" || slug == "vigil-pentecost" || slug.startsWith("easter-7-")) {
        return "pentecost"
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
    val variantKey = canonVariantKey(ctx.properSlug, ctx.temporalKey, rite)
    val section = ContentStore.missal.firstOrNull { it.slug == "canon" }

    if (variantKey != null && section != null) {
        val modifiedBody = section.body.map { line ->
            var lat = line.lat
            var eng = line.eng
            if (line.lat.startsWith("Commúnicántes") || line.lat.startsWith("Communicántes")) {
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
            withJosephClause(MissalSection.Line(lat = lat, eng = eng, rubric = line.rubric), rite)
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
    } else if (section != null) {
        val modified = MissalSection(
            slug = section.slug, label = section.label,
            title = section.title, english = section.english,
            body = section.body.map { withJosephClause(it, rite) },
        )
        item(key = "ordinary_canon") { OrdinarySectionBlock(section = modified) }
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

/**
 * One shared walk of the interleaved Mass (Ordinary + Propers). The text
 * share and the PDF render from the same items so they can never drift.
 */
private sealed class MassShareItem {
    /** An Ordinary section; canonStyle marks the Canon's bespoke text layout. */
    data class Ordinary(
        val title: String,
        val english: String?,
        val pairs: List<Pair<String, String>>,
        val canonStyle: Boolean = false,
    ) : MassShareItem()

    data class ProperText(
        val label: String,
        val lat: String,
        val eng: String,
        val ref: String? = null,
    ) : MassShareItem()

    fun toHtmlSection(): MassHTMLExporter.MassSection = when (this) {
        is Ordinary -> MassHTMLExporter.MassSection(
            label = english?.let { "$title  ·  $it" } ?: title,
            lat = pairs.joinToString("\n") { it.first },
            eng = pairs.joinToString("\n") { it.second },
        )
        is ProperText -> MassHTMLExporter.MassSection(label, lat, eng, ref)
    }
}

private fun buildFullMassItems(
    proper: MassProper?,
    rite: MissalRite,
    ctx: LiturgicalContext,
    showLeonine: Boolean = true,
): List<MassShareItem> {
    val items = mutableListOf<MassShareItem>()

    fun addOrdinary(slug: String) {
        val section = ContentStore.missal.firstOrNull { it.slug == slug } ?: return
        items.add(MassShareItem.Ordinary(
            title = section.title,
            english = section.english,
            pairs = section.body.map { it.lat to it.eng },
        ))
    }

    fun addProper(label: String, lat: String, eng: String, ref: String? = null) {
        items.add(MassShareItem.ProperText(label, lat, eng, ref))
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
        val introit = if (ctx.season == LiturgicalSeason.PASSION) stripGloriaPatri(p.introit) else p.introit
        addProper("Introitus · Introit", introit.lat, introit.eng)
    }

    addOrdinary("kyrie")
    // Gloria — conditional via showGloria when proper is present
    if (proper != null) {
        if (showGloria(proper, ctx)) addOrdinary("gloria")
    } else {
        addOrdinary("gloria")
    }

    proper?.let { p ->
        addProper("Orátio · Collect", p.collect.lat, p.collect.eng)
        addProper("Léctio · Epistle", p.epistle.lat, p.epistle.eng, p.epistle.ref)
        p.gradual?.let { addProper("Graduále · Gradual", it.lat, it.eng) }
        p.alleluia?.let { addProper("Allelúja", it.lat, it.eng) }
        p.tract?.let { addProper("Tractus · Tract", it.lat, it.eng) }
        p.sequence?.let { addProper("Sequéntia · Sequence", it.lat, it.eng) }
        addProper("Evangélium · Gospel", p.gospel.lat, p.gospel.eng, p.gospel.ref)
    }

    // Credo — conditional when proper is present (Sundays, rank-1, Apostles/Doctors/Evangelists)
    if (proper != null) {
        if (showCredo(proper, ctx)) addOrdinary("credo")
    } else {
        addOrdinary("credo")
    }

    proper?.let { p ->
        addProper("Offertórium · Offertory", p.offertory.lat, p.offertory.eng)
    }

    addOrdinary("offertory_prayers")

    proper?.let { p ->
        addProper("Secréta · Secret", p.secret.lat, p.secret.eng)
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
    val variantKey = canonVariantKey(ctx.properSlug, ctx.temporalKey, rite)
    val canonSection = ContentStore.missal.firstOrNull { it.slug == "canon" }
    if (variantKey != null && canonSection != null) {
        val pairs = canonSection.body.map { line ->
            var lat = line.lat
            var eng = line.eng
            if (line.lat.startsWith("Commúnicántes") || line.lat.startsWith("Communicántes")) {
                val variant = ContentStore.canonVariant("communicantes", variantKey)
                if (variant != null) { lat = variant.first; eng = variant.second }
            }
            if (line.lat.startsWith("Hanc ígitur")) {
                val variant = ContentStore.canonVariant("hanc_igitur", variantKey)
                if (variant != null) { lat = variant.first; eng = variant.second }
            }
            val jl = withJosephClause(MissalSection.Line(lat = lat, eng = eng, rubric = line.rubric), rite)
            jl.lat to jl.eng
        }
        items.add(MassShareItem.Ordinary(
            title = canonSection.title,
            english = canonSection.english,
            pairs = pairs,
            canonStyle = true,
        ))
    } else if (canonSection != null) {
        val pairs = canonSection.body.map { line ->
            val jl = withJosephClause(line, rite)
            jl.lat to jl.eng
        }
        items.add(MassShareItem.Ordinary(
            title = canonSection.title,
            english = canonSection.english,
            pairs = pairs,
            canonStyle = true,
        ))
    } else {
        addOrdinary("canon")
    }

    addOrdinary("pater")
    addOrdinary("libera")
    // Agnus Dei — Requiem form for black-color Masses
    if (proper?.color == "black") {
        addOrdinary("agnus-requiem")
    } else {
        addOrdinary("agnus")
    }
    addOrdinary("orationes-ante-communionem")
    addOrdinary("panem-caelestem")
    addOrdinary("domine")
    addOrdinary("communio-sacerdotis")
    // Confiteor before Communion — retained in preconciliar practice
    addOrdinary("confiteor-communion")

    proper?.let { p ->
        addProper("Commúnio · Communion", p.communion.lat, p.communion.eng)
    }
    addOrdinary("ablutiones")

    proper?.let { p ->
        addProper("Postcommúnio · Postcommunion", p.postcommunion.lat, p.postcommunion.eng)
    }

    // Dismissal precedes the Placeat: doubled-Alleluia only in the EASTER
    // octave; 1960 rubrics say Ite missa est even without the Gloria.
    if (proper != null) {
        when {
            proper.color == "black" -> addOrdinary("requiescant")
            isEasterOctave(ctx) -> addOrdinary("ite-alleluia")
            showGloria(proper, ctx) || rite == MissalRite.RITE_1962 -> addOrdinary("ite")
            else -> addOrdinary("benedicamus")
        }
    } else {
        addOrdinary("ite")
    }

    // Placeat is said at every Mass; the blessing alone is omitted at Requiems.
    addOrdinary("placeat")
    if (proper?.color != "black") {
        addOrdinary("benedictio")
    }

    // Last Gospel — Palm Sunday substitutes Matt 21:1-9 in the pre-1955 rite
    addOrdinary(lastGospelOverride(ctx, rite) ?: "ultimum")
    if (showLeonine) {
        addOrdinary("leonine")
    }

    return items
}

private fun buildFullMassText(
    proper: MassProper?,
    rite: MissalRite,
    ctx: LiturgicalContext,
    showLeonine: Boolean = true,
): String {
    val lines = mutableListOf<String>()

    if (proper != null) {
        lines.add("✠ ${proper.title}")
        lines.add("  ${proper.englishTitle}")
        lines.add("  ${rite.short}")
    } else {
        lines.add("✠ Ordo Missæ")
        lines.add("  ${rite.short}")
    }
    lines.add("━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━")
    lines.add("")

    buildFullMassItems(proper, rite, ctx, showLeonine).forEach { item ->
        when (item) {
            is MassShareItem.Ordinary -> {
                if (item.canonStyle) {
                    lines.add("=== ${item.title} ===")
                    item.english?.let { lines.add(it) }
                } else {
                    var header = "══ ${item.title.uppercase()}"
                    item.english?.let { header += " · $it" }
                    lines.add("$header ══")
                }
                lines.add("")
                item.pairs.forEach { (lat, eng) ->
                    lines.add(lat)
                    lines.add(eng)
                    lines.add("")
                }
            }
            is MassShareItem.ProperText -> {
                lines.add("┌ ${item.label.uppercase()}")
                if (!item.ref.isNullOrEmpty()) lines.add("│ ${item.ref}")
                lines.add("│")
                item.lat.lines().filter { it.isNotEmpty() }.forEach { lines.add("│  $it") }
                lines.add("│")
                item.eng.lines().filter { it.isNotEmpty() }.forEach { lines.add("│  $it") }
                lines.add("└─────")
                lines.add("")
            }
        }
    }

    lines.add("— Introibo (app.introibo) —")
    return lines.joinToString("\n")
}
