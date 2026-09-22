package dev.vz.ljod.core.ui.motion

import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.composed
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.platform.LocalDensity
import androidx.compose.ui.unit.dp

fun Modifier.swipeable(
    onSwipeLeft: () -> Unit,
    onSwipeRight: () -> Unit,
    thresholdDp: Int = 80,
    maxOffsetDp: Int = 96,
): Modifier =
    composed {
        val density = LocalDensity.current
        val thresholdPx = with(density) { thresholdDp.dp.toPx() }
        val maxOffsetPx = with(density) { maxOffsetDp.dp.toPx() }
        var offsetX by remember { mutableFloatStateOf(0f) }
        graphicsLayer { translationX = offsetX }
            .pointerInput(Unit) {
                detectDragGestures(
                    onDragEnd = {
                        if (offsetX > thresholdPx) {
                            onSwipeRight()
                        } else if (offsetX < -thresholdPx) {
                            onSwipeLeft()
                        }
                        offsetX = 0f
                    },
                    onDrag = { _, drag ->
                        offsetX = (offsetX + drag.x).coerceIn(-maxOffsetPx, maxOffsetPx)
                    },
                )
            }
    }
