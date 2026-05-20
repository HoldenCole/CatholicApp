package com.lampstandhq.introibo.ui.prayers

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
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Text
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import com.lampstandhq.introibo.data.model.Prayer
import com.lampstandhq.introibo.data.model.strippingEm
import com.lampstandhq.introibo.ui.components.BilingualLine
import com.lampstandhq.introibo.ui.components.SmallLabel
import com.lampstandhq.introibo.ui.theme.IntroiboTheme
import com.lampstandhq.introibo.ui.theme.IntroiboType

/**
 * Single-prayer detail sheet. Shows category label, title,
 * optional note, and line-by-line Latin/English with a drop cap.
 * Ported from iOS PrayerDetailView.swift.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun PrayerDetailSheet(
    prayer: Prayer,
    onDismiss: () -> Unit,
) {
    Dialog(
        onDismissRequest = onDismiss,
        properties = DialogProperties(usePlatformDefaultWidth = false),
    ) {
        val colors = IntroiboTheme.colors
        val type = IntroiboType.current

        Column(
            modifier = Modifier
                .fillMaxSize()
                .background(colors.pageBackground),
        ) {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .background(colors.walnut)
                    .padding(horizontal = 8.dp, vertical = 4.dp),
            ) {
                IconButton(onClick = onDismiss) {
                    Icon(Icons.AutoMirrored.Filled.ArrowBack, "Back", tint = colors.sanctuaryRed)
                }
            }

            LazyColumn(
                modifier = Modifier.fillMaxSize(),
                contentPadding = androidx.compose.foundation.layout.PaddingValues(bottom = 80.dp),
            ) {
                // Header
                item {
                    Column(
                        horizontalAlignment = Alignment.CenterHorizontally,
                        modifier = Modifier
                            .fillMaxWidth()
                            .background(
                                Brush.verticalGradient(
                                    listOf(colors.walnut, colors.walnutHi)
                                )
                            )
                            .padding(horizontal = 28.dp),
                    ) {
                        SmallLabel(
                            text = "✠  ${prayer.category}  ✠",
                            color = colors.goldLeaf,
                            modifier = Modifier.padding(top = 28.dp),
                        )
                        Text(
                            text = prayer.title.strippingEm,
                            style = type.pageTitle,
                            color = colors.ivory,
                            textAlign = TextAlign.Center,
                            modifier = Modifier.padding(top = 8.dp),
                        )
                        Text(
                            text = prayer.eng.uppercase(),
                            style = type.captionSm.copy(
                                fontStyle = FontStyle.Italic,
                                letterSpacing = 2.5.sp,
                            ),
                            color = colors.muted,
                            modifier = Modifier.padding(top = 4.dp),
                        )
                        Box(
                            modifier = Modifier
                                .padding(top = 8.dp, bottom = 18.dp)
                                .width(60.dp)
                                .height(0.5.dp)
                                .background(colors.goldLeaf.copy(alpha = 0.4f)),
                        )
                    }
                }

                // Optional note
                prayer.note?.takeIf { it.isNotEmpty() }?.let { note ->
                    item {
                        Text(
                            text = note.strippingEm,
                            style = type.bodyIt,
                            color = colors.secondaryText,
                            modifier = Modifier
                                .padding(horizontal = 28.dp)
                                .padding(top = 16.dp, bottom = 4.dp),
                        )
                    }
                }

                // Prayer lines
                itemsIndexed(prayer.lines) { index, line ->
                    Column(
                        modifier = Modifier
                            .padding(horizontal = 28.dp)
                            .padding(top = if (index == 0) 20.dp else 12.dp),
                    ) {
                        if (index == 0) {
                            // Drop cap for first line
                            DropCapLine(
                                lat = line.lat.strippingEm,
                                eng = line.eng.strippingEm,
                            )
                        } else {
                            BilingualLine(
                                lat = line.lat.strippingEm,
                                eng = line.eng.strippingEm,
                                sideBySide = true,
                            )
                        }
                    }
                }

                item { Spacer(Modifier.height(40.dp)) }
            }
        }
    }
}

/**
 * First line with a decorative Latin drop cap.
 */
@Composable
private fun DropCapLine(lat: String, eng: String) {
    val colors = IntroiboTheme.colors
    val type = IntroiboType.current

    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(12.dp),
        verticalAlignment = Alignment.Top,
    ) {
        // Latin with drop cap
        Row(
            verticalAlignment = Alignment.Top,
            modifier = Modifier.weight(1f),
        ) {
            if (lat.isNotEmpty()) {
                Text(
                    text = lat.take(1),
                    style = type.body.copy(
                        fontSize = (type.body.fontSize.value * 2.8f).coerceAtMost(60f).sp,
                        fontStyle = FontStyle.Italic,
                    ),
                    color = colors.sanctuaryRed,
                )
                Spacer(Modifier.width(2.dp))
                Text(
                    text = lat.drop(1),
                    style = type.body,
                    color = colors.primaryText,
                    lineHeight = type.body.fontSize * 1.2f,
                )
            }
        }

        // English
        Text(
            text = eng,
            style = type.bodySm.copy(fontStyle = FontStyle.Italic),
            color = colors.secondaryText,
            lineHeight = type.bodySm.fontSize * 1.2f,
            modifier = Modifier.weight(1f),
        )
    }
}
