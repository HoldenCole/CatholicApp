package com.lampstandhq.introibo.ui.onboarding

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.tween
import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.size
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.alpha
import androidx.compose.ui.draw.scale
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.text.font.FontStyle
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import com.lampstandhq.introibo.ui.theme.IntroiboTheme
import com.lampstandhq.introibo.ui.theme.IntroiboType
import kotlinx.coroutines.delay

/**
 * Animated splash screen shown on app launch.
 *
 * Port of iOS Introibo/Screens/SplashView.swift.
 */
@Composable
fun SplashScreen(
    onFinished: () -> Unit,
) {
    val colors = IntroiboTheme.colors
    val type = IntroiboType.current

    var visible by remember { mutableStateOf(false) }
    val alpha by animateFloatAsState(
        targetValue = if (visible) 1f else 0f,
        animationSpec = tween(durationMillis = 800),
        label = "splash_alpha",
    )
    val crossScale by animateFloatAsState(
        targetValue = if (visible) 1f else 0.8f,
        animationSpec = tween(durationMillis = 800),
        label = "splash_scale",
    )

    LaunchedEffect(Unit) {
        visible = true
        delay(2000L)
        onFinished()
    }

    Box(
        modifier = Modifier
            .fillMaxSize()
            .background(
                Brush.verticalGradient(
                    colors = listOf(colors.walnut, colors.walnutHi, colors.walnut),
                )
            ),
        contentAlignment = Alignment.Center,
    ) {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .alpha(alpha),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Spacer(modifier = Modifier.weight(1f))

            // Monstrance icon
            SplashMonstranceIcon(modifier = Modifier.scale(crossScale))

            Spacer(modifier = Modifier.height(24.dp))

            Text(
                text = "Introíbo",
                style = type.pageTitle.copy(
                    fontSize = 42.sp,
                    fontWeight = FontWeight.SemiBold,
                    fontStyle = FontStyle.Italic,
                ),
                color = colors.ivory,
            )
            Spacer(modifier = Modifier.height(8.dp))
            Text(
                text = "AD ALTÁRE DEI",
                style = type.bodySm.copy(fontStyle = FontStyle.Italic),
                color = colors.goldLeaf,
                letterSpacing = 3.sp,
            )

            Spacer(modifier = Modifier.weight(1f))

            Text(
                text = "A prayer companion for traditional Catholics",
                style = type.captionSm.copy(fontStyle = FontStyle.Italic),
                color = colors.muted,
                textAlign = TextAlign.Center,
                modifier = Modifier.height(48.dp),
            )
        }
    }
}

@Composable
private fun SplashMonstranceIcon(modifier: Modifier = Modifier) {
    val colors = IntroiboTheme.colors

    Canvas(modifier = modifier.size(140.dp)) {
        val cx = size.width / 2f
        val cy = size.height / 2f

        // Outer rings
        drawCircle(
            color = colors.goldLeaf.copy(alpha = 0.3f),
            radius = 40.dp.toPx(),
            center = Offset(cx, cy),
            style = Stroke(width = 1.dp.toPx()),
        )
        drawCircle(
            color = colors.goldLeaf.copy(alpha = 0.2f),
            radius = 50.dp.toPx(),
            center = Offset(cx, cy),
            style = Stroke(width = 0.5.dp.toPx()),
        )

        // 12 rays
        for (i in 0 until 12) {
            val angleDeg = i * 30.0
            val angleRad = Math.toRadians(angleDeg)
            val innerR = 47.dp.toPx()
            val outerR = 56.dp.toPx()
            drawLine(
                color = colors.goldLeaf.copy(alpha = 0.25f),
                start = Offset(
                    cx + kotlin.math.cos(angleRad).toFloat() * innerR,
                    cy + kotlin.math.sin(angleRad).toFloat() * innerR,
                ),
                end = Offset(
                    cx + kotlin.math.cos(angleRad).toFloat() * outerR,
                    cy + kotlin.math.sin(angleRad).toFloat() * outerR,
                ),
                strokeWidth = 0.5.dp.toPx(),
            )
        }

        // Inner glow
        drawCircle(
            color = colors.goldLeaf.copy(alpha = 0.15f),
            radius = 25.dp.toPx(),
            center = Offset(cx, cy),
        )

        // Host
        drawCircle(
            color = colors.goldLeaf.copy(alpha = 0.5f),
            radius = 10.dp.toPx(),
            center = Offset(cx, cy),
        )

        // Cross on host
        drawLine(
            color = colors.ivory.copy(alpha = 0.4f),
            start = Offset(cx, cy - 5.dp.toPx()),
            end = Offset(cx, cy + 5.dp.toPx()),
            strokeWidth = 0.8.dp.toPx(),
        )
        drawLine(
            color = colors.ivory.copy(alpha = 0.4f),
            start = Offset(cx - 5.dp.toPx(), cy),
            end = Offset(cx + 5.dp.toPx(), cy),
            strokeWidth = 0.8.dp.toPx(),
        )

        // Stem
        drawLine(
            color = colors.goldLeaf.copy(alpha = 0.4f),
            start = Offset(cx, cy + 37.dp.toPx()),
            end = Offset(cx, cy + 48.dp.toPx()),
            strokeWidth = 3.dp.toPx(),
        )

        // Cross on top
        drawLine(
            color = colors.goldLeaf.copy(alpha = 0.4f),
            start = Offset(cx, cy - 41.dp.toPx()),
            end = Offset(cx, cy - 48.dp.toPx()),
            strokeWidth = 2.dp.toPx(),
        )
        drawLine(
            color = colors.goldLeaf.copy(alpha = 0.4f),
            start = Offset(cx - 5.dp.toPx(), cy - 43.dp.toPx()),
            end = Offset(cx + 5.dp.toPx(), cy - 43.dp.toPx()),
            strokeWidth = 2.dp.toPx(),
        )
    }
}
