package com.lampstandhq.introibo.ui.confession

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
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Text
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.runtime.Composable
import androidx.compose.runtime.rememberCoroutineScope
import kotlinx.coroutines.launch
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.lampstandhq.introibo.data.content.ContentStore
import com.lampstandhq.introibo.data.model.ExamenEntry
import com.lampstandhq.introibo.storage.settings.LanguageMode
import com.lampstandhq.introibo.ui.components.SmallLabel
import com.lampstandhq.introibo.ui.components.currentLanguageMode
import com.lampstandhq.introibo.ui.theme.IntroiboTheme
import com.lampstandhq.introibo.ui.theme.IntroiboType

/**
 * Examination of Conscience -- walks through the Ten Commandments
 * with traditional self-examination questions.
 *
 * Port of iOS Introibo/Screens/Confession/ExamenView.swift.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ExamenScreen(
    onDismiss: () -> Unit,
) {
    val colors = IntroiboTheme.colors
    val type = IntroiboType.current

    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    val scope = rememberCoroutineScope()

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = sheetState,
        containerColor = colors.pageBackground,
        dragHandle = null,
    ) {
        Column(modifier = Modifier.fillMaxSize()) {
            // Back button
            Row(modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 8.dp)) {
                IconButton(onClick = { scope.launch { sheetState.hide() }.invokeOnCompletion { onDismiss() } }) {
                    Icon(Icons.AutoMirrored.Filled.ArrowBack, "Back", tint = colors.sanctuaryRed)
                }
            }

            Column(
                modifier = Modifier
                    .fillMaxSize()
                    .verticalScroll(rememberScrollState()),
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
                    SmallLabel(text = "✠  Exámen Consciéntiæ  ✠", color = colors.goldLeaf)
                    Spacer(modifier = Modifier.height(8.dp))
                    Text(text = "Examination of Conscience", style = type.pageTitle, color = colors.ivory)
                    Text(
                        text = "DECÁLOGUS  ·  THE TEN COMMANDMENTS",
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
                    verticalArrangement = Arrangement.spacedBy(24.dp),
                ) {
                    // Intro
                    Box(modifier = Modifier.fillMaxWidth()) {
                        Box(
                            modifier = Modifier
                                .width(1.dp)
                                .matchParentSize()
                                .background(colors.sanctuaryRed.copy(alpha = 0.4f)),
                        )
                        Text(
                            text = "Go through each commandment quietly and honestly. Recall specific sins and their approximate number where you can. Do not rush, but do not dwell past what is useful.",
                            style = type.bodyIt,
                            color = colors.secondaryText,
                            lineHeight = type.bodyIt.fontSize * 1.25f,
                            modifier = Modifier.padding(start = 14.dp),
                        )
                    }

                    // Commandments
                    ContentStore.examen.forEach { entry ->
                        CommandmentBlock(entry)
                    }

                    // Closing
                    Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
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
                            SmallLabel(
                                text = "Post Exámen",
                                color = colors.sanctuaryRed,
                                modifier = Modifier.padding(horizontal = 10.dp),
                            )
                            Box(
                                modifier = Modifier
                                    .weight(1f)
                                    .height(0.5.dp)
                                    .background(colors.goldLeaf.copy(alpha = 0.4f)),
                            )
                        }
                        Text(
                            text = "Make an Act of Contrition. Resolve to avoid the occasions of sin. Proceed to confession.",
                            style = type.bodyIt,
                            color = colors.secondaryText,
                            lineHeight = type.bodyIt.fontSize * 1.2f,
                        )
                    }
                }
            }
        }
    }
}

@Composable
private fun CommandmentBlock(e: ExamenEntry) {
    val colors = IntroiboTheme.colors
    val type = IntroiboType.current

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 6.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Row(verticalAlignment = Alignment.Top) {
            Text(
                text = e.num,
                style = type.titleL.copy(fontStyle = FontStyle.Italic),
                color = colors.sanctuaryRed,
                modifier = Modifier.width(44.dp),
            )
            Spacer(modifier = Modifier.width(12.dp))
            Column {
                Text(
                    text = e.commandment,
                    style = type.titleM.copy(fontStyle = FontStyle.Italic),
                    color = colors.primaryText,
                )
                if (currentLanguageMode() != LanguageMode.VERNACULAR) {
                    Text(
                        text = e.latin,
                        style = type.captionSm.copy(fontStyle = FontStyle.Italic),
                        color = colors.secondaryText,
                    )
                }
            }
        }

        Column(
            modifier = Modifier.padding(start = 56.dp, top = 4.dp),
            verticalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            e.questions.forEach { q ->
                Row(verticalAlignment = Alignment.Top) {
                    Text(
                        text = "•",
                        style = type.body,
                        color = colors.goldLeaf,
                        modifier = Modifier.padding(end = 8.dp),
                    )
                    Text(
                        text = q,
                        style = type.bodySm,
                        color = colors.secondaryText,
                        lineHeight = type.bodySm.fontSize * 1.15f,
                    )
                }
            }
        }
    }
}
