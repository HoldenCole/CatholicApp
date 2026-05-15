package com.lampstandhq.introibo.ui.office

import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.runtime.rememberCoroutineScope
import kotlinx.coroutines.launch
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
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Text
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.lampstandhq.introibo.data.model.Hour
import com.lampstandhq.introibo.data.model.strippingEm
import com.lampstandhq.introibo.ui.components.BilingualLine
import com.lampstandhq.introibo.ui.components.SmallLabel
import com.lampstandhq.introibo.ui.theme.IntroiboTheme
import com.lampstandhq.introibo.ui.theme.IntroiboType

/**
 * Full liturgy for a single canonical hour, shown as a full-screen
 * bottom sheet. Renders all part types: vr, hymn, psalm, antiphon,
 * capitulum, canticle, pater, collect, closing, confiteor, responsory,
 * marian, heading, reading.
 *
 * Port of iOS Introibo/Screens/Office/HourView.swift.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun HourSheet(
    hour: Hour,
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
        Column(
            modifier = Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState()),
        ) {
            // Back button
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp, vertical = 8.dp),
            ) {
                IconButton(onClick = {
                    scope.launch { sheetState.hide() }.invokeOnCompletion { onDismiss() }
                }) {
                    Icon(Icons.AutoMirrored.Filled.ArrowBack, "Back", tint = colors.sanctuaryRed)
                }
            }

            // Header
            HourHeader(hour = hour)

            // Content
            Column(
                modifier = Modifier
                    .padding(horizontal = 20.dp, vertical = 24.dp),
                verticalArrangement = Arrangement.spacedBy(22.dp),
            ) {
                // Intro
                IntroBlock(text = hour.intro)

                // Parts
                hour.parts.forEach { part ->
                    PartView(part)
                }
            }
        }
    }
}

@Composable
private fun HourHeader(hour: Hour) {
    val colors = IntroiboTheme.colors
    val type = IntroiboType.current
    val numerals = listOf("", "I", "II", "III", "IV", "V", "VI", "VII", "VIII")
    val roman = if (hour.order < numerals.size) numerals[hour.order] else "${hour.order}"

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .background(
                Brush.verticalGradient(
                    colors = listOf(colors.walnut, colors.walnutHi)
                )
            )
            .padding(vertical = 8.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Spacer(modifier = Modifier.height(20.dp))

        SmallLabel(
            text = "✠  Hora $roman  ✠",
            color = colors.goldLeaf,
        )

        Spacer(modifier = Modifier.height(8.dp))

        Text(
            text = hour.name,
            style = type.pageTitle,
            color = colors.ivory,
        )

        Text(
            text = hour.eng.uppercase(),
            style = type.captionSm.copy(fontStyle = FontStyle.Italic),
            color = colors.muted,
            letterSpacing = 2.5.sp,
        )

        Text(
            text = hour.time,
            style = type.captionSm.copy(fontStyle = FontStyle.Italic),
            color = colors.muted,
            modifier = Modifier.padding(top = 2.dp),
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
}

@Composable
private fun IntroBlock(text: String) {
    val colors = IntroiboTheme.colors
    val type = IntroiboType.current

    Box(
        modifier = Modifier.fillMaxWidth(),
    ) {
        // Left accent bar
        Box(
            modifier = Modifier
                .width(1.dp)
                .matchParentSize()
                .background(colors.sanctuaryRed.copy(alpha = 0.4f)),
        )

        Text(
            text = text,
            style = type.bodyIt,
            color = colors.secondaryText,
            lineHeight = type.bodyIt.fontSize * 1.25f,
            modifier = Modifier.padding(start = 14.dp),
        )
    }
}

@Composable
private fun PartView(p: Hour.Part) {
    when (p.type) {
        "vr" -> VrBlock(p)
        "hymn" -> HymnBlock(p)
        "antiphon" -> SimpleBlock(p, labelFallback = "Antíphona")
        "psalm" -> PsalmBlock(p)
        "capitulum" -> SimpleBlock(p, labelFallback = "Capítulum")
        "canticle" -> PsalmBlock(p)
        "pater" -> PaterInlineBlock(p)
        "collect" -> SimpleBlock(p, labelFallback = "Collécta")
        "closing" -> SimpleBlock(p, labelFallback = "Conclúsio")
        "confiteor" -> ConfiteorBlock(p)
        "responsory" -> ResponsoryBlock(p)
        "marian" -> MarianBlock(p)
        "heading" -> HeadingBlock(p)
        "reading" -> ReadingBlock(p)
    }
}

@Composable
private fun VrBlock(p: Hour.Part) {
    val colors = IntroiboTheme.colors

    Column(
        modifier = Modifier.fillMaxWidth(),
        verticalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        SmallLabel(text = p.label ?: "Versus", color = colors.sanctuaryRed)

        if (p.lat != null && p.eng != null) {
            BilingualLine(lat = p.lat, eng = p.eng, sideBySide = true)
        }
        if (p.latR != null && p.engR != null) {
            Spacer(modifier = Modifier.height(4.dp))
            BilingualLine(lat = p.latR, eng = p.engR, sideBySide = true)
        }
    }
}

@Composable
private fun HymnBlock(p: Hour.Part) {
    val colors = IntroiboTheme.colors
    val type = IntroiboType.current

    Column(
        modifier = Modifier.fillMaxWidth(),
        verticalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        // Decorated label
        DecoratedLabel(text = p.label ?: "Hymnus")

        p.title?.let { title ->
            Text(
                text = title,
                style = type.titleM.copy(fontStyle = FontStyle.Italic),
                color = colors.primaryText,
            )
        }

        if (p.lat != null && p.eng != null) {
            val latStanzas = p.lat.split("\n\n")
            val engStanzas = p.eng.split("\n\n")
            val count = maxOf(latStanzas.size, engStanzas.size)

            Column(verticalArrangement = Arrangement.spacedBy(14.dp)) {
                for (i in 0 until count) {
                    BilingualLine(
                        lat = latStanzas.getOrElse(i) { "" },
                        eng = engStanzas.getOrElse(i) { "" },
                        sideBySide = true,
                    )
                }
            }
        }
    }
}

@Composable
private fun SimpleBlock(p: Hour.Part, labelFallback: String) {
    val colors = IntroiboTheme.colors
    val type = IntroiboType.current

    Column(
        modifier = Modifier.fillMaxWidth(),
        verticalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        SmallLabel(text = p.label ?: labelFallback, color = colors.sanctuaryRed)

        p.ref?.let { ref ->
            Text(
                text = ref,
                style = type.captionSm,
                color = colors.goldLeaf,
            )
        }

        if (p.lat != null && p.eng != null) {
            BilingualLine(lat = p.lat, eng = p.eng, sideBySide = true)
        } else {
            p.lat?.let { lat ->
                Text(
                    text = lat.strippingEm,
                    style = type.body,
                    color = colors.primaryText,
                    lineHeight = type.body.fontSize * 1.2f,
                )
            }
            p.eng?.let { eng ->
                Text(
                    text = eng.strippingEm,
                    style = type.bodySm.copy(fontStyle = FontStyle.Italic),
                    color = colors.secondaryText,
                    lineHeight = type.bodySm.fontSize * 1.15f,
                )
            }
        }
    }
}

@Composable
private fun PsalmBlock(p: Hour.Part) {
    val colors = IntroiboTheme.colors
    val type = IntroiboType.current

    Column(
        modifier = Modifier.fillMaxWidth(),
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        // Decorated label with optional ref
        Row(
            verticalAlignment = Alignment.CenterVertically,
            modifier = Modifier.fillMaxWidth(),
        ) {
            GoldLine(modifier = Modifier.weight(1f))
            SmallLabel(
                text = p.label ?: "Psalmus",
                color = colors.sanctuaryRed,
                modifier = Modifier.padding(horizontal = 10.dp),
            )
            p.ref?.let { ref ->
                Text(
                    text = ref,
                    style = type.captionSm,
                    color = colors.goldLeaf,
                    modifier = Modifier.padding(end = 10.dp),
                )
            }
            GoldLine(modifier = Modifier.weight(1f))
        }

        p.verses?.let { verses ->
            Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                verses.forEach { v ->
                    BilingualLine(lat = v.lat, eng = v.eng, sideBySide = true)
                }
            }
        }
    }
}

@Composable
private fun PaterInlineBlock(@Suppress("UNUSED_PARAMETER") p: Hour.Part) {
    val colors = IntroiboTheme.colors
    val type = IntroiboType.current

    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        SmallLabel(text = "Pater Noster", color = colors.sanctuaryRed)
        Text(
            text = "silently",
            style = type.captionSm.copy(fontStyle = FontStyle.Italic),
            color = colors.tertiaryText,
        )
    }
}

@Composable
private fun ConfiteorBlock(p: Hour.Part) {
    val colors = IntroiboTheme.colors
    val type = IntroiboType.current

    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        SmallLabel(text = p.label ?: "Confíteor", color = colors.sanctuaryRed)
        Text(
            text = "In the customary form",
            style = type.captionSm.copy(fontStyle = FontStyle.Italic),
            color = colors.tertiaryText,
        )
    }
}

@Composable
private fun ResponsoryBlock(p: Hour.Part) {
    val colors = IntroiboTheme.colors
    val type = IntroiboType.current

    Column(
        modifier = Modifier.fillMaxWidth(),
        verticalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        SmallLabel(text = p.label ?: "Respónsum", color = colors.sanctuaryRed)

        p.ref?.let { ref ->
            Text(text = ref, style = type.captionSm, color = colors.goldLeaf)
        }

        if (p.v1Lat != null && p.v1Eng != null) {
            BilingualLine(lat = p.v1Lat, eng = p.v1Eng, sideBySide = true)
        }
        if (p.r1Lat != null && p.r1Eng != null) {
            Spacer(modifier = Modifier.height(4.dp))
            BilingualLine(lat = p.r1Lat, eng = p.r1Eng, sideBySide = true)
        }
        if (p.v2Lat != null && p.v2Eng != null) {
            Spacer(modifier = Modifier.height(6.dp))
            BilingualLine(lat = p.v2Lat, eng = p.v2Eng, sideBySide = true)
        }
        if (p.r2Lat != null && p.r2Eng != null) {
            Spacer(modifier = Modifier.height(4.dp))
            BilingualLine(lat = p.r2Lat, eng = p.r2Eng, sideBySide = true)
        }
    }
}

@Composable
private fun MarianBlock(p: Hour.Part) {
    val colors = IntroiboTheme.colors
    val type = IntroiboType.current

    Column(
        modifier = Modifier.fillMaxWidth(),
        verticalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            modifier = Modifier.fillMaxWidth(),
        ) {
            GoldLine(modifier = Modifier.weight(1f))
            SmallLabel(
                text = p.title ?: "Antíphona Mariana",
                color = colors.sanctuaryRed,
                modifier = Modifier.padding(horizontal = 10.dp),
            )
            p.season?.let { season ->
                Text(
                    text = "($season)",
                    style = type.captionSm.copy(fontStyle = FontStyle.Italic),
                    color = colors.tertiaryText,
                    modifier = Modifier.padding(end = 10.dp),
                )
            }
            GoldLine(modifier = Modifier.weight(1f))
        }

        p.lat?.let { lat ->
            val eng = p.engBody ?: p.eng ?: ""
            BilingualLine(lat = lat, eng = eng, sideBySide = true)
        }
    }
}

@Composable
private fun HeadingBlock(p: Hour.Part) {
    val colors = IntroiboTheme.colors
    val type = IntroiboType.current

    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier
            .fillMaxWidth()
            .padding(top = 10.dp),
    ) {
        Box(
            modifier = Modifier
                .weight(1f)
                .height(0.5.dp)
                .background(colors.sanctuaryRed.copy(alpha = 0.3f)),
        )
        Text(
            text = p.label ?: "",
            style = type.titleM.copy(fontStyle = FontStyle.Italic),
            color = colors.sanctuaryRed,
            maxLines = 1,
            modifier = Modifier.padding(horizontal = 10.dp),
        )
        Box(
            modifier = Modifier
                .weight(1f)
                .height(0.5.dp)
                .background(colors.sanctuaryRed.copy(alpha = 0.3f)),
        )
    }
}

@Composable
private fun ReadingBlock(p: Hour.Part) {
    val colors = IntroiboTheme.colors
    val type = IntroiboType.current

    Column(
        modifier = Modifier.fillMaxWidth(),
        verticalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        SmallLabel(text = p.label ?: "Léctio", color = colors.goldLeaf)

        p.ref?.let { ref ->
            Text(text = ref, style = type.captionSm, color = colors.goldLeaf)
        }

        if (p.lat != null && p.eng != null) {
            BilingualLine(lat = p.lat, eng = p.eng, sideBySide = true)
        } else {
            p.lat?.let { lat ->
                Text(
                    text = lat.strippingEm,
                    style = type.body,
                    color = colors.primaryText,
                    lineHeight = type.body.fontSize * 1.2f,
                )
            }
            p.eng?.let { eng ->
                Text(
                    text = eng.strippingEm,
                    style = type.bodySm.copy(fontStyle = FontStyle.Italic),
                    color = colors.secondaryText,
                    lineHeight = type.bodySm.fontSize * 1.15f,
                )
            }
        }
    }
}

// -- Shared helpers --

@Composable
private fun DecoratedLabel(text: String) {
    val colors = IntroiboTheme.colors
    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier.fillMaxWidth(),
    ) {
        GoldLine(modifier = Modifier.weight(1f))
        SmallLabel(
            text = text,
            color = colors.sanctuaryRed,
            modifier = Modifier.padding(horizontal = 10.dp),
        )
        GoldLine(modifier = Modifier.weight(1f))
    }
}

@Composable
private fun GoldLine(modifier: Modifier = Modifier) {
    val colors = IntroiboTheme.colors
    Box(
        modifier = modifier
            .height(0.5.dp)
            .background(colors.goldLeaf.copy(alpha = 0.4f)),
    )
}
