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
import com.lampstandhq.introibo.storage.settings.MissalRite
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

        // Day list
        LazyColumn(
            state = listState,
            modifier = Modifier
                .fillMaxWidth()
                .weight(1f),
        ) {
            itemsIndexed(model.days) { _, day ->
                DayRow(day = day) { selectedDay = day }
                HorizontalDivider(
                    color = colors.frameLine.copy(alpha = 0.5f),
                    thickness = 0.5.dp,
                    modifier = Modifier.padding(start = 60.dp),
                )
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
private fun DayRow(day: CalendarDay, onClick: () -> Unit) {
    val colors = IntroiboTheme.colors
    val type = IntroiboType.current

    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier
            .fillMaxWidth()
            .clickable { onClick() }
            .padding(vertical = 14.dp),
    ) {
        // Liturgical colour bar
        Box(
            modifier = Modifier
                .width(3.dp)
                .height(52.dp)
                .background(day.colour?.let { liturgicalColor(it) } ?: Color.Transparent),
        )

        // Day number + weekday
        Column(
            horizontalAlignment = Alignment.CenterHorizontally,
            modifier = Modifier
                .width(52.dp)
                .padding(start = 4.dp),
        ) {
            Text(
                text = day.weekdayAbbrev,
                fontSize = 10.sp,
                fontWeight = FontWeight.Medium,
                letterSpacing = 0.5.sp,
                color = colors.tertiaryText,
            )
            Text(
                text = "${day.day}",
                fontSize = 24.sp,
                fontWeight = if (day.isMajor) FontWeight.SemiBold else FontWeight.Normal,
                color = if (day.isToday) colors.sanctuaryRed else colors.primaryText,
            )
        }

        // Feast / feria name + badges
        Column(
            modifier = Modifier
                .weight(1f)
                .padding(start = 12.dp),
        ) {
            Text(
                text = day.label ?: "Feria",
                style = type.body,
                fontWeight = if (day.isMajor) FontWeight.Medium else FontWeight.Normal,
                color = colors.primaryText,
                maxLines = 2,
                overflow = TextOverflow.Ellipsis,
            )
            if (day.isSunday) {
                Spacer(Modifier.height(4.dp))
                Text(
                    text = "SUNDAY OBLIGATION",
                    fontSize = 9.sp,
                    fontWeight = FontWeight.SemiBold,
                    letterSpacing = 0.5.sp,
                    color = colors.sanctuaryRed,
                    modifier = Modifier
                        .border(0.5.dp, colors.sanctuaryRed.copy(alpha = 0.5f), RoundedCornerShape(3.dp))
                        .padding(horizontal = 8.dp, vertical = 3.dp),
                )
            }
        }

        // Chevron
        Text(
            text = "›",
            fontSize = 20.sp,
            color = colors.tertiaryText,
            modifier = Modifier.padding(end = 16.dp),
        )
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
            Text(text = title, style = type.pageTitle, color = colors.ivory, textAlign = TextAlign.Center)
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
