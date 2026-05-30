package com.lampstandhq.introibo.ui.components

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowForward
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.lampstandhq.introibo.data.links.LinkTarget
import com.lampstandhq.introibo.data.links.RelatedLink
import com.lampstandhq.introibo.data.search.DeepLinkTarget
import com.lampstandhq.introibo.ui.theme.IntroiboTheme
import com.lampstandhq.introibo.ui.theme.IntroiboType

/**
 * "Vide Etiam · See Also" footer (Phase 2). A small, discoverable block listing
 * related links; each row's target string is parsed via [LinkTarget.parse] and
 * dispatched through [onLinkTap] (which the host wires to DeepLinkRouter.open).
 *
 * Renders nothing when [related] is null or empty, so detail screens can include
 * it unconditionally; it stays invisible until seed links arrive (Phase 4).
 *
 * Mirror of:
 *   Introibo/Design/RelatedLinksSection.swift
 */
@Composable
fun RelatedLinksSection(
    related: List<RelatedLink>?,
    onLinkTap: (DeepLinkTarget) -> Unit = {},
    modifier: Modifier = Modifier,
) {
    if (related.isNullOrEmpty()) return

    val colors = IntroiboTheme.colors
    val type = IntroiboType.current

    Column(
        modifier = modifier
            .fillMaxWidth()
            .padding(top = 8.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        SmallLabel(text = "Vide Etiam  ·  See Also", color = colors.goldLeaf)

        Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
            related.forEach { link ->
                val target = LinkTarget.parse(link.target)
                if (target != null) {
                    Row(
                        verticalAlignment = Alignment.Top,
                        horizontalArrangement = Arrangement.spacedBy(8.dp),
                        modifier = Modifier
                            .fillMaxWidth()
                            .clickable { onLinkTap(target) },
                    ) {
                        Icon(
                            imageVector = Icons.AutoMirrored.Filled.ArrowForward,
                            contentDescription = null,
                            tint = colors.sanctuaryRed.copy(alpha = 0.7f),
                            modifier = Modifier.size(14.dp),
                        )
                        Text(
                            text = link.label,
                            style = type.body,
                            color = colors.sanctuaryRed,
                        )
                    }
                }
            }
        }
    }
}
