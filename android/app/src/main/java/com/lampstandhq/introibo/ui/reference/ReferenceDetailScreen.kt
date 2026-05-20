package com.lampstandhq.introibo.ui.reference

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
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.lampstandhq.introibo.data.model.ReferenceEntry
import com.lampstandhq.introibo.data.model.strippingEm
import com.lampstandhq.introibo.storage.settings.LanguageMode
import com.lampstandhq.introibo.ui.components.SmallLabel
import com.lampstandhq.introibo.ui.components.currentLanguageMode
import com.lampstandhq.introibo.ui.theme.IntroiboTheme
import com.lampstandhq.introibo.ui.theme.IntroiboType

/**
 * Detail sheet for a single reference entry.
 *
 * Port of iOS Introibo/Screens/Reference/ReferenceDetailView.swift.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ReferenceDetailScreen(
    entry: ReferenceEntry,
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
                    SmallLabel(text = "✠  ${entry.cat}  ✠", color = colors.goldLeaf)
                    Spacer(modifier = Modifier.height(8.dp))
                    Text(
                        text = entry.title,
                        style = type.pageTitle,
                        color = colors.ivory,
                        textAlign = TextAlign.Center,
                        modifier = Modifier.padding(horizontal = 28.dp),
                    )
                    if (currentLanguageMode() != LanguageMode.VERNACULAR) {
                        entry.latin?.let { latin ->
                            Text(
                                text = latin.uppercase(),
                                style = type.captionSm.copy(fontStyle = FontStyle.Italic),
                                color = colors.muted,
                                letterSpacing = 2.5.sp,
                            )
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
                    verticalArrangement = Arrangement.spacedBy(22.dp),
                ) {
                    // Summary (drop cap style -- plain for now)
                    Text(
                        text = entry.summary.strippingEm,
                        style = type.body,
                        color = colors.primaryText,
                        lineHeight = type.body.fontSize * 1.25f,
                        modifier = Modifier.fillMaxWidth(),
                    )

                    // History
                    entry.history?.let { history ->
                        SectionBlock(title = "Historia", body = history)
                    }

                    // Practice
                    entry.practice?.let { practice ->
                        SectionBlock(title = "Praxis", body = practice)
                    }

                    // Notes
                    entry.notes?.let { notes ->
                        SectionBlock(title = "Notandum", body = notes)
                    }

                    // Scripture
                    entry.scripture?.let { s ->
                        ScriptureBlock(scripture = s)
                    }
                }
            }
        }
    }
}

@Composable
private fun SectionBlock(title: String, body: String) {
    val colors = IntroiboTheme.colors
    val type = IntroiboType.current

    Column(
        modifier = Modifier.fillMaxWidth(),
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        SmallLabel(text = title, color = colors.sanctuaryRed)
        Text(
            text = body.strippingEm,
            style = type.bodySm,
            color = colors.secondaryText,
            lineHeight = type.bodySm.fontSize * 1.2f,
        )
    }
}

@Composable
private fun ScriptureBlock(scripture: ReferenceEntry.Scripture) {
    val colors = IntroiboTheme.colors
    val type = IntroiboType.current

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .border(0.5.dp, colors.frameLine)
            .padding(14.dp),
        verticalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        SmallLabel(text = "Scriptura  ·  ${scripture.ref}", color = colors.sanctuaryRed)
        Text(
            text = scripture.lat,
            style = type.bodyIt,
            color = colors.primaryText,
        )
        Text(
            text = scripture.eng,
            style = type.captionSm.copy(fontStyle = FontStyle.Italic),
            color = colors.secondaryText,
        )
    }
}
