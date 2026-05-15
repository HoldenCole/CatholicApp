package com.lampstandhq.introibo.ui.reference

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.defaultMinSize
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Book
import androidx.compose.material.icons.filled.ChevronRight
import androidx.compose.material.icons.filled.History
import androidx.compose.material.icons.filled.LibraryBooks
import androidx.compose.material.icons.filled.MenuBook
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Text
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.rememberCoroutineScope
import com.lampstandhq.introibo.ui.components.SmallLabel
import kotlinx.coroutines.launch
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.unit.dp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import com.lampstandhq.introibo.data.content.ContentStore
import com.lampstandhq.introibo.data.model.MassProper
import com.lampstandhq.introibo.data.model.ReferenceEntry
import com.lampstandhq.introibo.ui.missal.ProperScreen
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

    var selectedEntry by remember { mutableStateOf<ReferenceEntry?>(null) }
    var selectedSection by remember { mutableStateOf<String?>(null) }

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
                SectionsGrid(onSectionClick = { section -> selectedSection = section })
            }

            // ---- Quick Links ----
            item {
                QuickLinksSection(onEntryClick = { entry -> selectedEntry = entry })
            }

            item { Spacer(Modifier.height(40.dp)) }
        }
    }

    var selectedProper by remember { mutableStateOf<MassProper?>(null) }

    // Section filter: show filtered list from that category
    selectedSection?.let { section ->
        if (section == "Propers") {
            PropersListSheet(
                onSelectProper = { proper ->
                    selectedSection = null
                    selectedProper = proper
                },
                onDismiss = { selectedSection = null },
            )
        } else {
            val entries = when (section) {
                "References" -> ContentStore.reference
                "History" -> ContentStore.reference.filter { it.cat == "Calendarium" }
                "Glossary" -> ContentStore.reference.filter { it.cat == "De Lingua Latina" }
                else -> emptyList()
            }
            if (entries.isNotEmpty()) {
                SectionListSheet(
                    title = section,
                    entries = entries,
                    onSelectEntry = { entry ->
                        selectedSection = null
                        selectedEntry = entry
                    },
                    onDismiss = { selectedSection = null },
                )
            } else {
                selectedSection = null
            }
        }
    }

    // Proper detail
    selectedProper?.let { proper ->
        Dialog(
            onDismissRequest = { selectedProper = null },
            properties = DialogProperties(usePlatformDefaultWidth = false),
        ) {
            ProperScreen(proper = proper, onDismiss = { selectedProper = null })
        }
    }

    // Reference detail bottom sheet
    selectedEntry?.let { entry ->
        ReferenceDetailScreen(
            entry = entry,
            onDismiss = { selectedEntry = null },
        )
    }
}

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun SectionListSheet(
    title: String,
    entries: List<ReferenceEntry>,
    onSelectEntry: (ReferenceEntry) -> Unit,
    onDismiss: () -> Unit,
) {
    val colors = IntroiboTheme.colors
    val type = IntroiboType.current
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    val scope = rememberCoroutineScope()

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = sheetState,
        containerColor = colors.pageBackground,
    ) {
        Column(modifier = Modifier.fillMaxSize()) {
            Row(
                modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 8.dp),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                IconButton(onClick = {
                    scope.launch { sheetState.hide() }.invokeOnCompletion { onDismiss() }
                }) {
                    Icon(Icons.AutoMirrored.Filled.ArrowBack, "Back", tint = colors.sanctuaryRed)
                }
                SmallLabel(text = title, color = colors.sanctuaryRed)
            }
            LazyColumn(
                modifier = Modifier.fillMaxSize().padding(horizontal = 20.dp),
                verticalArrangement = Arrangement.spacedBy(12.dp),
            ) {
                items(entries.size) { i ->
                    val entry = entries[i]
                    Column(
                        modifier = Modifier
                            .fillMaxWidth()
                            .clickable { onSelectEntry(entry) }
                            .padding(vertical = 8.dp),
                    ) {
                        Text(entry.title, style = type.titleM, color = colors.primaryText, fontStyle = FontStyle.Italic)
                        if (entry.latin != null) {
                            Text(entry.latin, style = type.captionSm, color = colors.secondaryText, fontStyle = FontStyle.Italic)
                        }
                    }
                    if (i < entries.size - 1) HorizontalDivider(color = colors.frameLine)
                }
            }
        }
    }
}

// ---------------------------------------------------------------------------
// Sections Grid
// ---------------------------------------------------------------------------

@Composable
private fun SectionsGrid(onSectionClick: (String) -> Unit = {}) {
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
                onClick = { onSectionClick("References") },
                modifier = Modifier.weight(1f),
            )
            SectionCard(
                icon = Icons.Filled.Book,
                title = "Propers",
                latin = "Missa et Sacramenta",
                count = "${ContentStore.reference.count { it.cat == "Missa et Sacramenta" }} articles",
                onClick = { onSectionClick("Propers") },
                modifier = Modifier.weight(1f),
            )
        }
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.spacedBy(12.dp),
        ) {
            SectionCard(
                icon = Icons.Filled.History,
                title = "Calendar",
                latin = "Calendarium",
                count = "${ContentStore.reference.count { it.cat == "Calendarium" }} articles",
                onClick = { onSectionClick("History") },
                modifier = Modifier.weight(1f),
            )
            SectionCard(
                icon = Icons.Filled.LibraryBooks,
                title = "Latin",
                latin = "De Lingua Latina",
                count = "${ContentStore.reference.count { it.cat == "De Lingua Latina" }} articles",
                onClick = { onSectionClick("Glossary") },
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
    onClick: () -> Unit = {},
    modifier: Modifier = Modifier,
) {
    val colors = IntroiboTheme.colors
    val type = IntroiboType.current

    Column(
        horizontalAlignment = Alignment.CenterHorizontally,
        modifier = modifier
            .border(0.5.dp, colors.frameLine)
            .clickable { onClick() }
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
private fun QuickLinksSection(onEntryClick: (ReferenceEntry) -> Unit = {}) {
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
                        .defaultMinSize(minHeight = 48.dp)
                        .clickable { onEntryClick(entry) }
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

// ---------------------------------------------------------------------------
// Propers List Sheet
// ---------------------------------------------------------------------------

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun PropersListSheet(
    onSelectProper: (MassProper) -> Unit,
    onDismiss: () -> Unit,
) {
    val colors = IntroiboTheme.colors
    val type = IntroiboType.current
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    val scope = rememberCoroutineScope()
    var search by remember { mutableStateOf("") }

    val propers = if (search.isBlank()) {
        ContentStore.propers
    } else {
        val q = search.lowercase()
        ContentStore.propers.filter {
            it.title.lowercase().contains(q) ||
            (it.english?.lowercase()?.contains(q) == true) ||
            it.slug.lowercase().contains(q)
        }
    }

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = sheetState,
        containerColor = colors.pageBackground,
    ) {
        Column(modifier = Modifier.fillMaxSize()) {
            Row(
                modifier = Modifier.fillMaxWidth().padding(horizontal = 16.dp, vertical = 8.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                IconButton(onClick = {
                    scope.launch { sheetState.hide() }.invokeOnCompletion { onDismiss() }
                }) {
                    Icon(Icons.AutoMirrored.Filled.ArrowBack, "Back", tint = colors.sanctuaryRed)
                }
                SmallLabel(text = "Propers · ${propers.size}", color = colors.sanctuaryRed)
            }

            androidx.compose.material3.TextField(
                value = search,
                onValueChange = { search = it },
                placeholder = { Text("Search propers…", style = type.body, color = colors.tertiaryText) },
                singleLine = true,
                modifier = Modifier.fillMaxWidth().padding(horizontal = 20.dp, vertical = 4.dp),
            )

            LazyColumn(
                modifier = Modifier.fillMaxSize().padding(horizontal = 20.dp),
                verticalArrangement = Arrangement.spacedBy(4.dp),
            ) {
                items(propers.size) { i ->
                    val proper = propers[i]
                    Column(
                        modifier = Modifier
                            .fillMaxWidth()
                            .defaultMinSize(minHeight = 48.dp)
                            .clickable { onSelectProper(proper) }
                            .padding(vertical = 8.dp),
                    ) {
                        Text(proper.title, style = type.titleM, color = colors.primaryText, fontStyle = FontStyle.Italic)
                        proper.english?.let { eng ->
                            Text(eng, style = type.captionSm, color = colors.secondaryText, fontStyle = FontStyle.Italic)
                        }
                    }
                    if (i < propers.size - 1) HorizontalDivider(color = colors.frameLine)
                }
            }
        }
    }
}
