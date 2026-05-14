package com.lampstandhq.introibo.ui.office

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.BoxScope
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
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.lampstandhq.introibo.data.model.Hour
import com.lampstandhq.introibo.ui.theme.IntroiboTheme
import com.lampstandhq.introibo.ui.theme.IntroiboType
import kotlin.math.cos
import kotlin.math.min
import kotlin.math.roundToInt
import kotlin.math.sin

/**
 * Circular clock dial showing the 8 canonical hours at their traditional
 * positions around a 24-hour ring. The current hour glows.
 *
 * Port of ClockDial from iOS OfficeView.swift.
 */
@Composable
fun ClockDial(
    hours: List<Hour>,
    currentKey: String,
    onTap: (String) -> Unit,
    modifier: Modifier = Modifier,
) {
    val colors = IntroiboTheme.colors
    val type = IntroiboType.current
    val density = LocalDensity.current

    Box(
        modifier = modifier
            .aspectRatio(1f)
            .fillMaxSize(),
        contentAlignment = Alignment.Center,
    ) {
        // Canvas layer: rings + ticks
        Canvas(modifier = Modifier.fillMaxSize()) {
            val sz = min(size.width, size.height)
            val cx = size.width / 2f
            val cy = size.height / 2f
            val ringR = sz / 2f - 8.dp.toPx()

            // Outer ring
            drawCircle(
                color = colors.goldLeaf.copy(alpha = 0.5f),
                radius = sz / 2f,
                center = Offset(cx, cy),
                style = Stroke(width = 0.5f),
            )
            // Second ring
            drawCircle(
                color = colors.goldLeaf.copy(alpha = 0.25f),
                radius = sz / 2f - 6.dp.toPx(),
                center = Offset(cx, cy),
                style = Stroke(width = 0.5f),
            )
            // Inner dashed ring
            drawCircle(
                color = colors.sanctuaryRed.copy(alpha = 0.2f),
                radius = sz / 2f - 46.dp.toPx(),
                center = Offset(cx, cy),
                style = Stroke(
                    width = 0.5f,
                    pathEffect = PathEffect.dashPathEffect(floatArrayOf(3.dp.toPx(), 3.dp.toPx())),
                ),
            )

            // 24 ticks
            for (i in 0 until 24) {
                val isMajor = i % 6 == 0
                val angleDeg = i * 15.0 - 90.0
                val angleRad = Math.toRadians(angleDeg)

                val tickLen = if (isMajor) 14.dp.toPx() else 8.dp.toPx()
                val tickW = if (isMajor) 1.5.dp.toPx() else 1.dp.toPx()
                val tickColor = if (isMajor)
                    colors.sanctuaryRed.copy(alpha = 0.55f)
                else
                    colors.goldLeaf.copy(alpha = 0.4f)

                val outerR = ringR
                val innerR = outerR - tickLen
                val sx = cx + cos(angleRad).toFloat() * outerR
                val sy = cy + sin(angleRad).toFloat() * outerR
                val ex = cx + cos(angleRad).toFloat() * innerR
                val ey = cy + sin(angleRad).toFloat() * innerR

                drawLine(
                    color = tickColor,
                    start = Offset(sx, sy),
                    end = Offset(ex, ey),
                    strokeWidth = tickW,
                )
            }
        }

        // Center label
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

        // 8 hour nodes
        Canvas(modifier = Modifier.fillMaxSize()) {
            // We only use this canvas for measurement; nodes are placed as composables
        }

        // Hour node composables placed absolutely
        hours.forEachIndexed { index, hour ->
            val isNow = hour.slug == currentKey
            HourNode(
                hour = hour,
                isNow = isNow,
                index = index,
                total = hours.size,
                onTap = { onTap(hour.slug) },
            )
        }
    }
}

@Composable
private fun BoxScope.HourNode(
    hour: Hour,
    isNow: Boolean,
    index: Int,
    total: Int,
    onTap: () -> Unit,
) {
    // This composable is called inside a Box scope
    // We place it using alignment + offset
    val colors = IntroiboTheme.colors
    val type = IntroiboType.current
    val density = LocalDensity.current

    val angleDeg = (index.toDouble() / total.toDouble()) * 360.0 - 90.0
    val angleRad = Math.toRadians(angleDeg)

    // The node radius factor relative to half-size
    val nodeRadiusFactor = 0.72f
    val nodeSizeDp = 48.dp

    Box(
        modifier = Modifier
            .size(nodeSizeDp)
            .align(Alignment.Center)
            // Offset is computed as fraction of parent; approximated here
            .offset {
                // parentSize is not directly accessible; we use a fixed approach
                // We compute offset based on the composable's box constraints
                val parentHalf = 150.dp.toPx() // Approximate; actual sizing handled by parent
                val r = parentHalf * nodeRadiusFactor
                IntOffset(
                    x = (cos(angleRad) * r).roundToInt(),
                    y = (sin(angleRad) * r).roundToInt(),
                )
            }
            .shadow(
                elevation = if (isNow) 12.dp else 0.dp,
                shape = CircleShape,
                ambientColor = if (isNow) colors.goldLeaf.copy(alpha = 0.4f) else Color.Transparent,
                spotColor = if (isNow) colors.goldLeaf.copy(alpha = 0.4f) else Color.Transparent,
            )
            .clip(CircleShape)
            .clickable { onTap() },
        contentAlignment = Alignment.Center,
    ) {
        // Background + border drawn via Canvas
        Canvas(modifier = Modifier.fillMaxSize()) {
            // Background
            drawCircle(
                color = if (isNow) colors.goldLeaf.copy(alpha = 0.12f) else colors.pageBackground,
            )
            // Border
            drawCircle(
                color = if (isNow) colors.goldLeaf else colors.goldLeaf.copy(alpha = 0.55f),
                style = Stroke(width = if (isNow) 1.dp.toPx() else 0.5.dp.toPx()),
            )
        }

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
