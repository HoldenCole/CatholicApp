package com.lampstandhq.introibo.app

import android.content.Context
import android.os.Bundle
import androidx.activity.ComponentActivity
import androidx.activity.compose.setContent
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import com.lampstandhq.introibo.storage.settings.AppTheme
import com.lampstandhq.introibo.storage.settings.FontSizeScale
import com.lampstandhq.introibo.storage.settings.SettingsRepository
import com.lampstandhq.introibo.ui.navigation.IntroiboNavHost
import com.lampstandhq.introibo.ui.onboarding.OnboardingScreen
import com.lampstandhq.introibo.ui.onboarding.SplashScreen
import com.lampstandhq.introibo.ui.theme.IntroiboTheme
import com.lampstandhq.introibo.ui.theme.LocalFontScale
import com.lampstandhq.introibo.ui.theme.LocalIntroiboTypography
import com.lampstandhq.introibo.ui.theme.introiboTypography

class MainActivity : ComponentActivity() {

    companion object {
        /** Intent action carrying a deep-link target (widget taps, etc.). */
        const val ACTION_DEEPLINK = "com.lampstandhq.introibo.action.DEEPLINK"

        /** String extra: "type:id[#pos]" wire string, or "widget:office" /
         *  "widget:prayer" (resolved against the clock when handled). */
        const val EXTRA_TARGET = "target"
    }

    /** Launcher-shortcut destination (a Screen route), consumed by the NavHost. */
    private val shortcutRoute = mutableStateOf<String?>(null)

    /** Widget/deep-link target wire string, consumed by the NavHost. */
    private val deepLinkTarget = mutableStateOf<String?>(null)

    private fun routeForIntent(intent: android.content.Intent?): String? = when (intent?.action) {
        "com.lampstandhq.introibo.action.MISSAL" -> "missal"
        "com.lampstandhq.introibo.action.OFFICE" -> "office"
        "com.lampstandhq.introibo.action.ROSARY" -> "rosary"
        else -> null
    }

    private fun consumeIntent(intent: android.content.Intent?) {
        routeForIntent(intent)?.let { shortcutRoute.value = it }
        if (intent?.action == ACTION_DEEPLINK) {
            intent.getStringExtra(EXTRA_TARGET)?.let { deepLinkTarget.value = it }
        }
    }

    override fun onNewIntent(intent: android.content.Intent) {
        super.onNewIntent(intent)
        consumeIntent(intent)
    }

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        consumeIntent(intent)

        setContent {
            val settingsRepo = remember { SettingsRepository(applicationContext) }

            val theme by settingsRepo.appTheme.collectAsState(initial = AppTheme.PARCHMENT)
            val fontScale by settingsRepo.fontScale.collectAsState(
                initial = FontSizeScale.DEFAULT_VALUE
            )

            val typography = introiboTypography(scale = fontScale)

            val prefs = remember {
                applicationContext.getSharedPreferences("introibo_onboarding", Context.MODE_PRIVATE)
            }
            val hasSeenOnboarding = prefs.getBoolean("has_seen_onboarding", false)

            var showSplash by rememberSaveable { mutableStateOf(true) }
            var onboardingDone by rememberSaveable { mutableStateOf(hasSeenOnboarding) }

            IntroiboTheme(themeKey = theme.rawValue) {
                CompositionLocalProvider(
                    LocalFontScale provides fontScale,
                    LocalIntroiboTypography provides typography,
                ) {
                    when {
                        showSplash -> {
                            SplashScreen(onFinished = { showSplash = false })
                        }
                        !onboardingDone -> {
                            OnboardingScreen(onComplete = {
                                prefs.edit().putBoolean("has_seen_onboarding", true).apply()
                                onboardingDone = true
                            })
                        }
                        else -> {
                            IntroiboNavHost(
                                shortcutRoute = shortcutRoute.value,
                                onShortcutConsumed = { shortcutRoute.value = null },
                                deepLinkTarget = deepLinkTarget.value,
                                onDeepLinkConsumed = { deepLinkTarget.value = null },
                            )
                        }
                    }
                }
            }
        }
    }
}
