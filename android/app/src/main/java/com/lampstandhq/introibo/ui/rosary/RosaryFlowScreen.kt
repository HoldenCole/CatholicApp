package com.lampstandhq.introibo.ui.rosary

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
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import kotlinx.coroutines.launch
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.lampstandhq.introibo.data.content.ContentStore
import com.lampstandhq.introibo.data.model.Mystery
import com.lampstandhq.introibo.data.model.MysterySetData
import com.lampstandhq.introibo.ui.components.BilingualLine
import com.lampstandhq.introibo.ui.components.SmallLabel
import com.lampstandhq.introibo.ui.theme.IntroiboTheme
import com.lampstandhq.introibo.ui.theme.IntroiboType

/**
 * Interactive bead-by-bead Rosary flow.
 *
 * Port of iOS Introibo/Screens/Rosary/RosaryFlowView.swift.
 */

private data class RosaryStep(
    val label: String,
    val latin: String,
    val english: String,
    val decade: Int = 0,
    val mystery: Mystery? = null,
    val meditation: String? = null,
    val beadInDecade: Int = 0,
)

@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun RosaryFlowScreen(
    set: MysterySetData,
    onDismiss: () -> Unit,
) {
    val colors = IntroiboTheme.colors
    val type = IntroiboType.current

    var stepIndex by remember { mutableIntStateOf(0) }
    var steps by remember { mutableStateOf<List<RosaryStep>>(emptyList()) }

    LaunchedEffect(set) {
        steps = buildSteps(set)
    }

    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    val scope = rememberCoroutineScope()

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = sheetState,
        containerColor = colors.pageBackground,
        dragHandle = null,
    ) {
        Column(modifier = Modifier.fillMaxSize()) {
            // Top bar
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp, vertical = 8.dp),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                IconButton(onClick = { scope.launch { sheetState.hide() }.invokeOnCompletion { onDismiss() } }) {
                    Icon(Icons.AutoMirrored.Filled.ArrowBack, "Back", tint = colors.sanctuaryRed)
                }
                if (steps.isNotEmpty() && stepIndex < steps.size) {
                    Text(
                        text = "${stepIndex + 1} / ${steps.size}",
                        style = type.captionSm,
                        color = colors.tertiaryText,
                    )
                }
            }

            when {
                steps.isEmpty() -> {
                    Box(
                        modifier = Modifier.fillMaxSize(),
                        contentAlignment = Alignment.Center,
                    ) {
                        Text("Loading...", style = type.body, color = colors.tertiaryText)
                    }
                }
                stepIndex >= steps.size -> {
                    CompletionView(set = set, onDismiss = onDismiss)
                }
                else -> {
                    val step = steps[stepIndex]
                    Column(modifier = Modifier.weight(1f)) {
                        Column(
                            modifier = Modifier
                                .weight(1f)
                                .verticalScroll(rememberScrollState())
                                .padding(bottom = 100.dp),
                            horizontalAlignment = Alignment.CenterHorizontally,
                            verticalArrangement = Arrangement.spacedBy(16.dp),
                        ) {
                            Spacer(modifier = Modifier.height(12.dp))

                            // Decade progress
                            BeadProgress(currentDecade = step.decade)

                            // Mystery context
                            step.mystery?.let { mystery ->
                                Column(
                                    modifier = Modifier
                                        .fillMaxWidth()
                                        .background(colors.frameLine.copy(alpha = 0.3f))
                                        .padding(horizontal = 28.dp, vertical = 10.dp),
                                    horizontalAlignment = Alignment.CenterHorizontally,
                                    verticalArrangement = Arrangement.spacedBy(6.dp),
                                ) {
                                    Text(
                                        text = mystery.title,
                                        style = type.titleL.copy(fontStyle = FontStyle.Italic),
                                        color = colors.primaryText,
                                        textAlign = TextAlign.Center,
                                    )
                                    Text(
                                        text = mystery.eng,
                                        style = type.captionSm.copy(fontStyle = FontStyle.Italic),
                                        color = colors.secondaryText,
                                    )
                                    Text(
                                        text = "Fruit: ${mystery.fruit}",
                                        style = type.captionSm.copy(fontStyle = FontStyle.Italic),
                                        color = colors.goldLeaf,
                                        modifier = Modifier.padding(top = 2.dp),
                                    )
                                }
                            }

                            // Step label
                            SmallLabel(text = step.label, color = colors.goldLeaf)

                            // Prayer text
                            Column(
                                modifier = Modifier.padding(horizontal = 28.dp),
                                verticalArrangement = Arrangement.spacedBy(10.dp),
                                horizontalAlignment = Alignment.Start,
                            ) {
                                BilingualLine(lat = step.latin, eng = step.english)
                            }

                            // Meditation
                            step.meditation?.let { meditation ->
                                Column(
                                    modifier = Modifier.padding(horizontal = 28.dp),
                                    verticalArrangement = Arrangement.spacedBy(6.dp),
                                ) {
                                    HorizontalDivider(
                                        color = colors.goldLeaf.copy(alpha = 0.3f),
                                        thickness = 0.5.dp,
                                    )
                                    Text(
                                        text = meditation,
                                        style = type.bodySm.copy(fontStyle = FontStyle.Italic),
                                        color = colors.tertiaryText,
                                        lineHeight = type.bodySm.fontSize * 1.2f,
                                    )
                                }
                            }

                            // Bead count within decade
                            if (step.beadInDecade > 0) {
                                Row(
                                    horizontalArrangement = Arrangement.spacedBy(4.dp),
                                    modifier = Modifier.padding(top = 12.dp),
                                ) {
                                    for (i in 1..10) {
                                        Box(
                                            modifier = Modifier
                                                .size(8.dp)
                                                .clip(CircleShape)
                                                .background(
                                                    if (i <= step.beadInDecade) colors.sanctuaryRed
                                                    else colors.frameLine
                                                ),
                                        )
                                    }
                                }
                            }
                        }

                        // Nav bar
                        NavBar(
                            stepIndex = stepIndex,
                            totalSteps = steps.size,
                            onPrev = { if (stepIndex > 0) stepIndex-- },
                            onNext = {
                                if (stepIndex + 1 < steps.size) {
                                    stepIndex++
                                } else {
                                    stepIndex = steps.size
                                }
                            },
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun BeadProgress(currentDecade: Int) {
    val colors = IntroiboTheme.colors
    Row(horizontalArrangement = Arrangement.spacedBy(6.dp)) {
        for (d in 0 until 5) {
            val color = when {
                d < currentDecade -> colors.sanctuaryRed
                d == currentDecade -> colors.goldLeaf
                else -> colors.frameLine
            }
            Box(
                modifier = Modifier
                    .size(12.dp)
                    .clip(CircleShape)
                    .background(color),
            )
        }
    }
}

@Composable
private fun NavBar(
    stepIndex: Int,
    totalSteps: Int,
    onPrev: () -> Unit,
    onNext: () -> Unit,
) {
    val colors = IntroiboTheme.colors
    val type = IntroiboType.current

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .background(
                Brush.verticalGradient(
                    colors = listOf(colors.pageBackground.copy(alpha = 0f), colors.pageBackground),
                )
            )
            .padding(horizontal = 28.dp)
            .padding(top = 12.dp, bottom = 36.dp),
        horizontalArrangement = Arrangement.spacedBy(18.dp),
    ) {
        // Back button
        Box(
            modifier = Modifier
                .size(52.dp)
                .background(
                    color = if (stepIndex == 0) colors.pageBackground.copy(alpha = 0.4f)
                    else colors.pageBackground
                )
                .then(
                    if (stepIndex > 0) Modifier.background(colors.pageBackground)
                    else Modifier
                ),
            contentAlignment = Alignment.Center,
        ) {
            TextButton(
                onClick = onPrev,
                enabled = stepIndex > 0,
            ) {
                Text(
                    text = "‹",
                    style = type.titleL,
                    color = colors.sanctuaryRed.copy(alpha = if (stepIndex == 0) 0.4f else 1f),
                )
            }
        }

        // Next button
        TextButton(
            onClick = onNext,
            modifier = Modifier
                .weight(1f)
                .background(colors.sanctuaryRed.copy(alpha = 0.85f))
                .padding(vertical = 4.dp),
        ) {
            SmallLabel(
                text = if (stepIndex + 1 < totalSteps) "Next  ✠" else "Finish  ✠",
                color = colors.ivory,
            )
        }
    }
}

@Composable
private fun CompletionView(
    set: MysterySetData,
    onDismiss: () -> Unit,
) {
    val colors = IntroiboTheme.colors
    val type = IntroiboType.current

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(colors.pageBackground),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        Text(
            text = "✠",
            style = type.pageTitle.copy(fontSize = 64.sp),
            color = colors.sanctuaryRed,
        )
        Spacer(modifier = Modifier.height(16.dp))
        Text(
            text = "Rosary Complete",
            style = type.pageTitle,
            color = colors.primaryText,
        )
        Text(
            text = set.english.uppercase(),
            style = type.captionSm.copy(fontStyle = FontStyle.Italic),
            color = colors.secondaryText,
            letterSpacing = 2.sp,
        )
        Spacer(modifier = Modifier.height(8.dp))
        Text(
            text = "Marked as prayed today",
            style = type.captionSm,
            color = colors.goldLeaf,
        )
        Spacer(modifier = Modifier.height(20.dp))
        TextButton(
            onClick = onDismiss,
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 28.dp),
        ) {
            SmallLabel(text = "Close", color = colors.sanctuaryRed)
        }
    }
}

private fun buildSteps(set: MysterySetData): List<RosaryStep> {
    val s = mutableListOf<RosaryStep>()

    fun prayer(slug: String): Pair<String, String> {
        val p = ContentStore.rosaryPrayers.firstOrNull { it.slug == slug }
        val line = p?.lines?.firstOrNull() ?: return Pair("", "")
        return Pair(line.lat, line.eng)
    }

    val signum = prayer("signum")
    val credo = prayer("credo")
    val pater = prayer("pater")
    val ave = prayer("ave")
    val gloria = prayer("gloria")
    val fatima = prayer("fatima")
    val salve = prayer("salve")

    // Opening
    s += RosaryStep(label = "Signum Crucis", latin = signum.first, english = signum.second, decade = 0)
    s += RosaryStep(label = "Credo", latin = credo.first, english = credo.second, decade = 0)
    s += RosaryStep(label = "Pater Noster", latin = pater.first, english = pater.second, decade = 0)
    val virtues = listOf("Faith", "Hope", "Charity")
    for (i in 1..3) {
        s += RosaryStep(
            label = "Ave María (${virtues[i - 1]})",
            latin = ave.first, english = ave.second,
            decade = 0, beadInDecade = i,
        )
    }
    s += RosaryStep(label = "Glória Patri", latin = gloria.first, english = gloria.second, decade = 0)

    // 5 Decades
    set.mysteries.forEachIndexed { dIdx, mystery ->
        s += RosaryStep(
            label = mystery.num,
            latin = mystery.title, english = mystery.eng,
            decade = dIdx, mystery = mystery,
            meditation = mystery.body + "\n\nFruit: " + mystery.fruit,
        )
        s += RosaryStep(label = "Pater Noster", latin = pater.first, english = pater.second, decade = dIdx, mystery = mystery)
        for (bead in 1..10) {
            s += RosaryStep(
                label = "Ave María  ·  $bead of 10",
                latin = ave.first, english = ave.second,
                decade = dIdx, mystery = mystery, beadInDecade = bead,
            )
        }
        s += RosaryStep(label = "Glória Patri", latin = gloria.first, english = gloria.second, decade = dIdx, mystery = mystery)
        s += RosaryStep(label = "Orátio Fátimæ", latin = fatima.first, english = fatima.second, decade = dIdx, mystery = mystery)
    }

    // Closing
    s += RosaryStep(label = "Salve Regína", latin = salve.first, english = salve.second, decade = 4)
    s += RosaryStep(label = "Signum Crucis", latin = signum.first, english = signum.second, decade = 4)

    return s
}
