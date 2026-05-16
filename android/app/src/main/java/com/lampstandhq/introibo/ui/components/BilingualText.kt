package com.lampstandhq.introibo.ui.components

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.unit.dp
import com.lampstandhq.introibo.data.model.strippingEm
import com.lampstandhq.introibo.storage.settings.LanguageMode
import com.lampstandhq.introibo.storage.settings.SettingsRepository
import com.lampstandhq.introibo.ui.theme.IntroiboTheme
import com.lampstandhq.introibo.ui.theme.IntroiboType

@Composable
fun currentLanguageMode(): LanguageMode {
    val repo = SettingsRepository(LocalContext.current)
    val mode by repo.languageMode.collectAsState(initial = LanguageMode.BOTH)
    return mode
}

@Composable
fun BilingualLine(
    lat: String,
    eng: String,
    sideBySide: Boolean = false,
    languageMode: String = currentLanguageMode().rawValue,
) {
    val colors = IntroiboTheme.colors
    val type = IntroiboType.current
    val cleanLat = lat.strippingEm
    val cleanEng = eng.strippingEm

    if (sideBySide && languageMode == "both") {
        Row(
            horizontalArrangement = Arrangement.spacedBy(12.dp),
            verticalAlignment = Alignment.Top,
            modifier = Modifier.fillMaxWidth(),
        ) {
            Text(
                text = cleanLat,
                style = type.body,
                color = colors.primaryText,
                lineHeight = type.body.fontSize * 1.2f,
                modifier = Modifier.weight(1f),
            )
            Text(
                text = cleanEng,
                style = type.bodyIt,
                color = colors.secondaryText,
                lineHeight = type.bodyIt.fontSize * 1.2f,
                modifier = Modifier.weight(1f),
            )
        }
    } else {
        Column(
            verticalArrangement = Arrangement.spacedBy(3.dp),
            horizontalAlignment = Alignment.Start,
        ) {
            if (languageMode != "vernacular") {
                Text(
                    text = cleanLat,
                    style = type.body,
                    color = colors.primaryText,
                    lineHeight = type.body.fontSize * 1.2f,
                )
            }
            if (languageMode != "latin") {
                Text(
                    text = cleanEng,
                    style = type.bodyIt,
                    color = colors.secondaryText,
                    lineHeight = type.bodyIt.fontSize * 1.2f,
                )
            }
        }
    }
}

/**
 * Shows Latin and/or English label text based on language mode.
 * In Both mode, shows Latin on top and English below.
 */
@Composable
fun LanguageAwareLabel(
    latin: String,
    english: String,
    modifier: Modifier = Modifier,
) {
    val mode = currentLanguageMode()
    val colors = IntroiboTheme.colors

    when (mode) {
        LanguageMode.LATIN_ONLY -> Text(latin, modifier = modifier)
        LanguageMode.VERNACULAR -> Text(english, modifier = modifier)
        LanguageMode.BOTH -> Column(modifier = modifier) {
            Text(latin)
            Text(english)
        }
    }
}
