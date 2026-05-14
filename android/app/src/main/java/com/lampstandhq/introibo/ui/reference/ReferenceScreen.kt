package com.lampstandhq.introibo.ui.reference

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Book
import androidx.compose.material.icons.filled.ChevronRight
import androidx.compose.material.icons.filled.History
import androidx.compose.material.icons.filled.LibraryBooks
import androidx.compose.material.icons.filled.MenuBook
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.unit.dp
import com.lampstandhq.introibo.data.content.ContentStore
import com.lampstandhq.introibo.ui.components.SmallLabel
import com.lampstandhq.introibo.ui.theme.IntroiboTheme
import com.lampstandhq.introibo.ui.theme.IntroiboType

private val quickLinkTitles = listOf(
    "The Holy Mass",
    "Baptism",
    "The Holy Eucharist",
    "Penance (Confession)",
    "The Rosary",
)

/**
 * Reference (Liber) tab screen. Shows section cards grid and
 * quick reference links. Ported from iOS ReferenceView.swift.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ReferenceScreen() {
    val colors = IntroiboTheme.colors
    val type = IntroiboType.current

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(colors.pageBackground),
    ) {
        TopAppBar(
            title = {
                Text(
                    text = "Liber",
                    style = type.titleM.copy(fontStyle = FontStyle.Italic),
                    color = colors.primaryText,
                )
            },
            colors = TopAppBarDefaults.topAppBarColors(
                containerColor = colors.pageBackground,
            ),
        )

        LazyColumn(
            modifier = Modifier
                .fillMaxSize()
                .padding(horizontal = 20.dp),
            verticalArrangement = Arrangement.spacedBy(28.dp),
        ) {
            item { Spacer(Modifier.height(4.dp)) }

            // ---- Sections Grid ----
            item {
                SectionsGrid()
            }

            // ---- Quick Links ----
            item {
                QuickLinksSection()
            }

            item { Spacer(Modifier.height(40.dp)) }
        }
    }
}

// ---------------------------------------------------------------------------
// Sections Grid
// ---------------------------------------------------------------------------

@Composable
private fun SectionsGrid() {
    val colors = IntroiboTheme.colors

    Column(verticalArrangement = Arrangement.spacedBy(12.dp)) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            SectionCard(
                icon = Icons.Filled.MenuBook,
                title = "References",
                latin = "Encyclopaedia",
                count = "${ContentStore.reference.size} articles",
                modifier = Modifier.weight(1f),
            )
            SectionCard(
                icon = Icons.Filled.Book,
                title = "Propers",
                latin = "Propria Missae",
                count = "${ContentStore.propers.size} formularies",
                modifier = Modifier.weight(1f),
            )
        }
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            SectionCard(
                icon = Icons.Filled.History,
                title = "History",
                latin = "Historia Missae",
                count = "Timeline",
                modifier = Modifier.weight(1f),
            )
            SectionCard(
                icon = Icons.Filled.LibraryBooks,
                title = "Glossary",
                latin = "Glossarium",
                count = "Liturgical terms",
                modifier = Modifier.weight(1f),
            )
        }
    }
}

@Composable
private fun SectionCard(
    icon: ImageVector,
    title: String,
    latin: String,
    count: String,
    modifier: Modifier = Modifier,
) {
    val colors = IntroiboTheme.colors
    val type = IntroiboType.current

    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        modifier = modifier
            .border(0.5.dp, colors.frameLine)
            .clickable { /* TODO: navigate to section */ }
            .padding(vertical = 20.dp),
    ) {
        Icon(
            imageVector = icon,
            contentDescription = title,
            tint = colors.sanctuaryRed,
            modifier = Modifier.size(24.dp),
        )
        Text(
            text = title,
            style = type.titleM.copy(fontStyle = FontStyle.Italic),
            color = colors.primaryText,
            modifier = Modifier.padding(top = 8.dp),
        )
        Text(
            text = latin,
            style = type.captionSm.copy(fontStyle = FontStyle.Italic),
            color = colors.secondaryText,
            modifier = Modifier.padding(top = 2.dp),
        )
        Text(
            text = count,
            style = type.captionSm,
            color = colors.tertiaryText,
            modifier = Modifier.padding(top = 2.dp),
        )
    }
}

// ---------------------------------------------------------------------------
// Quick Links
// ---------------------------------------------------------------------------

@Composable
private fun QuickLinksSection() {
    val colors = IntroiboTheme.colors
    val type = IntroiboType.current

    Column {
        // Header
        Row(
            verticalAlignment = Alignment.CenterVertically,
            modifier = Modifier.fillMaxWidth(),
        ) {
            Box(
                modifier = Modifier
                    .weight(1f)
                    .height(0.5.dp)
                    .background(colors.goldLeaf.copy(alpha = 0.4f)),
            )
            Text(
                text = "Quick Reference",
                style = type.captionSm.copy(fontStyle = FontStyle.Italic),
                color = colors.secondaryText,
                modifier = Modifier.padding(horizontal = 10.dp),
            )
            Box(
                modifier = Modifier
                    .weight(1f)
                    .height(0.5.dp)
                    .background(colors.goldLeaf.copy(alpha = 0.4f)),
            )
        }

        Spacer(Modifier.height(14.dp))

        quickLinkTitles.forEach { title ->
            val entry = ContentStore.reference.firstOrNull { it.title == title }
            if (entry != null) {
                Row(
                    verticalAlignment = Alignment.CenterVertically,
                    modifier = Modifier
                        .fillMaxWidth()
                        .clickable { /* TODO: open reference detail */ }
                        .padding(vertical = 8.dp),
                ) {
                    Text(
                        text = entry.title,
                        style = type.titleM.copy(fontStyle = FontStyle.Italic),
                        color = colors.primaryText,
                        modifier = Modifier.weight(1f),
                    )
                    Icon(
                        imageVector = Icons.Filled.ChevronRight,
                        contentDescription = null,
                        tint = colors.tertiaryText,
                        modifier = Modifier.size(12.dp),
                    )
                }
            }
        }
    }
}
