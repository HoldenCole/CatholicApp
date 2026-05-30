package com.lampstandhq.introibo.ui.office

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.PathEffect
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.layout.Layout
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.Constraints
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.lampstandhq.introibo.data.model.Hour
import com.lampstandhq.introibo.ui.theme.IntroiboTheme
import com.lampstandhq.introibo.ui.theme.IntroiboType
import kotlin.math.cos
import kotlin.math.min
import kotlin.math.roundToInt
import kotlin.math.sin

@Composable
fun ClockDial(
    hours: List<Hour>,
    currentKey: String,
    onTap: (String) -> Unit,
    modifier: Modifier = Modifier,
) {
    val colors = IntroiboTheme.colors

    Layout(
        modifier = modifier.aspectRatio(1f).fillMaxSize(),
        content = {
            // Child 0: Canvas for rings and ticks
            Canvas(modifier = Modifier.fillMaxSize()) {
                val sz = min(size.width, size.height)
                val cx = size.width / 2f
                val cy = size.height / 2f
                val ringR = sz / 2f - 8.dp.toPx()

                drawCircle(
                    color = colors.goldLeaf.copy(alpha = 0.5f),
                    radius = sz / 2f,
                    center = Offset(cx, cy),
                    style = Stroke(width = 0.5f),
                )
                drawCircle(
                    color = colors.goldLeaf.copy(alpha = 0.25f),
                    radius = sz / 2f - 6.dp.toPx(),
                    center = Offset(cx, cy),
                    style = Stroke(width = 0.5f),
                )
                drawCircle(
                    color = colors.sanctuaryRed.copy(alpha = 0.2f),
                    radius = sz / 2f - 46.dp.toPx(),
                    center = Offset(cx, cy),
                    style = Stroke(
                        width = 0.5f,
                        pathEffect = PathEffect.dashPathEffect(floatArrayOf(3.dp.toPx(), 3.dp.toPx())),
                    ),
                )

                for (i in 0 until 24) {
                    val isMajor = i % 6 == 0
                    val angleDeg = i * 15.0 - 90.0
                    val angleRad = Math.toRadians(angleDeg)
                    val tickLen = if (isMajor) 14.dp.toPx() else 8.dp.toPx()
                    val tickW = if (isMajor) 1.5.dp.toPx() else 1.dp.toPx()
                    val tickColor = if (isMajor) colors.sanctuaryRed.copy(alpha = 0.55f)
                    else colors.goldLeaf.copy(alpha = 0.4f)
                    val outerR = ringR
                    val innerR = outerR - tickLen
                    drawLine(
                        color = tickColor,
                        start = Offset(cx + cos(angleRad).toFloat() * outerR, cy + sin(angleRad).toFloat() * outerR),
                        end = Offset(cx + cos(angleRad).toFloat() * innerR, cy + sin(angleRad).toFloat() * innerR),
                        strokeWidth = tickW,
                    )
                }
            }

            // Child 1: Center label
            CenterLabel()

            // Children 2+: Hour nodes
            hours.forEachIndexed { index, hour ->
                HourNode(
                    hour = hour,
                    isNow = hour.slug == currentKey,
                    onTap = { onTap(hour.slug) },
                )
            }
        }
    ) { measurables, constraints ->
        val sz = min(constraints.maxWidth, constraints.maxHeight)
        val nodeR = sz * 0.72f / 2f
        val nodeSizePx = 48.dp.roundToPx()
        val cx = sz / 2
        val cy = sz / 2

        val placeables = measurables.mapIndexed { i, m ->
            when (i) {
                0 -> m.measure(Constraints.fixed(sz, sz))
                1 -> m.measure(Constraints(maxWidth = sz, maxHeight = sz))
                else -> m.measure(Constraints.fixed(nodeSizePx, nodeSizePx))
            }
        }

        layout(sz, sz) {
            // Canvas fills the whole area
            placeables[0].placeRelative(0, 0)
            // Center label
            placeables[1].placeRelative(
                cx - placeables[1].width / 2,
                cy - placeables[1].height / 2
            )
            // Hour nodes — evenly spaced around the circle
            val total = hours.size
            for (i in 2 until placeables.size) {
                val idx = i - 2
                val angleDeg = (idx.toDouble() / total.toDouble()) * 360.0 - 90.0
                val angleRad = Math.toRadians(angleDeg)
                val x = cx + (cos(angleRad) * nodeR).roundToInt() - nodeSizePx / 2
                val y = cy + (sin(angleRad) * nodeR).roundToInt() - nodeSizePx / 2
                placeables[i].placeRelative(x, y)
            }
        }
    }
}

@Composable
private fun CenterLabel() {
    val colors = IntroiboTheme.colors
    val type = IntroiboType.current
    Column(horizontalAlignment = Alignment.CenterHorizontally) {
        Text(
            text = "HORA HÆC",
            style = type.captionSm,
            color = colors.tertiaryText,
            letterSpacing = 2.sp,
        )
        Text(
            text = "✠",
            style = type.titleL,
            color = colors.sanctuaryRed,
        )
    }
}

@Composable
private fun HourNode(
    hour: Hour,
    isNow: Boolean,
    onTap: () -> Unit,
) {
    val colors = IntroiboTheme.colors
    val type = IntroiboType.current

    Box(
        modifier = Modifier
            .size(48.dp)
            .shadow(
                elevation = if (isNow) 12.dp else 0.dp,
                shape = CircleShape,
                ambientColor = if (isNow) colors.goldLeaf.copy(alpha = 0.4f) else Color.Transparent,
                spotColor = if (isNow) colors.goldLeaf.copy(alpha = 0.4f) else Color.Transparent,
            )
            .clip(CircleShape)
            .background(if (isNow) colors.goldLeaf.copy(alpha = 0.12f) else colors.pageBackground)
            .border(
                width = if (isNow) 1.dp else 0.5.dp,
                color = if (isNow) colors.goldLeaf else colors.goldLeaf.copy(alpha = 0.55f),
                shape = CircleShape,
            )
            .clickable { onTap() },
        contentAlignment = Alignment.Center,
    ) {
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            Text(
                text = hour.glyph,
                style = type.titleM.copy(fontStyle = FontStyle.Italic),
                color = colors.sanctuaryRed,
                textAlign = TextAlign.Center,
            )
            Text(
                text = formatTime(hour.hour, hour.minute),
                style = type.captionSm.copy(
                    fontSize = 8.sp,
                    fontWeight = FontWeight.SemiBold,
                    fontStyle = FontStyle.Italic,
                ),
                color = colors.tertiaryText,
                textAlign = TextAlign.Center,
            )
        }
    }
}

private fun formatTime(h: Int, m: Int): String {
    val hh = if (h % 12 == 0) 12 else h % 12
    val mm = if (m < 10) "0$m" else "$m"
    val suffix = if (h < 12) "AM" else "PM"
    return "$hh:$mm $suffix"
}
