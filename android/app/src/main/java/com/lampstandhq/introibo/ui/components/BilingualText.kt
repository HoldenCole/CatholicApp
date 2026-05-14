package com.lampstandhq.introibo.ui.components

import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.unit.dp
import com.lampstandhq.introibo.data.model.strippingEm
import com.lampstandhq.introibo.ui.theme.IntroiboTheme
import com.lampstandhq.introibo.ui.theme.IntroiboType

/**
 * Renders Latin and/or English text based on the user's language preference.
 * Port of Introibo/Design/BilingualText.swift.
 *
 * @param lat       Latin text (may contain `<em>` tags which are stripped).
 * @param eng       English text (may contain `<em>` tags which are stripped).
 * @param sideBySide When true **and** [languageMode] is "both", the two
 *                   texts render in a side-by-side [Row] instead of stacked.
 * @param languageMode Current language preference: "both", "latin", or "vernacular".
 */
@Composable
fun BilingualLine(
    lat: String,
    eng: String,
    sideBySide: Boolean = false,
    languageMode: String = "both",
) {
    val colors = IntroiboTheme.colors
    val type = IntroiboType.current
    val cleanLat = lat.strippingEm
    val cleanEng = eng.strippingEm

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
