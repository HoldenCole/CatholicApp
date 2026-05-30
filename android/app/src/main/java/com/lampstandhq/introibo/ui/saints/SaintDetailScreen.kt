package com.lampstandhq.introibo.ui.saints

import androidx.compose.foundation.Canvas
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
import androidx.compose.foundation.ExperimentalFoundationApi
import androidx.compose.foundation.relocation.BringIntoViewRequester
import androidx.compose.foundation.relocation.bringIntoViewRequester
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.lampstandhq.introibo.data.model.Saint
import com.lampstandhq.introibo.storage.progress.UserProgressRepository
import com.lampstandhq.introibo.data.content.ContentStore
import com.lampstandhq.introibo.data.search.ContentType
import com.lampstandhq.introibo.data.search.DeepLinkTarget
import com.lampstandhq.introibo.ui.components.BilingualLine
import com.lampstandhq.introibo.ui.components.ReferencedBySection
import com.lampstandhq.introibo.ui.components.RelatedLinksSection
import com.lampstandhq.introibo.ui.components.SmallLabel
import com.lampstandhq.introibo.ui.theme.IntroiboTheme
import com.lampstandhq.introibo.ui.theme.IntroiboType
import kotlinx.coroutines.launch

/**
 * Saint detail with practice checklist + streak tracking.
 *
 * Port of iOS Introibo/Screens/Saints/SaintDetailView.swift.
 */
@OptIn(ExperimentalMaterial3Api::class, ExperimentalFoundationApi::class)
@Composable
fun SaintDetailScreen(
    saint: Saint,
    onDismiss: () -> Unit,
    /**
     * Deep-link scroll anchor: "section:<index>" into [Saint.sections] or
     * "prayer:<index>" into [Saint.prayers], matching the saint search
     * extractor. null = no scroll.
     */
    scrollToAnchor: String? = null,
    onLinkTap: (DeepLinkTarget) -> Unit = {},
) {
    val colors = IntroiboTheme.colors
    val type = IntroiboType.current
    val context = LocalContext.current
    val progressRepo = remember { UserProgressRepository(context) }
    val scope = rememberCoroutineScope()

    // One BringIntoViewRequester per anchorable block (sections + prayers). The
    // anchor strings ("section:<i>"/"prayer:<i>") mirror SearchExtractors.saints.
    val sectionRequesters = remember(saint.slug) {
        List(saint.sections.size) { BringIntoViewRequester() }
    }
    val prayerRequesters = remember(saint.slug) {
        List(saint.prayers?.size ?: 0) { BringIntoViewRequester() }
    }
    LaunchedEffect(scrollToAnchor, saint.slug) {
        val anchor = scrollToAnchor ?: return@LaunchedEffect
        val requester = when {
            anchor.startsWith("section:") ->
                anchor.removePrefix("section:").toIntOrNull()?.let { sectionRequesters.getOrNull(it) }
            anchor.startsWith("prayer:") ->
                anchor.removePrefix("prayer:").toIntOrNull()?.let { prayerRequesters.getOrNull(it) }
            else -> null
        }
        requester?.bringIntoView()
    }

    val followedSlug by progressRepo.followedSaint.collectAsState(initial = null)
    val completed by progressRepo.completedPractices().collectAsState(initial = emptySet())
    var streak by remember { mutableIntStateOf(0) }

    val isFollowed = followedSlug == saint.slug
    val totalPractices = saint.sections.flatMap { it.practices }.size
    val progress = if (totalPractices > 0) completed.size.toDouble() / totalPractices.toDouble() else 0.0

    LaunchedEffect(saint.slug) {
        progressRepo.saintStreak(saint.slug).collect { streak = it }
    }

    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = sheetState,
        containerColor = colors.pageBackground,
        dragHandle = null,
    ) {
        Column(modifier = Modifier.fillMaxSize()) {
            // Back
            Row(modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 8.dp)) {
                IconButton(onClick = { scope.launch { sheetState.hide() }.invokeOnCompletion { onDismiss() } }) {
                    Icon(Icons.AutoMirrored.Filled.ArrowBack, "Back", tint = colors.sanctuaryRed)
                }
            }

            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .verticalScroll(rememberScrollState())
                    .padding(bottom = 80.dp),
            ) {
                // Header
                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .background(Brush.verticalGradient(listOf(colors.walnut, colors.walnutHi)))
                        .padding(vertical = 8.dp),
                    horizontalAlignment = Alignment.CenterHorizontally,
                ) {
                    Spacer(modifier = Modifier.height(20.dp))
                    SmallLabel(text = "✠  Praxes Sanctorum  ✠", color = colors.goldLeaf)
                    Spacer(modifier = Modifier.height(8.dp))
                    Text(
                        text = saint.name,
                        style = type.pageTitle,
                        color = colors.ivory,
                        textAlign = TextAlign.Center,
                        modifier = Modifier.padding(horizontal = 28.dp),
                    )
                    Text(
                        text = saint.title.uppercase(),
                        style = type.captionSm.copy(fontStyle = FontStyle.Italic),
                        color = colors.muted,
                        letterSpacing = 2.5.sp,
                        textAlign = TextAlign.Center,
                        modifier = Modifier.padding(horizontal = 28.dp),
                    )
                    if (isFollowed && streak > 0) {
                        Row(
                            modifier = Modifier.padding(top = 6.dp),
                            horizontalArrangement = Arrangement.spacedBy(6.dp),
                        ) {
                            for (i in 0 until minOf(streak, 7)) {
                                Box(
                                    modifier = Modifier
                                        .size(6.dp)
                                        .clip(CircleShape)
                                        .background(colors.goldLeaf),
                                )
                            }
                            if (streak > 7) {
                                Text(
                                    text = "+ ${streak - 7}",
                                    style = type.captionSm,
                                    color = colors.goldLeaf,
                                )
                            }
                        }
                    }
                    Spacer(modifier = Modifier.height(14.dp))
                    Box(
                        modifier = Modifier
                            .width(60.dp)
                            .height(0.5.dp)
                            .background(colors.goldLeaf.copy(alpha = 0.4f)),
                    )
                    Spacer(modifier = Modifier.height(14.dp))
                }

                Column(
                    modifier = Modifier.padding(horizontal = 28.dp, vertical = 24.dp),
                    verticalArrangement = Arrangement.spacedBy(24.dp),
                ) {
                    // Quote
                    Box(modifier = Modifier.fillMaxWidth()) {
                        Box(
                            modifier = Modifier
                                .width(1.dp)
                                .matchParentSize()
                                .background(colors.sanctuaryRed.copy(alpha = 0.4f)),
                        )
                        Text(
                            text = "“${saint.quote}”",
                            style = type.bodyIt,
                            color = colors.secondaryText,
                            lineHeight = type.bodyIt.fontSize * 1.25f,
                            modifier = Modifier.padding(start = 14.dp),
                        )
                    }

                    // Follow button
                    TextButton(
                        onClick = {
                            scope.launch {
                                if (isFollowed) {
                                    progressRepo.setFollowedSaint(null)
                                } else {
                                    progressRepo.setFollowedSaint(saint.slug)
                                }
                            }
                        },
                        modifier = Modifier
                            .fillMaxWidth()
                            .border(
                                0.5.dp,
                                if (isFollowed) colors.secondaryText.copy(alpha = 0.4f)
                                else colors.sanctuaryRed.copy(alpha = 0.6f),
                            )
                            .padding(vertical = 4.dp),
                    ) {
                        SmallLabel(
                            text = if (isFollowed) "Unfollow" else "Follow this Saint",
                            color = if (isFollowed) colors.secondaryText else colors.sanctuaryRed,
                        )
                    }

                    // Progress card (only when followed)
                    if (isFollowed) {
                        Column(
                            modifier = Modifier
                                .fillMaxWidth()
                                .border(0.5.dp, colors.frameLine)
                                .padding(vertical = 16.dp),
                            horizontalAlignment = Alignment.CenterHorizontally,
                            verticalArrangement = Arrangement.spacedBy(12.dp),
                        ) {
                            // Progress ring
                            Box(contentAlignment = Alignment.Center) {
                                val ringColor = colors.frameLine
                                val progressColor = colors.sanctuaryRed
                                Canvas(modifier = Modifier.size(70.dp)) {
                                    drawCircle(
                                        color = ringColor,
                                        style = Stroke(width = 4.dp.toPx()),
                                    )
                                    drawArc(
                                        color = progressColor,
                                        startAngle = -90f,
                                        sweepAngle = (progress * 360f).toFloat(),
                                        useCenter = false,
                                        style = Stroke(width = 4.dp.toPx(), cap = StrokeCap.Round),
                                    )
                                }
                                Text(
                                    text = "${completed.size}/$totalPractices",
                                    style = type.titleM.copy(fontStyle = FontStyle.Italic),
                                    color = colors.primaryText,
                                )
                            }
                            Text(
                                text = if (progress >= 1.0) "Perfect day" else "Today's progress",
                                style = type.captionSm.copy(fontStyle = FontStyle.Italic),
                                color = if (progress >= 1.0) colors.goldLeaf else colors.tertiaryText,
                            )
                            if (streak > 0) {
                                Text(
                                    text = "$streak day streak",
                                    style = type.captionSm,
                                    color = colors.goldLeaf,
                                )
                            }
                        }
                    }

                    // Sections with checkboxes
                    saint.sections.forEachIndexed { index, section ->
                        Box(
                            modifier = Modifier.bringIntoViewRequester(sectionRequesters[index]),
                        ) {
                            SectionBlock(
                                saint = saint,
                                section = section,
                                isFollowed = isFollowed,
                                completed = completed,
                                onToggle = { practiceId ->
                                    scope.launch {
                                        progressRepo.togglePractice(practiceId)
                                        // Check if all done
                                        val newCompleted = progressRepo.completedPractices().collect { done ->
                                            if (done.size == totalPractices) {
                                                progressRepo.bumpSaintStreak(saint.slug)
                                            }
                                        }
                                    }
                                },
                            )
                        }
                    }

                    // Saint prayers
                    saint.prayers?.takeIf { it.isNotEmpty() }?.let { prayers ->
                        SaintPrayersBlock(prayers, prayerRequesters, onLinkTap)
                    }

                    RelatedLinksSection(related = saint.related, onLinkTap = onLinkTap)
                    ReferencedBySection(
                        sources = ContentStore.linkGraph.referencedBy(
                            DeepLinkTarget(ContentType.SAINT, saint.slug, null)
                        ),
                        onLinkTap = onLinkTap,
                    )
                }
            }
        }
    }
}

@Composable
private fun SectionBlock(
    saint: Saint,
    section: Saint.Section,
    isFollowed: Boolean,
    completed: Set<String>,
    onToggle: (String) -> Unit,
) {
    val colors = IntroiboTheme.colors
    val type = IntroiboType.current

    Column(
        modifier = Modifier.fillMaxWidth(),
        verticalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        // Section header
        Row(
            verticalAlignment = Alignment.CenterVertically,
            modifier = Modifier.fillMaxWidth(),
        ) {
            Box(
                modifier = Modifier
                    .weight(1f)
                    .height(0.5.dp)
                    .background(colors.goldLeaf.copy(alpha = 0.3f)),
            )
            Text(
                text = section.lat.uppercase(),
                style = type.captionSm.copy(fontStyle = FontStyle.Italic),
                color = colors.sanctuaryRed,
                letterSpacing = 3.sp,
                modifier = Modifier.padding(horizontal = 6.dp),
            )
            Text(text = ".", color = colors.tertiaryText, modifier = Modifier.padding(end = 4.dp))
            Text(
                text = section.eng,
                style = type.captionSm.copy(fontStyle = FontStyle.Italic),
                color = colors.secondaryText,
            )
            Box(
                modifier = Modifier
                    .weight(1f)
                    .height(0.5.dp)
                    .background(colors.goldLeaf.copy(alpha = 0.3f)),
            )
        }

        section.practices.forEachIndexed { idx, p ->
            val practiceId = "${saint.slug}.${section.lat}.$idx"
            val isDone = practiceId in completed

            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .then(
                        if (isFollowed) Modifier.clickable { onToggle(practiceId) }
                        else Modifier
                    )
                    .padding(vertical = 4.dp),
                verticalAlignment = Alignment.Top,
            ) {
                if (isFollowed) {
                    Text(
                        text = if (isDone) "✓" else "○",
                        color = if (isDone) colors.goldLeaf else colors.frameLine,
                        style = type.titleM,
                        modifier = Modifier
                            .padding(end = 12.dp, top = 2.dp),
                    )
                }
                Column {
                    Text(
                        text = p.t,
                        style = type.titleM.copy(fontStyle = FontStyle.Italic),
                        color = if (isDone) colors.tertiaryText else colors.primaryText,
                        textDecoration = if (isDone) TextDecoration.LineThrough else TextDecoration.None,
                    )
                    Text(
                        text = p.d,
                        style = type.bodySm,
                        color = if (isDone) colors.tertiaryText else colors.secondaryText,
                        lineHeight = type.bodySm.fontSize * 1.2f,
                    )
                }
            }
            if (idx < section.practices.size - 1) {
                HorizontalDivider(color = colors.frameLine.copy(alpha = 0.5f))
            }
        }
    }
}

@OptIn(ExperimentalFoundationApi::class)
@Composable
private fun SaintPrayersBlock(
    prayers: List<Saint.SaintPrayer>,
    requesters: List<BringIntoViewRequester> = emptyList(),
    onLinkTap: (DeepLinkTarget) -> Unit = {},
) {
    val colors = IntroiboTheme.colors
    val type = IntroiboType.current

    Column(
        modifier = Modifier.fillMaxWidth(),
        verticalArrangement = Arrangement.spacedBy(14.dp),
    ) {
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
                text = "ORATIONES",
                style = type.captionSm.copy(fontStyle = FontStyle.Italic),
                color = colors.sanctuaryRed,
                letterSpacing = 3.sp,
                modifier = Modifier.padding(horizontal = 6.dp),
            )
            Text(text = ".", color = colors.tertiaryText, modifier = Modifier.padding(end = 4.dp))
            Text(
                text = "Prayers",
                style = type.captionSm.copy(fontStyle = FontStyle.Italic),
                color = colors.secondaryText,
            )
            Box(
                modifier = Modifier
                    .weight(1f)
                    .height(1.dp)
                    .background(colors.sanctuaryRed.copy(alpha = 0.4f)),
            )
        }

        prayers.forEachIndexed { index, prayer ->
            val prayerModifier = requesters.getOrNull(index)
                ?.let { Modifier.bringIntoViewRequester(it) }
                ?: Modifier
            Column(
                modifier = prayerModifier
                    .fillMaxWidth()
                    .padding(vertical = 8.dp, horizontal = 12.dp),
                verticalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                // Left accent bar
                Box(modifier = Modifier.fillMaxWidth()) {
                    Box(
                        modifier = Modifier
                            .width(2.dp)
                            .matchParentSize()
                            .background(colors.sanctuaryRed.copy(alpha = 0.15f)),
                    )
                    Column(
                        modifier = Modifier.padding(start = 12.dp),
                        verticalArrangement = Arrangement.spacedBy(8.dp),
                    ) {
                        Text(
                            text = prayer.title,
                            style = type.titleM.copy(fontStyle = FontStyle.Italic),
                            color = colors.primaryText,
                        )
                        prayer.note?.let { note ->
                            Text(
                                text = note,
                                style = type.captionSm.copy(fontStyle = FontStyle.Italic),
                                color = colors.goldLeaf,
                            )
                        }
                        BilingualLine(
                            lat = prayer.latin ?: "",
                            eng = prayer.eng,
                            sideBySide = true,
                            onLinkTap = onLinkTap,
                        )
                    }
                }
            }
        }
    }
}
