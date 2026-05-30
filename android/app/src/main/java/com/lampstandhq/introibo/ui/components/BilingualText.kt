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
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.LinkAnnotation
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.TextLinkStyles
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.style.TextDecoration
import androidx.compose.ui.text.withLink
import androidx.compose.ui.unit.dp
import com.lampstandhq.introibo.data.links.LinkMarkup
import com.lampstandhq.introibo.data.links.TextRun
import com.lampstandhq.introibo.data.model.strippingEm
import com.lampstandhq.introibo.data.search.DeepLinkTarget
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
    onLinkTap: (DeepLinkTarget) -> Unit = {},
) {
    val colors = IntroiboTheme.colors
    val type = IntroiboType.current
    // Render bodies through the inline-link parser. For a body with NO `<link>`
    // tags, LinkMarkup.runs returns a single TextRun.Text(body.strippingEm), so
    // the AnnotatedString carries the exact same characters and no spans —
    // i.e. visually identical to the previous plain Text(strippingEm).
    val cleanLat = linkedAnnotatedString(lat, colors.sanctuaryRed, onLinkTap)
    val cleanEng = linkedAnnotatedString(eng, colors.sanctuaryRed, onLinkTap)

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
 * Builds an [AnnotatedString] from inline `<link>` markup. Plain runs are
 * appended verbatim; link runs are wrapped in a [LinkAnnotation.Clickable]
 * styled sanctuary-red + underline, whose handler dispatches [onLinkTap] with
 * the parsed [DeepLinkTarget]. A link-free body yields a single plain run
 * identical to `body.strippingEm`. Mirrors iOS `ContextualLink.attributed`.
 */
private fun linkedAnnotatedString(
    body: String,
    linkColor: Color,
    onLinkTap: (DeepLinkTarget) -> Unit,
): AnnotatedString = buildAnnotatedString {
    for (run in LinkMarkup.runs(body)) {
        when (run) {
            is TextRun.Text -> append(run.text)
            is TextRun.Link -> {
                val target = run.target
                val link = LinkAnnotation.Clickable(
                    tag = target.wireString,
                    styles = TextLinkStyles(
                        style = SpanStyle(
                            color = linkColor,
                            textDecoration = TextDecoration.Underline,
                        ),
                    ),
                ) { onLinkTap(target) }
                withLink(link) { append(run.text) }
            }
        }
    }
}

/**
 * Shows Latin and/or English label text based on language mode.
 * In Both mode, shows Latin on top and English below.
 * Inherits color from LocalContentColor so it works on any background.
 */
@Composable
fun LanguageAwareLabel(
    latin: String,
    english: String,
    modifier: Modifier = Modifier,
    style: androidx.compose.ui.text.TextStyle = IntroiboType.current.captionSm.copy(fontStyle = androidx.compose.ui.text.font.FontStyle.Italic),
    color: androidx.compose.ui.graphics.Color = androidx.compose.material3.LocalContentColor.current,
) {
    when (currentLanguageMode()) {
        LanguageMode.LATIN_ONLY -> Text(latin, style = style, color = color, modifier = modifier)
        LanguageMode.VERNACULAR -> Text(english, style = style, color = color, modifier = modifier)
        LanguageMode.BOTH -> Column(modifier = modifier) {
            Text(latin, style = style, color = color)
            Text(english, style = style, color = color)
        }
    }
}
