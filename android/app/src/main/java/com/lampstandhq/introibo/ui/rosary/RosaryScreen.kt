package com.lampstandhq.introibo.ui.rosary

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
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.outlined.Notifications
import androidx.compose.material3.Divider
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
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.lampstandhq.introibo.data.content.ContentStore
import com.lampstandhq.introibo.data.liturgical.LiturgicalContext
import com.lampstandhq.introibo.data.model.MysterySetData
import com.lampstandhq.introibo.ui.components.SmallLabel
import com.lampstandhq.introibo.ui.theme.IntroiboTheme
import com.lampstandhq.introibo.ui.theme.IntroiboType

/**
 * Rosary landing screen. Shows today's suggested mystery set and lets
 * the user pick another. Tapping opens the bead-by-bead flow.
 *
 * Port of iOS Introibo/Screens/Rosary/RosaryView.swift.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun RosaryScreen(
    onBack: () -> Unit,
) {
    val colors = IntroiboTheme.colors
    val type = IntroiboType.current
    val ctx = remember { LiturgicalContext.current() }

    var selection by remember { mutableStateOf<MysterySetData?>(null) }
    var showNotification by remember { mutableStateOf(false) }

    Scaffold(
        topBar = {
            TopAppBar(
                title = {
                    Text(
                        text = "Sacratíssimum Rosárium",
                        style = type.titleM,
                        color = colors.primaryText,
                    )
                },
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
            horizontalAlignment = Alignment.CenterHorizontally,
            verticalArrangement = Arrangement.spacedBy(24.dp),
        ) {
            // Header
            Column(horizontalAlignment = Alignment.CenterHorizontally) {
                SmallLabel(text = "${ctx.feriaLatin}  ·  ${ctx.latinName}", color = colors.sanctuaryRed)
                Spacer(modifier = Modifier.height(4.dp))
                Text(
                    text = "Oratio per Rosárium",
                    style = type.titleL.copy(fontStyle = FontStyle.Italic),
                    color = colors.primaryText,
                )
                Text(
                    text = "PRAY THE ROSARY",
                    style = type.captionSm.copy(fontStyle = FontStyle.Italic),
                    color = colors.secondaryText,
                    letterSpacing = 2.sp,
                )
            }

            // Today's card
            val todaySlug = ctx.mystery.key
            ContentStore.mysterySet(todaySlug)?.let { todaySet ->
                Box(
                    modifier = Modifier
                        .fillMaxWidth()
                        .border(0.5.dp, colors.frameLine)
                        .clickable { selection = todaySet }
                        .padding(20.dp),
                ) {
                    Column(modifier = Modifier.fillMaxWidth()) {
                        SmallLabel(text = "Mystéria Hodiérna  ·  Today's Mysteries", color = colors.goldLeaf)
                        Spacer(modifier = Modifier.height(10.dp))
                        Text(text = todaySet.name, style = type.pageTitle, color = colors.primaryText)
                        Text(
                            text = todaySet.english.uppercase(),
                            style = type.captionSm.copy(fontStyle = FontStyle.Italic),
                            color = colors.secondaryText,
                            letterSpacing = 2.sp,
                        )
                        Spacer(modifier = Modifier.height(10.dp))
                        Row(modifier = Modifier.fillMaxWidth(), horizontalArrangement = Arrangement.End) {
                            SmallLabel(text = "Incipiámus  ✠  Begin", color = colors.sanctuaryRed)
                        }
                    }
                }
            }

            // Other mysteries
            Column(
                modifier = Modifier.fillMaxWidth(),
                verticalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                // Section header
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    modifier = Modifier.fillMaxWidth(),
                ) {
                    GoldDivider(modifier = Modifier.weight(1f))
                    SmallLabel(
                        text = "Ália Mystéria",
                        color = colors.sanctuaryRed,
                        modifier = Modifier.padding(horizontal = 10.dp),
                    )
                    GoldDivider(modifier = Modifier.weight(1f))
                }

                ContentStore.mysterySets.filter { it.slug != todaySlug }.forEach { set ->
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .clickable { selection = set }
                            .padding(vertical = 10.dp),
                        verticalAlignment = Alignment.Top,
                    ) {
                        Column(modifier = Modifier.weight(1f)) {
                            Text(
                                text = set.name,
                                style = type.titleM.copy(fontStyle = FontStyle.Italic),
                                color = colors.primaryText,
                            )
                            Text(
                                text = set.english,
                                style = type.captionSm.copy(fontStyle = FontStyle.Italic),
                                color = colors.secondaryText,
                            )
                        }
                        Text(
                            text = "›",
                            style = type.titleL,
                            color = colors.goldLeaf,
                        )
                    }
                    HorizontalDivider(color = colors.frameLine.copy(alpha = 0.5f))
                }
            }
        }
    }

    // Flow sheet
    selection?.let { set ->
        RosaryFlowScreen(
            set = set,
            onDismiss = { selection = null },
        )
    }

    // Notification sheet
    if (showNotification) {
        ModalBottomSheet(
            onDismissRequest = { showNotification = false },
            sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true),
            containerColor = colors.pageBackground,
        ) {
            com.lampstandhq.introibo.ui.prayers.NotificationScheduleSheet(
                scheduleId = "devotion.rosary",
                title = "The Holy Rosary",
                subtitle = "Remind me to pray the Rosary",
                onDismiss = { showNotification = false },
            )
        }
    }
}

@Composable
private fun GoldDivider(modifier: Modifier = Modifier) {
    val colors = IntroiboTheme.colors
    Box(
        modifier = modifier
            .height(0.5.dp)
            .fillMaxWidth()
            .padding(horizontal = 0.dp)
            .then(
                Modifier.height(0.5.dp)
            ),
    ) {
        HorizontalDivider(color = colors.goldLeaf.copy(alpha = 0.4f), thickness = 0.5.dp)
    }
}
