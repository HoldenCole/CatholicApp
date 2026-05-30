package com.lampstandhq.introibo.ui.theme

import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.Immutable
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.graphics.Color

// ---------------------------------------------------------------------------
// Raw colour tokens
// ---------------------------------------------------------------------------
// Canonical values from the prototype stylesheet. Do not invent new ones.
//   parchment  #F2E8D0   warm vellum
//   ink        #1C1410   warm black
//   sepia      #5A4A3A   body italic / descriptions
//   muted      #9A8670   meta text, Latin subtitles
//   red        #8B1A1A   sanctuary red (primary accent)
//   gold       #B8960C   gold leaf (ornaments only)
//   walnut     #1A130C   deep walnut (header gradient start, dark-mode bg)
//   walnutHi   #2C2015   walnut gradient end
//   ivory      #E8DFC9   antique ivory (dark-mode text)

object RawPalette {
    val Parchment = Color(0xFFF2E8D0)
    val Ink       = Color(0xFF1C1410)
    val Sepia     = Color(0xFF5A4A3A)
    val Muted     = Color(0xFF9A8670)
    val GoldLeaf  = Color(0xFFB8960C)
    val Walnut    = Color(0xFF1A130C)
    val WalnutHi  = Color(0xFF2C2015)
    val Ivory     = Color(0xFFE8DFC9)

    // Sanctuary red variants
    val RedLight  = Color(0xFF8B1A1A)
    val RedDark   = Color(0xFFDC5A5A)

    // Parchment-mode semantic overrides (darker for contrast against warm vellum)
    val ParchmentSecondaryText = Color(0xFF4C3E31)
    val ParchmentTertiaryText  = Color(0xFF7E6E5A)

    // Dark-mode semantic overrides
    val DarkPrimaryText   = Color(0xFFF0E9D7)
    val DarkSecondaryText = Color(0xFFC3B29B)
    val DarkTertiaryText  = Color(0xFF9B8973)

    // Liturgical colours (invariant across themes)
    val LiturgicalViolet = Color(0xFF6A359A)
    val LiturgicalRose   = Color(0xFFA04860)
    val LiturgicalWhite  = Color(0xFF7A5A0E)
    val LiturgicalGreen  = Color(0xFF3A5D28)

    // Dot colour used for the paper-grain overlay
    val GrainDot = Color(0xFF5C3C1E)
}

// ---------------------------------------------------------------------------
// Semantic colour scheme
// ---------------------------------------------------------------------------

@Immutable
data class IntroiboColorScheme(
    val pageBackground: Color,
    val primaryText: Color,
    val secondaryText: Color,
    val tertiaryText: Color,
    val sanctuaryRed: Color,
    val goldLeaf: Color,
    val ivory: Color,
    val muted: Color,
    val frameLine: Color,
    val walnut: Color,
    val walnutHi: Color,
    val parchment: Color,
)

// ---------------------------------------------------------------------------
// Theme instances
// ---------------------------------------------------------------------------

val parchmentColors = IntroiboColorScheme(
    pageBackground = RawPalette.Parchment,
    primaryText    = RawPalette.Ink,
    secondaryText  = RawPalette.ParchmentSecondaryText,
    tertiaryText   = RawPalette.ParchmentTertiaryText,
    sanctuaryRed   = RawPalette.RedLight,
    goldLeaf       = RawPalette.GoldLeaf,
    ivory          = RawPalette.Ivory,
    muted          = RawPalette.Muted,
    frameLine      = RawPalette.GoldLeaf.copy(alpha = 0.3f),
    walnut         = RawPalette.Walnut,
    walnutHi       = RawPalette.WalnutHi,
    parchment      = RawPalette.Parchment,
)

val whiteColors = IntroiboColorScheme(
    pageBackground = Color.White,
    primaryText    = RawPalette.Ink,
    secondaryText  = RawPalette.Sepia,
    tertiaryText   = RawPalette.Muted,
    sanctuaryRed   = RawPalette.RedLight,
    goldLeaf       = RawPalette.GoldLeaf,
    ivory          = RawPalette.Ivory,
    muted          = RawPalette.Muted,
    frameLine      = RawPalette.GoldLeaf.copy(alpha = 0.3f),
    walnut         = RawPalette.Walnut,
    walnutHi       = RawPalette.WalnutHi,
    parchment      = RawPalette.Parchment,
)

val darkColors = IntroiboColorScheme(
    pageBackground = RawPalette.Walnut,
    primaryText    = RawPalette.DarkPrimaryText,
    secondaryText  = RawPalette.DarkSecondaryText,
    tertiaryText   = RawPalette.DarkTertiaryText,
    sanctuaryRed   = RawPalette.RedDark,
    goldLeaf       = RawPalette.GoldLeaf,
    ivory          = RawPalette.Ivory,
    muted          = RawPalette.Muted,
    frameLine      = RawPalette.GoldLeaf.copy(alpha = 0.25f),
    walnut         = RawPalette.Walnut,
    walnutHi       = RawPalette.WalnutHi,
    parchment      = RawPalette.Parchment,
)

// ---------------------------------------------------------------------------
// CompositionLocal & theme accessor
// ---------------------------------------------------------------------------

val LocalIntroiboColors = staticCompositionLocalOf { parchmentColors }

/**
 * Introibo design-system theme wrapper and accessor.
 *
 * Usage:
 * ```
 * IntroiboTheme(themeKey = "parchment") {
 *     val colors = IntroiboTheme.colors
 *     Text("Hello", color = colors.primaryText)
 * }
 * ```
 */
object IntroiboTheme {
    /** Current [IntroiboColorScheme] from the nearest provider. */
    val colors: IntroiboColorScheme
        @Composable
        get() = LocalIntroiboColors.current

    /**
     * Provides the matching [IntroiboColorScheme] for [themeKey] to the
     * composition tree beneath [content].
     */
    @Composable
    operator fun invoke(
        themeKey: String = "parchment",
        content: @Composable () -> Unit,
    ) {
        val colors = when (themeKey) {
            "white" -> whiteColors
            "dark"  -> darkColors
            else    -> parchmentColors
        }

        CompositionLocalProvider(LocalIntroiboColors provides colors) {
            content()
        }
    }
}
