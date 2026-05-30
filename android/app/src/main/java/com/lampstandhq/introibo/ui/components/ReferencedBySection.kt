package com.lampstandhq.introibo.ui.components

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.lampstandhq.introibo.data.links.LinkSource
import com.lampstandhq.introibo.data.search.DeepLinkTarget
import com.lampstandhq.introibo.ui.theme.IntroiboTheme
import com.lampstandhq.introibo.ui.theme.IntroiboType

/**
 * "Citatur In · Referenced By" footer (Phase 3). The bidirectional counterpart
 * to [RelatedLinksSection]: lists every entry that links TO the current document
 * (computed by LinkGraph.referencedBy). Each row's [LinkSource] carries the
 * source entry's own [DeepLinkTarget], dispatched through [onLinkTap] (which the
 * host wires to DeepLinkRouter.open).
 *
 * Renders nothing when [sources] is empty, so detail screens can include it
 * unconditionally; it stays invisible until seed links arrive (Phase 4).
 *
 * Mirror of:
 *   Introibo/Design/ReferencedBySection.swift
 */
@Composable
fun ReferencedBySection(
    sources: List<LinkSource>,
    onLinkTap: (DeepLinkTarget) -> Unit = {},
    modifier: Modifier = Modifier,
) {
    if (sources.isEmpty()) return

    val colors = IntroiboTheme.colors
    val type = IntroiboType.current

    Column(
        modifier = modifier
            .fillMaxWidth()
            .padding(top = 8.dp),
        verticalArrangement = Arrangement.spacedBy(12.dp),
    ) {
        SmallLabel(text = "Citatur In  ·  Referenced By", color = colors.goldLeaf)

        Column(verticalArrangement = Arrangement.spacedBy(10.dp)) {
            sources.forEach { source ->
                Row(
                    verticalAlignment = Alignment.Top,
                    horizontalArrangement = Arrangement.spacedBy(8.dp),
                    modifier = Modifier
                        .fillMaxWidth()
                        .clickable { onLinkTap(source.target) },
                ) {
                    Icon(
                        imageVector = Icons.AutoMirrored.Filled.ArrowBack,
                        contentDescription = null,
                        tint = colors.sanctuaryRed.copy(alpha = 0.7f),
                        modifier = Modifier.size(14.dp),
                    )
                    Text(
                        text = source.label,
                        style = type.body,
                        color = colors.sanctuaryRed,
                    )
                }
            }
        }
    }
}
