package com.lampstandhq.introibo.ui.components

import androidx.compose.foundation.Canvas
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.geometry.Size
import androidx.compose.ui.graphics.BlendMode
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.drawscope.DrawScope
import androidx.compose.ui.graphics.drawscope.Stroke
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.dp
import com.lampstandhq.introibo.ui.theme.IntroiboTheme
import com.lampstandhq.introibo.ui.theme.RawPalette

// ---------------------------------------------------------------------------
// Paper grain overlay
// ---------------------------------------------------------------------------
// Subtle dot pattern drawn via Canvas — three layered radial dot fields at
// different scales, composited in multiply mode on top of the page to add
// tactile warmth without washing out content.  Mirrors the iOS
// PaperGrainOverlay in PageFrame.swift.

/**
 * Three-layer grain dot specification.
 */
private data class GrainLayer(
    val step: Float,
    val radius: Float,
    val alpha: Float,
    val offsetX: Float,
    val offsetY: Float,
)

private val grainLayers = listOf(
    GrainLayer(step = 7f,  radius = 0.6f, alpha = 0.025f, offsetX = 1f, offsetY = 2f),
    GrainLayer(step = 13f, radius = 0.7f, alpha = 0.02f,  offsetX = 5f, offsetY = 9f),
    GrainLayer(step = 11f, radius = 0.6f, alpha = 0.018f, offsetX = 3f, offsetY = 7f),
)

private fun DrawScope.drawGrainOverlay() {
    val dotBaseColor = RawPalette.GrainDot
    for (layer in grainLayers) {
        val dotColor = dotBaseColor.copy(alpha = layer.alpha * 0.7f)
        var y = layer.offsetY
        while (y < size.height) {
            var x = layer.offsetX
            while (x < size.width) {
                drawCircle(
                    color = dotColor,
                    radius = layer.radius,
                    center = Offset(x, y),
                    blendMode = BlendMode.Multiply,
                )
                x += layer.step
            }
            y += layer.step
        }
    }
}

// ---------------------------------------------------------------------------
// Gold frame border overlay
// ---------------------------------------------------------------------------
// Two concentric hairline rectangles in the gold-leaf frame colour, matching
// the iOS PageFrameModifier.

private fun DrawScope.drawGoldFrame(frameLineColor: Color, inset: Float) {
    // Outer hairline
    drawRect(
        color = frameLineColor,
        topLeft = Offset(inset, inset),
        size = Size(size.width - inset * 2, size.height - inset * 2),
        style = Stroke(width = 0.5f),
    )
    // Inner hairline, 3dp further in
    val inner = inset + 3f
    drawRect(
        color = frameLineColor.copy(alpha = frameLineColor.alpha * 0.5f),
        topLeft = Offset(inner, inner),
        size = Size(size.width - inner * 2, size.height - inner * 2),
        style = Stroke(width = 0.5f),
    )
}

// ---------------------------------------------------------------------------
// Public composables
// ---------------------------------------------------------------------------

/**
 * Paper grain overlay — add as a sibling inside a [Box] to layer the grain
 * on top of content, or wrap content with [PageChrome] for the full look.
 */
@Composable
fun PaperGrainOverlay(modifier: Modifier = Modifier) {
    Canvas(modifier = modifier.fillMaxSize()) {
        drawGrainOverlay()
    }
}

/**
 * Gold hairline page frame overlay.
 *
 * @param inset Distance from the edges for the outer hairline (default 10dp).
 */
@Composable
fun PageFrameOverlay(
    inset: Dp = 10.dp,
    modifier: Modifier = Modifier,
) {
    val frameLineColor = IntroiboTheme.colors.frameLine
    Canvas(modifier = modifier.fillMaxSize()) {
        drawGoldFrame(frameLineColor, inset.toPx())
    }
}

/**
 * Full Introibo page chrome: parchment/walnut background + paper grain
 * overlay + gold hairline frame. Use as the root container of each screen.
 *
 * This is the Compose equivalent of the iOS `.pageChrome()` modifier.
 *
 * ```
 * PageChrome {
 *     LazyColumn { ... }
 * }
 * ```
 */
@Composable
fun PageChrome(
    modifier: Modifier = Modifier,
    inset: Dp = 10.dp,
    content: @Composable () -> Unit,
) {
    val colors = IntroiboTheme.colors

    Box(
        modifier = modifier
            .fillMaxSize()
            .background(colors.pageBackground),
    ) {
        // Screen content
        content()

        // Paper grain layer (multiply blend)
        PaperGrainOverlay()

        // Gold frame on top
        PageFrameOverlay(inset = inset)
    }
}
