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
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.itemsIndexed
import androidx.compose.foundation.lazy.rememberLazyListState
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Text
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.lampstandhq.introibo.data.model.Hour
import com.lampstandhq.introibo.data.model.strippingEm
import com.lampstandhq.introibo.data.content.ContentStore
import com.lampstandhq.introibo.data.search.ContentType
import com.lampstandhq.introibo.data.search.DeepLinkTarget
import com.lampstandhq.introibo.ui.components.BilingualLine
import com.lampstandhq.introibo.ui.components.ReferencedBySection
import com.lampstandhq.introibo.ui.components.RelatedLinksSection
import com.lampstandhq.introibo.ui.components.SmallLabel
import com.lampstandhq.introibo.ui.theme.IntroiboTheme
import com.lampstandhq.introibo.ui.theme.IntroiboType

/**
 * Full liturgy for a single canonical hour, shown as a full-screen
 * bottom sheet. Renders all part types from the Divine Office import:
 * vr, hymn, psalm, antiphon, capitulum, canticle, pater, collect,
 * closing, confiteor, responsory, responsory_breve, marian, heading,
 * reading, lectio, preces, invitatory, suppressed.
 *
 * Port of iOS Introibo/Screens/Office/HourView.swift.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun HourSheet(
    hour: Hour,
    onDismiss: () -> Unit,
    /**
     * Deep-link scroll anchor: index into [Hour.parts] (= the "part:<index>"
     * position from the office search extractor), or null for no scroll.
     */
    scrollToPartIndex: Int? = null,
    onLinkTap: (DeepLinkTarget) -> Unit = {},
) {
    val colors = IntroiboTheme.colors
    val type = IntroiboType.current
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    val scope = rememberCoroutineScope()
    val listState = rememberLazyListState()

    // Back button + header occupy LazyColumn indices 0 and 1; parts begin at 2,
    // so part i sits at list index i + HEADER_ITEM_COUNT.
    LaunchedEffect(scrollToPartIndex, hour.slug) {
        val partIndex = scrollToPartIndex ?: return@LaunchedEffect
        if (partIndex in hour.parts.indices) {
            listState.animateScrollToItem(partIndex + HOUR_HEADER_ITEM_COUNT)
        }
    }

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = sheetState,
        containerColor = colors.pageBackground,
        dragHandle = null,
    ) {
        LazyColumn(
            state = listState,
            modifier = Modifier
                .fillMaxSize()
                .padding(bottom = 80.dp),
        ) {
            // Back button (list index 0)
            item(key = "back") {
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
            }

            // Header + intro (list index 1)
            item(key = "header") {
                Column {
                    HourHeader(hour = hour)
                    Column(
                        modifier = Modifier
                            .padding(horizontal = 20.dp)
                            .padding(top = 24.dp, bottom = 22.dp),
                    ) {
                        IntroBlock(text = hour.intro)
                    }
                }
            }

            // Parts (list index 2 onward; key "part:<i>" mirrors the extractor)
            itemsIndexed(hour.parts, key = { i, _ -> "part:$i" }) { _, part ->
                Column(
                    modifier = Modifier
                        .padding(horizontal = 20.dp)
                        .padding(bottom = 22.dp),
                ) {
                    PartView(part, onLinkTap)
                }
            }

            if (!hour.related.isNullOrEmpty()) {
                item(key = "related") {
                    RelatedLinksSection(
                        related = hour.related,
                        onLinkTap = onLinkTap,
                        modifier = Modifier
                            .padding(horizontal = 20.dp)
                            .padding(bottom = 22.dp),
                    )
                }
            }
            item(key = "referencedBy") {
                ReferencedBySection(
                    sources = ContentStore.linkGraph.referencedBy(
                        DeepLinkTarget(ContentType.OFFICE, hour.slug, null)
                    ),
                    onLinkTap = onLinkTap,
                    modifier = Modifier
                        .padding(horizontal = 20.dp)
                        .padding(bottom = 22.dp),
                )
            }
        }
    }
}

/** Number of fixed LazyColumn items (back button, header+intro) before parts. */
private const val HOUR_HEADER_ITEM_COUNT = 2

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
private fun PartView(p: Hour.Part, onLinkTap: (DeepLinkTarget) -> Unit = {}) {
    when (p.type) {
        "vr" -> VrBlock(p, onLinkTap)
        "hymn" -> HymnBlock(p, onLinkTap)
        "antiphon" -> SimpleBlock(p, labelFallback = "Antíphona", onLinkTap = onLinkTap)
        "psalm" -> PsalmBlock(p, onLinkTap)
        "capitulum" -> CapitulumBlock(p, onLinkTap)
        "canticle" -> PsalmBlock(p, onLinkTap)
        "pater" -> PaterInlineBlock(p, onLinkTap)
        "collect" -> SimpleBlock(p, labelFallback = "Collécta", onLinkTap = onLinkTap)
        "closing" -> SimpleBlock(p, labelFallback = "Conclúsio", onLinkTap = onLinkTap)
        "confiteor" -> ConfiteorBlock(p, onLinkTap)
        "responsory" -> ResponsoryBlock(p, onLinkTap)
        "marian" -> MarianBlock(p, onLinkTap)
        "heading" -> HeadingBlock(p)
        "reading" -> ReadingBlock(p, onLinkTap)
        "lectio" -> ReadingBlock(p, onLinkTap)
        "preces" -> PrecesBlock(p, onLinkTap)
        "invitatory" -> InvitatoryBlock(p, onLinkTap)
        "responsory_breve" -> ResponsoryBreveBlock(p, onLinkTap)
        "suppressed" -> { /* Intentionally empty — suppressed parts are not rendered. */ }
    }
}

@Composable
private fun VrBlock(p: Hour.Part, onLinkTap: (DeepLinkTarget) -> Unit = {}) {
    val colors = IntroiboTheme.colors

    Column(
        modifier = Modifier.fillMaxWidth(),
        verticalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        SmallLabel(text = p.label ?: "Versus", color = colors.sanctuaryRed)

        if (p.lat != null && p.eng != null) {
            BilingualLine(lat = p.lat, eng = p.eng, sideBySide = true, onLinkTap = onLinkTap)
        }
        if (p.latR != null && p.engR != null) {
            Spacer(modifier = Modifier.height(4.dp))
            BilingualLine(lat = p.latR, eng = p.engR, sideBySide = true, onLinkTap = onLinkTap)
        }
    }
}

@Composable
private fun HymnBlock(p: Hour.Part, onLinkTap: (DeepLinkTarget) -> Unit = {}) {
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
                        onLinkTap = onLinkTap,
                    )
                }
            }
        }
    }
}

@Composable
private fun SimpleBlock(p: Hour.Part, labelFallback: String, onLinkTap: (DeepLinkTarget) -> Unit = {}) {
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
            BilingualLine(lat = p.lat, eng = p.eng, sideBySide = true, onLinkTap = onLinkTap)
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
private fun PsalmBlock(p: Hour.Part, onLinkTap: (DeepLinkTarget) -> Unit = {}) {
    val colors = IntroiboTheme.colors
    val type = IntroiboType.current

    Column(
        modifier = Modifier.fillMaxWidth(),
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        if (!p.antiphonLat.isNullOrEmpty()) {
            SmallLabel(text = "Ant.", color = colors.sanctuaryRed)
            BilingualLine(lat = p.antiphonLat, eng = p.antiphonEng ?: "", sideBySide = true, onLinkTap = onLinkTap)
            Spacer(modifier = Modifier.height(4.dp))
        }

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
                    BilingualLine(lat = v.lat, eng = v.eng, sideBySide = true, onLinkTap = onLinkTap)
                }
            }
        }
    }
}

@Composable
private fun PaterInlineBlock(p: Hour.Part, onLinkTap: (DeepLinkTarget) -> Unit = {}) {
    val colors = IntroiboTheme.colors
    val type = IntroiboType.current

    Column {
        SmallLabel(text = p.label ?: "Pater Noster", color = colors.sanctuaryRed)
        Spacer(modifier = Modifier.height(6.dp))
        val lat = p.lat ?: ""
        val eng = p.eng ?: ""
        if (lat.isNotEmpty() && eng.isNotEmpty()) {
            val latParts = lat.split("\n\n")
            val engParts = eng.split("\n\n")
            val count = maxOf(latParts.size, engParts.size)
            Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                for (i in 0 until count) {
                    BilingualLine(
                        lat = latParts.getOrElse(i) { "" },
                        eng = engParts.getOrElse(i) { "" },
                        sideBySide = true,
                        onLinkTap = onLinkTap,
                    )
                }
            }
        }
    }
}

@Composable
private fun ConfiteorBlock(p: Hour.Part, onLinkTap: (DeepLinkTarget) -> Unit = {}) {
    val colors = IntroiboTheme.colors

    Column {
        SmallLabel(text = p.label ?: "Confíteor", color = colors.sanctuaryRed)
        Spacer(modifier = Modifier.height(6.dp))
        val lat = p.lat ?: ""
        val eng = p.eng ?: ""
        if (lat.isNotEmpty() && eng.isNotEmpty()) {
            val latParts = lat.split("\n\n")
            val engParts = eng.split("\n\n")
            val count = maxOf(latParts.size, engParts.size)
            Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                for (i in 0 until count) {
                    BilingualLine(
                        lat = latParts.getOrElse(i) { "" },
                        eng = engParts.getOrElse(i) { "" },
                        sideBySide = true,
                        onLinkTap = onLinkTap,
                    )
                }
            }
        }
    }
}

@Composable
private fun ResponsoryBlock(p: Hour.Part, onLinkTap: (DeepLinkTarget) -> Unit = {}) {
    val colors = IntroiboTheme.colors
    val type = IntroiboType.current

    Column(
        modifier = Modifier.fillMaxWidth(),
        verticalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        SmallLabel(text = p.label ?: "Responsórium", color = colors.sanctuaryRed)

        p.ref?.let { ref ->
            Text(text = ref, style = type.captionSm, color = colors.goldLeaf)
        }

        // Full Matins responsory (v1/r1/v2/r2 structured fields)
        if (p.v1Lat != null) {
            if (p.v1Lat != null && p.v1Eng != null) {
                ResponsoryLine(lat = p.v1Lat, eng = p.v1Eng, indent = false, onLinkTap = onLinkTap)
            }
            if (p.r1Lat != null && p.r1Eng != null) {
                Spacer(modifier = Modifier.height(4.dp))
                ResponsoryLine(lat = p.r1Lat, eng = p.r1Eng, indent = true, onLinkTap = onLinkTap)
            }
            if (p.v2Lat != null && p.v2Eng != null) {
                Spacer(modifier = Modifier.height(6.dp))
                ResponsoryLine(lat = p.v2Lat, eng = p.v2Eng, indent = true, onLinkTap = onLinkTap)
            }
            if (p.r2Lat != null && p.r2Eng != null) {
                Spacer(modifier = Modifier.height(4.dp))
                ResponsoryLine(lat = p.r2Lat, eng = p.r2Eng, indent = false, onLinkTap = onLinkTap)
            }
        }
        // Short / Breve responsory (lat/eng inline with ℟./℣. lines)
        else if (p.lat != null && p.eng != null) {
            val latLines = p.lat.split("\n").filter { it.isNotBlank() }
            val engLines = p.eng.split("\n").filter { it.isNotBlank() }
            val count = maxOf(latLines.size, engLines.size)

            Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                for (i in 0 until count) {
                    val latLine = latLines.getOrElse(i) { "" }
                    val engLine = engLines.getOrElse(i) { "" }
                    val isVersicle = latLine.startsWith("℣") || latLine.startsWith("V.")
                    ResponsoryLine(lat = latLine, eng = engLine, indent = isVersicle, onLinkTap = onLinkTap)
                }
            }
        }
    }
}

/**
 * Short responsory (responsory_breve) at small hours. Compact R/V format
 * with indented versicles. Mirrors iOS responsoryBreveBlock.
 */
@Composable
private fun ResponsoryBreveBlock(p: Hour.Part, onLinkTap: (DeepLinkTarget) -> Unit = {}) {
    val colors = IntroiboTheme.colors

    Column(
        modifier = Modifier.fillMaxWidth(),
        verticalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        SmallLabel(text = p.label ?: "Resp. Breve", color = colors.sanctuaryRed)

        if (p.lat != null && p.eng != null) {
            val latLines = p.lat.split("\n").filter { it.isNotBlank() }
            val engLines = p.eng.split("\n").filter { it.isNotBlank() }
            val count = maxOf(latLines.size, engLines.size)

            Column(verticalArrangement = Arrangement.spacedBy(6.dp)) {
                for (i in 0 until count) {
                    val latLine = latLines.getOrElse(i) { "" }
                    val engLine = engLines.getOrElse(i) { "" }
                    val isVersicle = latLine.startsWith("℣") || latLine.startsWith("V.")
                    ResponsoryLine(lat = latLine, eng = engLine, indent = isVersicle, onLinkTap = onLinkTap)
                }
            }
        }
    }
}

/** Single responsory line, optionally indented for versicles. */
@Composable
private fun ResponsoryLine(lat: String, eng: String, indent: Boolean, onLinkTap: (DeepLinkTarget) -> Unit = {}) {
    Box(modifier = if (indent) Modifier.padding(start = 16.dp) else Modifier) {
        BilingualLine(lat = lat, eng = eng, sideBySide = true, onLinkTap = onLinkTap)
    }
}

@Composable
private fun MarianBlock(p: Hour.Part, onLinkTap: (DeepLinkTarget) -> Unit = {}) {
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
            BilingualLine(lat = lat, eng = eng, sideBySide = true, onLinkTap = onLinkTap)
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
private fun ReadingBlock(p: Hour.Part, onLinkTap: (DeepLinkTarget) -> Unit = {}) {
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
            BilingualLine(lat = p.lat, eng = p.eng, sideBySide = true, onLinkTap = onLinkTap)
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

/**
 * Dedicated capitulum (short chapter) rendering with scripture reference
 * displayed in italic below the label. Mirrors iOS capitulumBlock.
 */
@Composable
private fun CapitulumBlock(p: Hour.Part, onLinkTap: (DeepLinkTarget) -> Unit = {}) {
    val colors = IntroiboTheme.colors
    val type = IntroiboType.current

    Column(
        modifier = Modifier.fillMaxWidth(),
        verticalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        SmallLabel(text = p.label ?: "Capítulum", color = colors.sanctuaryRed)

        p.ref?.let { ref ->
            Text(
                text = ref,
                style = type.captionSm.copy(fontStyle = FontStyle.Italic),
                color = colors.goldLeaf,
            )
        }

        if (p.lat != null && p.eng != null) {
            BilingualLine(lat = p.lat, eng = p.eng, sideBySide = true, onLinkTap = onLinkTap)
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

/**
 * Invitatory rendering: antiphon + Psalm 94 with the invitatory antiphon
 * woven between psalm sections. Falls back to simple bilingual text if the
 * part lacks verses. Mirrors iOS invitatoryBlock.
 */
@Composable
private fun InvitatoryBlock(p: Hour.Part, onLinkTap: (DeepLinkTarget) -> Unit = {}) {
    val colors = IntroiboTheme.colors

    Column(
        modifier = Modifier.fillMaxWidth(),
        verticalArrangement = Arrangement.spacedBy(8.dp),
    ) {
        SmallLabel(text = p.label ?: "Invitatorium", color = colors.sanctuaryRed)

        if (p.lat != null && p.eng != null) {
            Box(modifier = Modifier.padding(start = 10.dp)) {
                BilingualLine(lat = p.lat, eng = p.eng, sideBySide = true, onLinkTap = onLinkTap)
            }
        }

        p.verses?.let { verses ->
            Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
                verses.forEach { v ->
                    BilingualLine(lat = v.lat, eng = v.eng, sideBySide = true, onLinkTap = onLinkTap)
                }
            }
        }
    }
}

/**
 * Preces Feriales block — rendered for the Kyrie, Pater Noster,
 * versicle sets, psalm, and concluding versicles that the
 * [com.lampstandhq.introibo.data.content.OfficeAssembler] inserts
 * into Lauds and Vespers during Advent, Lent, and Passiontide.
 *
 * Handles both text-mode (lat/eng) and verse-mode (verses list).
 */
@Composable
private fun PrecesBlock(p: Hour.Part, onLinkTap: (DeepLinkTarget) -> Unit = {}) {
    val colors = IntroiboTheme.colors

    Column(
        modifier = Modifier.fillMaxWidth(),
        verticalArrangement = Arrangement.spacedBy(6.dp),
    ) {
        SmallLabel(text = p.label ?: "Preces", color = colors.sanctuaryRed)

        // Verse-mode (intercession versicles and concluding versicles)
        p.verses?.let { verses ->
            Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
                verses.forEach { v ->
                    BilingualLine(lat = v.lat, eng = v.eng, sideBySide = true, onLinkTap = onLinkTap)
                }
            }
        }

        // Text-mode (Kyrie, Pater Noster, psalm text)
        if (p.lat != null && p.eng != null && p.verses == null) {
            val latLines = p.lat.split("\n").filter { it.isNotBlank() }
            val engLines = p.eng.split("\n").filter { it.isNotBlank() }
            val count = maxOf(latLines.size, engLines.size)
            Column(verticalArrangement = Arrangement.spacedBy(4.dp)) {
                for (i in 0 until count) {
                    val latLine = latLines.getOrElse(i) { "" }
                    val engLine = engLines.getOrElse(i) { "" }
                    if (latLine.isNotEmpty() || engLine.isNotEmpty()) {
                        BilingualLine(
                            lat = latLine,
                            eng = engLine,
                            sideBySide = true,
                            onLinkTap = onLinkTap,
                        )
                    }
                }
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
