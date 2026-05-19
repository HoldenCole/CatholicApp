package com.lampstandhq.introibo.ui.theme

import androidx.compose.runtime.Composable
import androidx.compose.runtime.Immutable
import androidx.compose.runtime.compositionLocalOf
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.Font
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.TextUnit
import androidx.compose.ui.unit.sp
import com.lampstandhq.introibo.R
import com.lampstandhq.introibo.storage.settings.FontSizeScale

/**
 * CompositionLocal carrying the current font-size scale factor.
 * Defaults to [FontSizeScale.DEFAULT_VALUE] (1.15x).
 */
val LocalFontScale = compositionLocalOf { FontSizeScale.DEFAULT_VALUE }

// ---------------------------------------------------------------------------
// Typography tokens — bundled fonts matching the iOS app
// ---------------------------------------------------------------------------

private val DisplayFamily = FontFamily(
    Font(R.font.playfair_display_regular, FontWeight.Normal, FontStyle.Normal),
    Font(R.font.playfair_display_regular, FontWeight.SemiBold, FontStyle.Normal),
    Font(R.font.playfair_display_italic, FontWeight.Normal, FontStyle.Italic),
    Font(R.font.playfair_display_italic, FontWeight.SemiBold, FontStyle.Italic),
)

private val BodyFamily = FontFamily(
    Font(R.font.eb_garamond_regular, FontWeight.Normal, FontStyle.Normal),
    Font(R.font.eb_garamond_italic, FontWeight.Normal, FontStyle.Italic),
)

private val LabelFamily = FontFamily(
    Font(R.font.cormorant_garamond_regular, FontWeight.Normal, FontStyle.Normal),
    Font(R.font.cormorant_garamond_italic, FontWeight.Normal, FontStyle.Italic),
    Font(R.font.cormorant_garamond_bolditalic, FontWeight.Bold, FontStyle.Italic),
)

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
            fontSize = 34.sp,
        ),
        titleXL = TextStyle(
            fontFamily = DisplayFamily,
            fontWeight = FontWeight.SemiBold,
            fontSize = 28.sp,
        ),
        titleL = TextStyle(
            fontFamily = DisplayFamily,
            fontWeight = FontWeight.SemiBold,
            fontSize = 22.sp,
        ),
        titleM = TextStyle(
            fontFamily = DisplayFamily,
            fontWeight = FontWeight.Medium,
            fontSize = 18.sp,
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
            fontSize = 10.sp,
        ),
        smallLabel = TextStyle(
            fontFamily = LabelFamily,
            fontWeight = FontWeight.Bold,
            fontStyle = FontStyle.Italic,
            fontSize = 11.sp,
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
