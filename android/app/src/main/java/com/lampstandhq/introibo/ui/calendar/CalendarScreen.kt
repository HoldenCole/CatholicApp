package com.lampstandhq.introibo.ui.calendar

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
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.itemsIndexed
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
import com.lampstandhq.introibo.storage.settings.MissalRite
import com.lampstandhq.introibo.storage.settings.SettingsRepository
import com.lampstandhq.introibo.ui.theme.IntroiboTheme
import com.lampstandhq.introibo.ui.theme.IntroiboType
import com.lampstandhq.introibo.ui.theme.liturgicalColor
import kotlinx.coroutines.launch
import java.time.LocalDate

// MARK: - CalendarScreen (v1.2 feature 3: liturgical calendar)
//
// Browsable month grid of the traditional calendar, opened from the Today
// header. Each day shows its liturgical-colour pip; tapping a day opens a
// bottom-sheet detail with the feast/feria, season, colour, special-day flags,
// and a link to that day's Mass. All data comes from the bundled ordo tables
// via CalendarMonth.build / ContentStore.ordoForDate — zero network.
//
// iOS mirror: Introibo/Screens/Calendar/CalendarView.swift

private val weekdayLetters = listOf("S", "M", "T", "W", "T", "F", "S")

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

    val today = remember { LocalDate.now() }
    var year by rememberSaveable { mutableIntStateOf(today.year) }
    var month by rememberSaveable { mutableIntStateOf(today.monthValue) }
    var selectedDay by remember { mutableStateOf<CalendarDay?>(null) }

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

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(colors.pageBackground),
    ) {
        // ---- Title bar ----
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
                Icon(
                    imageVector = Icons.Filled.Close,
                    contentDescription = "Close",
                    tint = colors.tertiaryText,
                    modifier = Modifier.size(18.dp),
                )
            }
        }

        // ---- Month / year navigation ----
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 24.dp, vertical = 12.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            NavGlyph("«", enabled = year > yearRange.first) { step(-12) }
            NavGlyph("‹", enabled = canGoPrev) { step(-1) }
            Spacer(Modifier.weight(1f))
            Text(text = model.title, style = type.titleM, color = colors.primaryText)
            Spacer(Modifier.weight(1f))
            NavGlyph("›", enabled = canGoNext) { step(1) }
            NavGlyph("»", enabled = year < yearRange.last) { step(12) }
        }

        // ---- Weekday header ----
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 18.dp, bottom = 6.dp),
        ) {
            weekdayLetters.forEach { letter ->
                Text(
                    text = letter,
                    style = type.captionSm,
                    color = colors.tertiaryText,
                    textAlign = TextAlign.Center,
                    modifier = Modifier.weight(1f),
                )
            }
        }
        HorizontalDivider(color = colors.frameLine, thickness = 0.5.dp)

        // ---- Grid ----
        val cells: List<CalendarDay?> =
            List(model.leadingBlanks) { null } + model.days
        LazyVerticalGrid(
            columns = GridCells.Fixed(7),
            modifier = Modifier
                .fillMaxWidth()
                .weight(1f)
                .padding(horizontal = 18.dp, vertical = 8.dp),
        ) {
            itemsIndexed(cells) { _, cell ->
                if (cell == null) {
                    Box(Modifier.height(46.dp))
                } else {
                    DayCell(day = cell) { selectedDay = cell }
                }
            }
        }

        // ---- Colour legend ----
        Legend()
    }

    // ---- Day detail sheet ----
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
        fontSize = 18.sp,
        fontWeight = FontWeight.Medium,
        color = if (enabled) colors.goldLeaf else colors.frameLine,
        textAlign = TextAlign.Center,
        modifier = Modifier
            .width(28.dp)
            .let { if (enabled) it.clickable { onClick() } else it },
    )
}

@Composable
private fun DayCell(
    day: CalendarDay,
    onClick: () -> Unit,
) {
    val colors = IntroiboTheme.colors
    val type = IntroiboType.current
    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
        modifier = Modifier
            .height(46.dp)
            .fillMaxWidth()
            .clip(RoundedCornerShape(6.dp))
            .background(if (day.isToday) colors.sanctuaryRed else Color.Transparent)
            .clickable { onClick() },
    ) {
        Text(
            text = "${day.day}",
            style = type.bodySm,
            fontWeight = if (day.isMajor) FontWeight.SemiBold else FontWeight.Normal,
            color = if (day.isToday) colors.parchment else colors.primaryText,
        )
        Spacer(Modifier.height(3.dp))
        Box(
            modifier = Modifier
                .size(6.dp)
                .clip(RoundedCornerShape(3.dp))
                .background(day.colour?.let { liturgicalColor(it) } ?: Color.Transparent),
        )
    }
}

@Composable
private fun Legend() {
    val tertiary = IntroiboTheme.colors.tertiaryText
    val pairs = listOf(
        LiturgicalColour.WHITE to "White",
        LiturgicalColour.RED to "Red",
        LiturgicalColour.GREEN to "Green",
        LiturgicalColour.VIOLET to "Violet",
        LiturgicalColour.ROSE to "Rose",
        LiturgicalColour.BLACK to "Black",
    )
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(horizontal = 18.dp, vertical = 16.dp),
        horizontalArrangement = Arrangement.SpaceEvenly,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        pairs.forEach { (colour, label) ->
            Row(verticalAlignment = Alignment.CenterVertically) {
                Box(
                    modifier = Modifier
                        .size(6.dp)
                        .clip(RoundedCornerShape(3.dp))
                        .background(liturgicalColor(colour)),
                )
                Spacer(Modifier.width(4.dp))
                Text(text = label, fontSize = 9.sp, color = tertiary)
            }
        }
    }
}

@Composable
private fun DayDetail(
    day: CalendarDay,
    rite: MissalRite,
    onOpenProper: (String) -> Unit,
) {
    val colors = IntroiboTheme.colors
    val type = IntroiboType.current
    val ctx = remember(day.date) { LiturgicalContext.forDate(day.date) }
    val proper = remember(day.date, rite) { ContentStore.properForDate(day.date, rite) }
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
            Text(
                text = title,
                style = type.pageTitle,
                color = colors.ivory,
                textAlign = TextAlign.Center,
            )
            Spacer(Modifier.height(4.dp))
            Text(
                text = LongDateFormatter.format(day.date),
                style = type.bodySm.copy(fontStyle = FontStyle.Italic),
                color = colors.muted,
            )
        }

        Spacer(Modifier.height(20.dp))

        day.colour?.let { colour ->
            InfoRow(label = "Liturgical Colour", value = colour.key.replaceFirstChar { it.uppercase() }, swatch = colour)
            Spacer(Modifier.height(16.dp))
        }
        InfoRow(label = "Season", value = ctx.englishName)

        if (ctx.isFirstFriday || ctx.isFirstSaturday || ctx.isEmberDay) {
            Spacer(Modifier.height(16.dp))
            if (ctx.isFirstFriday) Flag("First Friday")
            if (ctx.isFirstSaturday) Flag("First Saturday")
            if (ctx.isEmberDay) Flag("Ember Day")
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
                Icon(
                    imageVector = Icons.Filled.MenuBook,
                    contentDescription = null,
                    tint = colors.sanctuaryRed,
                    modifier = Modifier.size(16.dp),
                )
                Spacer(Modifier.width(10.dp))
                Text(
                    text = "View the Mass",
                    style = type.titleM.copy(fontStyle = FontStyle.Italic),
                    color = colors.primaryText,
                )
                Spacer(Modifier.weight(1f))
                Text(text = "›", color = colors.tertiaryText, fontSize = 16.sp)
            }
        }
    }
}

@Composable
private fun InfoRow(label: String, value: String, swatch: LiturgicalColour? = null) {
    val colors = IntroiboTheme.colors
    val type = IntroiboType.current
    Column {
        Text(
            text = label.uppercase(),
            fontSize = 10.sp,
            letterSpacing = 1.5.sp,
            color = colors.tertiaryText,
        )
        Spacer(Modifier.height(4.dp))
        Row(verticalAlignment = Alignment.CenterVertically) {
            swatch?.let {
                Box(
                    modifier = Modifier
                        .size(10.dp)
                        .clip(RoundedCornerShape(5.dp))
                        .background(liturgicalColor(it)),
                )
                Spacer(Modifier.width(8.dp))
            }
            Text(text = value, style = type.body, color = colors.primaryText)
        }
    }
}

@Composable
private fun Flag(text: String) {
    val colors = IntroiboTheme.colors
    val type = IntroiboType.current
    Text(
        text = text,
        style = type.captionSm.copy(fontStyle = FontStyle.Italic),
        color = colors.sanctuaryRed,
        modifier = Modifier.padding(vertical = 2.dp),
    )
}
