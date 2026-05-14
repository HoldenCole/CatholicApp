package com.lampstandhq.introibo.ui.today

import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.ExperimentalMaterial3Api
import androidx.compose.material3.HorizontalDivider
import androidx.compose.material3.ModalBottomSheet
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.material3.rememberModalBottomSheetState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import kotlinx.coroutines.launch
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.unit.dp
import com.lampstandhq.introibo.data.penance.OptionalPenances
import com.lampstandhq.introibo.ui.theme.IntroiboTheme
import com.lampstandhq.introibo.ui.theme.IntroiboType

/**
 * Voluntary penances selection sheet.
 *
 * Port of iOS Introibo/Screens/Today/OptionalPenanceSheet.swift.
 */
@OptIn(ExperimentalMaterial3Api::class)
@Composable
fun PenanceSheet(
    onDismiss: () -> Unit,
) {
    val colors = IntroiboTheme.colors
    val type = IntroiboType.current
    val context = LocalContext.current

    var selected by remember { mutableStateOf(OptionalPenances.selectedIDs(context)) }

    val sheetState = rememberModalBottomSheetState(skipPartiallyExpanded = true)
    val scope = rememberCoroutineScope()

    ModalBottomSheet(
        onDismissRequest = onDismiss,
        sheetState = sheetState,
        containerColor = colors.pageBackground,
    ) {
        Column(modifier = Modifier.fillMaxWidth()) {
            // Title bar
            Row(
                modifier = Modifier
                    .fillMaxWidth()
                    .padding(horizontal = 16.dp, vertical = 8.dp),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically,
            ) {
                Text(
                    text = "Voluntary Penances",
                    style = type.titleM,
                    color = colors.primaryText,
                )
                TextButton(onClick = { scope.launch { sheetState.hide() }.invokeOnCompletion { onDismiss() } }) {
                    Text("Done", color = colors.sanctuaryRed, style = type.body)
                }
            }

            Column(
                modifier = Modifier
                    .fillMaxWidth()
                    .verticalScroll(rememberScrollState())
                    .padding(horizontal = 28.dp, vertical = 24.dp),
                verticalArrangement = Arrangement.spacedBy(16.dp),
            ) {
                Text(
                    text = "Choose voluntary penances to observe today. These are not obligatory but are meritorious offerings to God.",
                    style = type.bodySm.copy(fontStyle = FontStyle.Italic),
                    color = colors.secondaryText,
                    lineHeight = type.bodySm.fontSize * 1.2f,
                    modifier = Modifier.padding(bottom = 4.dp),
                )

                OptionalPenances.all.forEachIndexed { idx, penance ->
                    val isSelected = penance.id in selected

                    Row(
                        modifier = Modifier
                            .fillMaxWidth()
                            .clickable {
                                val newSelected = !isSelected
                                OptionalPenances.setSelected(context, penance.id, newSelected)
                                selected = if (newSelected) {
                                    selected + penance.id
                                } else {
                                    selected - penance.id
                                }
                            }
                            .padding(vertical = 8.dp),
                        verticalAlignment = Alignment.Top,
                    ) {
                        Text(
                            text = if (isSelected) "✓" else "○",
                            style = type.titleM,
                            color = if (isSelected) colors.sanctuaryRed else colors.tertiaryText,
                        )
                        Spacer(modifier = Modifier.width(14.dp))
                        Column {
                            Text(
                                text = penance.title,
                                style = type.titleM.copy(fontStyle = FontStyle.Italic),
                                color = colors.primaryText,
                            )
                            Text(
                                text = penance.latin,
                                style = type.captionSm.copy(fontStyle = FontStyle.Italic),
                                color = colors.goldLeaf,
                            )
                            Text(
                                text = penance.desc,
                                style = type.captionSm,
                                color = colors.secondaryText,
                                lineHeight = type.captionSm.fontSize * 1.3f,
                            )
                        }
                    }

                    if (idx < OptionalPenances.all.size - 1) {
                        HorizontalDivider(color = colors.frameLine.copy(alpha = 0.5f))
                    }
                }
            }
        }
    }
}
