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
        ctx.properSlug?.let { ContentStore.proper(it) }
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
                    val shareText = buildFullMassText(todayProper, rite)
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
                interleavedMassItems(todayProper, ctx)
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
) {
    // Prayers at the Foot of the Altar
    ordinaryItem("preces")
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

    // Preface, Sanctus, Canon, Pater Noster
    ordinaryItem("preface")
    ordinaryItem("sanctus")
    ordinaryItem("canon")
    ordinaryItem("pater")

    // Agnus Dei
    ordinaryItem("agnus")

    // Communion
    item { ProperSection(latin = "Communio", subtitle = "Communion", text = proper.communion) }

    ordinaryItem("domine")

    // Postcommunion
    item { ProperSection(latin = "Postcommunio", subtitle = "Postcommunion", text = proper.postcommunion) }

    // Placeat, Ite Missa Est, Last Gospel
    ordinaryItem("placeat")
    ordinaryItem("ite")
    ordinaryItem("ultimum")
}

private fun showGloria(proper: MassProper, ctx: LiturgicalContext): Boolean {
    if (ctx.season == com.lampstandhq.introibo.data.liturgical.LiturgicalSeason.EASTER ||
        ctx.season == com.lampstandhq.introibo.data.liturgical.LiturgicalSeason.CHRISTMAS) return true
    if (proper.color == "violet" || proper.color == "black") return false
    if (ctx.isSunday) {
        val preLent = listOf("septuagesima", "sexagesima", "quinquagesima")
        if (ctx.properSlug in preLent) return false
        return ctx.season != com.lampstandhq.introibo.data.liturgical.LiturgicalSeason.ADVENT &&
               ctx.season != com.lampstandhq.introibo.data.liturgical.LiturgicalSeason.LENT &&
               ctx.season != com.lampstandhq.introibo.data.liturgical.LiturgicalSeason.PASSION
    }
    return proper.rank == 1
}

private fun showCredo(proper: MassProper, ctx: LiturgicalContext): Boolean {
    if (ctx.isSunday) return true
    return proper.rank == 1
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

private fun buildFullMassText(proper: MassProper?, rite: MissalRite): String {
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

    addOrdinary("preces")
    addOrdinary("confiteor")

    proper?.let { p ->
        addProper("Introitus · Introit", p.introit.lat, p.introit.eng)
    }

    addOrdinary("kyrie")
    addOrdinary("gloria")

    proper?.let { p ->
        addProper("Oratio · Collect", p.collect.lat, p.collect.eng)
        addReading("Lectio · Epistle", p.epistle.ref, p.epistle.lat, p.epistle.eng)
        p.gradual?.let { addProper("Graduale · Gradual", it.lat, it.eng) }
        p.alleluia?.let { addProper("Alleluia", it.lat, it.eng) }
        p.tract?.let { addProper("Tractus · Tract", it.lat, it.eng) }
        p.sequence?.let { addProper("Sequentia · Sequence", it.lat, it.eng) }
        addReading("Evangelium · Gospel", p.gospel.ref, p.gospel.lat, p.gospel.eng)
    }

    addOrdinary("credo")

    proper?.let { p ->
        addProper("Offertorium · Offertory", p.offertory.lat, p.offertory.eng)
    }

    addOrdinary("offertory_prayers")

    proper?.let { p ->
        addProper("Secreta · Secret", p.secret.lat, p.secret.eng)
    }

    addOrdinary("preface")
    addOrdinary("sanctus")
    addOrdinary("canon")
    addOrdinary("pater")
    addOrdinary("agnus")

    proper?.let { p ->
        addProper("Communio · Communion", p.communion.lat, p.communion.eng)
    }

    addOrdinary("domine")

    proper?.let { p ->
        addProper("Postcommunio · Postcommunion", p.postcommunion.lat, p.postcommunion.eng)
    }

    addOrdinary("placeat")
    addOrdinary("ultimum")

    return lines.joinToString("\n")
}
