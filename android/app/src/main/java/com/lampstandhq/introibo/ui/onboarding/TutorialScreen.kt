package com.lampstandhq.introibo.ui.onboarding

import androidx.compose.foundation.background
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
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.lampstandhq.introibo.ui.theme.IntroiboTheme
import com.lampstandhq.introibo.ui.theme.IntroiboType
import kotlinx.coroutines.launch

/**
 * Multi-page tutorial showing app features.
 *
 * Port of iOS Introibo/Screens/TutorialView.swift.
 */

private data class TutorialStep(
    val title: String,
    val items: List<String>,
)

private val tutorialSteps = listOf(
    TutorialStep(
        title = "Today",
        items = listOf(
            "Your daily liturgical companion with feast day, season, and liturgical colour",
            "Tap the Propers card to read today's Epistle and Gospel",
            "Follow a patron saint and track your daily practices with streaks",
            "Penance obligations shown automatically based on the 1962 calendar",
            "Prayer rule progress and devotion links update throughout the day",
        ),
    ),
    TutorialStep(
        title = "The Missal",
        items = listOf(
            "Complete 1962 Missale Romanum with 426 daily Propers",
            "Ordinary and Propers interleaved in correct liturgical order",
            "Full Offertory prayers, Preface, Canon, and Last Gospel included",
            "Tap the share icon to save or send any proper as text",
            "Switch between Latin, English, or side-by-side in Settings",
        ),
    ),
    TutorialStep(
        title = "Prayers",
        items = listOf(
            "Build a personal prayer rule for morning, midday, and evening",
            "Tap the bell icon to set notification reminders for any prayer",
            "Search prayers by name in the library",
            "Browse 12 occasion categories: Before Mass, During Mass, Marian, and more",
            "Sort your library by custom order or A-Z",
        ),
    ),
    TutorialStep(
        title = "Settings",
        items = listOf(
            "Choose your Missal rite: 1962, 1955, or pre-1955 rubrics",
            "Select penance discipline: 1962, 1917, or stricter pre-Pius XII",
            "Display language: Latin and English, Latin only, or English only",
            "Three themes: Parchment, Clean White, and Dark Walnut",
            "Adjust text size with the font scale slider",
        ),
    ),
    TutorialStep(
        title = "More Features",
        items = listOf(
            "Interactive bead-by-bead Rosary with three traditional mystery sets",
            "14 Stations of the Cross with meditations and Stabat Mater",
            "All 8 canonical hours of the 1962 Divine Office",
            "Learn Latin with 10 lessons, 97 flashcards, and quizzes",
            "Confession guide with examination of conscience",
        ),
    ),
)

@Composable
fun TutorialScreen(
    onDismiss: () -> Unit,
) {
    val colors = IntroiboTheme.colors
    val type = IntroiboType.current
    val pagerState = rememberPagerState(pageCount = { tutorialSteps.size })
    val scope = rememberCoroutineScope()

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(colors.pageBackground),
    ) {
        HorizontalPager(
            state = pagerState,
            modifier = Modifier.weight(1f),
        ) { page ->
            val step = tutorialSteps[page]
            TutorialStepPage(step = step)
        }

        Column(
            modifier = Modifier.padding(bottom = 36.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            // Page dots
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                for (i in tutorialSteps.indices) {
                    Box(
                        modifier = Modifier
                            .size(8.dp)
                            .clip(CircleShape)
                            .background(
                                if (i == pagerState.currentPage) colors.sanctuaryRed
                                else colors.frameLine
                            ),
                    )
                }
            }

            Spacer(modifier = Modifier.height(14.dp))

            // Next / Finish button
            TextButton(
                onClick = {
                    if (pagerState.currentPage < tutorialSteps.size - 1) {
                        scope.launch { pagerState.animateScrollToPage(pagerState.currentPage + 1) }
                    } else {
                        onDismiss()
                    }
                },
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 28.dp)
                    .background(colors.sanctuaryRed)
                    .padding(vertical = 4.dp),
            ) {
                Text(
                    text = if (pagerState.currentPage < tutorialSteps.size - 1) "Next"
                    else "Introíbo ad altáre Dei  ✠",
                    style = type.bodySm.copy(
                        fontWeight = FontWeight.SemiBold,
                        fontStyle = FontStyle.Italic,
                    ),
                    color = colors.ivory,
                    letterSpacing = 2.sp,
                )
            }

            if (pagerState.currentPage < tutorialSteps.size - 1) {
                Spacer(modifier = Modifier.height(8.dp))
                TextButton(onClick = onDismiss) {
                    Text(
                        text = "Skip Tutorial",
                        style = type.captionSm.copy(fontStyle = FontStyle.Italic),
                        color = colors.tertiaryText,
                    )
                }
            }
        }
    }
}

@Composable
private fun TutorialStepPage(step: TutorialStep) {
    val colors = IntroiboTheme.colors
    val type = IntroiboType.current

    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState()),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Spacer(modifier = Modifier.height(30.dp))

        // Icon circle
        Box(
            modifier = Modifier
                .size(72.dp)
                .clip(CircleShape)
                .background(colors.sanctuaryRed),
            contentAlignment = Alignment.Center,
        ) {
            Text(
                text = "✠",
                style = type.titleL,
                color = colors.ivory,
            )
        }

        Spacer(modifier = Modifier.height(16.dp))

        Text(
            text = step.title,
            style = type.pageTitle.copy(fontSize = 30.sp, fontWeight = FontWeight.SemiBold),
            color = colors.primaryText,
        )

        Spacer(modifier = Modifier.height(8.dp))

        Box(
            modifier = Modifier
                .width(40.dp)
                .height(1.dp)
                .background(colors.goldLeaf.copy(alpha = 0.4f)),
        )

        Spacer(modifier = Modifier.height(16.dp))

        Column(
            modifier = Modifier.padding(horizontal = 32.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            step.items.forEach { item ->
                Row(verticalAlignment = Alignment.Top) {
                    Text(
                        text = "•",
                        style = type.body,
                        color = colors.sanctuaryRed,
                        modifier = Modifier
                            .width(24.dp)
                            .padding(top = 2.dp),
                    )
                    Text(
                        text = item,
                        style = type.body,
                        color = colors.secondaryText,
                        lineHeight = type.body.fontSize * 1.2f,
                    )
                }
            }
        }

        Spacer(modifier = Modifier.height(30.dp))
    }
}
