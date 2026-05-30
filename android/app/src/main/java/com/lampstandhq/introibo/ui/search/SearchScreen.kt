package com.lampstandhq.introibo.ui.search

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
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
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.text.KeyboardOptions
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Clear
import androidx.compose.material.icons.filled.Close
import androidx.compose.material.icons.filled.Search
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Text
import androidx.compose.material3.TextField
import androidx.compose.material3.TextFieldDefaults
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.text.AnnotatedString
import androidx.compose.ui.text.SpanStyle
import androidx.compose.ui.text.buildAnnotatedString
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.input.ImeAction
import androidx.compose.ui.text.input.KeyboardCapitalization
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.text.withStyle
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.lampstandhq.introibo.data.content.ContentStore
import com.lampstandhq.introibo.data.model.strippingEm
import com.lampstandhq.introibo.data.search.ContentType
import com.lampstandhq.introibo.data.search.SearchMatcher
import com.lampstandhq.introibo.data.search.SearchResult
import com.lampstandhq.introibo.data.search.SearchSnippet
import com.lampstandhq.introibo.ui.components.SmallLabel
import com.lampstandhq.introibo.ui.theme.IntroiboTheme
import com.lampstandhq.introibo.ui.theme.IntroiboType
import kotlinx.coroutines.delay

// ---------------------------------------------------------------------------
// SearchScreen (Phase 2: search UI)
// ---------------------------------------------------------------------------
//
// Full-screen cross-content search, mirror of iOS Introibo/Screens/Search/
// SearchView.swift. Zero-network: results come from the in-memory
// ContentStore.searchIndex via the pure SearchMatcher. No OkHttp / analytics.
//
// Phase 3 will wire result taps to deep-link navigation; for now a tap logs the
// target and dismisses.

// ---- ContentType display helpers ----

private val ContentType.displayName: String
    get() = when (this) {
        ContentType.PRAYER -> "Prayers"
        ContentType.MISSAL -> "Missal"
        ContentType.OFFICE -> "Office"
        ContentType.REFERENCE -> "Reference"
        ContentType.SAINT -> "Saints"
        ContentType.CALENDAR -> "Calendar"
    }

/** Stable display order for grouped sections. */
private val contentTypeDisplayOrder = listOf(
    ContentType.PRAYER, ContentType.MISSAL, ContentType.OFFICE,
    ContentType.REFERENCE, ContentType.SAINT, ContentType.CALENDAR,
)

// ---- Filter model ----

private sealed class SearchFilter(val label: String, val contentType: ContentType?) {
    data object All : SearchFilter("All", null)
    data class Type(val type: ContentType) : SearchFilter(type.displayName, type)
}

private val searchFilters: List<SearchFilter> = listOf(
    SearchFilter.All,
    SearchFilter.Type(ContentType.PRAYER),
    SearchFilter.Type(ContentType.MISSAL),
    SearchFilter.Type(ContentType.OFFICE),
    SearchFilter.Type(ContentType.REFERENCE),
    SearchFilter.Type(ContentType.SAINT),
    SearchFilter.Type(ContentType.CALENDAR),
)

// ---------------------------------------------------------------------------
// SearchScreen composable
// ---------------------------------------------------------------------------

@Composable
fun SearchScreen(
    onDismiss: () -> Unit,
) {
    val colors = IntroiboTheme.colors
    val type = IntroiboType.current

    var query by remember { mutableStateOf("") }
    var filter by remember { mutableStateOf<SearchFilter>(SearchFilter.All) }
    var results by remember { mutableStateOf<List<SearchResult>>(emptyList()) }

    // Debounced search: re-runs 250ms after the query stops changing, and
    // immediately when the filter changes. LaunchedEffect cancels the previous
    // coroutine whenever its keys change, giving us the debounce for free.
    LaunchedEffect(query, filter) {
        if (query.isNotEmpty()) delay(250)
        results = if (query.isBlank()) {
            emptyList()
        } else {
            SearchMatcher.search(query, ContentStore.searchIndex, filter.contentType)
        }
    }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(colors.pageBackground),
    ) {
        // ---- Header: title row + search field ----
        Column(
            modifier = Modifier
                .fillMaxWidth()
                .padding(horizontal = 24.dp)
                .padding(top = 20.dp, bottom = 12.dp),
        ) {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                modifier = Modifier.fillMaxWidth(),
            ) {
                SmallLabel(text = "Quaerere", color = colors.sanctuaryRed)
                Spacer(Modifier.weight(1f))
                IconButton(onClick = onDismiss, modifier = Modifier.size(28.dp)) {
                    Icon(
                        imageVector = Icons.Filled.Close,
                        contentDescription = "Close",
                        tint = colors.tertiaryText,
                        modifier = Modifier.size(18.dp),
                    )
                }
            }

            Spacer(Modifier.height(12.dp))

            TextField(
                value = query,
                onValueChange = { query = it },
                placeholder = {
                    Text(
                        text = "Search prayers, Mass, Office…",
                        style = type.body,
                        color = colors.tertiaryText,
                    )
                },
                leadingIcon = {
                    Icon(
                        imageVector = Icons.Filled.Search,
                        contentDescription = null,
                        tint = colors.tertiaryText,
                    )
                },
                trailingIcon = {
                    if (query.isNotEmpty()) {
                        IconButton(onClick = { query = "" }) {
                            Icon(
                                imageVector = Icons.Filled.Clear,
                                contentDescription = "Clear",
                                tint = colors.tertiaryText,
                            )
                        }
                    }
                },
                singleLine = true,
                textStyle = type.body.copy(color = colors.primaryText),
                keyboardOptions = KeyboardOptions(
                    capitalization = KeyboardCapitalization.None,
                    imeAction = ImeAction.Search,
                ),
                colors = TextFieldDefaults.colors(
                    focusedContainerColor = Color.Transparent,
                    unfocusedContainerColor = Color.Transparent,
                    focusedIndicatorColor = colors.sanctuaryRed,
                    unfocusedIndicatorColor = colors.frameLine,
                    cursorColor = colors.sanctuaryRed,
                ),
                modifier = Modifier.fillMaxWidth(),
            )
        }

        // ---- Filter chip row ----
        Row(
            modifier = Modifier
                .fillMaxWidth()
                .horizontalScroll(rememberScrollState())
                .padding(horizontal = 24.dp)
                .padding(bottom = 12.dp),
            horizontalArrangement = Arrangement.spacedBy(8.dp),
        ) {
            searchFilters.forEach { f ->
                val selected = f.label == filter.label
                FilterPill(
                    label = f.label,
                    selected = selected,
                    onClick = { filter = f },
                )
            }
        }

        HorizontalDivider(color = colors.frameLine, thickness = 0.5.dp)

        // ---- Results / states ----
        when {
            query.isBlank() -> EmptyPrompt()
            results.isEmpty() -> NoResults()
            else -> ResultsList(results = results, onSelect = { result ->
                // Phase 3: DeepLinkRouter.open(result.document.target)
                println("Search tap → ${result.document.id} target=${result.document.target}")
                onDismiss()
            })
        }
    }
}

// ---------------------------------------------------------------------------
// Filter pill (palette-styled to match the iOS chips)
// ---------------------------------------------------------------------------

@Composable
private fun FilterPill(
    label: String,
    selected: Boolean,
    onClick: () -> Unit,
) {
    val colors = IntroiboTheme.colors
    val type = IntroiboType.current
    Box(
        modifier = Modifier
            .clickable(onClick = onClick)
            .background(if (selected) colors.sanctuaryRed else Color.Transparent)
            .border(0.5.dp, if (selected) colors.sanctuaryRed else colors.frameLine)
            .padding(horizontal = 14.dp, vertical = 6.dp),
    ) {
        Text(
            text = label,
            style = type.captionSm.copy(fontStyle = FontStyle.Italic, fontSize = 12.sp),
            color = if (selected) colors.parchment else colors.secondaryText,
        )
    }
}

// ---------------------------------------------------------------------------
// Result list & rows
// ---------------------------------------------------------------------------

@Composable
private fun ResultsList(
    results: List<SearchResult>,
    onSelect: (SearchResult) -> Unit,
) {
    val colors = IntroiboTheme.colors
    LazyColumn(modifier = Modifier.fillMaxSize()) {
        contentTypeDisplayOrder.forEach { type ->
            val group = results.filter { it.document.type == type }
            if (group.isNotEmpty()) {
                item(key = "header-${type.wire}") {
                    SmallLabel(
                        text = type.displayName,
                        color = colors.sanctuaryRed,
                        modifier = Modifier
                            .padding(horizontal = 24.dp)
                            .padding(top = 18.dp, bottom = 8.dp),
                    )
                }
                items(group, key = { it.document.id }) { result ->
                    ResultRow(result = result, onClick = { onSelect(result) })
                }
            }
        }
    }
}

@Composable
private fun ResultRow(
    result: SearchResult,
    onClick: () -> Unit,
) {
    val colors = IntroiboTheme.colors
    val type = IntroiboType.current
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .clickable(onClick = onClick)
            .padding(horizontal = 24.dp, vertical = 10.dp),
    ) {
        Row(verticalAlignment = Alignment.Top) {
            Box(modifier = Modifier.width(24.dp)) {
                Text(
                    text = typeIndicator(result.document.type),
                    style = type.captionSm,
                    color = colors.goldLeaf,
                )
            }
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = result.document.title.strippingEm,
                    style = type.titleM,
                    color = colors.primaryText,
                )
                result.document.subtitle?.takeIf { it.isNotEmpty() }?.let { sub ->
                    Text(
                        text = sub.strippingEm,
                        style = type.captionSm.copy(fontStyle = FontStyle.Italic),
                        color = colors.tertiaryText,
                    )
                }
                Text(
                    text = highlightedSnippet(result.snippet, colors.sanctuaryRed),
                    style = type.bodySm,
                    color = colors.secondaryText,
                    maxLines = 2,
                    overflow = TextOverflow.Ellipsis,
                )
            }
        }
        Spacer(Modifier.height(10.dp))
        HorizontalDivider(color = colors.frameLine, thickness = 0.5.dp)
    }
}

/** Short text type indicator (parity with iOS SF Symbol pip). */
private fun typeIndicator(type: ContentType): String = when (type) {
    ContentType.PRAYER -> "✠"
    ContentType.MISSAL -> "M"
    ContentType.OFFICE -> "H"
    ContentType.REFERENCE -> "R"
    ContentType.SAINT -> "S"
    ContentType.CALENDAR -> "K"
}

/**
 * Builds an AnnotatedString from the snippet, applying a sanctuary-red bold
 * span on each highlight range. Ranges are character offsets produced by the
 * matcher against this same snippet text, so they are always valid bounds.
 */
private fun highlightedSnippet(snippet: SearchSnippet, highlightColor: Color): AnnotatedString =
    buildAnnotatedString {
        val text = snippet.text
        // Sort + clamp ranges defensively so overlapping/out-of-bounds spans
        // can never throw.
        val ranges = snippet.highlightRanges
            .map { it.first.coerceIn(0, text.length) to (it.last + 1).coerceIn(0, text.length) }
            .filter { it.first < it.second }
            .sortedBy { it.first }
        var cursor = 0
        for ((start, end) in ranges) {
            if (start < cursor) continue // skip overlap
            if (start > cursor) append(text.substring(cursor, start))
            withStyle(SpanStyle(color = highlightColor, fontWeight = FontWeight.SemiBold)) {
                append(text.substring(start, end))
            }
            cursor = end
        }
        if (cursor < text.length) append(text.substring(cursor))
    }

// ---------------------------------------------------------------------------
// Empty / no-result states
// ---------------------------------------------------------------------------

@Composable
private fun EmptyPrompt() {
    val colors = IntroiboTheme.colors
    val type = IntroiboType.current
    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(horizontal = 40.dp),
        verticalArrangement = Arrangement.Center,
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Text(text = "✠", style = type.titleL, color = colors.sanctuaryRed)
        Spacer(Modifier.height(10.dp))
        Text(
            text = "Search the whole library",
            style = type.titleM.copy(fontStyle = FontStyle.Italic),
            color = colors.primaryText,
        )
        Spacer(Modifier.height(6.dp))
        Text(
            text = "Prayers, the Mass, the Office, reference, saints, and the calendar.",
            style = type.captionSm.copy(fontStyle = FontStyle.Italic),
            color = colors.secondaryText,
            textAlign = TextAlign.Center,
        )
    }
}

@Composable
private fun NoResults() {
    val colors = IntroiboTheme.colors
    val type = IntroiboType.current
    Column(
        modifier = Modifier.fillMaxSize(),
        verticalArrangement = Arrangement.Center,
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Text(
            text = "No results",
            style = type.titleM.copy(fontStyle = FontStyle.Italic),
            color = colors.primaryText,
        )
        Spacer(Modifier.height(8.dp))
        SmallLabel(text = "Nihil inventum", color = colors.tertiaryText)
    }
}
