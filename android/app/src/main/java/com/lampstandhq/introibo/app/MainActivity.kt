package com.lampstandhq.introibo.app

import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import com.lampstandhq.introibo.storage.settings.AppTheme
import com.lampstandhq.introibo.storage.settings.FontSizeScale
import com.lampstandhq.introibo.storage.settings.SettingsRepository
import com.lampstandhq.introibo.ui.theme.IntroiboTheme
import com.lampstandhq.introibo.ui.theme.IntroiboType
import com.lampstandhq.introibo.ui.theme.LocalFontScale
import com.lampstandhq.introibo.ui.theme.LocalIntroiboTypography
import com.lampstandhq.introibo.ui.theme.introiboTypography

/**
 * Single-activity host for the Introibo Compose UI.
 *
 * Reads persisted preferences (theme, font scale, onboarding state) via
 * [SettingsRepository] and provides the design-system tokens via
 * [IntroiboTheme] before rendering the screen graph.
 */
class MainActivity : ComponentActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        enableEdgeToEdge()

        setContent {
            val settingsRepo = remember { SettingsRepository(applicationContext) }

            // Observe settings reactively.
            val theme by settingsRepo.appTheme.collectAsState(initial = AppTheme.PARCHMENT)
            val fontScale by settingsRepo.fontScale.collectAsState(
                initial = FontSizeScale.DEFAULT_VALUE
            )

            val typography = introiboTypography(scale = fontScale)

            IntroiboTheme(themeKey = theme.rawValue) {
                CompositionLocalProvider(
                    LocalFontScale provides fontScale,
                    LocalIntroiboTypography provides typography,
                ) {
                    // TODO: wire up onboarding check and navigation graph
                    MainContentPlaceholder()
                }
            }
        }
    }
}

// ---------------------------------------------------------------------------
// Placeholder screens — replace with real navigation graph when wired up.
// ---------------------------------------------------------------------------

@Composable
private fun MainContentPlaceholder() {
    Box(
        modifier = Modifier.fillMaxSize(),
        contentAlignment = Alignment.Center,
    ) {
        Text(
            text = "Introibo ad altare Dei",
            style = IntroiboType.current.pageTitle,
            color = IntroiboTheme.colors.primaryText,
        )
    }
}
