package com.lampstandhq.introibo.ui.components

import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.sp
import com.lampstandhq.introibo.ui.theme.IntroiboTheme
import com.lampstandhq.introibo.ui.theme.IntroiboType

/**
 * Small-caps label styled to match the iOS `.smallLabel()` modifier.
 *
 * Renders [text] in uppercase with wide letter-spacing and the label font,
 * exactly as used for rubric headings and section dividers throughout
 * the Introibo design system.
 *
 * @param text  Label text (will be uppercased automatically).
 * @param color Foreground colour; defaults to [IntroiboTheme.colors.tertiaryText].
 * @param modifier Optional [Modifier] for the underlying [Text].
 */
@Composable
fun SmallLabel(
    text: String,
    color: Color = IntroiboTheme.colors.tertiaryText,
    modifier: Modifier = Modifier,
) {
    val type = IntroiboType.current
    Text(
        text = text.uppercase(),
        style = type.smallLabel,
        color = color,
        letterSpacing = 2.5.sp,
        maxLines = 2,
        overflow = TextOverflow.Ellipsis,
        modifier = modifier,
    )
}
