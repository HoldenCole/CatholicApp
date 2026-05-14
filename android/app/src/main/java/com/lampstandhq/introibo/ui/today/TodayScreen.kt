package com.lampstandhq.introibo.ui.today

import androidx.compose.foundation.background
import androidx.compose.foundation.border
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
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.lifecycle.viewmodel.compose.viewModel
import com.lampstandhq.introibo.data.content.ContentStore
import com.lampstandhq.introibo.data.liturgical.LiturgicalColour
import com.lampstandhq.introibo.data.liturgical.LongDateFormatter
import com.lampstandhq.introibo.ui.components.SmallLabel
import com.lampstandhq.introibo.ui.theme.IntroiboTheme
import com.lampstandhq.introibo.ui.theme.IntroiboType
import com.lampstandhq.introibo.ui.theme.RawPalette
import java.time.LocalDate
import java.util.Calendar

// ---------------------------------------------------------------------------
// Daily Psalm helper — mirrors iOS DailyPsalm.swift
// ---------------------------------------------------------------------------

private data class PsalmVerse(val ref: String, val latin: String, val english: String)

private val dailyPsalms = listOf(
    PsalmVerse("Ps 26:4", "Unam petii a Domino, hanc requiram: ut inhabitem in domo Domini omnibus diebus vitae meae.", "One thing I have asked of the Lord, this will I seek after: that I may dwell in the house of the Lord all the days of my life."),
    PsalmVerse("Ps 41:2", "Quemadmodum desiderat cervus ad fontes aquarum, ita desiderat anima mea ad te, Deus.", "As the hart panteth after the fountains of water, so my soul panteth after Thee, O God."),
    PsalmVerse("Ps 50:12", "Cor mundum crea in me, Deus, et spiritum rectum innova in visceribus meis.", "Create a clean heart in me, O God, and renew a right spirit within my bowels."),
    PsalmVerse("Ps 22:1", "Dominus regit me, et nihil mihi deerit; in loco pascuae ibi me collocavit.", "The Lord ruleth me, and I shall want nothing; He hath set me in a place of pasture."),
    PsalmVerse("Ps 33:9", "Gustate et videte quoniam suavis est Dominus; beatus vir qui sperat in eo.", "O taste and see that the Lord is sweet; blessed is the man that hopeth in Him."),
    PsalmVerse("Ps 118:105", "Lucerna pedibus meis verbum tuum, et lumen semitis meis.", "Thy word is a lamp to my feet, and a light to my paths."),
    PsalmVerse("Ps 45:11", "Vacate et videte quoniam ego sum Deus; exaltabor in gentibus, et exaltabor in terra.", "Be still and see that I am God; I will be exalted among the nations, and I will be exalted in the earth."),
    PsalmVerse("Ps 129:1-2", "De profundis clamavi ad te, Domine; Domine, exaudi vocem meam.", "Out of the depths I have cried to Thee, O Lord; Lord, hear my voice."),
    PsalmVerse("Ps 83:2-3", "Quam dilecta tabernacula tua, Domine virtutum! Concupiscit et deficit anima mea in atria Domini.", "How lovely are Thy tabernacles, O Lord of hosts! My soul longeth and fainteth for the courts of the Lord."),
    PsalmVerse("Ps 102:1", "Benedic, anima mea, Domino, et omnia quae intra me sunt nomini sancto ejus.", "Bless the Lord, O my soul, and let all that is within me bless His holy name."),
    PsalmVerse("Ps 18:2", "Caeli enarrant gloriam Dei, et opera manuum ejus annuntiat firmamentum.", "The heavens show forth the glory of God, and the firmament declareth the work of His hands."),
    PsalmVerse("Ps 26:1", "Dominus illuminatio mea et salus mea, quem timebo?", "The Lord is my light and my salvation; whom shall I fear?"),
    PsalmVerse("Ps 50:3", "Miserere mei, Deus, secundum magnam misericordiam tuam.", "Have mercy on me, O God, according to Thy great mercy."),
    PsalmVerse("Ps 62:2", "Deus, Deus meus, ad te de luce vigilo. Sitivit in te anima mea.", "O God, my God, to Thee do I watch at break of day. For Thee my soul hath thirsted."),
    PsalmVerse("Ps 83:11", "Elegi abjectus esse in domo Dei mei magis quam habitare in tabernaculis peccatorum.", "I have chosen to be an abject in the house of my God, rather than to dwell in the tabernacles of sinners."),
    PsalmVerse("Ps 115:12", "Quid retribuam Domino pro omnibus quae retribuit mihi?", "What shall I render to the Lord for all the things that He hath rendered unto me?"),
    PsalmVerse("Ps 8:2", "Domine, Dominus noster, quam admirabile est nomen tuum in universa terra!", "O Lord, our Lord, how admirable is Thy name in the whole earth!"),
    PsalmVerse("Ps 138:14", "Confitebor tibi quia terribiliter magnificatus es; mirabilia opera tua.", "I will praise Thee, for Thou art fearfully magnified; wonderful are Thy works."),
    PsalmVerse("Ps 36:5", "Revela Domino viam tuam et spera in eo, et ipse faciet.", "Commit thy way to the Lord, and trust in Him, and He will do it."),
    PsalmVerse("Ps 89:1", "Domine, refugium factus es nobis a generatione in generationem.", "Lord, Thou hast been our refuge from generation to generation."),
    PsalmVerse("Ps 120:1-2", "Levavi oculos meos in montes, unde veniet auxilium mihi. Auxilium meum a Domino, qui fecit caelum et terram.", "I have lifted up my eyes to the mountains, from whence help shall come to me. My help is from the Lord, who made heaven and earth."),
    PsalmVerse("Ps 4:9", "In pace in idipsum dormiam et requiescam.", "In peace in the selfsame I will sleep, and I will rest."),
    PsalmVerse("Ps 142:10", "Doce me facere voluntatem tuam, quia Deus meus es tu.", "Teach me to do Thy will, for Thou art my God."),
    PsalmVerse("Ps 70:8", "Repleatur os meum laude, ut cantem gloriam tuam, tota die magnitudinem tuam.", "Let my mouth be filled with praise, that I may sing Thy glory, Thy greatness all the day long."),
    PsalmVerse("Ps 15:11", "Notas mihi fecisti vias vitae; adimplebis me laetitia cum vultu tuo.", "Thou hast made known to me the ways of life; Thou shalt fill me with joy with Thy countenance."),
    PsalmVerse("Ps 85:11", "Deduc me, Domine, in via tua, et ingrediar in veritate tua.", "Conduct me, O Lord, in Thy way, and I will walk in Thy truth."),
    PsalmVerse("Ps 144:18", "Prope est Dominus omnibus invocantibus eum, omnibus invocantibus eum in veritate.", "The Lord is nigh unto all them that call upon Him, to all that call upon Him in truth."),
    PsalmVerse("Ps 29:12", "Convertisti planctum meum in gaudium mihi; conscidisti saccum meum, et circumdedisti me laetitia.", "Thou hast turned for me my mourning into joy; Thou hast cut my sackcloth, and hast compassed me with gladness."),
    PsalmVerse("Ps 76:14-15", "Deus, in sancto via tua; quis Deus magnus sicut Deus noster? Tu es Deus qui facis mirabilia.", "Thy way, O God, is in the holy place; who is the great God like our God? Thou art the God that dost wonders."),
    PsalmVerse("Ps 116:1-2", "Laudate Dominum, omnes gentes; laudate eum, omnes populi. Quoniam confirmata est super nos misericordia ejus.", "O praise the Lord, all ye nations; praise Him, all ye people. For His mercy is confirmed upon us."),
)

private fun dailyPsalm(): PsalmVerse {
    val dayOfYear = Calendar.getInstance().get(Calendar.DAY_OF_YEAR)
    val idx = (dayOfYear - 1) % dailyPsalms.size
    return dailyPsalms[idx]
}

// ---------------------------------------------------------------------------
// Liturgical colour mapping
// ---------------------------------------------------------------------------

private fun liturgicalColor(colour: LiturgicalColour): Color = when (colour) {
    LiturgicalColour.VIOLET -> RawPalette.LiturgicalViolet
    LiturgicalColour.ROSE   -> RawPalette.LiturgicalRose
    LiturgicalColour.WHITE  -> RawPalette.LiturgicalWhite
    LiturgicalColour.RED    -> RawPalette.RedLight
    LiturgicalColour.GREEN  -> RawPalette.LiturgicalGreen
}

// ---------------------------------------------------------------------------
// TodayScreen composable
// ---------------------------------------------------------------------------

@Composable
fun TodayScreen(
    vm: TodayViewModel = viewModel(),
    onNavigateSettings: (() -> Unit)? = null,
) {
    val colors = IntroiboTheme.colors
    val type = IntroiboType.current

    val ctx by vm.ctx.collectAsState()
    val rite by vm.rite.collectAsState()
    val discipline by vm.discipline.collectAsState()
    val prayerRule by vm.prayerRule.collectAsState()
    val completedPrayers by vm.completedPrayers.collectAsState()
    val masteredLessons by vm.masteredLessons.collectAsState()
    val followedSaint by vm.followedSaint.collectAsState()
    val rosaryLastDate by vm.rosaryLastDate.collectAsState()

    var showSettings by remember { mutableStateOf(false) }

    val litColor = liturgicalColor(ctx.colour)

    LazyColumn(
        modifier = Modifier
            .fillMaxSize()
            .background(colors.pageBackground),
    ) {
        // ---- Dark walnut header ----
        item {
            Column(
                horizontalAlignment = Alignment.CenterHorizontally,
                modifier = Modifier
                    .fillMaxWidth()
                    .background(
                        Brush.verticalGradient(
                            listOf(colors.walnut, colors.walnutHi)
                        )
                    )
                    .padding(horizontal = 28.dp)
                    .padding(bottom = 22.dp),
            ) {
                // Settings gear
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(top = 12.dp),
                    horizontalArrangement = Arrangement.End,
                ) {
                    IconButton(onClick = { showSettings = true }) {
                        Icon(
                            imageVector = Icons.Filled.Settings,
                            contentDescription = "Settings",
                            tint = colors.goldLeaf,
                            modifier = Modifier.size(18.dp),
                        )
                    }
                }

                // Liturgical colour pip + season
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = Arrangement.Center,
                    modifier = Modifier.padding(top = 4.dp),
                ) {
                    Box(
                        modifier = Modifier
                            .size(8.dp)
                            .clip(CircleShape)
                            .background(litColor),
                    )
                    Spacer(Modifier.width(8.dp))
                    SmallLabel(
                        text = "${ctx.feriaLatin}  ·  ${ctx.latinName}",
                        color = colors.goldLeaf,
                    )
                }

                // English day name
                Text(
                    text = ctx.feriaEnglish,
                    style = type.pageTitle,
                    color = colors.ivory,
                    modifier = Modifier.padding(top = 4.dp),
                )

                // Date
                Text(
                    text = LongDateFormatter.format(ctx.date),
                    style = type.bodySm.copy(fontStyle = FontStyle.Italic),
                    color = colors.muted,
                )

                // Rite label
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    modifier = Modifier
                        .padding(top = 8.dp)
                        .clickable { showSettings = true },
                ) {
                    SmallLabel(
                        text = "Ritus  ·  ${rite.short}",
                        color = colors.goldLeaf,
                    )
                    Text(
                        text = " ›",
                        fontSize = 8.sp,
                        color = colors.goldLeaf,
                    )
                }

                // Seasonal note
                vm.seasonalNote()?.let { note ->
                    Text(
                        text = note,
                        style = type.captionSm.copy(fontStyle = FontStyle.Italic),
                        color = colors.goldLeaf,
                        modifier = Modifier.padding(top = 6.dp),
                    )
                }

                // Marian antiphon
                Text(
                    text = ctx.marian.title,
                    style = type.captionSm.copy(fontStyle = FontStyle.Italic),
                    color = colors.muted,
                    modifier = Modifier.padding(top = 2.dp),
                )

                // First Friday / First Saturday / Ember day flags
                if (vm.isFirstFriday() || vm.isFirstSaturday() || vm.isEmberDay()) {
                    Row(
                        horizontalArrangement = Arrangement.spacedBy(12.dp),
                        modifier = Modifier.padding(top = 4.dp),
                    ) {
                        if (vm.isFirstFriday()) {
                            Text(
                                text = "First Friday",
                                style = type.captionSm.copy(fontStyle = FontStyle.Italic),
                                color = colors.sanctuaryRed,
                            )
                        }
                        if (vm.isFirstSaturday()) {
                            Text(
                                text = "First Saturday",
                                style = type.captionSm.copy(fontStyle = FontStyle.Italic),
                                color = colors.sanctuaryRed,
                            )
                        }
                        if (vm.isEmberDay()) {
                            Text(
                                text = "Ember Day",
                                style = type.captionSm.copy(fontStyle = FontStyle.Italic),
                                color = colors.sanctuaryRed,
                            )
                        }
                    }
                }

                // Liturgical colour bar
                Box(
                    modifier = Modifier
                        .padding(top = 14.dp)
                        .padding(horizontal = 32.dp)
                        .fillMaxWidth()
                        .height(2.dp)
                        .background(litColor.copy(alpha = 0.5f)),
                )
            }
        }

        // ---- Main content cards ----
        item { Spacer(Modifier.height(24.dp)) }

        // Daily Psalm
        item {
            DailyPsalmCard(modifier = Modifier.padding(horizontal = 28.dp))
        }

        item { Spacer(Modifier.height(24.dp)) }

        // Propers card
        val proper = vm.todayProper()
        if (proper != null) {
            item {
                PropersCard(
                    proper = proper,
                    modifier = Modifier.padding(horizontal = 28.dp),
                )
            }
            item { Spacer(Modifier.height(24.dp)) }
        }

        // Penance card
        item {
            PenanceCard(
                ctx = ctx,
                discipline = discipline,
                followedSaint = followedSaint,
                modifier = Modifier.padding(horizontal = 28.dp),
            )
        }

        item { Spacer(Modifier.height(24.dp)) }

        // Saint card
        item {
            SaintCard(
                followedSaint = followedSaint,
                modifier = Modifier.padding(horizontal = 28.dp),
            )
        }

        item { Spacer(Modifier.height(24.dp)) }

        // Prayer rule card
        if (!prayerRule.isEmpty) {
            item {
                PrayerRuleCard(
                    prayerRule = prayerRule,
                    completedPrayers = completedPrayers,
                    modifier = Modifier.padding(horizontal = 28.dp),
                )
            }
            item { Spacer(Modifier.height(24.dp)) }
        }

        // Devotions section
        item {
            DevotionsSection(
                vm = vm,
                modifier = Modifier.padding(horizontal = 28.dp),
            )
        }

        item { Spacer(Modifier.height(24.dp)) }

        // Rosary card
        item {
            RosaryCard(
                ctx = ctx,
                rosaryLastDate = rosaryLastDate,
                modifier = Modifier.padding(horizontal = 28.dp),
            )
        }

        item { Spacer(Modifier.height(24.dp)) }

        // Schola card
        item {
            ScholaCard(
                masteredLessons = masteredLessons,
                modifier = Modifier.padding(horizontal = 28.dp),
            )
        }

        item { Spacer(Modifier.height(40.dp)) }
    }

    // Settings bottom sheet / dialog
    if (showSettings) {
        SettingsSheet(onDismiss = { showSettings = false })
    }
}

// ---------------------------------------------------------------------------
// Card composables
// ---------------------------------------------------------------------------

@Composable
private fun DailyPsalmCard(modifier: Modifier = Modifier) {
    val colors = IntroiboTheme.colors
    val type = IntroiboType.current
    val verse = remember { dailyPsalm() }

    Column(
        modifier = modifier
            .fillMaxWidth()
            .border(0.5.dp, colors.frameLine)
            .padding(16.dp),
    ) {
        SmallLabel(text = "Psalmus Hodiernus", color = colors.sanctuaryRed)
        Text(
            text = verse.ref,
            style = type.captionSm,
            color = colors.goldLeaf,
            modifier = Modifier.padding(top = 4.dp),
        )
        Text(
            text = verse.latin,
            style = type.bodyIt,
            color = colors.primaryText,
            lineHeight = type.bodyIt.fontSize * 1.25f,
            modifier = Modifier.padding(top = 6.dp),
        )
        Text(
            text = verse.english,
            style = type.bodySm.copy(fontStyle = FontStyle.Italic),
            color = colors.secondaryText,
            lineHeight = type.bodySm.fontSize * 1.2f,
            modifier = Modifier.padding(top = 4.dp),
        )
    }
}

@Composable
private fun PropersCard(
    proper: com.lampstandhq.introibo.data.model.MassProper,
    modifier: Modifier = Modifier,
) {
    val colors = IntroiboTheme.colors
    val type = IntroiboType.current

    Column(
        modifier = modifier
            .fillMaxWidth()
            .border(0.5.dp, colors.frameLine)
            .padding(16.dp),
    ) {
        SmallLabel(
            text = "Proprium Missae  ·  Today's Propers",
            color = colors.goldLeaf,
        )
        Text(
            text = proper.title,
            style = type.titleM.copy(fontStyle = FontStyle.Italic),
            color = colors.primaryText,
            modifier = Modifier.padding(top = 4.dp),
        )
        Text(
            text = proper.english,
            style = type.captionSm.copy(fontStyle = FontStyle.Italic),
            color = colors.secondaryText,
        )

        if (proper.epistle.ref.isNotEmpty() || proper.gospel.ref.isNotEmpty()) {
            Row(
                horizontalArrangement = Arrangement.spacedBy(12.dp),
                modifier = Modifier.padding(top = 6.dp),
            ) {
                if (proper.epistle.ref.isNotEmpty()) {
                    Row(horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                        Text(text = "Ep.", style = type.captionSm, color = colors.sanctuaryRed)
                        Text(text = proper.epistle.ref, style = type.captionSm, color = colors.tertiaryText)
                    }
                }
                if (proper.gospel.ref.isNotEmpty()) {
                    Row(horizontalArrangement = Arrangement.spacedBy(4.dp)) {
                        Text(text = "Ev.", style = type.captionSm, color = colors.sanctuaryRed)
                        Text(text = proper.gospel.ref, style = type.captionSm, color = colors.tertiaryText)
                    }
                }
            }
        }

        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(top = 8.dp),
            horizontalArrangement = Arrangement.End,
        ) {
            SmallLabel(
                text = "Lectio Hodierna  ✠  Read",
                color = colors.sanctuaryRed,
            )
        }
    }
}

@Composable
private fun PenanceCard(
    ctx: com.lampstandhq.introibo.data.liturgical.LiturgicalContext,
    discipline: com.lampstandhq.introibo.storage.settings.PenanceDiscipline,
    followedSaint: String?,
    modifier: Modifier = Modifier,
) {
    val colors = IntroiboTheme.colors
    val type = IntroiboType.current

    Column(
        modifier = modifier
            .fillMaxWidth()
            .border(0.5.dp, colors.frameLine)
            .padding(16.dp),
    ) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
        ) {
            SmallLabel(text = "Paenitentia", color = colors.sanctuaryRed)
            SmallLabel(text = discipline.short, color = colors.goldLeaf)
        }

        Text(
            text = ctx.penance.rubric,
            style = type.captionSm,
            color = colors.tertiaryText,
            modifier = Modifier.padding(top = 4.dp),
        )

        Text(
            text = ctx.penance.title,
            style = type.titleM.copy(fontStyle = FontStyle.Italic),
            color = colors.primaryText,
            modifier = Modifier.padding(top = 8.dp),
        )

        Text(
            text = ctx.penance.desc,
            style = type.bodySm,
            color = colors.secondaryText,
            lineHeight = type.bodySm.fontSize * 1.2f,
            modifier = Modifier.padding(top = 4.dp),
        )

        // Saint-specific penance
        if (followedSaint != null) {
            val saint = ContentStore.saints.firstOrNull { it.slug == followedSaint }
            if (saint?.penance != null) {
                Column(modifier = Modifier.padding(top = 8.dp)) {
                    Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
                        SmallLabel(
                            text = saint.penanceLatin ?: "Praxis Sancti",
                            color = colors.goldLeaf,
                        )
                        Text(text = "·", color = colors.tertiaryText)
                        Text(
                            text = saint.name,
                            style = type.captionSm.copy(fontStyle = FontStyle.Italic),
                            color = colors.secondaryText,
                        )
                    }
                    Text(
                        text = saint.penance!!,
                        style = type.bodySm.copy(fontStyle = FontStyle.Italic),
                        color = colors.primaryText,
                        lineHeight = type.bodySm.fontSize * 1.2f,
                        modifier = Modifier.padding(top = 4.dp),
                    )
                }
            }
        }
    }
}

@Composable
private fun SaintCard(
    followedSaint: String?,
    modifier: Modifier = Modifier,
) {
    val colors = IntroiboTheme.colors
    val type = IntroiboType.current

    if (followedSaint != null) {
        val saint = ContentStore.saints.firstOrNull { it.slug == followedSaint }
        if (saint != null) {
            val totalPractices = saint.sections.sumOf { it.practices.size }
            Row(
                verticalAlignment = Alignment.CenterVertically,
                modifier = modifier
                    .fillMaxWidth()
                    .border(1.dp, colors.sanctuaryRed.copy(alpha = 0.3f))
                    .padding(16.dp),
            ) {
                // Progress ring
                ProgressRing(
                    progress = 0f, // Will be wired when completedPractices is available
                    count = 0,
                    size = 56,
                    strokeWidth = 4f,
                )
                Spacer(Modifier.width(16.dp))
                Column(modifier = Modifier.weight(1f)) {
                    Text(
                        text = saint.name,
                        style = type.titleL.copy(fontStyle = FontStyle.Italic),
                        color = colors.primaryText,
                    )
                    Text(
                        text = "$totalPractices practices today",
                        style = type.captionSm,
                        color = colors.secondaryText,
                    )
                }
                Text(text = "Open", style = type.captionSm, color = colors.sanctuaryRed)
            }
        }
    } else {
        // Empty saint card
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            modifier = modifier
                .fillMaxWidth()
                .border(1.dp, colors.sanctuaryRed.copy(alpha = 0.3f))
                .padding(16.dp),
        ) {
            Text(
                text = "✠",
                style = type.titleL,
                color = colors.sanctuaryRed,
            )
            Text(
                text = "Follow a Saint",
                style = type.titleM.copy(fontStyle = FontStyle.Italic),
                color = colors.primaryText,
                modifier = Modifier.padding(top = 4.dp),
            )
            Text(
                text = "Choose a patron saint and track daily practices",
                style = type.captionSm.copy(fontStyle = FontStyle.Italic),
                color = colors.secondaryText,
                modifier = Modifier.padding(top = 2.dp),
            )
            SmallLabel(
                text = "Begin",
                color = colors.sanctuaryRed,
                modifier = Modifier.padding(top = 8.dp),
            )
        }
    }
}

@Composable
private fun PrayerRuleCard(
    prayerRule: com.lampstandhq.introibo.storage.progress.PrayerRule,
    completedPrayers: Set<String>,
    modifier: Modifier = Modifier,
) {
    val colors = IntroiboTheme.colors
    val type = IntroiboType.current

    val done = completedPrayers.intersect(prayerRule.allSlugs.toSet()).size
    val total = prayerRule.totalCount
    val progress = if (total > 0) done.toFloat() / total else 0f

    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier = modifier
            .fillMaxWidth()
            .border(0.5.dp, colors.frameLine)
            .padding(14.dp),
    ) {
        ProgressRing(
            progress = progress,
            count = done,
            size = 44,
            strokeWidth = 3f,
        )
        Spacer(Modifier.width(14.dp))
        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = "Prayer Rule",
                style = type.titleM.copy(fontStyle = FontStyle.Italic),
                color = colors.primaryText,
            )
            Text(
                text = if (progress >= 1f) "All prayers complete" else "$done of $total prayers today",
                style = type.captionSm,
                color = if (progress >= 1f) colors.goldLeaf else colors.secondaryText,
            )
        }
        Text(text = "Open", style = type.captionSm, color = colors.sanctuaryRed)
    }
}

@Composable
private fun DevotionsSection(
    vm: TodayViewModel,
    modifier: Modifier = Modifier,
) {
    val colors = IntroiboTheme.colors
    val type = IntroiboType.current

    Column(modifier = modifier.fillMaxWidth()) {
        SectionLabel(title = "Devotiones Hodiernae", subtitle = "Today's devotions")
        Spacer(Modifier.height(14.dp))

        DevotionRow(title = "The Divine Office", latin = "Officium Divinum, VIII Horae Canonicae")
        DevotionRow(title = "Stations of the Cross", latin = "Via Crucis, XIV stationes")
        DevotionRow(title = "Confession Guide", latin = "De Confessione")
        DevotionRow(title = vm.offeringTitle(), latin = vm.offeringLatin())
    }
}

@Composable
private fun DevotionRow(
    title: String,
    latin: String,
    modifier: Modifier = Modifier,
) {
    val colors = IntroiboTheme.colors
    val type = IntroiboType.current

    Column(
        modifier = modifier
            .fillMaxWidth()
            .padding(vertical = 4.dp),
    ) {
        Text(
            text = title,
            style = type.titleM,
            color = colors.primaryText,
        )
        Text(
            text = latin,
            style = type.captionSm.copy(fontStyle = FontStyle.Italic),
            color = colors.secondaryText,
        )
    }
}

@Composable
private fun RosaryCard(
    ctx: com.lampstandhq.introibo.data.liturgical.LiturgicalContext,
    rosaryLastDate: LocalDate?,
    modifier: Modifier = Modifier,
) {
    val colors = IntroiboTheme.colors
    val type = IntroiboType.current

    Column(modifier = modifier.fillMaxWidth()) {
        SectionLabel(title = "Sacratissimum Rosarium", subtitle = "of the Rosary")
        Spacer(Modifier.height(8.dp))

        Text(
            text = ctx.mystery.latinName,
            style = type.titleM.copy(fontStyle = FontStyle.Italic),
            color = colors.primaryText,
        )
        Text(
            text = ctx.mystery.englishName,
            style = type.captionSm.copy(fontStyle = FontStyle.Italic),
            color = colors.secondaryText,
        )

        if (rosaryLastDate != null) {
            val fmt = remember {
                java.time.format.DateTimeFormatter.ofLocalizedDate(
                    java.time.format.FormatStyle.MEDIUM
                )
            }
            Text(
                text = "Last prayed: ${rosaryLastDate.format(fmt)}",
                style = type.captionSm,
                color = colors.tertiaryText,
                modifier = Modifier.padding(top = 4.dp),
            )
        }
    }
}

@Composable
private fun ScholaCard(
    masteredLessons: Set<String>,
    modifier: Modifier = Modifier,
) {
    val colors = IntroiboTheme.colors
    val type = IntroiboType.current

    Column(modifier = modifier.fillMaxWidth()) {
        SectionLabel(title = "Schola", subtitle = "Latin learning")
        Spacer(Modifier.height(8.dp))
        Text(
            text = "Mastered: ${masteredLessons.size} of ${ContentStore.courses.size} lessons",
            style = type.bodySm,
            color = colors.secondaryText,
        )
    }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

@Composable
private fun SectionLabel(title: String, subtitle: String) {
    val colors = IntroiboTheme.colors
    val type = IntroiboType.current

    Column {
        SmallLabel(text = title, color = colors.sanctuaryRed)
        Text(
            text = subtitle,
            style = type.captionSm.copy(fontStyle = FontStyle.Italic),
            color = colors.tertiaryText,
        )
    }
}

/**
 * Circular progress ring with a count in the center.
 */
@Composable
private fun ProgressRing(
    progress: Float,
    count: Int,
    size: Int,
    strokeWidth: Float,
    modifier: Modifier = Modifier,
) {
    val colors = IntroiboTheme.colors
    val type = IntroiboType.current
    val ringColor = if (progress >= 1f) colors.goldLeaf else colors.sanctuaryRed

    Box(
        contentAlignment = Alignment.Center,
        modifier = modifier
            .size(size.dp)
            .drawBehind {
                val stroke = Stroke(width = strokeWidth.dp.toPx(), cap = StrokeCap.Round)
                // Background track
                drawArc(
                    color = colors.frameLine,
                    startAngle = 0f,
                    sweepAngle = 360f,
                    useCenter = false,
                    style = stroke,
                    topLeft = Offset(stroke.width / 2, stroke.width / 2),
                    size = Size(
                        this.size.width - stroke.width,
                        this.size.height - stroke.width
                    ),
                )
                // Progress arc
                if (progress > 0f) {
                    drawArc(
                        color = ringColor,
                        startAngle = -90f,
                        sweepAngle = 360f * progress,
                        useCenter = false,
                        style = stroke,
                        topLeft = Offset(stroke.width / 2, stroke.width / 2),
                        size = Size(
                            this.size.width - stroke.width,
                            this.size.height - stroke.width
                        ),
                    )
                }
            },
    ) {
        Text(
            text = "$count",
            style = type.titleM,
            color = colors.primaryText,
        )
    }
}

// ---------------------------------------------------------------------------
// Settings sheet placeholder — wraps SettingsScreen
// ---------------------------------------------------------------------------

@Composable
private fun SettingsSheet(onDismiss: () -> Unit) {
    // Using a full-screen dialog approach for the settings sheet
    androidx.compose.ui.window.Dialog(onDismissRequest = onDismiss) {
        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(IntroiboTheme.colors.pageBackground),
        ) {
            SettingsScreen(onDismiss = onDismiss)
        }
    }
}
