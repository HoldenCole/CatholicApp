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
import com.lampstandhq.introibo.data.model.ConfessionGuide
import com.lampstandhq.introibo.storage.settings.LanguageMode
import com.lampstandhq.introibo.ui.components.SmallLabel
import com.lampstandhq.introibo.ui.components.currentLanguageMode
import com.lampstandhq.introibo.ui.theme.IntroiboTheme
import com.lampstandhq.introibo.ui.theme.IntroiboType

/**
 * Reader for a single guided confession path (Liber I or Liber II).
 *
 * Port of iOS Introibo/Screens/Confession/GuideReaderView.swift.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun GuideReaderScreen(
    guide: ConfessionGuide,
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
                    SmallLabel(text = "✠  ${guide.name}  ✠", color = colors.goldLeaf)
                    Spacer(modifier = Modifier.height(8.dp))
                    Text(
                        text = guide.title,
                        style = type.pageTitle,
                        color = colors.ivory,
                        modifier = Modifier.padding(horizontal = 28.dp),
                    )
                    Text(
                        text = "SACRAMÉNTUM PÆNITÉNTIÆ",
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
                    // Subtitle
                    guide.subtitle?.let { sub ->
                        Box(modifier = Modifier.fillMaxWidth()) {
                            Box(
                                modifier = Modifier
                                    .width(1.dp)
                                    .matchParentSize()
                                    .background(colors.sanctuaryRed.copy(alpha = 0.4f)),
                            )
                            Text(
                                text = sub,
                                style = type.bodyIt,
                                color = colors.secondaryText,
                                lineHeight = type.bodyIt.fontSize * 1.25f,
                                modifier = Modifier.padding(start = 14.dp),
                            )
                        }
                    }

                    // Steps
                    guide.steps.forEach { step ->
                        StepBlock(step)
                    }
                }
            }
        }
    }
}

@Composable
private fun StepBlock(step: ConfessionGuide.Step) {
    val colors = IntroiboTheme.colors
    val type = IntroiboType.current

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 4.dp),
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        Row(verticalAlignment = Alignment.Top) {
            Text(
                text = step.num,
                style = type.titleL.copy(fontStyle = FontStyle.Italic),
                color = colors.sanctuaryRed,
                modifier = Modifier.width(44.dp),
            )
            Spacer(modifier = Modifier.width(12.dp))
            Column {
                Text(
                    text = step.title,
                    style = type.titleM.copy(fontStyle = FontStyle.Italic),
                    color = colors.primaryText,
                )
                if (currentLanguageMode() != LanguageMode.VERNACULAR) {
                    step.latin?.let { latin ->
                        Text(
                            text = latin,
                            style = type.captionSm.copy(fontStyle = FontStyle.Italic),
                            color = colors.secondaryText,
                        )
                    }
                }
            }
        }

        Text(
            text = step.body,
            style = type.bodySm,
            color = colors.secondaryText,
            lineHeight = type.bodySm.fontSize * 1.2f,
            modifier = Modifier.padding(start = 56.dp),
        )
    }
}
