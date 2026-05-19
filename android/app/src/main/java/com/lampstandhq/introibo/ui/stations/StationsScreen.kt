package com.lampstandhq.introibo.ui.stations

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
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
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.outlined.Notifications
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Scaffold
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.lampstandhq.introibo.data.content.ContentStore
import com.lampstandhq.introibo.data.model.Station
import com.lampstandhq.introibo.data.model.strippingEm
import com.lampstandhq.introibo.storage.settings.LanguageMode
import com.lampstandhq.introibo.ui.components.SmallLabel
import com.lampstandhq.introibo.ui.components.currentLanguageMode
import com.lampstandhq.introibo.ui.theme.IntroiboTheme
import com.lampstandhq.introibo.ui.theme.IntroiboType

/**
 * Stations of the Cross -- 14 stations with meditations.
 *
 * Port of iOS Introibo/Screens/Stations/StationsView.swift.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun StationsScreen(
    onBack: () -> Unit,
) {
    val colors = IntroiboTheme.colors
    val type = IntroiboType.current

    var activeIndex by remember { mutableStateOf<Int?>(null) }
    var showNotification by rememberSaveable { mutableStateOf(false) }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("Via Crucis", style = type.titleM, color = colors.primaryText) },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(Icons.AutoMirrored.Filled.ArrowBack, "Back", tint = colors.sanctuaryRed)
                    }
                },
                actions = {
                    IconButton(onClick = { showNotification = true }) {
                        Icon(Icons.Outlined.Notifications, "Notification", tint = colors.sanctuaryRed)
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(containerColor = colors.pageBackground),
            )
        },
        containerColor = colors.pageBackground,
    ) { padding ->
        val idx = activeIndex
        if (idx != null) {
            PrayStationView(
                stations = ContentStore.stations,
                index = idx,
                onBack = { activeIndex = maxOf(idx - 1, 0) },
                onNext = { activeIndex = if (idx + 1 < ContentStore.stations.size) idx + 1 else null },
                onClose = { activeIndex = null },
                modifier = Modifier.padding(padding),
            )
        } else {
            StartList(
                stations = ContentStore.stations,
                onBegin = { activeIndex = 0 },
                onStation = { activeIndex = it },
                modifier = Modifier.padding(padding),
            )
        }
    }

    if (showNotification) {
        ModalBottomSheet(
            onDismissRequest = { showNotification = false },
            sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true),
            containerColor = colors.pageBackground,
        ) {
            com.lampstandhq.introibo.ui.prayers.NotificationScheduleSheet(
                scheduleId = "devotion.stations",
                title = "Via Crucis",
                subtitle = "Remind me to pray the Stations",
                onDismiss = { showNotification = false },
            )
        }
    }
}

@Composable
private fun StartList(
    stations: List<Station>,
    onBegin: () -> Unit,
    onStation: (Int) -> Unit,
    modifier: Modifier = Modifier,
) {
    val colors = IntroiboTheme.colors
    val type = IntroiboType.current

    Column(
        modifier = modifier
            .fillMaxSize()
            .verticalScroll(rememberScrollState()),
    ) {
        // Dark header
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .background(
                    Brush.verticalGradient(listOf(colors.walnut, colors.walnutHi))
                )
                .padding(bottom = 18.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Spacer(modifier = Modifier.height(24.dp))
            Text(text = "✠", style = type.titleL.copy(fontSize = 36.sp), color = colors.sanctuaryRed.copy(alpha = 0.6f))
            Spacer(modifier = Modifier.height(10.dp))
            Text(text = "Via Crucis", style = type.pageTitle, color = colors.ivory)
            Text(
                text = "THE WAY OF THE CROSS",
                style = type.captionSm.copy(fontStyle = FontStyle.Italic),
                color = colors.muted,
                letterSpacing = 2.5.sp,
            )
            Text(
                text = "XIV Statiónes",
                style = type.captionSm.copy(fontStyle = FontStyle.Italic),
                color = colors.muted,
                modifier = Modifier.padding(top = 2.dp),
            )
            Spacer(modifier = Modifier.height(14.dp))
            Box(
                modifier = Modifier
                    .width(60.dp)
                    .height(1.dp)
                    .background(colors.sanctuaryRed.copy(alpha = 0.4f)),
            )
        }

        // Begin button
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 28.dp, vertical = 20.dp)
                .border(0.5.dp, colors.sanctuaryRed.copy(alpha = 0.5f))
                .clickable { onBegin() }
                .padding(vertical = 14.dp),
            horizontalArrangement = Arrangement.Center,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(text = "✠", style = type.titleM, color = colors.sanctuaryRed)
            Spacer(modifier = Modifier.width(10.dp))
            Text(
                text = "Incipiámus",
                style = type.titleM.copy(fontStyle = FontStyle.Italic),
                color = colors.sanctuaryRed,
            )
            Text(
                text = "  ·  BEGIN",
                style = type.captionSm.copy(fontStyle = FontStyle.Italic),
                color = colors.secondaryText,
                letterSpacing = 2.sp,
            )
        }

        // Station list
        Column(
            modifier = Modifier
                .padding(horizontal = 20.dp)
                .padding(bottom = 40.dp),
        ) {
            stations.forEachIndexed { idx, s ->
                val isLeft = idx % 2 == 0
                val moodColor = stationColor(s, colors)

                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(bottom = 4.dp)
                        .clip(RoundedCornerShape(8.dp))
                        .background(moodColor.copy(alpha = 0.06f))
                        .border(0.5.dp, moodColor.copy(alpha = 0.2f), RoundedCornerShape(8.dp))
                        .clickable { onStation(idx) }
                        .padding(horizontal = 16.dp, vertical = 8.dp),
                    verticalAlignment = Alignment.CenterVertically,
                    horizontalArrangement = if (isLeft) Arrangement.Start else Arrangement.End,
                ) {
                    if (isLeft) {
                        StationMarker(station = s, color = moodColor)
                        Spacer(modifier = Modifier.width(14.dp))
                        StationInfo(station = s, alignment = Alignment.Start)
                    } else {
                        StationInfo(station = s, alignment = Alignment.End)
                        Spacer(modifier = Modifier.width(14.dp))
                        StationMarker(station = s, color = moodColor)
                    }
                }
            }
        }
    }
}

@Composable
private fun StationMarker(station: Station, color: Color) {
    val type = IntroiboType.current
    Box(
        modifier = Modifier
            .size(48.dp)
            .clip(CircleShape)
            .background(color.copy(alpha = 0.12f))
            .border(1.5.dp, color.copy(alpha = 0.6f), CircleShape),
        contentAlignment = Alignment.Center,
    ) {
        Text(
            text = station.station,
            style = type.titleM.copy(fontStyle = FontStyle.Italic),
            color = color,
        )
    }
}

@Composable
private fun StationInfo(station: Station, alignment: Alignment.Horizontal) {
    val colors = IntroiboTheme.colors
    val type = IntroiboType.current
    val textAlign = if (alignment == Alignment.Start) TextAlign.Start else TextAlign.End

    Column(horizontalAlignment = alignment) {
        Text(
            text = station.title,
            style = type.titleM.copy(fontStyle = FontStyle.Italic),
            color = colors.primaryText,
            textAlign = textAlign,
        )
        if (currentLanguageMode() != LanguageMode.VERNACULAR) {
            Text(
                text = station.latin,
                style = type.captionSm.copy(fontStyle = FontStyle.Italic),
                color = colors.secondaryText,
                textAlign = textAlign,
            )
        }
    }
}

// -- Praying a single station --

@Composable
private fun PrayStationView(
    stations: List<Station>,
    index: Int,
    onBack: () -> Unit,
    onNext: () -> Unit,
    onClose: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val colors = IntroiboTheme.colors
    val type = IntroiboType.current
    val station = stations[index]
    val numColor = numeralColor(station, colors)

    Column(
        modifier = modifier
            .fillMaxSize()
            .background(
                Brush.verticalGradient(listOf(colors.walnut, colors.walnutHi))
            ),
    ) {
        // Close button
        Row(modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 8.dp)) {
            TextButton(onClick = onClose) {
                Text("‹ Via", color = colors.goldLeaf, style = type.body)
            }
        }

        Column(
            modifier = Modifier
                .weight(1f)
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 28.dp)
                .padding(bottom = 120.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(18.dp),
        ) {
            SmallLabel(
                text = "Státio ${station.station}  ·  ${index + 1} of 14",
                color = colors.goldLeaf,
            )

            Text(
                text = station.station,
                style = type.pageTitle.copy(
                    fontSize = 96.sp,
                    fontWeight = FontWeight.SemiBold,
                    fontStyle = FontStyle.Italic,
                ),
                color = numColor,
            )

            Text(
                text = station.title,
                style = type.titleL.copy(fontStyle = FontStyle.Italic),
                color = colors.ivory,
                textAlign = TextAlign.Center,
            )

            if (currentLanguageMode() != LanguageMode.VERNACULAR) {
                Text(
                    text = station.latin.uppercase(),
                    style = type.captionSm.copy(fontStyle = FontStyle.Italic),
                    color = colors.muted,
                    letterSpacing = 2.5.sp,
                    textAlign = TextAlign.Center,
                )
            }

            HorizontalDivider(color = colors.goldLeaf.copy(alpha = 0.3f))

            // Versicle
            Column(
                modifier = Modifier.fillMaxWidth(),
                verticalArrangement = Arrangement.spacedBy(8.dp),
                horizontalAlignment = Alignment.Start,
            ) {
                Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
                    Text(
                        text = "℣. Adorámus te, Christe, et benedícimus tibi.",
                        style = type.bodyIt,
                        color = colors.ivory,
                    )
                    Text(
                        text = "We adore Thee, O Christ, and we bless Thee.",
                        style = type.captionSm.copy(fontStyle = FontStyle.Italic),
                        color = colors.muted,
                    )
                }
                Column(verticalArrangement = Arrangement.spacedBy(2.dp)) {
                    Text(
                        text = "℟. Quia per sanctam Crucem tuam redemísti mundum.",
                        style = type.bodyIt,
                        color = colors.ivory,
                    )
                    Text(
                        text = "Because by Thy holy Cross Thou hast redeemed the world.",
                        style = type.captionSm.copy(fontStyle = FontStyle.Italic),
                        color = colors.muted,
                    )
                }
                Text(
                    text = "Pater Noster  ·  Ave María  ·  Glória Patri",
                    style = type.captionSm.copy(fontStyle = FontStyle.Italic),
                    color = colors.goldLeaf,
                    modifier = Modifier.padding(top = 4.dp),
                )
            }

            // Meditation
            Text(
                text = station.med,
                style = type.body,
                color = colors.ivory,
                lineHeight = type.body.fontSize * 1.25f,
                modifier = Modifier.padding(top = 10.dp),
            )

            HorizontalDivider(color = colors.goldLeaf.copy(alpha = 0.3f))

            // Stabat Mater
            Column(
                horizontalAlignment = Alignment.CenterHorizontally,
                verticalArrangement = Arrangement.spacedBy(8.dp),
            ) {
                SmallLabel(text = "Orátio  ·  Stabat Mater", color = colors.goldLeaf)
                Text(
                    text = htmlToMultiline(station.stabatLat),
                    style = type.bodyIt,
                    color = colors.ivory,
                    textAlign = TextAlign.Center,
                )
                Text(
                    text = htmlToMultiline(station.stabatEng),
                    style = type.captionSm.copy(fontStyle = FontStyle.Italic),
                    color = colors.muted,
                    textAlign = TextAlign.Center,
                    modifier = Modifier.padding(top = 2.dp),
                )
            }
        }

        // Nav bar
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .background(
                    Brush.verticalGradient(
                        listOf(colors.walnut.copy(alpha = 0f), colors.walnut)
                    )
                )
                .padding(horizontal = 28.dp)
                .padding(top = 24.dp, bottom = 36.dp),
            horizontalArrangement = Arrangement.spacedBy(18.dp),
        ) {
            TextButton(
                onClick = onBack,
                enabled = index > 0,
                modifier = Modifier
                    .size(52.dp)
                    .border(1.dp, colors.goldLeaf.copy(alpha = 0.55f)),
            ) {
                Text(
                    text = "‹",
                    style = type.titleL,
                    color = colors.goldLeaf.copy(alpha = if (index == 0) 0.4f else 1f),
                )
            }

            TextButton(
                onClick = onNext,
                modifier = Modifier
                    .weight(1f)
                    .background(colors.goldLeaf.copy(alpha = 0.12f))
                    .border(1.dp, colors.goldLeaf)
                    .padding(vertical = 4.dp),
            ) {
                SmallLabel(
                    text = if (index + 1 < 14) "Sequens  ✠  Next Station" else "Finis  ✠  Finish",
                    color = colors.ivory,
                )
            }
        }
    }
}

private fun stationColor(s: Station, colors: com.lampstandhq.introibo.ui.theme.IntroiboColorScheme): Color =
    when (s.mood) {
        "mood-death" -> colors.sanctuaryRed
        "mood-mother" -> colors.goldLeaf
        "mood-tomb" -> Color.Gray
        else -> colors.sanctuaryRed.copy(alpha = 0.7f)
    }

private fun numeralColor(s: Station, colors: com.lampstandhq.introibo.ui.theme.IntroiboColorScheme): Color =
    when (s.mood) {
        "mood-death" -> colors.sanctuaryRed
        "mood-mother" -> colors.goldLeaf
        "mood-tomb" -> Color.Gray
        else -> colors.sanctuaryRed.copy(alpha = 0.5f)
    }

private fun htmlToMultiline(s: String): String =
    s.replace("<br>", "\n")
        .replace("<br/>", "\n")
        .replace("<br />", "\n")
        .strippingEm
