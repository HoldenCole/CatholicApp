package com.lampstandhq.introibo.ui.onboarding

import androidx.compose.foundation.Canvas
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
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.foundation.clickable
import kotlinx.coroutines.launch
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.lampstandhq.introibo.ui.theme.IntroiboTheme
import com.lampstandhq.introibo.ui.theme.IntroiboType
import kotlinx.coroutines.launch

/**
 * 3-page onboarding flow with HorizontalPager.
 *
 * Port of iOS Introibo/Screens/OnboardingView.swift.
 */
@Composable
fun OnboardingScreen(
    onComplete: () -> Unit,
) {
    val colors = IntroiboTheme.colors
    val type = IntroiboType.current
    val context = androidx.compose.ui.platform.LocalContext.current
    val settingsRepo = remember { com.lampstandhq.introibo.storage.settings.SettingsRepository(context) }
    val scope = rememberCoroutineScope()
    val pagerState = rememberPagerState(pageCount = { 4 })
    var showTutorial by remember { mutableStateOf(false) }

    if (showTutorial) {
        TutorialScreen(
            onDismiss = {
                showTutorial = false
                onComplete()
            },
        )
        return
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(colors.pageBackground),
    ) {
        // Pager
        HorizontalPager(
            state = pagerState,
            modifier = Modifier.weight(1f),
        ) { page ->
            when (page) {
                0 -> WelcomePage()
                1 -> TraditionPage()
                2 -> SettingsPage(settingsRepo, scope)
                3 -> FeaturesPage()
            }
        }

        // Dots + buttons
        Column(
            modifier = Modifier.padding(bottom = 36.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            // Page dots
            Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
                for (i in 0 until 4) {
                    Box(
                        modifier = Modifier
                            .size(8.dp)
                            .clip(CircleShape)
                            .background(if (i == pagerState.currentPage) colors.sanctuaryRed else colors.frameLine),
                    )
                }
            }

            Spacer(modifier = Modifier.height(16.dp))

            // Continue / Tour button
            TextButton(
                onClick = {
                    if (pagerState.currentPage < 3) {
                        scope.launch { pagerState.animateScrollToPage(pagerState.currentPage + 1) }
                    } else {
                        showTutorial = true
                    }
                },
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 28.dp)
                    .background(colors.sanctuaryRed)
                    .padding(vertical = 4.dp),
            ) {
                Text(
                    text = if (pagerState.currentPage < 3) "Continue" else "Take a Quick Tour  ✠",
                    style = type.bodySm.copy(
                        fontWeight = FontWeight.SemiBold,
                        fontStyle = FontStyle.Italic,
                    ),
                    color = colors.ivory,
                    letterSpacing = 2.sp,
                )
            }

            Spacer(modifier = Modifier.height(8.dp))

            TextButton(onClick = onComplete) {
                Text(
                    text = if (pagerState.currentPage < 3) "Skip" else "Skip Tutorial",
                    style = type.captionSm.copy(fontStyle = FontStyle.Italic),
                    color = colors.tertiaryText,
                )
            }
        }
    }
}

@Composable
private fun WelcomePage() {
    val colors = IntroiboTheme.colors
    val type = IntroiboType.current

    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState()),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Spacer(modifier = Modifier.height(60.dp))

        MonstranceIcon()

        Spacer(modifier = Modifier.height(20.dp))

        Text(
            text = "Introíbo",
            style = type.pageTitle.copy(fontSize = 44.sp, fontWeight = FontWeight.SemiBold),
            color = colors.primaryText,
        )
        Text(
            text = "AD ALTÁRE DEI",
            style = type.captionSm.copy(fontStyle = FontStyle.Italic),
            color = colors.secondaryText,
            letterSpacing = 3.sp,
        )

        Spacer(modifier = Modifier.height(8.dp))
        Box(
            modifier = Modifier
                .width(40.dp)
                .height(1.dp)
                .background(colors.sanctuaryRed.copy(alpha = 0.4f)),
        )

        Spacer(modifier = Modifier.height(16.dp))

        Text(
            text = "A prayer companion for\ntraditional Catholics",
            style = type.titleM.copy(fontStyle = FontStyle.Italic),
            color = colors.secondaryText,
            textAlign = TextAlign.Center,
        )

        Spacer(modifier = Modifier.height(20.dp))

        Row(
            horizontalArrangement = Arrangement.spacedBy(16.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Column(verticalArrangement = Arrangement.spacedBy(6.dp), horizontalAlignment = Alignment.CenterHorizontally) {
                Text("Ad free", style = type.captionSm.copy(fontStyle = FontStyle.Italic), color = colors.primaryText)
                Text("Latin first", style = type.captionSm.copy(fontStyle = FontStyle.Italic), color = colors.primaryText)
            }
            Box(
                modifier = Modifier
                    .width(0.5.dp)
                    .height(30.dp)
                    .background(colors.goldLeaf.copy(alpha = 0.3f)),
            )
            Column(verticalArrangement = Arrangement.spacedBy(6.dp), horizontalAlignment = Alignment.CenterHorizontally) {
                Text("1962 Calendar", style = type.captionSm.copy(fontStyle = FontStyle.Italic), color = colors.primaryText)
                Text("Works offline", style = type.captionSm.copy(fontStyle = FontStyle.Italic), color = colors.primaryText)
            }
        }

        Spacer(modifier = Modifier.height(40.dp))
    }
}

@Composable
private fun TraditionPage() {
    val colors = IntroiboTheme.colors
    val type = IntroiboType.current

    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState()),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Spacer(modifier = Modifier.height(60.dp))

        Text(text = "✠", style = type.pageTitle.copy(fontSize = 48.sp), color = colors.sanctuaryRed)

        Spacer(modifier = Modifier.height(16.dp))

        Text(
            text = "Tradition First",
            style = type.pageTitle.copy(fontSize = 34.sp, fontWeight = FontWeight.SemiBold),
            color = colors.primaryText,
        )

        Spacer(modifier = Modifier.height(8.dp))
        Box(
            modifier = Modifier
                .width(40.dp)
                .height(1.dp)
                .background(colors.sanctuaryRed.copy(alpha = 0.4f)),
        )
        Spacer(modifier = Modifier.height(16.dp))

        Column(
            modifier = Modifier.padding(horizontal = 32.dp),
            verticalArrangement = Arrangement.spacedBy(18.dp),
        ) {
            TraditionRow("The 1962 Missal", "Every prayer, rubric, and response of the Traditional Latin Mass. No Novus Ordo.")
            TraditionRow("The Roman Breviary", "All eight canonical hours as they were prayed before the reforms. Not the Liturgy of the Hours.")
            TraditionRow("Latin Always", "Every prayer in Ecclesiastical Latin with faithful English translation. Latin is never hidden or secondary.")
            TraditionRow("Traditional Penance", "Friday abstinence, Lenten fast, Ember Days. Choose 1962, 1917, or stricter pre-Pius XII discipline.")
            TraditionRow("Follow a Patron Saint", "Daily practice checklists, streak tracking, and prayers for 7 patron saints of the traditional life.")
        }

        Spacer(modifier = Modifier.height(40.dp))
    }
}

@Composable
private fun TraditionRow(title: String, desc: String) {
    val colors = IntroiboTheme.colors
    val type = IntroiboType.current

    Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
        Text(text = title, style = type.titleM.copy(fontStyle = FontStyle.Italic), color = colors.sanctuaryRed)
        Text(text = desc, style = type.bodySm, color = colors.secondaryText, lineHeight = type.bodySm.fontSize * 1.2f)
    }
}

@Composable
private fun FeaturesPage() {
    val colors = IntroiboTheme.colors
    val type = IntroiboType.current

    val features = listOf(
        "Liturgical Today" to "Daily psalm, penance, season, feast days, and today's Mass propers.",
        "1962 Missal" to "Complete Ordinary and 574 daily Propers interleaved in correct Mass order.",
        "67 Prayers" to "Every essential prayer in Latin and English with a personal prayer rule.",
        "Rosary & Stations" to "Interactive bead-by-bead Rosary. 14 Stations with meditations.",
        "Divine Office" to "All 8 canonical hours of the 1962 Breviary.",
        "Confession Guide" to "Examination of conscience and two guided confession paths.",
        "Follow a Saint" to "7 patron saints with daily practices and streak tracking.",
        "Learn Latin" to "10 lessons with 97 flashcards and quizzes.",
        "Reference Library" to "41 articles, 574 searchable propers, TLM history, and glossary.",
    )

    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState()),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Spacer(modifier = Modifier.height(40.dp))

        MonstranceIcon(size = 60)

        Spacer(modifier = Modifier.height(16.dp))

        Text(
            text = "Everything You Need",
            style = type.pageTitle.copy(fontSize = 28.sp, fontWeight = FontWeight.SemiBold),
            color = colors.primaryText,
        )

        Spacer(modifier = Modifier.height(8.dp))
        Box(
            modifier = Modifier
                .width(40.dp)
                .height(1.dp)
                .background(colors.sanctuaryRed.copy(alpha = 0.4f)),
        )
        Spacer(modifier = Modifier.height(16.dp))

        Column(
            modifier = Modifier.padding(horizontal = 28.dp),
            verticalArrangement = Arrangement.spacedBy(16.dp),
        ) {
            features.forEach { (title, desc) ->
                Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
                    Text(text = title, style = type.titleM.copy(fontStyle = FontStyle.Italic), color = colors.primaryText)
                    Text(text = desc, style = type.captionSm, color = colors.secondaryText, lineHeight = type.captionSm.fontSize * 1.3f)
                }
            }
        }

        Spacer(modifier = Modifier.height(40.dp))
    }
}

@Composable
private fun MonstranceIcon(size: Int = 100) {
    val colors = IntroiboTheme.colors

    Canvas(modifier = Modifier.size(size.dp)) {
        val cx = this.size.width / 2f
        val cy = this.size.height / 2f
        val scale = size / 100f

        // Background circle
        drawCircle(
            color = colors.sanctuaryRed,
            radius = 45f * scale,
            center = Offset(cx, cy),
        )

        // Outer ring
        drawCircle(
            color = colors.parchment,
            radius = 30f * scale,
            center = Offset(cx, cy),
            style = Stroke(width = 1.2f * scale),
        )

        // Inner gold ring
        drawCircle(
            color = colors.goldLeaf.copy(alpha = 0.45f),
            radius = 20f * scale,
            center = Offset(cx, cy),
            style = Stroke(width = 0.8f * scale),
        )

        // Host
        drawCircle(
            color = colors.goldLeaf.copy(alpha = 0.65f),
            radius = 8f * scale,
            center = Offset(cx, cy),
        )

        // Cross on host
        drawLine(
            color = colors.sanctuaryRed.copy(alpha = 0.4f),
            start = Offset(cx, cy - 4f * scale),
            end = Offset(cx, cy + 4f * scale),
            strokeWidth = 0.8f * scale,
        )
        drawLine(
            color = colors.sanctuaryRed.copy(alpha = 0.4f),
            start = Offset(cx - 4f * scale, cy),
            end = Offset(cx + 4f * scale, cy),
            strokeWidth = 0.8f * scale,
        )
    }
}

@Composable
private fun SettingsPage(
    settingsRepo: com.lampstandhq.introibo.storage.settings.SettingsRepository,
    scope: kotlinx.coroutines.CoroutineScope,
) {
    val colors = IntroiboTheme.colors
    val type = IntroiboType.current

    val rite by settingsRepo.missalRite.collectAsState(initial = com.lampstandhq.introibo.storage.settings.MissalRite.RITE_1962)
    val penance by settingsRepo.penanceDiscipline.collectAsState(initial = com.lampstandhq.introibo.storage.settings.PenanceDiscipline.DISCIPLINE_1962)
    val language by settingsRepo.languageMode.collectAsState(initial = com.lampstandhq.introibo.storage.settings.LanguageMode.BOTH)

    Column(
        modifier = Modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState()),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Spacer(modifier = Modifier.height(60.dp))

        Text(text = "✠", style = type.pageTitle.copy(fontSize = 48.sp), color = colors.sanctuaryRed)
        Spacer(modifier = Modifier.height(16.dp))
        Text(
            text = "Set Up Your Missal",
            style = type.pageTitle.copy(fontSize = 34.sp, fontWeight = FontWeight.SemiBold),
            color = colors.primaryText,
        )
        Spacer(modifier = Modifier.height(8.dp))
        Box(
            modifier = Modifier
                .width(40.dp)
                .height(1.dp)
                .background(colors.sanctuaryRed.copy(alpha = 0.4f)),
        )
        Spacer(modifier = Modifier.height(24.dp))

        // Rite selection
        Column(modifier = Modifier.padding(horizontal = 32.dp).fillMaxWidth()) {
            Text("Missal Rite", style = type.titleM.copy(fontStyle = FontStyle.Italic), color = colors.sanctuaryRed)
            Spacer(modifier = Modifier.height(8.dp))
            com.lampstandhq.introibo.storage.settings.MissalRite.entries.forEach { r ->
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clickable { scope.launch { settingsRepo.setMissalRite(r) } }
                        .padding(vertical = 10.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Text(r.label, style = type.body, color = colors.primaryText, modifier = Modifier.weight(1f))
                    if (rite == r) {
                        Text("✓", color = colors.sanctuaryRed, style = type.titleM)
                    }
                }
            }
        }

        Spacer(modifier = Modifier.height(24.dp))

        // Penance discipline
        Column(modifier = Modifier.padding(horizontal = 32.dp).fillMaxWidth()) {
            Text("Penance Discipline", style = type.titleM.copy(fontStyle = FontStyle.Italic), color = colors.sanctuaryRed)
            Spacer(modifier = Modifier.height(8.dp))
            com.lampstandhq.introibo.storage.settings.PenanceDiscipline.entries.forEach { d ->
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clickable { scope.launch { settingsRepo.setPenanceDiscipline(d) } }
                        .padding(vertical = 10.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Text(d.label, style = type.body, color = colors.primaryText, modifier = Modifier.weight(1f))
                    if (penance == d) {
                        Text("✓", color = colors.sanctuaryRed, style = type.titleM)
                    }
                }
            }
        }

        Spacer(modifier = Modifier.height(24.dp))

        // Language
        Column(modifier = Modifier.padding(horizontal = 32.dp).fillMaxWidth()) {
            Text("Language", style = type.titleM.copy(fontStyle = FontStyle.Italic), color = colors.sanctuaryRed)
            Spacer(modifier = Modifier.height(8.dp))
            com.lampstandhq.introibo.storage.settings.LanguageMode.entries.forEach { l ->
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clickable { scope.launch { settingsRepo.setLanguageMode(l) } }
                        .padding(vertical = 10.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Text(l.label(), style = type.body, color = colors.primaryText, modifier = Modifier.weight(1f))
                    if (language == l) {
                        Text("✓", color = colors.sanctuaryRed, style = type.titleM)
                    }
                }
            }
        }

        Spacer(modifier = Modifier.height(40.dp))
    }
}
