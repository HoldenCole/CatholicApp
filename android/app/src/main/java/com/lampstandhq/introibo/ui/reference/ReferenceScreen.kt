package com.lampstandhq.introibo.ui.reference

import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.IntrinsicSize
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.defaultMinSize
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.filled.ArrowBack
import androidx.compose.material.icons.filled.Book
import androidx.compose.material.icons.filled.ChevronRight
import androidx.compose.material.icons.filled.History
import androidx.compose.material.icons.filled.LibraryBooks
import androidx.compose.material.icons.filled.MenuBook
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Text
import androidx.compose.material3.TextField
import androidx.compose.material3.TextFieldDefaults
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.compose.ui.window.Dialog
import androidx.compose.ui.window.DialogProperties
import com.lampstandhq.introibo.data.content.ContentStore
import com.lampstandhq.introibo.data.model.MassProper
import com.lampstandhq.introibo.data.model.ReferenceEntry
import com.lampstandhq.introibo.storage.settings.LanguageMode
import com.lampstandhq.introibo.ui.components.SmallLabel
import com.lampstandhq.introibo.ui.components.currentLanguageMode
import com.lampstandhq.introibo.ui.missal.ProperScreen
import com.lampstandhq.introibo.ui.theme.IntroiboTheme
import com.lampstandhq.introibo.ui.theme.IntroiboType
import kotlinx.coroutines.launch

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

    // Section sheets
    selectedSection?.let { section ->
        when (section) {
            "References" -> {
                ReferenceListSheet(
                    onSelectEntry = { entry ->
                        selectedSection = null
                        selectedEntry = entry
                    },
                    onDismiss = { selectedSection = null },
                )
            }
            "Propers" -> {
                PropersListSheet(
                    onSelectProper = { proper ->
                        selectedSection = null
                        selectedProper = proper
                    },
                    onDismiss = { selectedSection = null },
                )
            }
            "History" -> {
                TLMHistorySheet(
                    onDismiss = { selectedSection = null },
                )
            }
            "Glossary" -> {
                GlossarySheet(
                    onDismiss = { selectedSection = null },
                )
            }
            else -> {
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

// ---------------------------------------------------------------------------
// Reference List Sheet (grouped by category)
// ---------------------------------------------------------------------------

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun ReferenceListSheet(
    onSelectEntry: (ReferenceEntry) -> Unit,
    onDismiss: () -> Unit,
) {
    val colors = IntroiboTheme.colors
    val type = IntroiboType.current
    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    val scope = rememberCoroutineScope()

    val grouped = remember {
        val seen = mutableListOf<String>()
        val buckets = mutableMapOf<String, MutableList<ReferenceEntry>>()
        for (e in ContentStore.reference) {
            if (e.cat !in buckets) {
                seen.add(e.cat)
                buckets[e.cat] = mutableListOf()
            }
            buckets[e.cat]!!.add(e)
        }
        seen.map { cat -> cat to (buckets[cat] ?: emptyList()) }
    }

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = sheetState,
        containerColor = colors.pageBackground,
    ) {
        Column(modifier = Modifier.fillMaxSize()) {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp, vertical = 8.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                IconButton(onClick = {
                    scope.launch { sheetState.hide() }.invokeOnCompletion { onDismiss() }
                }) {
                    Icon(Icons.AutoMirrored.Filled.ArrowBack, "Back", tint = colors.sanctuaryRed)
                }
                SmallLabel(text = "References", color = colors.sanctuaryRed)
            }

            LazyColumn(
                modifier = Modifier
                    .fillMaxSize()
                    .padding(horizontal = 20.dp),
            ) {
                item { Spacer(Modifier.height(4.dp)) }

                grouped.forEach { (category, items) ->
                    // Category header
                    item(key = "cat_$category") {
                        Row(
                            verticalAlignment = Alignment.CenterVertically,
                            modifier = Modifier
                                .fillMaxWidth()
                                .padding(top = 8.dp),
                        ) {
                            Box(
                                modifier = Modifier
                                    .weight(1f)
                                    .height(1.dp)
                                    .background(colors.sanctuaryRed.copy(alpha = 0.4f)),
                            )
                            Text(
                                text = category.uppercase(),
                                style = type.titleM.copy(fontStyle = FontStyle.Italic),
                                color = colors.sanctuaryRed,
                                letterSpacing = 2.sp,
                                modifier = Modifier.padding(horizontal = 10.dp),
                            )
                            Box(
                                modifier = Modifier
                                    .weight(1f)
                                    .height(1.dp)
                                    .background(colors.sanctuaryRed.copy(alpha = 0.4f)),
                            )
                        }
                        Spacer(Modifier.height(14.dp))
                    }

                    // Entries in this category
                    items.forEachIndexed { index, entry ->
                        item(key = "entry_${entry.slug}") {
                            Column(
                                modifier = Modifier
                                    .fillMaxWidth()
                                    .clickable { onSelectEntry(entry) }
                                    .padding(vertical = 6.dp),
                            ) {
                                Text(
                                    text = entry.title,
                                    style = type.titleM.copy(fontStyle = FontStyle.Italic),
                                    color = colors.primaryText,
                                )
                                if (entry.latin != null && currentLanguageMode() != LanguageMode.VERNACULAR) {
                                    Text(
                                        text = entry.latin,
                                        style = type.captionSm.copy(fontStyle = FontStyle.Italic),
                                        color = colors.secondaryText,
                                    )
                                }
                                Text(
                                    text = entry.summary,
                                    style = type.captionSm,
                                    color = colors.tertiaryText,
                                    maxLines = 1,
                                    overflow = TextOverflow.Ellipsis,
                                    modifier = Modifier.padding(top = 2.dp),
                                )
                            }
                            if (index < items.size - 1) {
                                HorizontalDivider(color = colors.frameLine)
                            }
                        }
                    }

                    item(key = "spacer_$category") {
                        Spacer(Modifier.height(28.dp))
                    }
                }

                item { Spacer(Modifier.height(40.dp)) }
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

    val propers = remember(search) {
        if (search.isBlank()) {
            ContentStore.allPropers
        } else {
            val q = search.lowercase()
            ContentStore.allPropers.filter {
                it.title.lowercase().contains(q) ||
                it.english.lowercase().contains(q) ||
                it.epistle.ref.lowercase().contains(q) ||
                it.gospel.ref.lowercase().contains(q) ||
                it.slug.lowercase().contains(q)
            }
        }
    }

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = sheetState,
        containerColor = colors.pageBackground,
    ) {
        Column(modifier = Modifier.fillMaxSize()) {
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp, vertical = 8.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                IconButton(onClick = {
                    scope.launch { sheetState.hide() }.invokeOnCompletion { onDismiss() }
                }) {
                    Icon(Icons.AutoMirrored.Filled.ArrowBack, "Back", tint = colors.sanctuaryRed)
                }
                SmallLabel(text = "Propers · ${propers.size}", color = colors.sanctuaryRed)
            }

            // Search bar
            Row(
                verticalAlignment = Alignment.CenterVertically,
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 20.dp)
                    .background(colors.frameLine.copy(alpha = 0.3f))
                    .padding(horizontal = 12.dp, vertical = 4.dp),
            ) {
                Icon(
                    imageVector = Icons.Filled.MenuBook,
                    contentDescription = null,
                    tint = colors.tertiaryText,
                    modifier = Modifier.size(18.dp),
                )
                TextField(
                    value = search,
                    onValueChange = { search = it },
                    placeholder = {
                        Text(
                            "Search by saint, date, or scripture",
                            style = type.body,
                            color = colors.tertiaryText,
                        )
                    },
                    singleLine = true,
                    colors = TextFieldDefaults.colors(
                        focusedContainerColor = Color.Transparent,
                        unfocusedContainerColor = Color.Transparent,
                        focusedIndicatorColor = Color.Transparent,
                        unfocusedIndicatorColor = Color.Transparent,
                        cursorColor = colors.primaryText,
                    ),
                    textStyle = type.body.copy(color = colors.primaryText),
                    modifier = Modifier
                        .weight(1f)
                        .padding(start = 8.dp),
                )
            }

            Spacer(Modifier.height(4.dp))

            LazyColumn(
                modifier = Modifier.fillMaxSize(),
            ) {
                items(propers.size) { i ->
                    val proper = propers[i]
                    Column(
                        modifier = Modifier
                            .fillMaxWidth()
                            .clickable { onSelectProper(proper) }
                            .padding(vertical = 10.dp, horizontal = 20.dp),
                    ) {
                        Text(
                            text = proper.title,
                            style = type.titleM.copy(fontStyle = FontStyle.Italic),
                            color = colors.primaryText,
                        )
                        if (currentLanguageMode() != LanguageMode.LATIN_ONLY) {
                            Text(
                                text = proper.english,
                                style = type.captionSm.copy(fontStyle = FontStyle.Italic),
                                color = colors.secondaryText,
                                modifier = Modifier.padding(top = 3.dp),
                            )
                        }
                        if (proper.epistle.ref.isNotEmpty() || proper.gospel.ref.isNotEmpty()) {
                            Row(
                                horizontalArrangement = Arrangement.spacedBy(8.dp),
                                modifier = Modifier.padding(top = 2.dp),
                            ) {
                                if (proper.epistle.ref.isNotEmpty()) {
                                    Text(
                                        text = "Ep. ${proper.epistle.ref}",
                                        style = type.captionSm,
                                        color = colors.tertiaryText,
                                    )
                                }
                                if (proper.gospel.ref.isNotEmpty()) {
                                    Text(
                                        text = "Ev. ${proper.gospel.ref}",
                                        style = type.captionSm,
                                        color = colors.tertiaryText,
                                    )
                                }
                            }
                        }
                    }
                    HorizontalDivider(
                        color = colors.frameLine,
                        modifier = Modifier.padding(start = 20.dp),
                    )
                }
            }
        }
    }
}

// ---------------------------------------------------------------------------
// TLM History Timeline Sheet
// ---------------------------------------------------------------------------

private data class TimelineEvent(
    val year: String,
    val title: String,
    val desc: String,
)

private val tlmHistoryEvents = listOf(
    TimelineEvent("33 AD", "The Last Supper", "Our Lord institutes the Holy Sacrifice of the Mass at the Last Supper, commanding the Apostles to do this in memory of Him."),
    TimelineEvent("c. 100", "Apostolic Liturgy", "The Didache describes early Christian worship with prayers over bread and wine following the pattern established by the Apostles."),
    TimelineEvent("c. 225", "Apostolic Tradition", "Hippolytus of Rome records the earliest known Eucharistic Prayer, showing the Roman Canon already taking shape."),
    TimelineEvent("c. 380", "Latin Becomes Standard", "Pope Damasus I commissions the Vulgate Bible and Latin replaces Greek as the language of the Roman liturgy."),
    TimelineEvent("590–604", "Pope St. Gregory the Great", "Reforms and codifies the Roman liturgy. The Canon of the Mass reaches essentially its final form. Gregorian Chant is organized."),
    TimelineEvent("800", "Carolingian Standardisation", "Charlemagne mandates the Roman Rite throughout his empire, spreading the Gregorian liturgy across Western Europe."),
    TimelineEvent("1215", "Fourth Lateran Council", "Defines transubstantiation as dogma. Mandates annual confession and communion. The Mass is the centre of Catholic life."),
    TimelineEvent("1474", "First Printed Missal", "The Missale Romanum is among the first books printed, standardising the texts that had been transmitted in manuscripts."),
    TimelineEvent("1545–1563", "Council of Trent", "Responds to the Protestant Reformation by affirming the sacrificial nature of the Mass and mandating liturgical reform."),
    TimelineEvent("1570", "Missal of Pius V", "Pope St. Pius V promulgates the Tridentine Missal, codifying the Roman Rite and establishing liturgical uniformity."),
    TimelineEvent("1604", "Clement VIII Revision", "Minor corrections to the Missale Romanum, refining rubrics without altering the substance of the rite."),
    TimelineEvent("1634", "Urban VIII Revision", "Further small revisions to hymns and rubrics. The Mass remains substantially unchanged for centuries."),
    TimelineEvent("1911–1913", "Pius X Breviary Reform", "Reorganises the Divine Office psalmody. The Mass itself remains untouched."),
    TimelineEvent("1955", "Holy Week Reforms", "Pius XII reforms the Holy Week liturgy, the most significant change to the Mass since 1570."),
    TimelineEvent("1962", "The 1962 Missal", "Pope John XXIII issues the last edition of the Tridentine Missal, incorporating minor rubrical changes. This is the Missal used by traditional Catholics today."),
    TimelineEvent("1969", "Novus Ordo Missae", "Paul VI promulgates the new Mass. The traditional Mass is widely suppressed but never formally abrogated."),
    TimelineEvent("1984", "Quattuor Abhinc Annos", "John Paul II permits limited use of the 1962 Missal under indult, beginning the restoration of the traditional Mass."),
    TimelineEvent("1988", "Ecclesia Dei", "After the consecrations by Archbishop Lefebvre, John Paul II establishes the Ecclesia Dei Commission and calls for generous provision of the traditional Mass."),
    TimelineEvent("2007", "Summorum Pontificum", "Benedict XVI declares that the traditional Mass was never abrogated and frees its celebration, recognising it as the Extraordinary Form."),
    TimelineEvent("2021", "Traditionis Custodes", "Francis restricts the traditional Mass. Traditional Catholic communities continue to grow worldwide."),
)

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun TLMHistorySheet(
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
        dragHandle = null,
    ) {
        Column(modifier = Modifier.fillMaxSize()) {
            // Back row
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp, vertical = 8.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                IconButton(onClick = {
                    scope.launch { sheetState.hide() }.invokeOnCompletion { onDismiss() }
                }) {
                    Icon(Icons.AutoMirrored.Filled.ArrowBack, "Back", tint = colors.sanctuaryRed)
                }
                SmallLabel(text = "History", color = colors.sanctuaryRed)
            }

            LazyColumn(modifier = Modifier.fillMaxSize()) {
                // Header
                item {
                    Column(
                        modifier = Modifier
                            .fillMaxWidth()
                            .background(
                                Brush.verticalGradient(
                                    listOf(colors.walnut, colors.walnutHi)
                                )
                            ),
                        horizontalAlignment = Alignment.CenterHorizontally,
                    ) {
                        Spacer(Modifier.height(24.dp))
                        Text(
                            text = "✠",
                            style = type.pageTitle.copy(fontSize = 36.sp),
                            color = colors.sanctuaryRed.copy(alpha = 0.6f),
                        )
                        Spacer(Modifier.height(8.dp))
                        Text(
                            text = "History of the Mass",
                            style = type.pageTitle,
                            color = colors.ivory,
                        )
                        Text(
                            text = "FROM THE LAST SUPPER TO THE PRESENT DAY",
                            style = type.captionSm.copy(fontStyle = FontStyle.Italic),
                            color = colors.muted,
                            letterSpacing = 2.5.sp,
                            modifier = Modifier.padding(top = 4.dp),
                        )
                        Spacer(Modifier.height(14.dp))
                        Box(
                            modifier = Modifier
                                .width(60.dp)
                                .height(0.5.dp)
                                .background(colors.goldLeaf.copy(alpha = 0.4f)),
                        )
                        Spacer(Modifier.height(14.dp))
                    }
                }

                // Timeline entries
                item { Spacer(Modifier.height(24.dp)) }

                items(tlmHistoryEvents.size) { idx ->
                    val event = tlmHistoryEvents[idx]
                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .height(IntrinsicSize.Min)
                            .padding(horizontal = 20.dp),
                    ) {
                        // Timeline dot and line
                        Column(
                            horizontalAlignment = Alignment.CenterHorizontally,
                            modifier = Modifier
                                .width(20.dp)
                                .fillMaxHeight(),
                        ) {
                            Box(
                                modifier = Modifier
                                    .size(10.dp)
                                    .clip(CircleShape)
                                    .background(colors.sanctuaryRed.copy(alpha = 0.15f))
                                    .border(1.dp, colors.sanctuaryRed.copy(alpha = 0.5f), CircleShape),
                            )
                            if (idx < tlmHistoryEvents.size - 1) {
                                Box(
                                    modifier = Modifier
                                        .width(1.dp)
                                        .weight(1f)
                                        .background(colors.sanctuaryRed.copy(alpha = 0.15f)),
                                )
                            }
                        }

                        Spacer(Modifier.width(14.dp))

                        // Text content
                        Column(
                            modifier = Modifier.padding(bottom = 20.dp),
                        ) {
                            Text(
                                text = event.year,
                                style = type.captionSm,
                                color = colors.goldLeaf,
                            )
                            Text(
                                text = event.title,
                                style = type.titleM.copy(fontStyle = FontStyle.Italic),
                                color = colors.primaryText,
                                modifier = Modifier.padding(top = 4.dp),
                            )
                            Text(
                                text = event.desc,
                                style = type.bodySm,
                                color = colors.secondaryText,
                                lineHeight = type.bodySm.fontSize * 1.2f,
                                modifier = Modifier.padding(top = 4.dp),
                            )
                        }
                    }
                }

                item { Spacer(Modifier.height(40.dp)) }
            }
        }
    }
}

// ---------------------------------------------------------------------------
// Glossary Sheet
// ---------------------------------------------------------------------------

private data class GlossaryTerm(
    val lat: String,
    val eng: String,
    val def: String,
)

private val glossaryTerms = listOf(
    GlossaryTerm("Introitus", "Introit", "The entrance antiphon sung as the priest approaches the altar."),
    GlossaryTerm("Collecta", "Collect", "The prayer of the day, collecting the intentions of the faithful."),
    GlossaryTerm("Lectio", "Epistle", "The first scripture reading, usually from the letters of St. Paul."),
    GlossaryTerm("Graduale", "Gradual", "A psalm response sung between the Epistle and Gospel."),
    GlossaryTerm("Evangelium", "Gospel", "The reading from one of the four Gospels."),
    GlossaryTerm("Offertorium", "Offertory", "The antiphon accompanying the preparation of the gifts."),
    GlossaryTerm("Secreta", "Secret", "The prayer said silently over the offerings before the Preface."),
    GlossaryTerm("Praefatio", "Preface", "The solemn prayer of thanksgiving introducing the Canon."),
    GlossaryTerm("Canon", "Canon", "The unchanging central prayer of the Mass containing the Consecration."),
    GlossaryTerm("Communio", "Communion", "The antiphon sung during the distribution of Holy Communion."),
    GlossaryTerm("Postcommunio", "Postcommunion", "The prayer of thanksgiving after Communion."),
    GlossaryTerm("Feria", "Feria", "A weekday without a feast. The Mass of the preceding Sunday is repeated."),
    GlossaryTerm("Dominica", "Sunday", "The Lord’s Day, always at least a second-class feast."),
    GlossaryTerm("Proprium", "Proper", "The parts of the Mass that change according to the day or feast."),
    GlossaryTerm("Ordinarium", "Ordinary", "The unchanging parts of the Mass (Kyrie, Gloria, Credo, etc.)."),
    GlossaryTerm("Rubrica", "Rubric", "A liturgical instruction, printed in red in the Missal."),
    GlossaryTerm("Missa Cantata", "Sung Mass", "A Mass where the celebrant sings the prayers, with or without deacon and subdeacon."),
    GlossaryTerm("Missa Solemnis", "Solemn Mass", "A Mass celebrated with deacon and subdeacon, incense, and full ceremonies."),
    GlossaryTerm("Missa Lecta", "Low Mass", "A Mass spoken (not sung) by a single priest, the most common weekday form."),
    GlossaryTerm("Tempus per Annum", "Ordinary Time", "The weeks outside Advent, Christmas, Lent, and Easter."),
    GlossaryTerm("Quadragesima", "Lent", "The forty days of penance from Ash Wednesday to Easter."),
    GlossaryTerm("Hebdomada Sancta", "Holy Week", "The week from Palm Sunday to Holy Saturday."),
    GlossaryTerm("Octava", "Octave", "An eight-day celebration extending a major feast."),
    GlossaryTerm("Vigilia", "Vigil", "The day before a feast, often observed with fasting."),
    GlossaryTerm("Commune", "Common", "Standard Mass texts used for categories of saints (martyrs, confessors, virgins)."),
)

@OptIn(ExperimentalMaterial3Api::class)
@Composable
private fun GlossarySheet(
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
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp, vertical = 8.dp),
                verticalAlignment = Alignment.CenterVertically,
            ) {
                IconButton(onClick = {
                    scope.launch { sheetState.hide() }.invokeOnCompletion { onDismiss() }
                }) {
                    Icon(Icons.AutoMirrored.Filled.ArrowBack, "Back", tint = colors.sanctuaryRed)
                }
                SmallLabel(text = "Glossary", color = colors.sanctuaryRed)
            }

            LazyColumn(
                modifier = Modifier.fillMaxSize(),
            ) {
                item { Spacer(Modifier.height(12.dp)) }

                items(glossaryTerms.size) { i ->
                    val term = glossaryTerms[i]
                    Column(
                        modifier = Modifier
                            .padding(vertical = 10.dp, horizontal = 20.dp),
                    ) {
                        Row(
                            verticalAlignment = Alignment.Bottom,
                            horizontalArrangement = Arrangement.spacedBy(10.dp),
                        ) {
                            Text(
                                text = term.lat,
                                style = type.titleM.copy(fontStyle = FontStyle.Italic),
                                color = colors.primaryText,
                            )
                            Text(
                                text = term.eng,
                                style = type.captionSm.copy(fontStyle = FontStyle.Italic),
                                color = colors.secondaryText,
                            )
                        }
                        Text(
                            text = term.def,
                            style = type.bodySm,
                            color = colors.secondaryText,
                            lineHeight = type.bodySm.fontSize * 1.2f,
                            modifier = Modifier.padding(top = 4.dp),
                        )
                    }
                    HorizontalDivider(
                        color = colors.frameLine,
                        modifier = Modifier.padding(start = 20.dp),
                    )
                }

                item { Spacer(Modifier.height(12.dp)) }
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
                latin = "Propria Missae",
                count = "${ContentStore.allPropers.size} formularies",
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
                title = "History",
                latin = "Historia Missae",
                count = "Timeline",
                onClick = { onSectionClick("History") },
                modifier = Modifier.weight(1f),
            )
            SectionCard(
                icon = Icons.Filled.LibraryBooks,
                title = "Glossary",
                latin = "Glossarium",
                count = "Liturgical terms",
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
        if (currentLanguageMode() != LanguageMode.VERNACULAR) {
            Text(
                text = latin,
                style = type.captionSm.copy(fontStyle = FontStyle.Italic),
                color = colors.secondaryText,
                modifier = Modifier.padding(top = 2.dp),
            )
        }
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
                        .padding(vertical = 4.dp),
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
                        modifier = Modifier.size(10.dp),
                    )
                }
            }
        }
    }
}
