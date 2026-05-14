package com.lampstandhq.introibo.ui.missal

import android.content.Intent
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.filled.Share
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.Text
import androidx.compose.material3.TopAppBar
import androidx.compose.material3.TopAppBarDefaults
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import com.lampstandhq.introibo.data.model.MassProper
import com.lampstandhq.introibo.ui.components.SmallLabel
import com.lampstandhq.introibo.ui.theme.IntroiboTheme
import com.lampstandhq.introibo.ui.theme.IntroiboType

/**
 * Proper detail view — displays all proper texts for a given Mass day.
 * Ported from iOS ProperView.swift.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun ProperScreen(
    proper: MassProper,
    onDismiss: () -> Unit = {},
) {
    val context = LocalContext.current
    val colors = IntroiboTheme.colors
    val type = IntroiboType.current

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(colors.pageBackground),
    ) {
        TopAppBar(
            title = {},
            navigationIcon = {
                IconButton(onClick = onDismiss) {
                    Text(text = "Done", color = colors.sanctuaryRed, style = type.body)
                }
            },
            actions = {
                IconButton(onClick = {
                    val shareText = properAsText(proper)
                    val shareIntent = Intent(Intent.ACTION_SEND).apply {
                        this.type = "text/plain"
                        putExtra(Intent.EXTRA_TEXT, shareText)
                    }
                    context.startActivity(Intent.createChooser(shareIntent, "Share Propers"))
                }) {
                    Icon(
                        imageVector = Icons.Filled.Share,
                        contentDescription = "Share",
                        tint = colors.sanctuaryRed,
                    )
                }
            },
            colors = TopAppBarDefaults.topAppBarColors(
                containerColor = colors.walnut,
            ),
        )

        LazyColumn(modifier = Modifier.fillMaxSize()) {
            // Header
            item {
                Column(
                    horizontalAlignment = Alignment.CenterHorizontally,
                    modifier = Modifier
                        .fillMaxWidth()
                        .background(
                            Brush.verticalGradient(
                                listOf(colors.walnut, colors.walnutHi)
                            )
                        )
                        .padding(horizontal = 20.dp),
                ) {
                    SmallLabel(
                        text = "✠  Proprium Missae  ✠",
                        color = colors.goldLeaf,
                        modifier = Modifier.padding(top = 28.dp),
                    )
                    Text(
                        text = proper.title,
                        style = type.pageTitle,
                        color = colors.ivory,
                        textAlign = TextAlign.Center,
                        modifier = Modifier.padding(top = 8.dp, start = 20.dp, end = 20.dp),
                    )
                    Text(
                        text = proper.english.uppercase(),
                        style = type.captionSm.copy(
                            fontStyle = FontStyle.Italic,
                            letterSpacing = type.smallLabel.letterSpacing,
                        ),
                        color = colors.muted,
                        modifier = Modifier.padding(top = 4.dp),
                    )
                    proper.preface?.let { preface ->
                        Text(
                            text = "Praefatio: ${preface.replaceFirstChar { it.titlecase() }}",
                            style = type.captionSm.copy(fontStyle = FontStyle.Italic),
                            color = colors.muted,
                            modifier = Modifier.padding(top = 4.dp),
                        )
                    }
                    Box(
                        modifier = Modifier
                            .padding(vertical = 14.dp)
                            .width(60.dp)
                            .height(0.5.dp)
                            .background(colors.goldLeaf.copy(alpha = 0.4f)),
                    )
                }
            }

            // Proper sections
            item {
                Column(
                    modifier = Modifier
                        .padding(horizontal = 20.dp)
                        .padding(top = 24.dp, bottom = 40.dp),
                    verticalArrangement = Arrangement.spacedBy(28.dp),
                ) {
                    ProperSection(latin = "Introitus", subtitle = "Introit", text = proper.introit)
                    ProperSection(latin = "Oratio", subtitle = "Collect", text = proper.collect)
                    ReadingSection(latin = "Lectio", subtitle = "Epistle", reading = proper.epistle)

                    proper.gradual?.let {
                        ProperSection(latin = "Graduale", subtitle = "Gradual", text = it)
                    }
                    proper.alleluia?.let {
                        ProperSection(latin = "Alleluia", subtitle = "Alleluia", text = it)
                    }
                    proper.tract?.let {
                        ProperSection(latin = "Tractus", subtitle = "Tract", text = it)
                    }
                    proper.sequence?.let {
                        ProperSection(latin = "Sequentia", subtitle = "Sequence", text = it)
                    }

                    ReadingSection(latin = "Evangelium", subtitle = "Gospel", reading = proper.gospel)
                    ProperSection(latin = "Offertorium", subtitle = "Offertory", text = proper.offertory)
                    ProperSection(latin = "Secreta", subtitle = "Secret", text = proper.secret)
                    ProperSection(latin = "Communio", subtitle = "Communion", text = proper.communion)
                    ProperSection(latin = "Postcommunio", subtitle = "Postcommunion", text = proper.postcommunion)
                }
            }
        }
    }
}

// ---------------------------------------------------------------------------
// Text export
// ---------------------------------------------------------------------------

private fun properAsText(proper: MassProper): String {
    val lines = mutableListOf<String>()
    lines.add(proper.title)
    lines.add(proper.english)
    lines.add("")

    fun addSection(label: String, lat: String, eng: String) {
        lines.add("-- $label --")
        lines.add(lat)
        lines.add(eng)
        lines.add("")
    }

    fun addReading(label: String, ref: String, lat: String, eng: String) {
        lines.add("-- $label --")
        if (ref.isNotEmpty()) lines.add(ref)
        lines.add(lat)
        lines.add(eng)
        lines.add("")
    }

    addSection("Introitus", proper.introit.lat, proper.introit.eng)
    addSection("Oratio", proper.collect.lat, proper.collect.eng)
    addReading("Lectio", proper.epistle.ref, proper.epistle.lat, proper.epistle.eng)
    proper.gradual?.let { addSection("Graduale", it.lat, it.eng) }
    proper.alleluia?.let { addSection("Alleluia", it.lat, it.eng) }
    proper.tract?.let { addSection("Tractus", it.lat, it.eng) }
    proper.sequence?.let { addSection("Sequentia", it.lat, it.eng) }
    addReading("Evangelium", proper.gospel.ref, proper.gospel.lat, proper.gospel.eng)
    addSection("Offertorium", proper.offertory.lat, proper.offertory.eng)
    addSection("Secreta", proper.secret.lat, proper.secret.eng)
    proper.preface?.let {
        lines.add("Preface: ${it.replaceFirstChar { c -> c.titlecase() }}")
        lines.add("")
    }
    addSection("Communio", proper.communion.lat, proper.communion.eng)
    addSection("Postcommunio", proper.postcommunion.lat, proper.postcommunion.eng)

    return lines.joinToString("\n")
}
