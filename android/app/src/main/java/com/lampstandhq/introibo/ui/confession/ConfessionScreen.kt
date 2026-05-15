package com.lampstandhq.introibo.ui.confession

import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.rememberScrollState
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
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.lampstandhq.introibo.data.content.ContentStore
import com.lampstandhq.introibo.data.model.ConfessionGuide
import com.lampstandhq.introibo.ui.components.SmallLabel
import com.lampstandhq.introibo.ui.theme.IntroiboTheme
import com.lampstandhq.introibo.ui.theme.IntroiboType

/**
 * De Confessione -- landing screen with two guided paths + direct
 * access to the Examination of Conscience.
 *
 * Port of iOS Introibo/Screens/Confession/ConfessionView.swift.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ConfessionScreen(
    openExamen: Boolean = false,
    onBack: () -> Unit,
) {
    val colors = IntroiboTheme.colors
    val type = IntroiboType.current

    var selectedGuide by remember { mutableStateOf<ConfessionGuide?>(null) }
    var showExamen by remember { mutableStateOf(false) }
    var showNotification by remember { mutableStateOf(false) }

    LaunchedEffect(openExamen) {
        if (openExamen) showExamen = true
    }

    Scaffold(
        topBar = {
            TopAppBar(
                title = { Text("De Confessióne", style = type.titleM, color = colors.primaryText) },
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
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 28.dp, vertical = 24.dp),
            verticalArrangement = Arrangement.spacedBy(24.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            // Header
            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                SmallLabel(text = "Sacraméntum Pæniténtiæ", color = colors.sanctuaryRed)
                Spacer(modifier = Modifier.height(4.dp))
                Text(
                    text = "The Sacrament of Penance",
                    style = type.titleL.copy(fontStyle = FontStyle.Italic),
                    color = colors.primaryText,
                )
                Text(
                    text = "Two guided paths, plus the Examination of Conscience.",
                    style = type.captionSm.copy(fontStyle = FontStyle.Italic),
                    color = colors.secondaryText,
                    modifier = Modifier.padding(top = 2.dp),
                )
            }

            // Examen card
            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .border(0.5.dp, colors.frameLine)
                    .clickable { showExamen = true }
                    .padding(20.dp),
            ) {
                SmallLabel(text = "Exámen Consciéntiæ", color = colors.goldLeaf)
                Spacer(modifier = Modifier.height(8.dp))
                Text(
                    text = "Examination of Conscience",
                    style = type.titleL.copy(fontStyle = FontStyle.Italic),
                    color = colors.primaryText,
                )
                Text(
                    text = "Walk through the Ten Commandments with traditional questions for each.",
                    style = type.captionSm.copy(fontStyle = FontStyle.Italic),
                    color = colors.secondaryText,
                )
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(top = 8.dp),
                    horizontalArrangement = Arrangement.End,
                ) {
                    SmallLabel(text = "Incipiámus  ✠  Begin", color = colors.sanctuaryRed)
                }
            }

            // Guide list
            Column(
                modifier = Modifier.fillMaxWidth(),
                verticalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    modifier = Modifier.fillMaxWidth(),
                ) {
                    GoldLine(modifier = Modifier.weight(1f))
                    SmallLabel(
                        text = "Libri Duo  ·  Two Paths",
                        color = colors.sanctuaryRed,
                        modifier = Modifier.padding(horizontal = 10.dp),
                    )
                    GoldLine(modifier = Modifier.weight(1f))
                }

                ContentStore.confessionGuides.forEachIndexed { idx, guide ->
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .clickable { selectedGuide = guide }
                            .padding(vertical = 10.dp),
                        verticalAlignment = Alignment.Top,
                    ) {
                        Column(modifier = Modifier.weight(1f)) {
                            Text(
                                text = guide.name,
                                style = type.titleM.copy(fontStyle = FontStyle.Italic),
                                color = colors.primaryText,
                            )
                            Text(
                                text = guide.title,
                                style = type.captionSm.copy(fontStyle = FontStyle.Italic),
                                color = colors.secondaryText,
                            )
                            guide.subtitle?.let { sub ->
                                Text(
                                    text = sub,
                                    style = type.captionSm.copy(fontStyle = FontStyle.Italic),
                                    color = colors.tertiaryText,
                                    maxLines = 1,
                                    overflow = TextOverflow.Ellipsis,
                                    modifier = Modifier.padding(top = 2.dp),
                                )
                            }
                        }
                        Text("›", style = type.titleL, color = colors.goldLeaf)
                    }
                    if (idx < ContentStore.confessionGuides.size - 1) {
                        HorizontalDivider(color = colors.frameLine.copy(alpha = 0.5f))
                    }
                }
            }
        }
    }

    // Examen sheet
    if (showExamen) {
        ExamenScreen(onDismiss = { showExamen = false })
    }

    // Guide reader sheet
    selectedGuide?.let { guide ->
        GuideReaderScreen(guide = guide, onDismiss = { selectedGuide = null })
    }

    // Notification sheet
    if (showNotification) {
        ModalBottomSheet(
            onDismissRequest = { showNotification = false },
            sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true),
            containerColor = colors.pageBackground,
        ) {
            com.lampstandhq.introibo.ui.prayers.NotificationScheduleSheet(
                scheduleId = "devotion.confession",
                title = "Confession",
                subtitle = "Remind me to go to Confession",
                onDismiss = { showNotification = false },
            )
        }
    }
}

@Composable
private fun GoldLine(modifier: Modifier = Modifier) {
    val colors = IntroiboTheme.colors
    androidx.compose.foundation.layout.Box(
        modifier = modifier
            .height(0.5.dp)
            .fillMaxWidth()
    ) {
        HorizontalDivider(color = colors.goldLeaf.copy(alpha = 0.4f), thickness = 0.5.dp)
    }
}
