package com.lampstandhq.introibo.ui.theme

import androidx.compose.runtime.Composable
import androidx.compose.runtime.Immutable
import androidx.compose.runtime.compositionLocalOf
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.TextUnit
import androidx.compose.ui.unit.sp
import com.lampstandhq.introibo.storage.settings.FontSizeScale

/**
 * CompositionLocal carrying the current font-size scale factor.
 * Defaults to [FontSizeScale.DEFAULT_VALUE] (1.15x).
 */
val LocalFontScale = compositionLocalOf { FontSizeScale.DEFAULT_VALUE }

// ---------------------------------------------------------------------------
// Typography tokens
// ---------------------------------------------------------------------------
// The iOS app uses three families: Playfair Display (display), EB Garamond
// (body), and Cormorant Garamond (labels). Since we may not have these
// bundled on first pass we fall back to the system serif family — the same
// approach used in the iOS code when USE_BUNDLED_FONTS is false.

private val DisplayFamily = FontFamily.Serif
private val BodyFamily    = FontFamily.Serif
private val LabelFamily   = FontFamily.Serif

/**
 * All Introibo text styles, pre-scaled by the user's font-size preference.
 */
@Immutable
data class IntroiboTypography(
    /** 34sp semibold italic serif — top-level page headings */
    val pageTitle: TextStyle,
    /** 28sp semibold serif */
    val titleXL: TextStyle,
    /** 22sp semibold serif */
    val titleL: TextStyle,
    /** 18sp medium serif */
    val titleM: TextStyle,
    /** 16sp regular serif — main body text */
    val body: TextStyle,
    /** 16sp italic serif — body emphasis / English text */
    val bodyIt: TextStyle,
    /** 14sp regular serif — compact body */
    val bodySm: TextStyle,
    /** 12sp italic serif — captions */
    val captionSm: TextStyle,
    /** 11sp bold italic serif, uppercase + tracking — small labels / rubrics */
    val smallLabel: TextStyle,
)

/**
 * Build a full [IntroiboTypography] set scaled by [scale].
 */
fun introiboTypography(scale: Float = FontSizeScale.DEFAULT_VALUE): IntroiboTypography {
    fun scaled(size: Float): TextUnit = (size * scale).sp

    return IntroiboTypography(
        pageTitle = TextStyle(
            fontFamily = DisplayFamily,
            fontWeight = FontWeight.SemiBold,
            fontStyle = FontStyle.Italic,
            fontSize = scaled(34f),
        ),
        titleXL = TextStyle(
            fontFamily = DisplayFamily,
            fontWeight = FontWeight.SemiBold,
            fontSize = scaled(28f),
        ),
        titleL = TextStyle(
            fontFamily = DisplayFamily,
            fontWeight = FontWeight.SemiBold,
            fontSize = scaled(22f),
        ),
        titleM = TextStyle(
            fontFamily = DisplayFamily,
            fontWeight = FontWeight.Medium,
            fontSize = scaled(18f),
        ),
        body = TextStyle(
            fontFamily = BodyFamily,
            fontWeight = FontWeight.Normal,
            fontSize = scaled(16f),
        ),
        bodyIt = TextStyle(
            fontFamily = BodyFamily,
            fontWeight = FontWeight.Normal,
            fontStyle = FontStyle.Italic,
            fontSize = scaled(16f),
        ),
        bodySm = TextStyle(
            fontFamily = BodyFamily,
            fontWeight = FontWeight.Normal,
            fontSize = scaled(14f),
        ),
        captionSm = TextStyle(
            fontFamily = LabelFamily,
            fontWeight = FontWeight.Normal,
            fontStyle = FontStyle.Italic,
            fontSize = scaled(10f),
        ),
        smallLabel = TextStyle(
            fontFamily = LabelFamily,
            fontWeight = FontWeight.Bold,
            fontStyle = FontStyle.Italic,
            fontSize = scaled(11f),
            letterSpacing = 2.5.sp,
        ),
    )
}

// ---------------------------------------------------------------------------
// CompositionLocal
// ---------------------------------------------------------------------------

val LocalIntroiboTypography = compositionLocalOf { introiboTypography() }

/**
 * Convenience accessor: `IntroiboType.current` in a composable scope.
 */
object IntroiboType {
    val current: IntroiboTypography
        @Composable
        get() = LocalIntroiboTypography.current
}
