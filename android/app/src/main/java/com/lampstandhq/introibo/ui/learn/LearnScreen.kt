package com.lampstandhq.introibo.ui.learn

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
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.ChevronRight
import androidx.compose.material.icons.filled.Verified
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.drawBehind
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.StrokeCap
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.unit.dp
import com.lampstandhq.introibo.data.content.ContentStore
import com.lampstandhq.introibo.data.model.Course
import com.lampstandhq.introibo.storage.progress.UserProgressRepository
import com.lampstandhq.introibo.ui.components.SmallLabel
import com.lampstandhq.introibo.ui.theme.IntroiboTheme
import com.lampstandhq.introibo.ui.theme.IntroiboType
import java.util.Calendar

private val romanNumerals = listOf("", "I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X")

private fun roman(n: Int): String =
    if (n < romanNumerals.size) romanNumerals[n] else "$n"

/**
 * Learn (Schola) tab screen. Shows progress ring, daily flashcard,
 * and lesson list. Ported from iOS LearnView.swift.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun LearnScreen() {
    val context = LocalContext.current
    val colors = IntroiboTheme.colors
    val type = IntroiboType.current

    val progressRepo = remember { UserProgressRepository(context) }
    val mastered by progressRepo.masteredLessons.collectAsState(initial = emptySet())

    val courses = ContentStore.courses
    val progress = if (courses.isNotEmpty()) mastered.size.toFloat() / courses.size else 0f

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(colors.pageBackground),
    ) {
        TopAppBar(
            title = {
                Text(
                    text = "Schola Latina",
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
            verticalArrangement = Arrangement.spacedBy(24.dp),
        ) {
            item { Spacer(Modifier.height(4.dp)) }

            // ---- Progress Header ----
            item {
                Column(
                    horizontalAlignment = Alignment.CenterHorizontally,
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(vertical = 20.dp),
                ) {
                    // Progress ring
                    Box(
                        contentAlignment = Alignment.Center,
                        modifier = Modifier
                            .size(80.dp)
                            .drawBehind {
                                val stroke = Stroke(width = 5.dp.toPx(), cap = StrokeCap.Round)
                                drawArc(
                                    color = colors.frameLine,
                                    startAngle = 0f,
                                    sweepAngle = 360f,
                                    useCenter = false,
                                    style = stroke,
                                    topLeft = Offset(stroke.width / 2, stroke.width / 2),
                                    size = Size(
                                        size.width - stroke.width,
                                        size.height - stroke.width
                                    ),
                                )
                                if (progress > 0f) {
                                    drawArc(
                                        color = colors.sanctuaryRed,
                                        startAngle = -90f,
                                        sweepAngle = 360f * progress,
                                        useCenter = false,
                                        style = stroke,
                                        topLeft = Offset(stroke.width / 2, stroke.width / 2),
                                        size = Size(
                                            size.width - stroke.width,
                                            size.height - stroke.width
                                        ),
                                    )
                                }
                            },
                    ) {
                        Column(horizontalAlignment = Alignment.CenterHorizontally) {
                            Text(
                                text = "${mastered.size}",
                                style = type.titleXL,
                                color = colors.primaryText,
                            )
                            Text(
                                text = "of ${courses.size}",
                                style = type.captionSm,
                                color = colors.tertiaryText,
                            )
                        }
                    }

                    Text(
                        text = "Lessons Mastered",
                        style = type.captionSm.copy(fontStyle = FontStyle.Italic),
                        color = colors.secondaryText,
                        modifier = Modifier.padding(top = 14.dp),
                    )

                    // Dot indicators
                    Row(
                        horizontalArrangement = Arrangement.spacedBy(4.dp),
                        modifier = Modifier.padding(top = 8.dp),
                    ) {
                        courses.forEach { c ->
                            Box(
                                modifier = Modifier
                                    .size(8.dp)
                                    .clip(CircleShape)
                                    .background(
                                        if (c.slug in mastered) colors.goldLeaf else colors.frameLine
                                    ),
                            )
                        }
                    }
                }
            }

            // ---- Daily Flashcard ----
            item {
                DailyFlashcard(courses = courses)
            }

            // ---- Lessons ----
            item {
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
                        text = "LECTIONES",
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
            }

            items(courses) { course ->
                LessonRow(course = course, isMastered = course.slug in mastered)
            }

            item { Spacer(Modifier.height(40.dp)) }
        }
    }
}

// ---------------------------------------------------------------------------
// Daily flashcard
// ---------------------------------------------------------------------------

@Composable
private fun DailyFlashcard(courses: List<Course>) {
    val colors = IntroiboTheme.colors
    val type = IntroiboType.current

    val allCards = remember {
        courses.flatMap { c ->
            c.sections.filter { it.type == "cards" }.flatMap { it.items ?: emptyList() }
        }.filter { it.lat != null && it.eng != null }
    }

    if (allCards.isEmpty()) return

    val dayIndex = Calendar.getInstance().get(Calendar.DAY_OF_YEAR) % allCards.size.coerceAtLeast(1)
    val card = allCards[dayIndex]

    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        modifier = Modifier
            .fillMaxWidth()
            .border(0.5.dp, colors.goldLeaf.copy(alpha = 0.3f))
            .padding(20.dp),
    ) {
        SmallLabel(text = "Verbum Hodie", color = colors.goldLeaf)
        Text(
            text = card.lat ?: "",
            style = type.titleL.copy(fontStyle = FontStyle.Italic),
            color = colors.primaryText,
            modifier = Modifier.padding(top = 8.dp),
        )
        card.phon?.let { phon ->
            Text(
                text = "[$phon]",
                style = type.captionSm,
                color = colors.tertiaryText,
                modifier = Modifier.padding(top = 2.dp),
            )
        }
        Text(
            text = card.eng ?: "",
            style = type.body.copy(fontStyle = FontStyle.Italic),
            color = colors.secondaryText,
            modifier = Modifier.padding(top = 4.dp),
        )
    }
}

// ---------------------------------------------------------------------------
// Lesson row
// ---------------------------------------------------------------------------

@Composable
private fun LessonRow(course: Course, isMastered: Boolean) {
    val colors = IntroiboTheme.colors
    val type = IntroiboType.current
    val cardCount = course.sections.filter { it.type == "cards" }.sumOf { (it.items ?: emptyList()).size }

    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier
            .fillMaxWidth()
            .clickable { /* TODO: open course detail */ }
            .padding(vertical = 12.dp, horizontal = 8.dp),
    ) {
        // Roman numeral badge
        Box(
            contentAlignment = Alignment.Center,
            modifier = Modifier
                .size(44.dp)
                .clip(CircleShape)
                .background(
                    if (isMastered) colors.goldLeaf.copy(alpha = 0.12f)
                    else colors.sanctuaryRed.copy(alpha = 0.08f)
                )
                .border(
                    1.dp,
                    if (isMastered) colors.goldLeaf.copy(alpha = 0.5f)
                    else colors.sanctuaryRed.copy(alpha = 0.3f),
                    CircleShape,
                ),
        ) {
            Text(
                text = roman(course.num),
                style = type.titleM.copy(fontStyle = FontStyle.Italic),
                color = if (isMastered) colors.goldLeaf else colors.sanctuaryRed,
            )
        }

        Spacer(Modifier.width(14.dp))

        Column(modifier = Modifier.weight(1f)) {
            Text(
                text = course.title,
                style = type.titleM.copy(fontStyle = FontStyle.Italic),
                color = colors.primaryText,
            )
            Text(
                text = course.latin,
                style = type.captionSm.copy(fontStyle = FontStyle.Italic),
                color = colors.secondaryText,
                modifier = Modifier.padding(top = 2.dp),
            )
            Row(
                horizontalArrangement = Arrangement.spacedBy(8.dp),
                modifier = Modifier.padding(top = 4.dp),
            ) {
                Text(
                    text = "$cardCount cards",
                    style = type.captionSm,
                    color = colors.tertiaryText,
                )
                if (isMastered) {
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        horizontalArrangement = Arrangement.spacedBy(3.dp),
                    ) {
                        Icon(
                            imageVector = Icons.Filled.Verified,
                            contentDescription = null,
                            tint = colors.goldLeaf,
                            modifier = Modifier.size(10.dp),
                        )
                        Text(
                            text = "Mastered",
                            style = type.captionSm,
                            color = colors.goldLeaf,
                        )
                    }
                }
            }
        }

        Icon(
            imageVector = Icons.Filled.ChevronRight,
            contentDescription = null,
            tint = colors.tertiaryText,
            modifier = Modifier.size(14.dp),
        )
    }
}
