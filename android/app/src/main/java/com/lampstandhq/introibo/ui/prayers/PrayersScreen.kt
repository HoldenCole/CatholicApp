package com.lampstandhq.introibo.ui.prayers

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.defaultMinSize
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.CheckCircle
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.MenuBook
import androidx.compose.material.icons.filled.RadioButtonUnchecked
import androidx.compose.material.icons.filled.Schedule
import androidx.compose.material.icons.filled.Search
import androidx.compose.material.icons.filled.SortByAlpha
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Text
import androidx.compose.material3.TextField
import androidx.compose.material3.TextFieldDefaults
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.unit.dp
import com.lampstandhq.introibo.data.content.ContentStore
import com.lampstandhq.introibo.data.model.Prayer
import com.lampstandhq.introibo.data.model.strippingEm
import com.lampstandhq.introibo.storage.progress.PrayerRule
import com.lampstandhq.introibo.storage.progress.UserProgressRepository
import com.lampstandhq.introibo.ui.components.SmallLabel
import com.lampstandhq.introibo.ui.theme.IntroiboTheme
import com.lampstandhq.introibo.ui.theme.IntroiboType
import kotlinx.coroutines.launch

private val occasions = listOf(
    "Morning", "Before Mass", "During Mass", "After Mass", "Meals",
    "Marian", "Eucharistic", "Before Confession",
    "For the Departed", "In Temptation", "For Protection", "Evening",
)

/**
 * Prayers (Oratio) tab screen. Shows prayer rule, occasions grid,
 * and full prayer library with search. Ported from iOS PrayersView.swift.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun PrayersScreen() {
    val context = LocalContext.current
    val colors = IntroiboTheme.colors
    val type = IntroiboType.current
    val scope = rememberCoroutineScope()

    val progressRepo = remember { UserProgressRepository(context) }
    val prayerRule by progressRepo.prayerRule.collectAsState(initial = PrayerRule())
    val completedPrayers by progressRepo.completedPrayers().collectAsState(initial = emptySet())

    var selectedPrayer by remember { mutableStateOf<Prayer?>(null) }
    var searchText by remember { mutableStateOf("") }
    var sortAlphabetical by remember { mutableStateOf(false) }
    var showPrayerRuleEditor by remember { mutableStateOf(false) }
    var selectedOccasion by remember { mutableStateOf<String?>(null) }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(colors.pageBackground),
    ) {
        TopAppBar(
            title = {
                Text(
                    text = "Oratio",
                    style = type.titleM.copy(fontStyle = FontStyle.Italic),
                    color = colors.primaryText,
                )
            },
            colors = TopAppBarDefaults.topAppBarColors(
                containerColor = colors.pageBackground,
            ),
        )

        LazyColumn(
            modifier = Modifier
                .fillMaxSize()
                .padding(horizontal = 20.dp),
            verticalArrangement = Arrangement.spacedBy(28.dp),
        ) {
            item { Spacer(Modifier.height(4.dp)) }

            // ---- Daily Rule or Setup Card ----
            item {
                if (!prayerRule.isEmpty) {
                    DailyRuleSection(
                        prayerRule = prayerRule,
                        completedPrayers = completedPrayers,
                        onTogglePrayer = { slug ->
                            scope.launch { progressRepo.togglePrayer(slug) }
                        },
                        onOpenPrayer = { prayer -> selectedPrayer = prayer },
                    )
                } else {
                    SetupRuleCard(onBegin = { showPrayerRuleEditor = true })
                }
            }

            // ---- Occasions Grid ----
            item {
                OccasionsSection(onOccasionClick = { occasion -> selectedOccasion = occasion })
            }

            // ---- Full Library ----
            item {
                FullLibrarySection(
                    searchText = searchText,
                    onSearchChange = { searchText = it },
                    sortAlphabetical = sortAlphabetical,
                    onToggleSort = { sortAlphabetical = !sortAlphabetical },
                    onSelectPrayer = { selectedPrayer = it },
                )
            }

            item { Spacer(Modifier.height(40.dp)) }
        }
    }

    // Prayer detail sheet
    selectedPrayer?.let { prayer ->
        PrayerDetailSheet(
            prayer = prayer,
            onDismiss = { selectedPrayer = null },
        )
    }

    // Occasion filter sheet - shows prayers for the selected occasion
    selectedOccasion?.let { occasion ->
        val occasionPrayers = ContentStore.prayers.filter {
            (it.occasions ?: emptyList()).contains(occasion)
        }
        if (occasionPrayers.isNotEmpty()) {
            OccasionPrayerSheet(
                occasion = occasion,
                prayers = occasionPrayers,
                onSelectPrayer = { prayer ->
                    selectedOccasion = null
                    selectedPrayer = prayer
                },
                onDismiss = { selectedOccasion = null },
            )
        } else {
            selectedOccasion = null
        }
    }

    // Prayer rule editor sheet
    if (showPrayerRuleEditor) {
        PrayerRuleEditorSheet(
            progressRepo = progressRepo,
            onDismiss = { showPrayerRuleEditor = false },
        )
    }
}

// ---------------------------------------------------------------------------
// Daily Rule Section
// ---------------------------------------------------------------------------

@Composable
private fun DailyRuleSection(
    prayerRule: PrayerRule,
    completedPrayers: Set<String>,
    onTogglePrayer: (String) -> Unit,
    onOpenPrayer: (Prayer) -> Unit,
) {
    val colors = IntroiboTheme.colors
    val type = IntroiboType.current

    val done = completedPrayers.intersect(prayerRule.allSlugs.toSet()).size
    val total = prayerRule.totalCount
    val progress = if (total > 0) done.toFloat() / total else 0f

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .border(1.dp, colors.sanctuaryRed.copy(alpha = 0.3f))
            .padding(16.dp),
    ) {
        // Header with progress ring
        Row(
            verticalAlignment = Alignment.CenterVertically,
            modifier = Modifier.fillMaxWidth(),
        ) {
            Column(modifier = Modifier.weight(1f)) {
                SmallLabel(text = "Regula Orationis", color = colors.sanctuaryRed)
                Text(
                    text = "My Daily Rule",
                    style = type.captionSm.copy(fontStyle = FontStyle.Italic),
                    color = colors.secondaryText,
                )
            }

            // Progress ring
            Box(
                contentAlignment = Alignment.Center,
                modifier = Modifier
                    .size(40.dp)
                    .drawBehind {
                        val stroke = Stroke(width = 3.dp.toPx(), cap = StrokeCap.Round)
                        drawArc(
                            color = colors.frameLine,
                            startAngle = 0f,
                            sweepAngle = 360f,
                            useCenter = false,
                            style = stroke,
                            topLeft = Offset(stroke.width / 2, stroke.width / 2),
                            size = Size(size.width - stroke.width, size.height - stroke.width),
                        )
                        if (progress > 0f) {
                            drawArc(
                                color = if (done == total && total > 0) colors.goldLeaf else colors.sanctuaryRed,
                                startAngle = -90f,
                                sweepAngle = 360f * progress,
                                useCenter = false,
                                style = stroke,
                                topLeft = Offset(stroke.width / 2, stroke.width / 2),
                                size = Size(size.width - stroke.width, size.height - stroke.width),
                            )
                        }
                    },
            ) {
                Text(
                    text = "$done",
                    style = type.titleM,
                    color = colors.primaryText,
                )
            }
        }

        Spacer(Modifier.height(12.dp))

        // Rule periods
        if (prayerRule.morning.isNotEmpty()) {
            RulePeriod(
                lat = "Mane", eng = "Morning",
                slugs = prayerRule.morning,
                completedPrayers = completedPrayers,
                onToggle = onTogglePrayer,
                onOpen = onOpenPrayer,
            )
        }
        if (prayerRule.midday.isNotEmpty()) {
            RulePeriod(
                lat = "Meridies", eng = "Midday",
                slugs = prayerRule.midday,
                completedPrayers = completedPrayers,
                onToggle = onTogglePrayer,
                onOpen = onOpenPrayer,
            )
        }
        if (prayerRule.evening.isNotEmpty()) {
            RulePeriod(
                lat = "Vesperae", eng = "Evening",
                slugs = prayerRule.evening,
                completedPrayers = completedPrayers,
                onToggle = onTogglePrayer,
                onOpen = onOpenPrayer,
            )
        }
    }
}

@Composable
private fun RulePeriod(
    lat: String,
    eng: String,
    slugs: List<String>,
    completedPrayers: Set<String>,
    onToggle: (String) -> Unit,
    onOpen: (Prayer) -> Unit,
) {
    val colors = IntroiboTheme.colors
    val type = IntroiboType.current

    Column(modifier = Modifier.padding(top = 12.dp)) {
        SmallLabel(text = "$lat  ·  $eng", color = colors.goldLeaf)
        Spacer(Modifier.height(8.dp))

        slugs.forEach { slug ->
            // Office hours in the rule ("office-<hour>") render as a checkable
            // row with the hour's name and time (iOS parity).
            if (slug.startsWith("office-")) {
                val hour = ContentStore.hour(slug.removePrefix("office-")) ?: return@forEach
                val isDone = slug in completedPrayers
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    modifier = Modifier
                        .fillMaxWidth()
                        .clickable { onToggle(slug) }
                        .padding(vertical = 4.dp),
                ) {
                    Icon(
                        imageVector = if (isDone) Icons.Filled.CheckCircle else Icons.Filled.RadioButtonUnchecked,
                        contentDescription = null,
                        tint = if (isDone) colors.goldLeaf else colors.frameLine,
                        modifier = Modifier.size(24.dp),
                    )
                    Spacer(Modifier.width(12.dp))
                    Column(modifier = Modifier.weight(1f)) {
                        Text(
                            text = hour.name,
                            style = type.titleM.copy(fontStyle = FontStyle.Italic),
                            color = if (isDone) colors.tertiaryText else colors.primaryText,
                            textDecoration = if (isDone) TextDecoration.LineThrough else null,
                        )
                        Text(
                            text = "${hour.eng} — ${hour.time}",
                            style = type.captionSm,
                            color = if (isDone) colors.tertiaryText else colors.secondaryText,
                        )
                    }
                    Icon(
                        imageVector = Icons.Filled.Schedule,
                        contentDescription = null,
                        tint = colors.sanctuaryRed,
                        modifier = Modifier.size(16.dp),
                    )
                }
                return@forEach
            }

            val prayer = ContentStore.prayer(slug) ?: return@forEach
            val isDone = slug in completedPrayers

            Row(
                verticalAlignment = Alignment.CenterVertically,
                modifier = Modifier
                    .fillMaxWidth()
                    .clickable { onToggle(slug) }
                    .padding(vertical = 4.dp),
            ) {
                Icon(
                    imageVector = if (isDone) Icons.Filled.CheckCircle else Icons.Filled.RadioButtonUnchecked,
                    contentDescription = null,
                    tint = if (isDone) colors.goldLeaf else colors.frameLine,
                    modifier = Modifier.size(24.dp),
                )
                Spacer(Modifier.width(12.dp))
                Column(modifier = Modifier.weight(1f)) {
                    Text(
                        text = prayer.title.strippingEm,
                        style = type.titleM.copy(fontStyle = FontStyle.Italic),
                        color = if (isDone) colors.tertiaryText else colors.primaryText,
                        textDecoration = if (isDone) TextDecoration.LineThrough else null,
                    )
                    Text(
                        text = prayer.eng,
                        style = type.captionSm,
                        color = if (isDone) colors.tertiaryText else colors.secondaryText,
                    )
                }
                IconButton(onClick = { onOpen(prayer) }) {
                    Icon(
                        imageVector = Icons.Filled.MenuBook,
                        contentDescription = "Read",
                        tint = colors.sanctuaryRed,
                        modifier = Modifier.size(16.dp),
                    )
                }
            }
        }
    }
}

// ---------------------------------------------------------------------------
// Setup CTA
// ---------------------------------------------------------------------------

@Composable
private fun SetupRuleCard(onBegin: () -> Unit = {}) {
    val colors = IntroiboTheme.colors
    val type = IntroiboType.current

    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        modifier = Modifier
            .fillMaxWidth()
            .border(1.dp, colors.sanctuaryRed.copy(alpha = 0.3f))
            .clickable { onBegin() }
            .padding(20.dp),
    ) {
        Text(text = "✠", style = type.titleL, color = colors.sanctuaryRed)
        Text(
            text = "Create Your Prayer Rule",
            style = type.titleM.copy(fontStyle = FontStyle.Italic),
            color = colors.primaryText,
            modifier = Modifier.padding(top = 4.dp),
        )
        Text(
            text = "Choose prayers for morning, midday, and evening",
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

// ---------------------------------------------------------------------------
// Occasions Grid
// ---------------------------------------------------------------------------

@Composable
private fun OccasionsSection(onOccasionClick: (String) -> Unit = {}) {
    val colors = IntroiboTheme.colors
    val type = IntroiboType.current

    Column {
        // Header
        Row(
            verticalAlignment = Alignment.CenterVertically,
            modifier = Modifier.fillMaxWidth(),
        ) {
            Box(
                modifier = Modifier
                    .weight(1f)
                    .height(1.dp)
                    .background(colors.sanctuaryRed.copy(alpha = 0.4f)),
            )
            Text(
                text = "OCCASIONES",
                style = type.titleM.copy(
                    fontStyle = FontStyle.Italic,
                    letterSpacing = type.smallLabel.letterSpacing,
                ),
                color = colors.sanctuaryRed,
                modifier = Modifier.padding(horizontal = 10.dp),
            )
            Box(
                modifier = Modifier
                    .weight(1f)
                    .height(1.dp)
                    .background(colors.sanctuaryRed.copy(alpha = 0.4f)),
            )
        }

        Spacer(Modifier.height(14.dp))

        // Grid - using a Column with Rows since LazyVerticalGrid can't nest in LazyColumn
        val rows = occasions.chunked(2)
        rows.forEach { rowItems ->
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.spacedBy(10.dp),
            ) {
                rowItems.forEach { occasion ->
                    val count = ContentStore.prayers.count { (it.occasions ?: emptyList()).contains(occasion) }
                    Column(
                        horizontalAlignment = Alignment.CenterHorizontally,
                        modifier = Modifier
                            .weight(1f)
                            .defaultMinSize(minHeight = 48.dp)
                            .border(0.5.dp, colors.frameLine)
                            .clickable { onOccasionClick(occasion) }
                            .padding(vertical = 14.dp),
                    ) {
                        Text(
                            text = occasion,
                            style = type.captionSm,
                            color = colors.primaryText,
                        )
                        Text(
                            text = "$count",
                            style = type.captionSm,
                            color = colors.tertiaryText,
                        )
                    }
                }
                // If odd number, add empty spacer
                if (rowItems.size < 2) {
                    Spacer(Modifier.weight(1f))
                }
            }
            Spacer(Modifier.height(10.dp))
        }
    }
}

// ---------------------------------------------------------------------------
// Full Library
// ---------------------------------------------------------------------------

@Composable
private fun FullLibrarySection(
    searchText: String,
    onSearchChange: (String) -> Unit,
    sortAlphabetical: Boolean,
    onToggleSort: () -> Unit,
    onSelectPrayer: (Prayer) -> Unit,
) {
    val colors = IntroiboTheme.colors
    val type = IntroiboType.current

    val sortedPrayers = remember(searchText, sortAlphabetical) {
        var list = ContentStore.prayers.toList()
        if (searchText.isNotBlank()) {
            val q = searchText.lowercase()
            list = list.filter {
                it.title.strippingEm.lowercase().contains(q) ||
                    it.eng.lowercase().contains(q)
            }
        }
        if (sortAlphabetical) {
            list = list.sortedBy { it.title.strippingEm.lowercase() }
        }
        list
    }

    Column {
        // Header
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
            Text(
                text = "All Prayers",
                style = type.captionSm.copy(fontStyle = FontStyle.Italic),
                color = colors.secondaryText,
                modifier = Modifier.padding(horizontal = 10.dp),
            )
            Box(
                modifier = Modifier
                    .weight(1f)
                    .height(0.5.dp)
                    .background(colors.goldLeaf.copy(alpha = 0.4f)),
            )
        }

        Spacer(Modifier.height(14.dp))

        // Search bar
        TextField(
            value = searchText,
            onValueChange = onSearchChange,
            placeholder = {
                Text("Search prayers", style = type.body, color = colors.tertiaryText)
            },
            leadingIcon = {
                Icon(
                    imageVector = Icons.Filled.Search,
                    contentDescription = null,
                    tint = colors.tertiaryText,
                    modifier = Modifier.size(18.dp),
                )
            },
            trailingIcon = if (searchText.isNotEmpty()) {
                {
                    IconButton(onClick = { onSearchChange("") }) {
                        Icon(
                            imageVector = Icons.Filled.Close,
                            contentDescription = "Clear",
                            tint = colors.tertiaryText,
                        )
                    }
                }
            } else null,
            singleLine = true,
            colors = TextFieldDefaults.colors(
                focusedContainerColor = colors.frameLine.copy(alpha = 0.3f),
                unfocusedContainerColor = colors.frameLine.copy(alpha = 0.3f),
                focusedIndicatorColor = Color.Transparent,
                unfocusedIndicatorColor = Color.Transparent,
            ),
            shape = RoundedCornerShape(8.dp),
            modifier = Modifier.fillMaxWidth(),
        )

        Spacer(Modifier.height(10.dp))

        // Sort toggle
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.End,
        ) {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                modifier = Modifier
                    .border(
                        0.5.dp,
                        colors.sanctuaryRed.copy(alpha = 0.3f),
                        RoundedCornerShape(4.dp),
                    )
                    .defaultMinSize(minHeight = 48.dp)
                    .clickable(onClick = onToggleSort)
                    .padding(horizontal = 10.dp, vertical = 6.dp),
            ) {
                Icon(
                    imageVector = Icons.Filled.SortByAlpha,
                    contentDescription = null,
                    tint = colors.sanctuaryRed,
                    modifier = Modifier.size(12.dp),
                )
                Spacer(Modifier.width(4.dp))
                Text(
                    text = if (sortAlphabetical) "A - Z" else "Default",
                    style = type.captionSm,
                    color = colors.sanctuaryRed,
                )
            }
        }

        Spacer(Modifier.height(14.dp))

        // Prayer list
        sortedPrayers.forEachIndexed { index, prayer ->
            Row(
                verticalAlignment = Alignment.Top,
                modifier = Modifier
                    .fillMaxWidth()
                    .defaultMinSize(minHeight = 48.dp)
                    .clickable { onSelectPrayer(prayer) }
                    .padding(vertical = 4.dp),
            ) {
                Text(
                    text = prayer.title.strippingEm.take(1),
                    style = type.titleL.copy(fontStyle = FontStyle.Italic),
                    color = colors.sanctuaryRed,
                    modifier = Modifier.width(22.dp),
                )
                Spacer(Modifier.width(14.dp))
                Column {
                    Text(
                        text = prayer.title.strippingEm,
                        style = type.titleM.copy(fontStyle = FontStyle.Italic),
                        color = colors.primaryText,
                    )
                    Text(
                        text = prayer.eng,
                        style = type.captionSm.copy(fontStyle = FontStyle.Italic),
                        color = colors.secondaryText,
                    )
                }
            }

            if (index < sortedPrayers.lastIndex) {
                HorizontalDivider(
                    color = colors.frameLine,
                    modifier = Modifier.padding(vertical = 4.dp),
                )
            }
        }
    }
}

// ---------------------------------------------------------------------------
// Occasion Prayer Sheet - shows prayers filtered by occasion
// ---------------------------------------------------------------------------

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun OccasionPrayerSheet(
    occasion: String,
    prayers: List<Prayer>,
    onSelectPrayer: (Prayer) -> Unit,
    onDismiss: () -> Unit,
) {
    val colors = IntroiboTheme.colors
    val type = IntroiboType.current

    val sheetState = androidx.compose.material3.rememberModalBottomSheetState(skipPartiallyExpanded = true)
    val scope = rememberCoroutineScope()

    androidx.compose.material3.ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = sheetState,
        containerColor = colors.pageBackground,
        dragHandle = null,
    ) {
        Column(modifier = Modifier.fillMaxSize()) {
            // Done button
            Row(modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 8.dp)) {
                IconButton(
                    onClick = { scope.launch { sheetState.hide() }.invokeOnCompletion { onDismiss() } }
                ) {
                    Icon(Icons.AutoMirrored.Filled.ArrowBack, "Back", tint = colors.sanctuaryRed)
                }
            }

            // Header
            Column(
                horizontalAlignment = Alignment.CenterHorizontally,
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(vertical = 12.dp),
            ) {
                SmallLabel(text = "Occasio", color = colors.goldLeaf)
                Text(
                    text = occasion,
                    style = type.titleL.copy(fontStyle = FontStyle.Italic),
                    color = colors.primaryText,
                    modifier = Modifier.padding(top = 4.dp),
                )
                Text(
                    text = "${prayers.size} prayers",
                    style = type.captionSm,
                    color = colors.secondaryText,
                )
            }

            HorizontalDivider(color = colors.frameLine)

            // Prayer list
            LazyColumn(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(horizontal = 20.dp),
            ) {
                items(prayers) { prayer ->
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        modifier = Modifier
                            .fillMaxWidth()
                            .clickable { onSelectPrayer(prayer) }
                            .padding(vertical = 10.dp),
                    ) {
                        Column(modifier = Modifier.weight(1f)) {
                            Text(
                                text = prayer.title.strippingEm,
                                style = type.titleM.copy(fontStyle = FontStyle.Italic),
                                color = colors.primaryText,
                            )
                            Text(
                                text = prayer.eng,
                                style = type.captionSm.copy(fontStyle = FontStyle.Italic),
                                color = colors.secondaryText,
                            )
                        }
                        Icon(
                            imageVector = Icons.Filled.MenuBook,
                            contentDescription = "Read",
                            tint = colors.sanctuaryRed,
                            modifier = Modifier.size(16.dp),
                        )
                    }
                    HorizontalDivider(color = colors.frameLine.copy(alpha = 0.5f))
                }
                item { Spacer(Modifier.height(40.dp)) }
            }
        }
    }
}

// ---------------------------------------------------------------------------
// Prayer Rule Editor Sheet - allows selecting prayers for morning/midday/evening
// ---------------------------------------------------------------------------

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun PrayerRuleEditorSheet(
    progressRepo: UserProgressRepository,
    onDismiss: () -> Unit,
) {
    val colors = IntroiboTheme.colors
    val type = IntroiboType.current
    val scope = rememberCoroutineScope()

    val currentRule by progressRepo.prayerRule.collectAsState(initial = PrayerRule())

    var morning by remember(currentRule) { mutableStateOf(currentRule.morning) }
    var midday by remember(currentRule) { mutableStateOf(currentRule.midday) }
    var evening by remember(currentRule) { mutableStateOf(currentRule.evening) }
    var period by remember { mutableStateOf(0) } // 0=morning 1=midday 2=evening

    val selected = when (period) { 0 -> morning; 1 -> midday; else -> evening }
    val inOtherPeriods = (morning + midday + evening).toSet() - selected.toSet()
    fun toggle(slug: String) {
        val updated = if (slug in selected) selected - slug else selected + slug
        when (period) { 0 -> morning = updated; 1 -> midday = updated; else -> evening = updated }
    }

    val sheetState = androidx.compose.material3.rememberModalBottomSheetState(skipPartiallyExpanded = true)
    val prayersByCategory = remember {
        listOf("Rosárium", "Missa", "Devotiónes", "Ante Crucifíxum")
            .map { cat -> cat to ContentStore.prayers.filter { it.category == cat } }
            .filter { it.second.isNotEmpty() }
    }

    androidx.compose.material3.ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = sheetState,
        containerColor = colors.pageBackground,
        dragHandle = null,
    ) {
        Column(modifier = Modifier.fillMaxSize()) {
            // Header with Save / Cancel
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp, vertical = 8.dp),
                horizontalArrangement = Arrangement.SpaceBetween,
            ) {
                androidx.compose.material3.TextButton(
                    onClick = { scope.launch { sheetState.hide() }.invokeOnCompletion { onDismiss() } }
                ) {
                    Text("Cancel", color = colors.tertiaryText, style = type.body)
                }
                androidx.compose.material3.TextButton(onClick = {
                    scope.launch {
                        progressRepo.savePrayerRule(
                            PrayerRule(morning = morning, midday = midday, evening = evening)
                        )
                        sheetState.hide()
                    }.invokeOnCompletion { onDismiss() }
                }) {
                    Text("Save", color = colors.sanctuaryRed, style = type.body)
                }
            }

            Column(
                horizontalAlignment = Alignment.CenterHorizontally,
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(bottom = 12.dp),
            ) {
                SmallLabel(text = "Regula Orationis", color = colors.sanctuaryRed)
                Text(
                    text = "Create Your Prayer Rule",
                    style = type.titleL.copy(fontStyle = FontStyle.Italic),
                    color = colors.primaryText,
                    modifier = Modifier.padding(top = 4.dp),
                )
            }

            // Period selector — one list below applies to the chosen period.
            Row(
                horizontalArrangement = Arrangement.spacedBy(8.dp),
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 20.dp, vertical = 4.dp),
            ) {
                listOf(
                    "Mane" to morning.size,
                    "Meridies" to midday.size,
                    "Vesperae" to evening.size,
                ).forEachIndexed { i, (label, count) ->
                    val active = period == i
                    Text(
                        text = if (count > 0) "$label ($count)" else label,
                        style = type.captionSm.copy(fontStyle = FontStyle.Italic),
                        color = if (active) colors.pageBackground else colors.sanctuaryRed,
                        modifier = Modifier
                            .clip(RoundedCornerShape(50))
                            .background(if (active) colors.sanctuaryRed else colors.sanctuaryRed.copy(alpha = 0.08f))
                            .clickable { period = i }
                            .padding(horizontal = 14.dp, vertical = 6.dp),
                    )
                }
            }

            LazyColumn(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(horizontal = 20.dp),
            ) {
                // Canonical hours first — each adds "office-<slug>" to the rule.
                item(key = "hours-header") {
                    RuleSectionHeader("Horæ Canonicæ  ·  Canonical Hours")
                }
                items(ContentStore.hours, key = { "office-" + it.slug }) { hour ->
                    val slug = "office-" + hour.slug
                    if (slug !in inOtherPeriods) {
                        RulePickRow(
                            title = hour.name,
                            subtitle = hour.eng + " — " + hour.time,
                            isSelected = slug in selected,
                            onToggle = { toggle(slug) },
                        )
                    }
                }

                prayersByCategory.forEach { (category, prayers) ->
                    item(key = "hdr-" + category) { RuleSectionHeader(category) }
                    items(prayers, key = { it.slug }) { prayer ->
                        if (prayer.slug !in inOtherPeriods) {
                            RulePickRow(
                                title = prayer.title.strippingEm,
                                subtitle = prayer.eng,
                                isSelected = prayer.slug in selected,
                                onToggle = { toggle(prayer.slug) },
                            )
                        }
                    }
                }

                item { Spacer(Modifier.height(40.dp)) }
            }
        }
    }
}

@Composable
private fun RuleSectionHeader(text: String) {
    val colors = IntroiboTheme.colors
    Column(modifier = Modifier.padding(top = 18.dp, bottom = 6.dp)) {
        SmallLabel(text = text, color = colors.goldLeaf)
    }
}

@Composable
private fun RulePickRow(
    title: String,
    subtitle: String,
    isSelected: Boolean,
    onToggle: () -> Unit,
) {
    val colors = IntroiboTheme.colors
    val type = IntroiboType.current
    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier
            .fillMaxWidth()
            .clickable { onToggle() }
            .padding(vertical = 5.dp),
    ) {
        Icon(
            imageVector = if (isSelected) Icons.Filled.CheckCircle else Icons.Filled.RadioButtonUnchecked,
            contentDescription = null,
            tint = if (isSelected) colors.sanctuaryRed else colors.frameLine,
            modifier = Modifier.size(20.dp),
        )
        Spacer(Modifier.width(10.dp))
        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = title,
                style = type.body,
                color = if (isSelected) colors.primaryText else colors.secondaryText,
            )
            Text(
                text = subtitle,
                style = type.captionSm,
                color = colors.tertiaryText,
            )
        }
    }
}
