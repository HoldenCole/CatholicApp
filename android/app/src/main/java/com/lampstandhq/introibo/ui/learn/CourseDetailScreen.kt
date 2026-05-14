package com.lampstandhq.introibo.ui.learn

import androidx.compose.foundation.background
import androidx.compose.foundation.border
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
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.lampstandhq.introibo.data.model.Course
import com.lampstandhq.introibo.storage.progress.UserProgressRepository
import com.lampstandhq.introibo.ui.components.BilingualLine
import com.lampstandhq.introibo.ui.components.SmallLabel
import com.lampstandhq.introibo.ui.theme.IntroiboTheme
import com.lampstandhq.introibo.ui.theme.IntroiboType
import kotlinx.coroutines.launch

/**
 * A single Latin lesson detail view.
 *
 * Port of iOS Introibo/Screens/Learn/CourseDetailView.swift.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun CourseDetailScreen(
    course: Course,
    onDismiss: () -> Unit,
    onMasteryChange: () -> Unit = {},
) {
    val colors = IntroiboTheme.colors
    val type = IntroiboType.current
    val context = LocalContext.current
    val progressRepo = remember { UserProgressRepository(context) }
    val scope = rememberCoroutineScope()

    val masteredSet by progressRepo.masteredLessons.collectAsState(initial = emptySet())
    val isMastered = course.slug in masteredSet

    var showQuiz by remember { mutableStateOf(false) }

    val allCards = course.sections
        .mapNotNull { it.items }
        .flatten()
        .filter { it.lat != null && it.eng != null }

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true),
        containerColor = colors.pageBackground,
        dragHandle = null,
    ) {
        Column(modifier = Modifier.fillMaxSize()) {
            // Done
            Row(modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 8.dp)) {
                TextButton(onClick = onDismiss) {
                    Text("Done", color = colors.sanctuaryRed, style = type.body)
                }
            }

            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .verticalScroll(rememberScrollState()),
            ) {
                // Header
                val numerals = listOf("", "I", "II", "III", "IV", "V", "VI", "VII", "VIII", "IX", "X")
                val roman = if (course.num < numerals.size) numerals[course.num] else "${course.num}"

                Column(
                    modifier = Modifier
                        .fillMaxWidth()
                        .background(Brush.verticalGradient(listOf(colors.walnut, colors.walnutHi)))
                        .padding(vertical = 8.dp),
                    horizontalAlignment = Alignment.CenterHorizontally,
                ) {
                    Spacer(modifier = Modifier.height(20.dp))
                    SmallLabel(text = "✠  Lésson $roman  ✠", color = colors.goldLeaf)
                    Spacer(modifier = Modifier.height(8.dp))
                    Text(
                        text = course.title,
                        style = type.pageTitle,
                        color = colors.ivory,
                        textAlign = TextAlign.Center,
                        modifier = Modifier.padding(horizontal = 28.dp),
                    )
                    Text(
                        text = course.latin.uppercase(),
                        style = type.captionSm.copy(fontStyle = FontStyle.Italic),
                        color = colors.muted,
                        letterSpacing = 2.5.sp,
                    )
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
                    verticalArrangement = Arrangement.spacedBy(22.dp),
                ) {
                    // Intro
                    Text(
                        text = course.intro,
                        style = type.body,
                        color = colors.primaryText,
                        lineHeight = type.body.fontSize * 1.25f,
                        modifier = Modifier.fillMaxWidth(),
                    )

                    // Sections
                    course.sections.forEach { s ->
                        SectionView(s)
                    }

                    // Quiz button
                    if (allCards.size >= 4) {
                        TextButton(
                            onClick = { showQuiz = true },
                            modifier = Modifier
                                .fillMaxWidth()
                                .border(0.5.dp, colors.goldLeaf.copy(alpha = 0.6f))
                                .padding(vertical = 4.dp),
                        ) {
                            SmallLabel(text = "Test Yourself", color = colors.goldLeaf)
                        }
                    }

                    // Mastery button
                    TextButton(
                        onClick = {
                            scope.launch {
                                progressRepo.setMastered(course.slug, !isMastered)
                                onMasteryChange()
                            }
                        },
                        modifier = Modifier
                            .fillMaxWidth()
                            .border(
                                0.5.dp,
                                if (isMastered) colors.goldLeaf.copy(alpha = 0.6f)
                                else colors.sanctuaryRed.copy(alpha = 0.6f),
                            )
                            .padding(vertical = 4.dp),
                    ) {
                        SmallLabel(
                            text = if (isMastered) "Marked as Mastered  ✠  Unmark" else "Mark as Mastered",
                            color = if (isMastered) colors.goldLeaf else colors.sanctuaryRed,
                        )
                    }
                }
            }
        }
    }

    if (showQuiz) {
        QuizScreen(
            cards = allCards,
            lessonTitle = course.title,
            onDismiss = { showQuiz = false },
        )
    }
}

@Composable
private fun SectionView(s: Course.Section) {
    when (s.type) {
        "cards" -> CardsSection(s)
        else -> TextSection(s)
    }
}

@Composable
private fun TextSection(s: Course.Section) {
    val colors = IntroiboTheme.colors
    val type = IntroiboType.current

    Column(
        modifier = Modifier.fillMaxWidth(),
        verticalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        s.label?.let { label ->
            SmallLabel(text = label, color = colors.sanctuaryRed)
        }
        s.html?.let { html ->
            Text(
                text = plainText(html),
                style = type.body,
                color = colors.primaryText,
                lineHeight = type.body.fontSize * 1.25f,
            )
        }
    }
}

@Composable
private fun CardsSection(s: Course.Section) {
    val colors = IntroiboTheme.colors
    val type = IntroiboType.current

    Column(
        modifier = Modifier.fillMaxWidth(),
        verticalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        s.label?.let { label ->
            SmallLabel(text = label, color = colors.sanctuaryRed)
        }
        s.note?.let { note ->
            Text(
                text = note,
                style = type.captionSm.copy(fontStyle = FontStyle.Italic),
                color = colors.secondaryText,
            )
        }
        s.items?.forEach { card ->
            FlashCardRow(card)
        }
    }
}

@Composable
private fun FlashCardRow(card: Course.Section.Card) {
    val colors = IntroiboTheme.colors
    val type = IntroiboType.current

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .border(0.5.dp, colors.frameLine)
            .padding(12.dp),
        horizontalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        Column(modifier = Modifier.weight(1f)) {
            card.lat?.let { lat ->
                Text(text = lat, style = type.body, color = colors.primaryText)
            }
            card.phon?.let { phon ->
                Text(
                    text = phon,
                    style = type.captionSm.copy(fontStyle = FontStyle.Italic),
                    color = colors.tertiaryText,
                )
            }
        }
        card.eng?.let { eng ->
            Text(
                text = eng,
                style = type.bodySm.copy(fontStyle = FontStyle.Italic),
                color = colors.secondaryText,
                modifier = Modifier.weight(1f),
            )
        }
    }
}

private fun plainText(html: String): String {
    var s = html
    s = s.replace("</p>", "\n\n")
    s = s.replace("<br>", "\n")
    s = s.replace("<br/>", "\n")
    s = s.replace("<br />", "\n")
    s = s.replace(Regex("<[^>]+>"), "")
    s = s.replace("&amp;", "&")
    s = s.replace("&nbsp;", " ")
    return s.trim()
}
