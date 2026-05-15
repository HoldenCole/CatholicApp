package com.lampstandhq.introibo.ui.prayers

import android.content.Intent
import android.provider.Settings
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.layout.defaultMinSize
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Switch
import androidx.compose.material3.SwitchDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableIntStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.lampstandhq.introibo.storage.notification.NotificationSchedule
import com.lampstandhq.introibo.storage.notification.NotificationStore
import com.lampstandhq.introibo.storage.notification.PrayerNotificationManager
import com.lampstandhq.introibo.ui.components.SmallLabel
import com.lampstandhq.introibo.ui.theme.IntroiboTheme
import com.lampstandhq.introibo.ui.theme.IntroiboType
import kotlinx.coroutines.launch

/**
 * Notification schedule configuration sheet.
 *
 * Port of iOS Introibo/Screens/Prayers/NotificationScheduleSheet.swift.
 */
@Composable
fun NotificationScheduleSheet(
    scheduleId: String,
    title: String,
    subtitle: String,
    onDismiss: () -> Unit,
) {
    val colors = IntroiboTheme.colors
    val type = IntroiboType.current
    val context = LocalContext.current
    val scope = rememberCoroutineScope()

    val notifStore = remember { NotificationStore(context) }
    val notifManager = remember { PrayerNotificationManager(context) }

    var isEnabled by remember { mutableStateOf(false) }
    var selectedDays by remember { mutableStateOf(setOf(1, 2, 3, 4, 5, 6, 7)) }
    var selectedHour by remember { mutableIntStateOf(8) }
    var selectedMinute by remember { mutableIntStateOf(0) }

    val dayNames = listOf("Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat")

    LaunchedEffect(scheduleId) {
        val existing = notifStore.schedule(scheduleId)
        if (existing != null) {
            isEnabled = existing.isEnabled
            selectedDays = existing.days
            selectedHour = existing.hour
            selectedMinute = existing.minute
        }
    }

    fun save() {
        scope.launch {
            val schedule = NotificationSchedule(
                id = scheduleId,
                days = if (isEnabled) selectedDays else emptySet(),
                hour = selectedHour,
                minute = selectedMinute,
                isEnabled = isEnabled,
            )
            notifStore.upsert(schedule)
            notifManager.scheduleAll(notifStore)
        }
    }

    Column(
        modifier = Modifier
            .fillMaxWidth()
            .verticalScroll(rememberScrollState())
            .padding(horizontal = 20.dp)
            .padding(top = 24.dp, bottom = 40.dp),
        verticalArrangement = Arrangement.spacedBy(24.dp),
    ) {
        // Header
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(vertical = 12.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Text(
                text = title,
                style = type.titleL.copy(fontStyle = FontStyle.Italic),
                color = colors.primaryText,
            )
            Text(
                text = subtitle,
                style = type.captionSm.copy(fontStyle = FontStyle.Italic),
                color = colors.secondaryText,
            )
        }

        // Toggle
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .border(0.5.dp, colors.frameLine)
                .padding(16.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Text(
                text = "Remind Me",
                style = type.titleM,
                color = colors.primaryText,
                modifier = Modifier.weight(1f),
            )
            Switch(
                checked = isEnabled,
                onCheckedChange = { isEnabled = it },
                colors = SwitchDefaults.colors(
                    checkedThumbColor = colors.sanctuaryRed,
                    checkedTrackColor = colors.sanctuaryRed.copy(alpha = 0.3f),
                ),
            )
        }

        if (isEnabled) {
            // Days selector
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .border(0.5.dp, colors.frameLine)
                    .padding(16.dp),
                verticalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                SmallLabel(text = "Days", color = colors.sanctuaryRed)
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                ) {
                    for (day in 1..7) {
                        val isSelected = day in selectedDays
                        Box(
                            modifier = Modifier
                                .defaultMinSize(minWidth = 48.dp, minHeight = 48.dp)
                                .size(38.dp)
                                .clip(CircleShape)
                                .background(if (isSelected) colors.sanctuaryRed else colors.pageBackground)
                                .border(
                                    0.5.dp,
                                    if (isSelected) colors.sanctuaryRed else colors.frameLine,
                                    CircleShape,
                                )
                                .clickable {
                                    selectedDays = if (isSelected && selectedDays.size > 1) {
                                        selectedDays - day
                                    } else if (!isSelected) {
                                        selectedDays + day
                                    } else {
                                        selectedDays
                                    }
                                },
                            contentAlignment = Alignment.Center,
                        ) {
                            Text(
                                text = dayNames[day - 1],
                                style = type.captionSm,
                                color = if (isSelected) colors.ivory else colors.primaryText,
                            )
                        }
                    }
                }
            }

            // Time selector (simple hour/minute display)
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .border(0.5.dp, colors.frameLine)
                    .padding(16.dp),
                verticalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                SmallLabel(text = "Time", color = colors.sanctuaryRed)
                Row(
                    modifier = Modifier.fillMaxWidth(),
                    horizontalArrangement = Arrangement.Center,
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    // Hour picker (simple buttons)
                    Column(horizontalAlignment = Alignment.CenterHorizontally) {
                        TextButton(onClick = { selectedHour = (selectedHour + 1) % 24 }) {
                            Text("▲", color = colors.sanctuaryRed)
                        }
                        Text(
                            text = String.format("%02d", selectedHour),
                            style = type.titleL,
                            color = colors.primaryText,
                        )
                        TextButton(onClick = { selectedHour = if (selectedHour > 0) selectedHour - 1 else 23 }) {
                            Text("▼", color = colors.sanctuaryRed)
                        }
                    }
                    Text(
                        text = " : ",
                        style = type.titleL,
                        color = colors.primaryText,
                    )
                    Column(horizontalAlignment = Alignment.CenterHorizontally) {
                        TextButton(onClick = { selectedMinute = (selectedMinute + 5) % 60 }) {
                            Text("▲", color = colors.sanctuaryRed)
                        }
                        Text(
                            text = String.format("%02d", selectedMinute),
                            style = type.titleL,
                            color = colors.primaryText,
                        )
                        TextButton(onClick = { selectedMinute = if (selectedMinute >= 5) selectedMinute - 5 else 55 }) {
                            Text("▼", color = colors.sanctuaryRed)
                        }
                    }
                }
            }
        }

        // Save + Close buttons
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            TextButton(
                onClick = onDismiss,
                modifier = Modifier.weight(1f),
            ) {
                Text("Cancel", color = colors.sanctuaryRed, style = type.body)
            }
            TextButton(
                onClick = { save(); onDismiss() },
                modifier = Modifier
                    .weight(1f)
                    .background(colors.sanctuaryRed.copy(alpha = 0.1f)),
            ) {
                Text("Save", color = colors.sanctuaryRed, style = type.body)
            }
        }
    }
}
