package com.lampstandhq.introibo.app

import android.content.Context
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.activity.enableEdgeToEdge
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import com.lampstandhq.introibo.storage.settings.AppTheme
import com.lampstandhq.introibo.storage.settings.FontSizeScale
import com.lampstandhq.introibo.storage.settings.SettingsRepository
import com.lampstandhq.introibo.ui.navigation.IntroiboNavHost
import com.lampstandhq.introibo.ui.theme.IntroiboTheme
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

            // Check onboarding state
            val prefs = remember {
                applicationContext.getSharedPreferences("introibo_onboarding", Context.MODE_PRIVATE)
            }
            val hasSeenOnboarding = prefs.getBoolean("has_seen_onboarding", false)

            IntroiboTheme(themeKey = theme.rawValue) {
                CompositionLocalProvider(
                    LocalFontScale provides fontScale,
                    LocalIntroiboTypography provides typography,
                ) {
                    if (hasSeenOnboarding) {
                        IntroiboNavHost()
                    } else {
                        // Show onboarding then mark complete.
                        // For now, go straight to main nav and mark onboarding done.
                        // Replace with OnboardingScreen when it's ported.
                        prefs.edit().putBoolean("has_seen_onboarding", true).apply()
                        IntroiboNavHost()
                    }
                }
            }
        }
    }
}
