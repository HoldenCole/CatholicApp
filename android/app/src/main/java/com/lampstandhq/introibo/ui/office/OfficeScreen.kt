package com.lampstandhq.introibo.ui.office

import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.layout.aspectRatio
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
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.runtime.collectAsState
import androidx.compose.ui.platform.LocalContext
import com.lampstandhq.introibo.data.content.ContentStore
import com.lampstandhq.introibo.data.liturgical.LiturgicalContext
import com.lampstandhq.introibo.data.liturgical.OfficeSchedule
import com.lampstandhq.introibo.data.model.Hour
import com.lampstandhq.introibo.storage.settings.MissalRite
import com.lampstandhq.introibo.storage.settings.SettingsRepository
import com.lampstandhq.introibo.ui.theme.IntroiboTheme
import com.lampstandhq.introibo.ui.theme.IntroiboType
import com.lampstandhq.introibo.ui.components.LanguageAwareLabel

/**
 * The Divine Office -- Officium Divinum. Shows a 24-hour canonical clock
 * dial with the 8 hours placed at their traditional times.
 *
 * Port of iOS Introibo/Screens/Office/OfficeView.swift.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun OfficeScreen(
    onBack: () -> Unit,
) {
    val colors = IntroiboTheme.colors
    val type = IntroiboType.current
    val appContext = LocalContext.current
    val settingsRepo = remember { SettingsRepository(appContext) }
    // The Office ordo (festal psalms, Matins structure, proper overrides)
    // depends on the selected rite — iOS parity.
    val rite by settingsRepo.missalRite.collectAsState(initial = MissalRite.RITE_1962)
    val ctx = remember(rite) { LiturgicalContext.forDate(java.time.LocalDate.now(), rite = rite) }

    var selectedHour by remember { mutableStateOf<Hour?>(null) }
    var showNotification by rememberSaveable { mutableStateOf(false) }

    Scaffold(
        topBar = {
            TopAppBar(
                title = {
                    Text(
                        text = "Officium Divinum",
                        style = type.titleM,
                        color = colors.primaryText,
                    )
                },
                navigationIcon = {
                    IconButton(onClick = onBack) {
                        Icon(
                            imageVector = Icons.AutoMirrored.Filled.ArrowBack,
                            contentDescription = "Back",
                            tint = colors.sanctuaryRed,
                        )
                    }
                },
                actions = {
                    IconButton(onClick = { showNotification = true }) {
                        Icon(
                            imageVector = Icons.Outlined.Notifications,
                            contentDescription = "Notification",
                            tint = colors.sanctuaryRed,
                        )
                    }
                },
                colors = TopAppBarDefaults.topAppBarColors(
                    containerColor = colors.pageBackground,
                ),
            )
        },
        containerColor = colors.pageBackground,
    ) { padding ->
        Column(
            modifier = Modifier
                .fillMaxSize()
                .padding(padding)
                .verticalScroll(rememberScrollState())
                .padding(horizontal = 28.dp)
                .padding(top = 18.dp, bottom = 40.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Text(
                text = "Officium Divínum",
                style = type.titleL.copy(fontStyle = FontStyle.Italic),
                color = colors.primaryText,
            )

            Spacer(modifier = Modifier.height(4.dp))

            Text(
                text = "THE DIVINE OFFICE  ·  1962 ROMAN BREVIARY",
                style = type.captionSm,
                color = colors.secondaryText,
                letterSpacing = 2.sp,
            )

            Spacer(modifier = Modifier.height(10.dp))

            LanguageAwareLabel(
                latin = "“${ctx.feriaLatin}  ·  ${ctx.latinName}”",
                english = "“${ctx.feriaEnglish}  ·  ${ctx.englishName}”",
                color = colors.tertiaryText,
            )

            Spacer(modifier = Modifier.height(12.dp))

            ClockDial(
                hours = ContentStore.hours.filter { it.slug != "office-of-the-dead" },
                currentKey = currentHourKey(),
                onTap = { slug ->
                    ContentStore.hourForToday(slug, rite)?.let { selectedHour = it }
                },
                modifier = Modifier
                    .fillMaxWidth()
                    .aspectRatio(1f),
            )

            Spacer(modifier = Modifier.height(12.dp))

            Text(
                text = "Tap any hour to enter its prayer.",
                style = type.captionSm.copy(fontStyle = FontStyle.Italic),
                color = colors.tertiaryText,
            )
            Text(
                text = "The current hour glows.",
                style = type.captionSm.copy(fontStyle = FontStyle.Italic),
                color = colors.tertiaryText,
            )

            // Office of the Dead — a votive office outside the daily cursus,
            // so it lives below the dial rather than on it. Opened from the
            // raw template (no temporal/sanctoral overlay), like iOS.
            ContentStore.hours.firstOrNull { it.slug == "office-of-the-dead" }?.let { dead ->
                Spacer(modifier = Modifier.height(44.dp))
                Column(
                    horizontalAlignment = Alignment.CenterHorizontally,
                    modifier = Modifier
                        .fillMaxWidth()
                        .border(0.5.dp, colors.goldLeaf.copy(alpha = 0.45f), RoundedCornerShape(10.dp))
                        .clickable { selectedHour = dead }
                        .padding(vertical = 18.dp),
                ) {
                    Text(text = "✠", style = type.titleM, color = colors.sanctuaryRed)
                    Text(
                        text = "Officium Defunctórum",
                        style = type.titleM.copy(fontStyle = FontStyle.Italic),
                        color = colors.primaryText,
                    )
                    Text(
                        text = "OFFICE OF THE DEAD",
                        style = type.captionSm.copy(fontStyle = FontStyle.Italic, letterSpacing = 2.sp),
                        color = colors.secondaryText,
                    )
                }
            }
        }
    }

    // Hour sheet
    selectedHour?.let { hour ->
        HourSheet(
            hour = hour,
            onDismiss = { selectedHour = null },
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
                scheduleId = "devotion.office",
                title = "Divine Office",
                subtitle = "Remind me to pray the Office",
                onDismiss = { showNotification = false },
            )
        }
    }
}

// Closest preceding canonical hour; before Matutinum roll back to the previous
// day's Completorium. Delegates to the shared OfficeSchedule so the Office tab
// and the home-screen widget never diverge.
private fun currentHourKey(): String =
    OfficeSchedule.currentHourSlug(ContentStore.hours)
