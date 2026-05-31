package com.lampstandhq.introibo.ui.today

import android.content.Intent
import android.net.Uri
import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.defaultMinSize
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.automirrored.filled.HelpOutline
import androidx.compose.material.icons.filled.Check
import androidx.compose.material.icons.filled.ChevronRight
import androidx.compose.material.icons.filled.Email
import androidx.compose.material.icons.filled.Refresh
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Switch
import androidx.compose.material3.SwitchDefaults
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Slider
import androidx.compose.material3.SliderDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.lampstandhq.introibo.storage.progress.UserProgressRepository
import com.lampstandhq.introibo.storage.settings.AppTheme
import com.lampstandhq.introibo.storage.settings.FontRange
import com.lampstandhq.introibo.storage.settings.FontSizeScale
import com.lampstandhq.introibo.storage.settings.LanguageMode
import com.lampstandhq.introibo.storage.settings.MissalRite
import com.lampstandhq.introibo.storage.settings.PenanceDiscipline
import com.lampstandhq.introibo.storage.settings.SettingsRepository
import com.lampstandhq.introibo.ui.components.SmallLabel
import com.lampstandhq.introibo.ui.theme.IntroiboTheme
import com.lampstandhq.introibo.ui.theme.IntroiboType
import kotlinx.coroutines.launch

/**
 * Full Settings screen, ported from iOS SettingsView.swift.
 * All sections: rite, penance, language, theme, font size, tutorial,
 * feedback, reset, and about.
 */
@Composable
fun SettingsScreen(onDismiss: () -> Unit = {}, onOpenTutorial: (() -> Unit)? = null) {
    val context = LocalContext.current
    val colors = IntroiboTheme.colors
    val type = IntroiboType.current
    val scope = rememberCoroutineScope()

    val settingsRepo = remember { SettingsRepository(context) }
    val progressRepo = remember { UserProgressRepository(context) }

    val rite by settingsRepo.missalRite.collectAsState(initial = MissalRite.RITE_1962)
    val penance by settingsRepo.penanceDiscipline.collectAsState(initial = PenanceDiscipline.DISCIPLINE_1962)
    val theme by settingsRepo.appTheme.collectAsState(initial = AppTheme.PARCHMENT)
    val language by settingsRepo.languageMode.collectAsState(initial = LanguageMode.BOTH)
    val fontScale by settingsRepo.fontScale.collectAsState(initial = FontSizeScale.DEFAULT_VALUE)
    val fontRange by settingsRepo.fontRange.collectAsState(initial = FontRange.NORMAL)
    val showLeonine by settingsRepo.showLeoninePrayers.collectAsState(initial = true)

    var showResetConfirm by remember { mutableStateOf(false) }
    var showTutorial by remember { mutableStateOf(false) }
    var localFontScale by remember(fontScale) { mutableFloatStateOf(fontScale) }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(colors.pageBackground),
    ) {
        // Top bar
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 8.dp, vertical = 12.dp),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically,
        ) {
            IconButton(onClick = onDismiss) {
                Icon(
                    imageVector = Icons.AutoMirrored.Filled.ArrowBack,
                    contentDescription = "Back",
                    tint = colors.sanctuaryRed,
                )
            }
            Text(
                text = "Settings",
                style = type.titleM.copy(fontStyle = FontStyle.Italic),
                color = colors.primaryText,
                textAlign = TextAlign.Center,
                modifier = Modifier.weight(1f),
            )
            // Spacer to balance the layout (back arrow is on the left)
            Spacer(modifier = Modifier.size(48.dp))
        }

        LazyColumn(
            modifier = Modifier
                .fillMaxSize()
                .padding(horizontal = 16.dp),
        ) {
            // ---- Rite Section ----
            item {
                SettingsSectionHeader(
                    title = "Ritus · Missal Rite",
                )
            }
            item {
                MissalRite.entries.forEach { r ->
                    SettingsRadioRow(
                        label = r.label,
                        isSelected = rite == r,
                        onClick = { scope.launch { settingsRepo.setMissalRite(r) } },
                    )
                }
                SettingsSectionFooter(
                    text = "Controls the rubrics displayed in the Missal. Most traditional parishes use the 1962 Missal.",
                )
            }

            // ---- Leonine Prayers Section ----
            item {
                SettingsSectionHeader(title = "Preces Leoninae · Leonine Prayers")
            }
            item {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    modifier = Modifier
                        .fillMaxWidth()
                        .padding(vertical = 10.dp),
                ) {
                    Column(modifier = Modifier.weight(1f)) {
                        Text(
                            text = "Leonine Prayers",
                            style = type.body,
                            color = colors.primaryText,
                        )
                        Text(
                            text = "Prayers after Low Mass (Leo XIII, 1884)",
                            style = type.captionSm,
                            color = colors.secondaryText,
                        )
                    }
                    Switch(
                        checked = showLeonine,
                        onCheckedChange = { checked ->
                            scope.launch { settingsRepo.setShowLeoninePrayers(checked) }
                        },
                        colors = SwitchDefaults.colors(
                            checkedThumbColor = colors.sanctuaryRed,
                            checkedTrackColor = colors.sanctuaryRed.copy(alpha = 0.3f),
                        ),
                    )
                }
                SettingsSectionFooter(
                    text = "The Leonine Prayers were instituted by Leo XIII in 1884 and suppressed by Inter Oecumenici in 1964. Enable for strict 1962 observance; disable for post-1964 practice.",
                )
            }

            // ---- Penance Section ----
            item {
                SettingsSectionHeader(title = "Paenitentia · Penance Discipline")
            }
            item {
                PenanceDiscipline.entries.forEach { d ->
                    SettingsRadioRow(
                        label = d.label,
                        isSelected = penance == d,
                        onClick = { scope.launch { settingsRepo.setPenanceDiscipline(d) } },
                    )
                }
                SettingsSectionFooter(
                    text = "Determines which fasting and abstinence obligations appear on the Today screen.",
                )
            }

            // ---- Language Section ----
            item {
                SettingsSectionHeader(title = "Lingua · Language")
            }
            item {
                LanguageMode.entries.forEach { l ->
                    SettingsRadioRow(
                        label = l.label,
                        isSelected = language == l,
                        onClick = { scope.launch { settingsRepo.setLanguageMode(l) } },
                    )
                }
                SettingsSectionFooter(
                    text = "Choose which text to display in prayers, the Missal, and the Divine Office.",
                )
            }

            // ---- Appearance Section ----
            item {
                SettingsSectionHeader(title = "Apparitus · Appearance")
            }
            item {
                AppTheme.entries.forEach { t ->
                    SettingsRadioRow(
                        label = t.label,
                        isSelected = theme == t,
                        onClick = { scope.launch { settingsRepo.setAppTheme(t) } },
                    )
                }
                SettingsSectionFooter(
                    text = "Parchment: warm vellum background. Clean White: modern white with walnut tab bar. Dark: deep walnut for low light.",
                )
            }

            // ---- Font Size Section ----
            item {
                SettingsSectionHeader(title = "Littera · Text Size")
            }
            item {
                Column(modifier = Modifier.padding(vertical = 8.dp)) {
                    // Preview text
                    Text(
                        text = "Introibo ad altare Dei",
                        style = type.body.copy(
                            fontSize = (16 * localFontScale).sp,
                            fontFamily = FontFamily.Serif,
                            fontStyle = FontStyle.Italic,
                        ),
                        color = colors.primaryText,
                        textAlign = TextAlign.Center,
                        modifier = Modifier.fillMaxWidth(),
                    )

                    Spacer(Modifier.height(12.dp))

                    // Slider
                    Row(
                        verticalAlignment = Alignment.CenterVertically,
                        modifier = Modifier.fillMaxWidth(),
                    ) {
                        Text(
                            text = "A",
                            fontSize = 10.sp,
                            fontFamily = FontFamily.Serif,
                            color = colors.tertiaryText,
                        )
                        Slider(
                            value = localFontScale,
                            onValueChange = { localFontScale = it },
                            onValueChangeFinished = {
                                scope.launch { settingsRepo.setFontScale(localFontScale) }
                            },
                            valueRange = fontRange.min..fontRange.max,
                            steps = ((fontRange.max - fontRange.min) / 0.05f).toInt() - 1,
                            colors = SliderDefaults.colors(
                                thumbColor = colors.sanctuaryRed,
                                activeTrackColor = colors.sanctuaryRed,
                                inactiveTrackColor = colors.frameLine,
                            ),
                            modifier = Modifier
                                .weight(1f)
                                .padding(horizontal = 8.dp),
                        )
                        Text(
                            text = "A",
                            fontSize = 24.sp,
                            fontFamily = FontFamily.Serif,
                            color = colors.tertiaryText,
                        )
                    }

                    Spacer(Modifier.height(8.dp))

                    // Range selector
                    Row(
                        modifier = Modifier.fillMaxWidth(),
                        horizontalArrangement = Arrangement.SpaceEvenly,
                    ) {
                        FontRange.entries.forEach { r ->
                            val isSelected = fontRange == r
                            Text(
                                text = r.label,
                                style = type.captionSm,
                                color = if (isSelected) colors.sanctuaryRed else colors.tertiaryText,
                                modifier = Modifier
                                    .background(
                                        if (isSelected) colors.sanctuaryRed.copy(alpha = 0.08f)
                                        else androidx.compose.ui.graphics.Color.Transparent,
                                        RoundedCornerShape(6.dp),
                                    )
                                    .clickable {
                                        scope.launch {
                                            settingsRepo.setFontRange(r)
                                            if (localFontScale < r.min || localFontScale > r.max) {
                                                localFontScale = r.defaultVal
                                                settingsRepo.setFontScale(r.defaultVal)
                                            }
                                        }
                                    }
                                    .padding(vertical = 8.dp, horizontal = 16.dp),
                            )
                        }
                    }
                }
                SettingsSectionFooter(
                    text = "Choose a scale range, then adjust the slider. Smaller for compact reading, Bigger for accessibility.",
                )
            }

            // ---- Tutorial Section ----
            item {
                SettingsSectionHeader(title = "")
            }
            item {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    modifier = Modifier
                        .fillMaxWidth()
                        .clickable {
                            if (onOpenTutorial != null) {
                                onOpenTutorial()
                            } else {
                                showTutorial = true
                            }
                        }
                        .padding(vertical = 12.dp),
                ) {
                    Icon(
                        imageVector = Icons.AutoMirrored.Filled.HelpOutline,
                        contentDescription = null,
                        tint = colors.primaryText,
                        modifier = Modifier.padding(end = 8.dp),
                    )
                    Text(
                        text = "App Tutorial",
                        style = type.body,
                        color = colors.primaryText,
                        modifier = Modifier.weight(1f),
                    )
                    Icon(
                        imageVector = Icons.Filled.ChevronRight,
                        contentDescription = null,
                        tint = colors.tertiaryText,
                    )
                }
                HorizontalDivider(color = colors.frameLine)
            }

            // ---- Feedback Section ----
            item {
                SettingsSectionHeader(title = "Opinor · Feedback")
            }
            item {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    modifier = Modifier
                        .fillMaxWidth()
                        .clickable {
                            val emailIntent = Intent(Intent.ACTION_SENDTO).apply {
                                data = Uri.parse("mailto:contact@lampstandhq.com?subject=Introibo%20Feedback")
                            }
                            context.startActivity(
                                Intent.createChooser(emailIntent, "Send Feedback")
                            )
                        }
                        .padding(vertical = 12.dp),
                ) {
                    Icon(
                        imageVector = Icons.Filled.Email,
                        contentDescription = null,
                        tint = colors.primaryText,
                        modifier = Modifier.padding(end = 8.dp),
                    )
                    Text(
                        text = "Send Feedback",
                        style = type.body,
                        color = colors.primaryText,
                        modifier = Modifier.weight(1f),
                    )
                }
                SettingsSectionFooter(
                    text = "Report issues, suggest features, or share your experience.",
                )
            }

            // ---- Reset Section ----
            item {
                SettingsSectionHeader(title = "")
            }
            item {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    modifier = Modifier
                        .fillMaxWidth()
                        .clickable { showResetConfirm = true }
                        .padding(vertical = 12.dp),
                ) {
                    Icon(
                        imageVector = Icons.Filled.Refresh,
                        contentDescription = null,
                        tint = colors.sanctuaryRed,
                        modifier = Modifier.padding(end = 8.dp),
                    )
                    Text(
                        text = "Reset All Progress",
                        style = type.body,
                        color = colors.sanctuaryRed,
                    )
                }
                SettingsSectionFooter(
                    text = "Clears all local progress. Settings (rite, penance, theme) are not affected.",
                )
            }

            // ---- Licenses Section ----
            item {
                SettingsSectionHeader(title = "Licentia · Licenses")
            }
            item {
                Column(modifier = Modifier.padding(vertical = 8.dp)) {
                    Text(
                        text = "Divinum Officium",
                        style = type.bodySm.copy(fontFamily = FontFamily.Serif),
                        color = colors.primaryText,
                    )
                    Spacer(Modifier.height(4.dp))
                    Text(
                        text = "Liturgical texts for the Divine Office and Holy Mass are sourced from the Divinum Officium project (divinumofficium.com).",
                        style = type.captionSm,
                        color = colors.secondaryText,
                    )
                    Spacer(Modifier.height(4.dp))
                    Text(
                        text = "Licensed under the MIT License.",
                        style = type.captionSm.copy(fontStyle = FontStyle.Italic),
                        color = colors.tertiaryText,
                    )
                }
            }
            item {
                SettingsSectionFooter(
                    text = "Introibo uses open-source liturgical data to ensure accuracy.",
                )
            }

            // ---- About Section ----
            item {
                SettingsSectionHeader(title = "About")
            }
            item {
                Column(modifier = Modifier.padding(vertical = 8.dp)) {
                    AboutRow(label = "App", value = "Introibo")
                    AboutRow(label = "Version", value = "1.2")
                    Spacer(Modifier.height(8.dp))
                    Text(
                        text = "Ad altare Dei",
                        style = type.captionSm.copy(fontStyle = FontStyle.Italic),
                        color = colors.secondaryText,
                        textAlign = TextAlign.End,
                        modifier = Modifier.fillMaxWidth(),
                    )
                    Spacer(Modifier.height(4.dp))
                    Text(
                        text = "A prayer companion for the traditional Catholic life. Ad free. Works offline.",
                        style = type.captionSm,
                        color = colors.secondaryText,
                    )
                    Spacer(Modifier.height(12.dp))
                    Text(
                        text = "Built by Lampstand",
                        style = type.captionSm,
                        color = colors.tertiaryText,
                        textAlign = TextAlign.Center,
                        modifier = Modifier
                            .fillMaxWidth()
                            .padding(top = 12.dp),
                    )
                }
            }

            item { Spacer(Modifier.height(40.dp)) }
        }
    }

    // Reset confirmation dialog
    if (showResetConfirm) {
        AlertDialog(
            onDismissRequest = { showResetConfirm = false },
            title = { Text("Clear all local progress?") },
            text = {
                Text(
                    "This will clear your followed saint, streaks, rosary history, and mastered lessons. Settings are preserved.",
                )
            },
            confirmButton = {
                TextButton(onClick = {
                    scope.launch {
                        progressRepo.resetAll()
                        showResetConfirm = false
                    }
                }) {
                    Text("Reset", color = colors.sanctuaryRed)
                }
            },
            dismissButton = {
                TextButton(onClick = { showResetConfirm = false }) {
                    Text("Cancel")
                }
            },
        )
    }

    // Tutorial dialog
    if (showTutorial) {
        androidx.compose.ui.window.Dialog(
            onDismissRequest = { showTutorial = false },
            properties = androidx.compose.ui.window.DialogProperties(usePlatformDefaultWidth = false),
        ) {
            com.lampstandhq.introibo.ui.onboarding.TutorialScreen(
                onDismiss = { showTutorial = false },
            )
        }
    }
}

// ---------------------------------------------------------------------------
// Settings section helper composables
// ---------------------------------------------------------------------------

@Composable
private fun SettingsSectionHeader(title: String) {
    if (title.isNotEmpty()) {
        val colors = IntroiboTheme.colors
        SmallLabel(
            text = title,
            color = colors.sanctuaryRed,
            modifier = Modifier.padding(top = 24.dp, bottom = 8.dp),
        )
    } else {
        Spacer(Modifier.height(16.dp))
    }
}

@Composable
private fun SettingsSectionFooter(text: String) {
    val colors = IntroiboTheme.colors
    val type = IntroiboType.current
    Text(
        text = text,
        style = type.captionSm,
        color = colors.tertiaryText,
        modifier = Modifier.padding(top = 6.dp, bottom = 8.dp),
    )
}

@Composable
private fun SettingsRadioRow(
    label: String,
    isSelected: Boolean,
    onClick: () -> Unit,
) {
    val colors = IntroiboTheme.colors
    val type = IntroiboType.current

    Row(
        verticalAlignment = Alignment.CenterVertically,
        modifier = Modifier
            .fillMaxWidth()
            .defaultMinSize(minHeight = 48.dp)
            .clickable(onClick = onClick)
            .padding(vertical = 10.dp),
    ) {
        Text(
            text = label,
            style = type.body,
            color = colors.primaryText,
            modifier = Modifier.weight(1f),
        )
        if (isSelected) {
            Icon(
                imageVector = Icons.Filled.Check,
                contentDescription = "Selected",
                tint = colors.sanctuaryRed,
            )
        }
    }
    HorizontalDivider(color = colors.frameLine.copy(alpha = 0.5f))
}

@Composable
private fun AboutRow(label: String, value: String) {
    val colors = IntroiboTheme.colors
    val type = IntroiboType.current

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .padding(vertical = 4.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
    ) {
        Text(text = label, style = type.body, color = colors.primaryText)
        Text(
            text = value,
            style = type.body.copy(fontStyle = FontStyle.Italic),
            color = colors.secondaryText,
        )
    }
}
