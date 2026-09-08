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
import androidx.compose.material.icons.filled.DateRange
import androidx.compose.material.icons.filled.Search
import androidx.compose.material.icons.filled.Settings
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
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
import com.lampstandhq.introibo.data.liturgical.LiturgicalContext
import com.lampstandhq.introibo.data.liturgical.LongDateFormatter
import com.lampstandhq.introibo.data.liturgical.VernacularDates
import com.lampstandhq.introibo.data.liturgical.penanceFor
import com.lampstandhq.introibo.data.model.MassProper
import com.lampstandhq.introibo.data.model.Prayer
import com.lampstandhq.introibo.ui.prayers.PrayerDetailSheet
import com.lampstandhq.introibo.ui.components.SmallLabel
import com.lampstandhq.introibo.ui.missal.ProperScreen
import com.lampstandhq.introibo.ui.theme.IntroiboTheme
import com.lampstandhq.introibo.ui.theme.IntroiboType
import com.lampstandhq.introibo.ui.theme.liturgicalColor
import com.lampstandhq.introibo.ui.theme.scaledSp
import com.lampstandhq.introibo.ui.components.BilingualLine
import com.lampstandhq.introibo.ui.components.LanguageAwareLabel
import com.lampstandhq.introibo.ui.components.currentLanguageMode
import com.lampstandhq.introibo.storage.settings.LanguageMode
import com.lampstandhq.introibo.storage.settings.PenanceDiscipline
import java.time.LocalDate
import java.util.Calendar

// ---------------------------------------------------------------------------
// Daily Psalm helper — mirrors iOS DailyPsalm.swift
// ---------------------------------------------------------------------------

private data class PsalmVerse(val ref: String, val latin: String, val english: String)

private val dailyPsalms = listOf(
    PsalmVerse("Ps 26:4", "Unam pétii a Dómino, hanc requíram: ut inhábitem in domo Dómini ómnibus diébus vitæ meæ.", "One thing I have asked of the Lord, this will I seek after: that I may dwell in the house of the Lord all the days of my life."),
    PsalmVerse("Ps 41:2", "Quemádmodum desíderat cervus ad fontes aquárum, ita desíderat ánima mea ad te, Deus.", "As the hart panteth after the fountains of water, so my soul panteth after Thee, O God."),
    PsalmVerse("Ps 50:12", "Cor mundum crea in me, Deus, et spíritum rectum ínnova in viscéribus meis.", "Create a clean heart in me, O God, and renew a right spirit within my bowels."),
    PsalmVerse("Ps 22:1", "Dóminus regit me, et nihil mihi déerit; in loco páscuæ ibi me collocávit.", "The Lord ruleth me, and I shall want nothing; He hath set me in a place of pasture."),
    PsalmVerse("Ps 33:9", "Gustáte et vidéte quóniam suávis est Dóminus; beátus vir qui sperat in eo.", "O taste and see that the Lord is sweet; blessed is the man that hopeth in Him."),
    PsalmVerse("Ps 118:105", "Lucérna pédibus meis verbum tuum, et lumen sémitis meis.", "Thy word is a lamp to my feet, and a light to my paths."),
    PsalmVerse("Ps 45:11", "Vacáte et vidéte quóniam ego sum Deus; exaltábor in géntibus, et exaltábor in terra.", "Be still and see that I am God; I will be exalted among the nations, and I will be exalted in the earth."),
    PsalmVerse("Ps 129:1-2", "De profúndis clamávi ad te, Dómine; Dómine, exáudi vocem meam.", "Out of the depths I have cried to Thee, O Lord; Lord, hear my voice."),
    PsalmVerse("Ps 83:2-3", "Quam dilécta tabernácula tua, Dómine virtútum! Concupíscit et déficit ánima mea in átria Dómini.", "How lovely are Thy tabernacles, O Lord of hosts! My soul longeth and fainteth for the courts of the Lord."),
    PsalmVerse("Ps 102:1", "Bénedic, ánima mea, Dómino, et ómnia quæ intra me sunt nómini sancto ejus.", "Bless the Lord, O my soul, and let all that is within me bless His holy name."),
    PsalmVerse("Ps 18:2", "Cæli enárrant glóriam Dei, et ópera mánuum ejus annúntiat firmaméntum.", "The heavens show forth the glory of God, and the firmament declareth the work of His hands."),
    PsalmVerse("Ps 26:1", "Dóminus illuminátio mea et salus mea, quem timébo?", "The Lord is my light and my salvation; whom shall I fear?"),
    PsalmVerse("Ps 50:3", "Miserére mei, Deus, secúndum magnam misericórdiam tuam.", "Have mercy on me, O God, according to Thy great mercy."),
    PsalmVerse("Ps 62:2", "Deus, Deus meus, ad te de luce vígilo. Sitívit in te ánima mea.", "O God, my God, to Thee do I watch at break of day. For Thee my soul hath thirsted."),
    PsalmVerse("Ps 83:11", "Elegi abjéctus esse in domo Dei mei magis quam habitáre in tabernáculis peccatórum.", "I have chosen to be an abject in the house of my God, rather than to dwell in the tabernacles of sinners."),
    PsalmVerse("Ps 115:12", "Quid retríbuam Dómino pro ómnibus quæ retríbuit mihi?", "What shall I render to the Lord for all the things that He hath rendered unto me?"),
    PsalmVerse("Ps 8:2", "Dómine, Dóminus noster, quam admirábile est nomen tuum in univérsa terra!", "O Lord, our Lord, how admirable is Thy name in the whole earth!"),
    PsalmVerse("Ps 138:14", "Confitébor tibi quia terribíliter magnificátus es; mirabília ópera tua.", "I will praise Thee, for Thou art fearfully magnified; wonderful are Thy works."),
    PsalmVerse("Ps 36:5", "Revéla Dómino viam tuam et spera in eo, et ipse fáciet.", "Commit thy way to the Lord, and trust in Him, and He will do it."),
    PsalmVerse("Ps 89:1", "Dómine, refúgium factus es nobis a generatióne in generatiónem.", "Lord, Thou hast been our refuge from generation to generation."),
    PsalmVerse("Ps 120:1-2", "Levávi óculos meos in montes, unde véniet auxílium mihi. Auxílium meum a Dómino, qui fecit cælum et terram.", "I have lifted up my eyes to the mountains, from whence help shall come to me. My help is from the Lord, who made heaven and earth."),
    PsalmVerse("Ps 4:9", "In pace in idípsum dórmiam et requiéscam.", "In peace in the selfsame I will sleep, and I will rest."),
    PsalmVerse("Ps 142:10", "Doce me fácere voluntátem tuam, quia Deus meus es tu.", "Teach me to do Thy will, for Thou art my God."),
    PsalmVerse("Ps 70:8", "Repleátur os meum laude, ut cantem glóriam tuam, tota die magnitúdinem tuam.", "Let my mouth be filled with praise, that I may sing Thy glory, Thy greatness all the day long."),
    PsalmVerse("Ps 15:11", "Notas mihi fecísti vias vitæ; adimplébis me lætítia cum vultu tuo.", "Thou hast made known to me the ways of life; Thou shalt fill me with joy with Thy countenance."),
    PsalmVerse("Ps 85:11", "Deduc me, Dómine, in via tua, et ingrédiar in veritáte tua.", "Conduct me, O Lord, in Thy way, and I will walk in Thy truth."),
    PsalmVerse("Ps 144:18", "Prope est Dóminus ómnibus invocántibus eum, ómnibus invocántibus eum in veritáte.", "The Lord is nigh unto all them that call upon Him, to all that call upon Him in truth."),
    PsalmVerse("Ps 29:12", "Convertísti planctum meum in gáudium mihi; conscidísti saccum meum, et circumdedísti me lætítia.", "Thou hast turned for me my mourning into joy; Thou hast cut my sackcloth, and hast compassed me with gladness."),
    PsalmVerse("Ps 76:14-15", "Deus, in sancto via tua; quis Deus magnus sicut Deus noster? Tu es Deus qui facis mirabília.", "Thy way, O God, is in the holy place; who is the great God like our God? Thou art the God that dost wonders."),
    PsalmVerse("Ps 116:1-2", "Laudáte Dóminum, omnes gentes; laudáte eum, omnes pópuli. Quóniam confirmáta est super nos misericórdia ejus.", "O praise the Lord, all ye nations; praise Him, all ye people. For His mercy is confirmed upon us."),
    PsalmVerse("Ps 30:6", "In manus tuas comméndo spíritum meum; redemísti me, Dómine, Deus veritátis.", "Into Thy hands I commend my spirit; Thou hast redeemed me, O Lord, the God of truth."),
    PsalmVerse("Ps 90:1-2", "Qui hábitat in adjutório Altíssimi, in protectióne Dei cæli commorábitur. Dicet Dómino: Suscéptor meus es tu et refúgium meum.", "He that dwelleth in the aid of the Most High shall abide under the protection of the God of heaven. He shall say to the Lord: Thou art my protector and my refuge."),
    PsalmVerse("Ps 39:2-3", "Exspéctans exspectávi Dóminum, et inténdit mihi. Et exaudívit preces meas, et edúxit me de lacu misériæ.", "With expectation I have waited for the Lord, and He was attentive to me. And He heard my prayers, and brought me out of the pit of misery."),
    PsalmVerse("Ps 24:4-5", "Vias tuas, Dómine, demónstra mihi, et sémitas tuas édoce me. Dírige me in veritáte tua et doce me.", "Show me Thy ways, O Lord, and teach me Thy paths. Direct me in Thy truth and teach me."),
    PsalmVerse("Ps 33:19", "Juxta est Dóminus iis qui tribulántur corde, et húmiles spíritu salvábit.", "The Lord is nigh unto them that are of a contrite heart, and He will save the humble of spirit."),
    PsalmVerse("Ps 46:2", "Omnes gentes, pláudite mánibus; jubiláte Deo in voce exsultatiónis.", "O clap your hands, all ye nations; shout unto God with the voice of joy."),
    PsalmVerse("Ps 95:1", "Cantáte Dómino cánticum novum; cantáte Dómino, omnis terra.", "Sing ye to the Lord a new canticle; sing to the Lord, all the earth."),
    PsalmVerse("Ps 102:2-3", "Bénedic, ánima mea, Dómino, et noli oblivísci omnes retributiónes ejus. Qui propitiátur ómnibus iniquitátibus tuis, qui sanat omnes infirmitátes tuas.", "Bless the Lord, O my soul, and never forget all He hath done for thee. Who forgiveth all thy iniquities, who healeth all thy diseases."),
    PsalmVerse("Ps 118:1", "Beáti immaculáti in via, qui ámbulant in lege Dómini.", "Blessed are the undefiled in the way, who walk in the law of the Lord."),
    PsalmVerse("Ps 112:1-2", "Laudáte, púeri, Dóminum; laudáte nomen Dómini. Sit nomen Dómini benedíctum, ex hoc nunc et usque in sǽculum.", "Praise the Lord, ye children; praise ye the name of the Lord. Blessed be the name of the Lord, from henceforth now and for ever."),
    PsalmVerse("Ps 103:24", "Quam magnificáta sunt ópera tua, Dómine! Omnia in sapiéntia fecísti; impléta est terra possessióne tua.", "How great are Thy works, O Lord! Thou hast made all things in wisdom; the earth is filled with Thy riches."),
    PsalmVerse("Ps 22:4", "Nam et si ambulávero in médio umbræ mortis, non timébo mala, quóniam tu mecum es.", "For though I should walk in the midst of the shadow of death, I will fear no evils, for Thou art with me."),
    PsalmVerse("Ps 91:2-3", "Bonum est confitéri Dómino, et psállere nómini tuo, Altíssime. Ad annuntiándum mane misericórdiam tuam, et veritátem tuam per noctem.", "It is good to give praise to the Lord, and to sing to Thy name, O Most High. To show forth Thy mercy in the morning, and Thy truth in the night."),
    PsalmVerse("Ps 148:1-2", "Laudáte Dóminum de cælis; laudáte eum in excélsis. Laudáte eum, omnes Ángeli ejus; laudáte eum, omnes virtútes ejus.", "Praise ye the Lord from the heavens; praise Him in the high places. Praise ye Him, all His angels; praise ye Him, all His hosts."),
)

private fun dailyPsalm(): PsalmVerse {
    val dayOfYear = Calendar.getInstance().get(Calendar.DAY_OF_YEAR)
    val idx = (dayOfYear - 1) % dailyPsalms.size
    val v = dailyPsalms[idx]
    // The vernacular side follows the active overlay (Torres Amat for
    // Spanish, keyed by ref); English is the literal above.
    return ContentStore.dailyPsalmES[v.ref]?.let { v.copy(english = it) } ?: v
}

// ---------------------------------------------------------------------------
// Liturgical colour mapping
// ---------------------------------------------------------------------------

// Liturgical colour → display Color now lives in ui.theme.liturgicalColor
// (single source of truth shared with the calendar). Imported below.

// ---------------------------------------------------------------------------
// TodayScreen composable
// ---------------------------------------------------------------------------

@Composable
fun TodayScreen(
    vm: TodayViewModel = viewModel(),
    onNavigateSettings: (() -> Unit)? = null,
    onNavigateOffice: (() -> Unit)? = null,
    onNavigateStations: (() -> Unit)? = null,
    onNavigateConfession: (() -> Unit)? = null,
    onNavigateRosary: (() -> Unit)? = null,
    onNavigateSaints: (() -> Unit)? = null,
    onNavigateSearch: (() -> Unit)? = null,
    onNavigateCalendar: (() -> Unit)? = null,
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
    val showUpcomingFeasts by vm.showUpcomingFeasts.collectAsState()

    var showSettings by rememberSaveable { mutableStateOf(false) }
    var showProper by remember { mutableStateOf<MassProper?>(null) }
    var showOfferingPrayer by remember { mutableStateOf<Prayer?>(null) }

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
                    IconButton(onClick = { onNavigateCalendar?.invoke() }) {
                        Icon(
                            imageVector = Icons.Filled.DateRange,
                            contentDescription = ContentStore.uiString("today.calendar_a11y", "Calendar"),
                            tint = colors.goldLeaf,
                            modifier = Modifier.size(18.dp),
                        )
                    }
                    IconButton(onClick = { onNavigateSearch?.invoke() }) {
                        Icon(
                            imageVector = Icons.Filled.Search,
                            contentDescription = ContentStore.uiString("common.search", "Search"),
                            tint = colors.goldLeaf,
                            modifier = Modifier.size(18.dp),
                        )
                    }
                    IconButton(onClick = { onNavigateSettings?.invoke() ?: run { showSettings = true } }) {
                        Icon(
                            imageVector = Icons.Filled.Settings,
                            contentDescription = ContentStore.uiString("common.settings", "Settings"),
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
                    LanguageAwareLabel(
                        // The big title below already names the weekday — the
                        // caps line carries only the season, so it reads as one
                        // quiet line instead of three crowded ones.
                        latin = ctx.latinName,
                        english = ctx.englishName,
                        color = colors.goldLeaf,
                    )
                }

                // Day name — respects language mode
                val langMode = currentLanguageMode()
                Text(
                    text = if (langMode == LanguageMode.LATIN_ONLY) ctx.feriaLatin else ctx.feriaEnglish,
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
                        .clickable { onNavigateSettings?.invoke() ?: run { showSettings = true } },
                ) {
                    SmallLabel(
                        text = "Ritus  ·  ${rite.short}",
                        color = colors.goldLeaf,
                    )
                    Text(
                        text = " ›",
                        fontSize = scaledSp(8f),
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

                // Marian antiphon (suppressed during Triduum)
                if (!ctx.marian.isSuppressed) {
                    Text(
                        text = ctx.marian.title,
                        style = type.captionSm.copy(fontStyle = FontStyle.Italic),
                        color = colors.muted,
                        modifier = Modifier.padding(top = 2.dp),
                    )
                }

                // First Friday / First Saturday / Ember day flags
                if (vm.isFirstFriday() || vm.isFirstSaturday() || vm.isEmberDay()) {
                    Row(
                        horizontalArrangement = Arrangement.spacedBy(12.dp),
                        modifier = Modifier.padding(top = 4.dp),
                    ) {
                        if (vm.isFirstFriday()) {
                            Text(
                                text = ContentStore.uiString("flag.first_friday", "First Friday"),
                                style = type.captionSm.copy(fontStyle = FontStyle.Italic),
                                color = colors.sanctuaryRed,
                            )
                        }
                        if (vm.isFirstSaturday()) {
                            Text(
                                text = ContentStore.uiString("flag.first_saturday", "First Saturday"),
                                style = type.captionSm.copy(fontStyle = FontStyle.Italic),
                                color = colors.sanctuaryRed,
                            )
                        }
                        if (vm.isEmberDay()) {
                            Text(
                                text = ContentStore.uiString("flag.ember_day", "Ember Day"),
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

        // Upcoming feasts (next 14 days) — Settings toggle, off by default.
        if (showUpcomingFeasts) {
            item {
                UpcomingFeastsCard(
                    rite = rite,
                    modifier = Modifier.padding(horizontal = 28.dp),
                    onClick = { onNavigateCalendar?.invoke() },
                )
            }

            item { Spacer(Modifier.height(24.dp)) }
        }

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
                    onClick = { showProper = proper },
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
                onNavigateSaints = onNavigateSaints,
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
                onNavigateOffice = onNavigateOffice,
                onNavigateStations = onNavigateStations,
                onNavigateConfession = onNavigateConfession,
                onOfferingClick = { showOfferingPrayer = it },
                modifier = Modifier.padding(horizontal = 28.dp),
            )
        }

        item { Spacer(Modifier.height(24.dp)) }

        // Rosary card
        item {
            RosaryCard(
                ctx = ctx,
                rosaryLastDate = rosaryLastDate,
                onNavigateRosary = onNavigateRosary,
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

    // Proper detail dialog
    showProper?.let { properData ->
        androidx.compose.ui.window.Dialog(
            onDismissRequest = { showProper = null },
            properties = androidx.compose.ui.window.DialogProperties(usePlatformDefaultWidth = false),
        ) {
            ProperScreen(
                proper = properData,
                onDismiss = { showProper = null },
            )
        }
    }

    // Offering prayer detail
    showOfferingPrayer?.let { prayer ->
        PrayerDetailSheet(
            prayer = prayer,
            onDismiss = { showOfferingPrayer = null },
        )
    }
}

// ---------------------------------------------------------------------------
// Card composables
// ---------------------------------------------------------------------------

@Composable
private fun UpcomingFeastsCard(
    rite: com.lampstandhq.introibo.storage.settings.MissalRite,
    modifier: Modifier = Modifier,
    onClick: () -> Unit = {},
) {
    val colors = IntroiboTheme.colors
    // Keyed by today's date so a recomposition after midnight refreshes the
    // window (matches the rest of the Today screen's day-scoped behaviour).
    val todayKey = java.time.LocalDate.now()
    val upcoming = remember(rite, todayKey) {
        com.lampstandhq.introibo.data.liturgical.LiturgicalYear.upcoming(start = todayKey, rite = rite).take(4)
    }
    if (upcoming.isEmpty()) return
    val langMode = currentLanguageMode()

    Column(
        modifier = modifier
            .fillMaxWidth()
            .border(0.5.dp, colors.frameLine)
            .clickable { onClick() }
            .padding(16.dp),
    ) {
        Row(verticalAlignment = Alignment.CenterVertically) {
            SmallLabel(text = "Ventura · " + ContentStore.uiString("today.upcoming", "Upcoming"), color = colors.tertiaryText)
            Spacer(Modifier.weight(1f))
            Text(text = "›", fontSize = scaledSp(12f), color = colors.tertiaryText)
        }
        Spacer(Modifier.height(8.dp))
        upcoming.forEach { day ->
            Row(
                verticalAlignment = Alignment.CenterVertically,
                modifier = Modifier.padding(vertical = 3.dp),
            ) {
                Box(
                    modifier = Modifier
                        .size(6.dp)
                        .clip(androidx.compose.foundation.shape.CircleShape)
                        .background(
                            (day.colour?.let { com.lampstandhq.introibo.ui.theme.liturgicalColor(it) }
                                ?: colors.frameLine).copy(alpha = 0.85f),
                        ),
                )
                Spacer(Modifier.width(10.dp))
                Text(
                    text = VernacularDates.weekdayDayMonthAbbrev(day.date),
                    fontSize = scaledSp(12f),
                    color = colors.tertiaryText,
                    modifier = Modifier.width(72.dp),
                )
                Text(
                    text = if (langMode == LanguageMode.LATIN_ONLY) {
                        day.label ?: day.weekdayName
                    } else {
                        day.englishName ?: day.label ?: day.weekdayName
                    },
                    fontSize = scaledSp(14f),
                    color = colors.primaryText,
                    maxLines = 1,
                    overflow = androidx.compose.ui.text.style.TextOverflow.Ellipsis,
                    modifier = Modifier.weight(1f),
                )
                com.lampstandhq.introibo.ui.calendar.DayMarkerPips(day)
            }
        }
    }
}

@Composable
private fun DailyPsalmCard(modifier: Modifier = Modifier) {
    val colors = IntroiboTheme.colors
    val type = IntroiboType.current
    val verse = remember(ContentStore.currentVernacular) { dailyPsalm() }

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
        Spacer(modifier = Modifier.height(6.dp))
        BilingualLine(lat = verse.latin, eng = verse.english)
    }
}

@Composable
private fun PropersCard(
    proper: com.lampstandhq.introibo.data.model.MassProper,
    onClick: () -> Unit = {},
    modifier: Modifier = Modifier,
) {
    val colors = IntroiboTheme.colors
    val type = IntroiboType.current

    Column(
        modifier = modifier
            .fillMaxWidth()
            .border(0.5.dp, colors.frameLine)
            .clickable { onClick() }
            .padding(16.dp),
    ) {
        SmallLabel(
            text = "Proprium Missae  ·  " + ContentStore.uiString("today.propers", "Today's Propers"),
            color = colors.goldLeaf,
        )
        Text(
            text = proper.title,
            style = type.titleM.copy(fontStyle = FontStyle.Italic),
            color = colors.primaryText,
            modifier = Modifier.padding(top = 4.dp),
        )
        // Subtitle: the vernacular feast name. DO sanctoral imports carry
        // the Latin officium in `english` too, so prefer the ordo-name
        // translation and drop the line rather than repeat the Latin.
        val properSubtitle = ContentStore.ordoNameEnglish(proper.title) ?: proper.english
        if (currentLanguageMode() != LanguageMode.LATIN_ONLY &&
            properSubtitle != proper.title
        ) {
            Text(
                text = properSubtitle,
                style = type.captionSm.copy(fontStyle = FontStyle.Italic),
                color = colors.secondaryText,
            )
        }

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
                text = ContentStore.uiString("today.lectio", "Léctio Hodiérna  ✠  Read"),
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
    val appContext = androidx.compose.ui.platform.LocalContext.current

    val penance = remember(ctx, discipline) { ctx.penanceFor(discipline) }
    var showPenanceSheet by remember { mutableStateOf(false) }
    // Recompute after the sheet closes so edits show immediately.
    val selectedPenances = remember(showPenanceSheet) {
        com.lampstandhq.introibo.data.penance.OptionalPenances.selected(appContext)
    }

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
            text = penance.rubric,
            style = type.captionSm,
            color = colors.tertiaryText,
            modifier = Modifier.padding(top = 4.dp),
        )

        Text(
            text = penance.title,
            style = type.titleM.copy(fontStyle = FontStyle.Italic),
            color = colors.primaryText,
            modifier = Modifier.padding(top = 8.dp),
        )

        Text(
            text = penance.desc,
            style = type.bodySm,
            color = colors.secondaryText,
            lineHeight = type.bodySm.fontSize * 1.2f,
            modifier = Modifier.padding(top = 4.dp),
        )

        // Next obligation
        val nextObl = remember(discipline) { nextObligationDay(discipline) }
        if (nextObl != null) {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                modifier = Modifier.padding(top = 8.dp),
            ) {
                Text(text = "→", fontSize = scaledSp(11f), color = colors.sanctuaryRed)
                Spacer(Modifier.width(6.dp))
                Text(
                    text = ContentStore.uiString("today.next_obligation", "Next obligation: {0}").replace("{0}", "${nextObl}"),
                    style = type.captionSm.copy(fontStyle = FontStyle.Italic),
                    color = colors.secondaryText,
                )
            }
        }

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

        // Voluntary penances the user has taken on (iOS parity).
        if (selectedPenances.isNotEmpty()) {
            Column(modifier = Modifier.padding(top = 8.dp)) {
                SmallLabel(text = "Pæniténtiæ Voluntáriæ", color = colors.goldLeaf)
                selectedPenances.forEach { p ->
                    Text(
                        text = "· ${p.title}",
                        style = type.captionSm.copy(fontStyle = FontStyle.Italic),
                        color = colors.primaryText,
                    )
                }
            }
        }

        Text(
            text = if (selectedPenances.isEmpty()) ContentStore.uiString("today.penance.choose", "Choose optional penances") else ContentStore.uiString("today.penance.edit", "Edit penances"),
            style = type.captionSm.copy(fontStyle = FontStyle.Italic),
            color = colors.sanctuaryRed,
            modifier = Modifier
                .padding(top = 8.dp)
                .clickable { showPenanceSheet = true },
        )
    }

    if (showPenanceSheet) {
        PenanceSheet(onDismiss = { showPenanceSheet = false })
    }
}

@Composable
private fun SaintCard(
    followedSaint: String?,
    onNavigateSaints: (() -> Unit)? = null,
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
                    .then(if (onNavigateSaints != null) Modifier.clickable { onNavigateSaints() } else Modifier)
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
                        text = ContentStore.uiString("today.practices", "{0} practices today").replace("{0}", "${totalPractices}"),
                        style = type.captionSm,
                        color = colors.secondaryText,
                    )
                }
                Text(text = ContentStore.uiString("common.open", "Open"), style = type.captionSm, color = colors.sanctuaryRed)
            }
        }
    } else {
        // Empty saint card
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            modifier = modifier
                .fillMaxWidth()
                .border(1.dp, colors.sanctuaryRed.copy(alpha = 0.3f))
                .then(if (onNavigateSaints != null) Modifier.clickable { onNavigateSaints() } else Modifier)
                .padding(16.dp),
        ) {
            Text(
                text = "✠",
                style = type.titleL,
                color = colors.sanctuaryRed,
            )
            Text(
                text = ContentStore.uiString("today.saints.follow", "Follow a Saint"),
                style = type.titleM.copy(fontStyle = FontStyle.Italic),
                color = colors.primaryText,
                modifier = Modifier.padding(top = 4.dp),
            )
            Text(
                text = ContentStore.uiString("today.saints.sub", "Choose a patron saint and track daily practices"),
                style = type.captionSm.copy(fontStyle = FontStyle.Italic),
                color = colors.secondaryText,
                modifier = Modifier.padding(top = 2.dp),
            )
            SmallLabel(
                text = ContentStore.uiString("today.saints.begin", "Begin"),
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
                text = ContentStore.uiString("today.prayer_rule", "Prayer Rule"),
                style = type.titleM.copy(fontStyle = FontStyle.Italic),
                color = colors.primaryText,
            )
            Text(
                text = if (progress >= 1f) ContentStore.uiString("today.prayer_rule.done", "All prayers complete") else ContentStore.uiString("today.prayer_rule.progress", "{done} of {total} prayers today").replace("{done}", "$done").replace("{total}", "$total"),
                style = type.captionSm,
                color = if (progress >= 1f) colors.goldLeaf else colors.secondaryText,
            )
        }
        Text(text = ContentStore.uiString("common.open", "Open"), style = type.captionSm, color = colors.sanctuaryRed)
    }
}

@Composable
private fun DevotionsSection(
    vm: TodayViewModel,
    onNavigateOffice: (() -> Unit)? = null,
    onNavigateStations: (() -> Unit)? = null,
    onNavigateConfession: (() -> Unit)? = null,
    onOfferingClick: (Prayer) -> Unit = {},
    modifier: Modifier = Modifier,
) {
    val colors = IntroiboTheme.colors
    val type = IntroiboType.current

    Column(modifier = modifier.fillMaxWidth()) {
        SectionLabel(title = "Devotiones Hodiernae", subtitle = ContentStore.uiString("today.devotions.sub", "Today's devotions"))
        Spacer(Modifier.height(14.dp))

        DevotionRow(title = ContentStore.uiString("today.devotion.office", "The Divine Office"), latin = "Officium Divinum, VIII Horae Canonicae", onClick = onNavigateOffice)
        DevotionRow(title = ContentStore.uiString("today.devotion.stations", "Stations of the Cross"), latin = "Via Crucis, XIV stationes", onClick = onNavigateStations)
        DevotionRow(title = ContentStore.uiString("today.devotion.confession", "Confession Guide"), latin = "De Confessione", onClick = onNavigateConfession)
        DevotionRow(title = vm.offeringTitle(), latin = vm.offeringLatin(), onClick = {
            ContentStore.prayer(vm.offeringSlug())?.let { onOfferingClick(it) }
        })
    }
}

@Composable
private fun DevotionRow(
    title: String,
    latin: String,
    onClick: (() -> Unit)? = null,
    modifier: Modifier = Modifier,
) {
    val colors = IntroiboTheme.colors
    val type = IntroiboType.current

    Column(
        modifier = modifier
            .fillMaxWidth()
            .then(if (onClick != null) Modifier.clickable { onClick() } else Modifier)
            .padding(vertical = 4.dp),
    ) {
        Text(
            text = title,
            style = type.titleM,
            color = colors.primaryText,
        )
        if (currentLanguageMode() != LanguageMode.VERNACULAR) {
            Text(
                text = latin,
                style = type.captionSm.copy(fontStyle = FontStyle.Italic),
                color = colors.secondaryText,
            )
        }
    }
}

@Composable
private fun RosaryCard(
    ctx: com.lampstandhq.introibo.data.liturgical.LiturgicalContext,
    rosaryLastDate: LocalDate?,
    onNavigateRosary: (() -> Unit)? = null,
    modifier: Modifier = Modifier,
) {
    val colors = IntroiboTheme.colors
    val type = IntroiboType.current

    Column(
        modifier = modifier
            .fillMaxWidth()
            .then(if (onNavigateRosary != null) Modifier.clickable { onNavigateRosary() } else Modifier),
    ) {
        SectionLabel(title = "Sacratissimum Rosarium", subtitle = ContentStore.uiString("today.rosary.sub", "of the Rosary"))
        Spacer(Modifier.height(8.dp))

        val rosaryLang = currentLanguageMode()
        if (rosaryLang != LanguageMode.VERNACULAR) {
            Text(
                text = ctx.mystery.latinName,
                style = type.titleM.copy(fontStyle = FontStyle.Italic),
                color = colors.primaryText,
            )
        }
        if (rosaryLang != LanguageMode.LATIN_ONLY) {
            Text(
                text = ctx.mystery.englishName,
                style = if (rosaryLang == LanguageMode.VERNACULAR) type.titleM.copy(fontStyle = FontStyle.Italic) else type.captionSm.copy(fontStyle = FontStyle.Italic),
                color = if (rosaryLang == LanguageMode.VERNACULAR) colors.primaryText else colors.secondaryText,
            )
        }

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
        SectionLabel(title = "Schola", subtitle = ContentStore.uiString("today.schola.sub", "Latin learning"))
        Spacer(Modifier.height(8.dp))
        Text(
            text = ContentStore.uiString("today.mastered", "Mastered: {0} of {1} lessons").replace("{0}", "${masteredLessons.size}").replace("{1}", "${ContentStore.courses.size}"),
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

// Pure helper (no composables) — computed inside remember{} at the call site.
private fun nextObligationDay(discipline: PenanceDiscipline): String? {
    var d = java.time.LocalDate.now().plusDays(1)
    repeat(60) {
        val ctx = LiturgicalContext.forDate(d, discipline)
        if (ctx.penance.strict || (ctx.isFriday && !ctx.isSunday)) {
            return "${VernacularDates.weekdayLongDate(d)} (${ctx.penance.title})"
        }
        d = d.plusDays(1)
    }
    return null
}

@Composable
private fun SettingsSheet(onDismiss: () -> Unit) {
    // Using a full-screen dialog approach for the settings sheet
    androidx.compose.ui.window.Dialog(
        onDismissRequest = onDismiss,
        properties = androidx.compose.ui.window.DialogProperties(usePlatformDefaultWidth = false),
    ) {
        Box(
            modifier = Modifier
                .fillMaxSize()
                .background(IntroiboTheme.colors.pageBackground),
        ) {
            SettingsScreen(onDismiss = onDismiss)
        }
    }
}
