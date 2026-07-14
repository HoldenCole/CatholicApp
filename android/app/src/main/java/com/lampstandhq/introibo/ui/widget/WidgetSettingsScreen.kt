package com.lampstandhq.introibo.ui.widget

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.RadioButtonChecked
import androidx.compose.material.icons.filled.RadioButtonUnchecked
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.lampstandhq.introibo.data.content.ContentStore
import com.lampstandhq.introibo.data.widget.WidgetConfig
import com.lampstandhq.introibo.data.widget.WidgetMode
import com.lampstandhq.introibo.data.widget.WidgetSlot
import com.lampstandhq.introibo.ui.theme.IntroiboTheme
import com.lampstandhq.introibo.ui.theme.IntroiboType
import com.lampstandhq.introibo.widget.IntroiboWidgetProvider

// MARK: - WidgetSettingsScreen
//
// The home-screen widget's small configuration surface: mode, and (for the
// chosen-prayer mode) one prayer per time slot. Deliberately minimal — more
// slots / per-day rules / multiple prayers belong to the future Rule-
// integration mode, not here. No tracking options exist or may be added
// (wellbeing CUT LINE).
//
// iOS mirror: WidgetSettingsView in SettingsView.swift.

@Composable
fun WidgetSettingsScreen(onBack: () -> Unit = {}) {
    val context = LocalContext.current
    val colors = IntroiboTheme.colors
    val type = IntroiboType.current

    var mode by remember { mutableStateOf(WidgetConfig.mode(context)) }
    var pickingSlot by remember { mutableStateOf<WidgetSlot?>(null) }
    // Bump to re-read slot assignments after a pick.
    var revision by remember { mutableStateOf(0) }

    fun refreshWidget() = IntroiboWidgetProvider.refreshAll(context)

    // Back (system or header arrow) from the prayer picker returns to the
    // slot list, not out of widget settings entirely.
    androidx.activity.compose.BackHandler(enabled = pickingSlot != null) {
        pickingSlot = null
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(colors.pageBackground),
    ) {
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 8.dp, vertical = 12.dp),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            IconButton(onClick = {
                if (pickingSlot != null) pickingSlot = null else onBack()
            }) {
                Icon(
                    imageVector = Icons.AutoMirrored.Filled.ArrowBack,
                    contentDescription = "Back",
                    tint = colors.sanctuaryRed,
                )
            }
            Text(
                text = "Home Screen Widget",
                style = type.titleM.copy(fontStyle = FontStyle.Italic),
                color = colors.primaryText,
                textAlign = TextAlign.Center,
                modifier = Modifier.weight(1f),
            )
            Spacer(modifier = Modifier.size(48.dp))
        }

        val slotPicking = pickingSlot
        if (slotPicking != null) {
            // Prayer picker for one slot.
            val current = WidgetConfig.slotPrayer(context, slotPicking)
            LazyColumn(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(horizontal = 16.dp),
            ) {
                item {
                    Text(
                        text = "${slotPicking.label} prayer",
                        style = type.bodySm,
                        color = colors.secondaryText,
                        modifier = Modifier.padding(vertical = 12.dp),
                    )
                }
                val grouped = ContentStore.prayers.groupBy { it.category }
                grouped.forEach { (category, prayers) ->
                    item(key = "hdr-$category") {
                        Text(
                            text = category,
                            style = type.smallLabel,
                            color = colors.tertiaryText,
                            modifier = Modifier.padding(top = 16.dp, bottom = 6.dp),
                        )
                    }
                    items(prayers.size, key = { "p-${prayers[it].slug}" }) { i ->
                        val prayer = prayers[i]
                        Row(
                            modifier = Modifier
                                .fillMaxWidth()
                                .clickable {
                                    WidgetConfig.setSlotPrayer(context, slotPicking, prayer.slug)
                                    revision++
                                    pickingSlot = null
                                    refreshWidget()
                                }
                                .padding(vertical = 10.dp),
                            verticalAlignment = Alignment.CenterVertically,
                        ) {
                            Column(modifier = Modifier.weight(1f)) {
                                Text(prayer.title, style = type.body, color = colors.primaryText)
                                Text(prayer.eng, style = type.smallLabel, color = colors.tertiaryText)
                            }
                            if (prayer.slug == current) {
                                Icon(
                                    imageVector = Icons.Filled.Check,
                                    contentDescription = "Selected",
                                    tint = colors.sanctuaryRed,
                                )
                            }
                        }
                    }
                }
            }
            return@Column
        }

        LazyColumn(
            modifier = Modifier
                .fillMaxSize()
                .padding(horizontal = 16.dp),
        ) {
            item {
                Text(
                    text = "The widget offers the right prayer for this part of the day. It is an invitation, never a scorekeeper.",
                    style = type.bodySm.copy(fontStyle = FontStyle.Italic),
                    color = colors.secondaryText,
                    modifier = Modifier.padding(vertical = 12.dp),
                )
            }

            item {
                Text(
                    text = "MODUS · MODE",
                    style = type.smallLabel,
                    color = colors.tertiaryText,
                    modifier = Modifier.padding(top = 12.dp, bottom = 6.dp),
                )
            }
            item {
                ModeRow(
                    title = "Divine Office",
                    subtitle = "The canonical hour for the current time",
                    selected = mode == WidgetMode.OFFICE,
                ) {
                    mode = WidgetMode.OFFICE
                    WidgetConfig.setMode(context, WidgetMode.OFFICE)
                    refreshWidget()
                }
            }
            item {
                ModeRow(
                    title = "Chosen prayers",
                    subtitle = "Your own prayer for morning, midday, and evening",
                    selected = mode == WidgetMode.PRAYER,
                ) {
                    mode = WidgetMode.PRAYER
                    WidgetConfig.setMode(context, WidgetMode.PRAYER)
                    refreshWidget()
                }
            }

            if (mode == WidgetMode.PRAYER) {
                item {
                    Text(
                        text = "ORATIONES · SLOT PRAYERS",
                        style = type.smallLabel,
                        color = colors.tertiaryText,
                        modifier = Modifier.padding(top = 20.dp, bottom = 6.dp),
                    )
                }
                items(WidgetSlot.entries.size, key = { "slot-$it-$revision" }) { i ->
                    val slot = WidgetSlot.entries[i]
                    val slug = WidgetConfig.slotPrayer(context, slot)
                    val prayer = ContentStore.prayers.firstOrNull { it.slug == slug }
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .clickable { pickingSlot = slot }
                            .padding(vertical = 10.dp),
                        verticalAlignment = Alignment.CenterVertically,
                    ) {
                        Column(modifier = Modifier.weight(1f)) {
                            Text(slot.label, style = type.smallLabel, color = colors.tertiaryText)
                            Text(
                                prayer?.title ?: slug,
                                style = type.body,
                                color = colors.primaryText,
                            )
                        }
                        Text("Change", style = type.smallLabel, color = colors.sanctuaryRed)
                    }
                }
            }
        }
    }
}

@Composable
private fun ModeRow(
    title: String,
    subtitle: String,
    selected: Boolean,
    onSelect: () -> Unit,
) {
    val colors = IntroiboTheme.colors
    val type = IntroiboType.current
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onSelect)
            .padding(vertical = 10.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Icon(
            imageVector = if (selected) {
                Icons.Filled.RadioButtonChecked
            } else {
                Icons.Filled.RadioButtonUnchecked
            },
            contentDescription = null,
            tint = if (selected) colors.sanctuaryRed else colors.tertiaryText,
        )
        Column(modifier = Modifier.padding(start = 12.dp)) {
            Text(title, style = type.body, color = colors.primaryText)
            Text(subtitle, style = type.smallLabel, color = colors.tertiaryText)
        }
    }
}
