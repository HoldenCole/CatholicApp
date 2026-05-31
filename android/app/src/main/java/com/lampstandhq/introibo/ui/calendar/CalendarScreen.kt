package com.lampstandhq.introibo.ui.calendar

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
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.MenuBook
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Text
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.lampstandhq.introibo.data.content.ContentStore
import com.lampstandhq.introibo.data.liturgical.CalendarDay
import com.lampstandhq.introibo.data.liturgical.CalendarMonth
import com.lampstandhq.introibo.data.liturgical.LiturgicalColour
import com.lampstandhq.introibo.data.liturgical.LiturgicalContext
import com.lampstandhq.introibo.data.liturgical.LongDateFormatter
import com.lampstandhq.introibo.data.liturgical.isEmberDay
import com.lampstandhq.introibo.data.liturgical.isFirstFriday
import com.lampstandhq.introibo.data.liturgical.isFirstSaturday
import com.lampstandhq.introibo.storage.settings.LanguageMode
import com.lampstandhq.introibo.storage.settings.MissalRite
import com.lampstandhq.introibo.storage.settings.PenanceDiscipline
import com.lampstandhq.introibo.storage.settings.SettingsRepository
import com.lampstandhq.introibo.ui.theme.IntroiboTheme
import com.lampstandhq.introibo.ui.theme.IntroiboType
import com.lampstandhq.introibo.ui.theme.liturgicalColor
import kotlinx.coroutines.launch
import java.time.LocalDate

// MARK: - CalendarScreen (v1.2 feature 3: liturgical calendar)
//
// List-based month view of the traditional calendar. Each day gets a full row
// showing the liturgical-colour bar, day-of-week, day number, feast/feria
// name, and Sunday-obligation badge. Tapping a row opens a bottom-sheet
// detail. iOS mirror: Introibo/Screens/Calendar/CalendarView.swift

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun CalendarScreen(
    onBack: () -> Unit,
    onOpenProper: (String) -> Unit,
) {
    val context = LocalContext.current
    val colors = IntroiboTheme.colors
    val type = IntroiboType.current
    val settingsRepo = remember { SettingsRepository(context) }
    val rite by settingsRepo.missalRite.collectAsState(initial = MissalRite.RITE_1962)
    val langMode by settingsRepo.languageMode.collectAsState(initial = LanguageMode.BOTH)

    val today = remember { LocalDate.now() }
    var year by rememberSaveable { mutableIntStateOf(today.year) }
    var month by rememberSaveable { mutableIntStateOf(today.monthValue) }
    var selectedDay by remember { mutableStateOf<CalendarDay?>(null) }
    var viewMode by rememberSaveable { mutableStateOf("list") } // "list" | "month"

    val yearRange = remember(rite) { ContentStore.ordoYearRange(rite) }
    val model = remember(year, month, rite) { CalendarMonth.build(year, month, rite, today) }

    val canGoPrev = !(year == yearRange.first && month == 1)
    val canGoNext = !(year == yearRange.last && month == 12)
    val isCurrentMonth = year == today.year && month == today.monthValue

    fun step(months: Int) {
        var m = month + months
        var y = year
        while (m > 12) { m -= 12; y += 1 }
        while (m < 1) { m += 12; y -= 1 }
        y = y.coerceIn(yearRange.first, yearRange.last)
        year = y
        month = m
    }

    val listState = rememberLazyListState()
    LaunchedEffect(year, month) {
        val todayIdx = model.days.indexOfFirst { it.isToday }
        if (todayIdx >= 0) listState.animateScrollToItem(todayIdx)
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(colors.pageBackground),
    ) {
        // Title bar
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 24.dp)
                .padding(top = 20.dp, bottom = 8.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(
                text = "KALENDÁRIUM",
                style = type.smallLabel,
                color = colors.sanctuaryRed,
                letterSpacing = 2.sp,
            )
            Spacer(Modifier.weight(1f))
            ViewModePicker(viewMode) { viewMode = it }
            Spacer(Modifier.width(8.dp))
            if (!isCurrentMonth) {
                Text(
                    text = "Today",
                    style = type.captionSm,
                    color = colors.sanctuaryRed,
                    modifier = Modifier
                        .clickable { year = today.year; month = today.monthValue }
                        .padding(end = 8.dp),
                )
            }
            IconButton(onClick = onBack) {
                Icon(Icons.Filled.Close, "Close", tint = colors.tertiaryText, modifier = Modifier.size(18.dp))
            }
        }

        // Month / year nav
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 24.dp, vertical = 10.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            NavGlyph("‹", canGoPrev) { step(-1) }
            Spacer(Modifier.weight(1f))
            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                Text(text = model.title.substringBefore(" "), style = type.titleM, color = colors.primaryText)
                Text(text = "$year", style = type.captionSm, color = colors.tertiaryText)
            }
            Spacer(Modifier.weight(1f))
            NavGlyph("›", canGoNext) { step(1) }
        }
        HorizontalDivider(color = colors.frameLine, thickness = 0.5.dp)

        // Content — list, week, or month grid
        fun showsSeasonHeader(idx: Int): Boolean {
            if (idx < 0 || idx >= model.days.size) return false
            if (model.days[idx].seasonLabel == null) return false
            if (idx == 0) return true
            return model.days[idx - 1].seasonLabel != model.days[idx].seasonLabel
        }
        when (viewMode) {
            "month" -> {
                MonthGrid(model = model, langMode = langMode) { selectedDay = it }
            }
            else -> {
                LazyColumn(
                    state = listState,
                    modifier = Modifier.fillMaxWidth().weight(1f),
                ) {
                    itemsIndexed(model.days) { idx, day ->
                        if (showsSeasonHeader(idx)) SeasonDivider(day.seasonLabel ?: "")
                        DayRow(day = day, mode = langMode) { selectedDay = day }
                        if (idx < model.days.size - 1 && !showsSeasonHeader(idx + 1)) {
                            HorizontalDivider(color = colors.goldLeaf.copy(alpha = 0.16f), thickness = 0.5.dp, modifier = Modifier.padding(start = 78.dp))
                        }
                    }
                }
            }
        }
    }

    // Day detail sheet
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    val scope = rememberCoroutineScope()
    selectedDay?.let { day ->
        ModalBottomSheet(
            onDismissRequest = { selectedDay = null },
            sheetState = sheetState,
            containerColor = colors.pageBackground,
        ) {
            DayDetail(
                day = day,
                rite = rite,
                mode = langMode,
                discipline = settingsRepo.penanceDiscipline.collectAsState(initial = PenanceDiscipline.DISCIPLINE_1962).value,
                onOpenProper = { slug ->
                    scope.launch { sheetState.hide() }.invokeOnCompletion {
                        selectedDay = null
                        onOpenProper(slug)
                    }
                },
            )
        }
    }
}

@Composable
private fun NavGlyph(glyph: String, enabled: Boolean, onClick: () -> Unit) {
    val colors = IntroiboTheme.colors
    Text(
        text = glyph,
        fontSize = 22.sp,
        fontWeight = FontWeight.Medium,
        color = if (enabled) colors.goldLeaf else colors.frameLine,
        textAlign = TextAlign.Center,
        modifier = Modifier
            .size(44.dp)
            .clip(CircleShape)
            .background(if (enabled) colors.goldLeaf.copy(alpha = 0.08f) else Color.Transparent)
            .let { if (enabled) it.clickable { onClick() } else it }
            .padding(top = 8.dp),
    )
}

@Composable
private fun SeasonDivider(label: String) {
    val colors = IntroiboTheme.colors
    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 28.dp)
            .padding(top = 24.dp, bottom = 12.dp),
    ) {
        HorizontalDivider(color = colors.goldLeaf.copy(alpha = 0.3f), thickness = 0.5.dp, modifier = Modifier.weight(1f))
        Text(
            text = label.uppercase(),
            fontSize = 10.sp,
            fontWeight = FontWeight.SemiBold,
            letterSpacing = 2.5.sp,
            color = colors.goldLeaf,
            modifier = Modifier.padding(horizontal = 12.dp),
        )
        HorizontalDivider(color = colors.goldLeaf.copy(alpha = 0.3f), thickness = 0.5.dp, modifier = Modifier.weight(1f))
    }
}

@Composable
private fun DayRow(day: CalendarDay, mode: LanguageMode, onClick: () -> Unit) {
    val colors = IntroiboTheme.colors
    val type = IntroiboType.current

    val litColor = day.colour?.let { liturgicalColor(it) } ?: colors.frameLine
    val ringColor = when {
        day.isToday -> colors.sanctuaryRed
        else -> litColor.copy(alpha = if (day.isMajor) 0.8f else 0.45f)
    }

    Row(
        verticalAlignment = Alignment.Top,
        modifier = Modifier
            .fillMaxWidth()
            .clickable { onClick() }
            .padding(horizontal = 22.dp, vertical = 13.dp),
    ) {
        // Illuminated medallion: soft colour wash + ring around the serif number.
        Box(
            contentAlignment = Alignment.Center,
            modifier = Modifier
                .size(40.dp)
                .clip(CircleShape)
                .background(if (day.isToday) colors.sanctuaryRed else litColor.copy(alpha = 0.14f))
                .border(if (day.isMajor) 1.5.dp else 1.dp, ringColor, CircleShape),
        ) {
            Text(
                text = "${day.day}",
                fontSize = 16.sp,
                fontFamily = type.pageTitle.fontFamily,
                fontWeight = if (day.isMajor) FontWeight.SemiBold else FontWeight.Normal,
                color = if (day.isToday) colors.parchment else colors.primaryText,
            )
        }

        Spacer(Modifier.width(14.dp))

        // Weekday + bilingual feast name
        Column(modifier = Modifier.weight(1f)) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                Text(
                    text = day.weekdayAbbrev,
                    fontSize = 10.sp,
                    fontWeight = FontWeight.Medium,
                    letterSpacing = 1.sp,
                    color = colors.tertiaryText,
                )
                if (day.isSunday) {
                    Spacer(Modifier.width(6.dp))
                    Text(text = "✠", fontSize = 9.sp, color = colors.sanctuaryRed)
                }
            }
            if (mode != LanguageMode.VERNACULAR) {
                Text(
                    text = day.label ?: "Feria",
                    style = type.body,
                    fontWeight = if (day.isMajor) FontWeight.SemiBold else FontWeight.Normal,
                    color = colors.primaryText,
                    maxLines = 2,
                    overflow = TextOverflow.Ellipsis,
                )
            }
            if (mode != LanguageMode.LATIN_ONLY) {
                Text(
                    text = day.englishLine,
                    style = type.captionSm.copy(fontStyle = FontStyle.Italic),
                    color = colors.secondaryText,
                    maxLines = 2,
                    overflow = TextOverflow.Ellipsis,
                )
            }
        }

        Spacer(Modifier.width(8.dp))
        Text(text = "›", fontSize = 18.sp, color = colors.tertiaryText.copy(alpha = 0.6f))
    }
}

@Composable
private fun DayDetail(
    day: CalendarDay,
    rite: MissalRite,
    mode: LanguageMode,
    discipline: PenanceDiscipline = PenanceDiscipline.DISCIPLINE_1962,
    onOpenProper: (String) -> Unit,
) {
    val colors = IntroiboTheme.colors
    val type = IntroiboType.current
    val ctx = remember(day.date, discipline) { LiturgicalContext.forDate(day.date, discipline) }
    val proper = remember(day.date, rite) { ContentStore.properForDate(day.date, rite) }
    val penance = ctx.penance
    val title = day.ordo?.name ?: ctx.feriaLatin

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 28.dp)
            .padding(bottom = 32.dp),
    ) {
        // Header band
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            modifier = Modifier
                .fillMaxWidth()
                .clip(RoundedCornerShape(8.dp))
                .background(Brush.verticalGradient(listOf(colors.walnut, colors.walnutHi)))
                .padding(vertical = 18.dp, horizontal = 16.dp),
        ) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                day.colour?.let {
                    Box(
                        modifier = Modifier
                            .size(8.dp)
                            .clip(RoundedCornerShape(4.dp))
                            .background(liturgicalColor(it)),
                    )
                    Spacer(Modifier.width(8.dp))
                }
                Text(
                    text = "${ctx.feriaEnglish}  ·  ${ctx.englishName}",
                    style = type.smallLabel,
                    color = colors.goldLeaf,
                    letterSpacing = 1.5.sp,
                )
            }
            Spacer(Modifier.height(8.dp))
            Text(text = title, style = type.pageTitle, color = colors.ivory, textAlign = TextAlign.Center)
            if (mode != LanguageMode.LATIN_ONLY && day.englishName != null) {
                Spacer(Modifier.height(6.dp))
                Text(
                    text = day.englishName,
                    style = type.bodySm.copy(fontStyle = FontStyle.Italic),
                    color = colors.goldLeaf.copy(alpha = 0.85f),
                    textAlign = TextAlign.Center,
                )
            }
            Spacer(Modifier.height(4.dp))
            Text(
                text = LongDateFormatter.format(day.date),
                style = type.bodySm.copy(fontStyle = FontStyle.Italic),
                color = colors.muted,
            )
        }

        Spacer(Modifier.height(20.dp))

        day.colour?.let { colour ->
            InfoRow("Liturgical Colour", colour.key.replaceFirstChar { it.uppercase() }, colour)
            Spacer(Modifier.height(16.dp))
        }
        InfoRow("Season", ctx.englishName)

        if (ctx.isFirstFriday || ctx.isFirstSaturday || ctx.isEmberDay) {
            Spacer(Modifier.height(16.dp))
            if (ctx.isFirstFriday) Flag("First Friday")
            if (ctx.isFirstSaturday) Flag("First Saturday")
            if (ctx.isEmberDay) Flag("Ember Day")
        }

        if (day.isSunday) {
            Spacer(Modifier.height(16.dp))
            Flag("Sunday Obligation")
        }

        // Penance / fasting card
        Spacer(Modifier.height(18.dp))
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .border(
                    0.5.dp,
                    if (penance.strict) colors.sanctuaryRed.copy(alpha = 0.3f) else colors.frameLine,
                    RoundedCornerShape(6.dp),
                )
                .padding(14.dp),
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(
                    text = "FASTING & ABSTINENCE",
                    fontSize = 10.sp,
                    letterSpacing = 1.5.sp,
                    color = colors.tertiaryText,
                )
                Text(
                    text = discipline.short,
                    fontSize = 9.sp,
                    color = colors.goldLeaf,
                )
            }
            Spacer(Modifier.height(8.dp))
            Row(verticalAlignment = Alignment.CenterVertically) {
                Box(
                    modifier = Modifier
                        .size(8.dp)
                        .clip(CircleShape)
                        .background(if (penance.strict) colors.sanctuaryRed else colors.goldLeaf),
                )
                Spacer(Modifier.width(8.dp))
                Text(
                    text = penance.title,
                    style = type.body,
                    fontWeight = FontWeight.Medium,
                    color = colors.primaryText,
                )
            }
            Spacer(Modifier.height(6.dp))
            Text(
                text = penance.desc,
                style = type.captionSm,
                color = colors.secondaryText,
                lineHeight = type.captionSm.fontSize * 1.4f,
            )
        }

        if (proper != null) {
            Spacer(Modifier.height(20.dp))
            Row(
                verticalAlignment = Alignment.CenterVertically,
                modifier = Modifier
                    .fillMaxWidth()
                    .clickable { onOpenProper(proper.slug) }
                    .padding(14.dp),
            ) {
                Icon(Icons.Filled.MenuBook, null, tint = colors.sanctuaryRed, modifier = Modifier.size(16.dp))
                Spacer(Modifier.width(10.dp))
                Text("View the Mass", style = type.titleM.copy(fontStyle = FontStyle.Italic), color = colors.primaryText)
                Spacer(Modifier.weight(1f))
                Text("›", color = colors.tertiaryText, fontSize = 16.sp)
            }
        }
    }
}

@Composable
private fun InfoRow(label: String, value: String, swatch: LiturgicalColour? = null) {
    val colors = IntroiboTheme.colors
    val type = IntroiboType.current
    Column {
        Text(label.uppercase(), fontSize = 10.sp, letterSpacing = 1.5.sp, color = colors.tertiaryText)
        Spacer(Modifier.height(4.dp))
        Row(verticalAlignment = Alignment.CenterVertically) {
            swatch?.let {
                Box(Modifier.size(10.dp).clip(RoundedCornerShape(5.dp)).background(liturgicalColor(it)))
                Spacer(Modifier.width(8.dp))
            }
            Text(value, style = type.body, color = colors.primaryText)
        }
    }
}

@Composable
private fun Flag(text: String) {
    val colors = IntroiboTheme.colors
    val type = IntroiboType.current
    Text(text, style = type.captionSm.copy(fontStyle = FontStyle.Italic), color = colors.sanctuaryRed, modifier = Modifier.padding(vertical = 2.dp))
}

// ---------------------------------------------------------------------------
// View mode picker
// ---------------------------------------------------------------------------

private data class ModeEntry(val key: String, val icon: String)
private val modes = listOf(
    ModeEntry("list", "≡"),
    ModeEntry("month", "▦"),
)

@Composable
private fun ViewModePicker(current: String, onSelect: (String) -> Unit) {
    val colors = IntroiboTheme.colors
    Row(
        modifier = Modifier
            .border(0.5.dp, colors.frameLine, RoundedCornerShape(5.dp))
            .clip(RoundedCornerShape(5.dp)),
    ) {
        modes.forEach { mode ->
            val selected = current == mode.key
            Box(
                contentAlignment = Alignment.Center,
                modifier = Modifier
                    .size(width = 30.dp, height = 26.dp)
                    .background(if (selected) colors.sanctuaryRed else Color.Transparent)
                    .clickable { onSelect(mode.key) },
            ) {
                Text(
                    text = mode.icon,
                    fontSize = 12.sp,
                    fontWeight = FontWeight.Medium,
                    color = if (selected) colors.parchment else colors.tertiaryText,
                )
            }
        }
    }
}

// ---------------------------------------------------------------------------
// Month grid view
// ---------------------------------------------------------------------------

private val weekdayLetters = listOf("S", "M", "T", "W", "T", "F", "S")

@Composable
private fun MonthGrid(
    model: CalendarMonth,
    langMode: LanguageMode,
    onSelect: (CalendarDay) -> Unit,
) {
    val colors = IntroiboTheme.colors
    Column(modifier = Modifier.fillMaxWidth().weight(1f)) {
        Row(modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 8.dp)) {
            weekdayLetters.forEach { letter ->
                Text(
                    text = letter,
                    fontSize = 10.sp,
                    fontWeight = FontWeight.Medium,
                    color = colors.tertiaryText,
                    textAlign = TextAlign.Center,
                    modifier = Modifier.weight(1f),
                )
            }
        }
        LazyVerticalGrid(
            columns = GridCells.Fixed(7),
            modifier = Modifier.fillMaxWidth().weight(1f).padding(horizontal = 16.dp),
        ) {
            items(model.leadingBlanks) { Box(Modifier.height(56.dp)) }
            items(model.days.size) { idx ->
                val day = model.days[idx]
                GridCell(day, langMode) { onSelect(day) }
            }
        }
    }
}

@Composable
private fun GridCell(day: CalendarDay, langMode: LanguageMode, onClick: () -> Unit) {
    val colors = IntroiboTheme.colors
    val litColor = day.colour?.let { liturgicalColor(it) } ?: colors.frameLine
    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        modifier = Modifier
            .height(56.dp)
            .fillMaxWidth()
            .clickable { onClick() },
    ) {
        Box(
            contentAlignment = Alignment.Center,
            modifier = Modifier
                .size(30.dp)
                .clip(CircleShape)
                .background(if (day.isToday) colors.sanctuaryRed else litColor.copy(alpha = 0.14f))
                .border(if (day.isMajor) 1.5.dp else 0.5.dp,
                    if (day.isToday) colors.sanctuaryRed else litColor.copy(alpha = if (day.isMajor) 0.8f else 0.3f),
                    CircleShape),
        ) {
            Text(
                text = "${day.day}",
                fontSize = 13.sp,
                fontWeight = if (day.isMajor) FontWeight.SemiBold else FontWeight.Normal,
                color = if (day.isToday) colors.parchment else colors.primaryText,
            )
        }
        Spacer(Modifier.height(2.dp))
        val label = if (langMode != LanguageMode.LATIN_ONLY && day.englishName != null) {
            day.englishName.substringBefore(",")
        } else {
            (day.label ?: "").split(" ").take(3).joinToString(" ")
        }
        Text(
            text = label,
            fontSize = 8.sp,
            color = colors.secondaryText,
            maxLines = 2,
            overflow = TextOverflow.Ellipsis,
            textAlign = TextAlign.Center,
            lineHeight = 9.sp,
        )
    }
}
