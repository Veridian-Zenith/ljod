package dev.vz.ljod.core.ui.motion

import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Modifier
import androidx.compose.ui.composed
import androidx.compose.ui.draw.drawWithCache
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.BlendMode
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import dev.vz.ljod.core.ui.theme.AmoledPalette

fun Modifier.animatedAurora(
    primary: Color = AmoledPalette.accent,
    secondary: Color = AmoledPalette.accentHot,
    tertiary: Color = AmoledPalette.accentDeep,
    intensity: Float = 0.18f,
    speedMs: Int = 6000,
): Modifier =
    composed {
        val transition = rememberInfiniteTransition(label = "aurora")
        val phase by transition.animateFloat(
            initialValue = 0f,
            targetValue = 1f,
            animationSpec =
                infiniteRepeatable(
                    animation = tween(durationMillis = speedMs, easing = LinearEasing),
                    repeatMode = RepeatMode.Restart,
                ),
            label = "phase",
        )
        drawWithCache {
            val w = size.width
            val h = size.height
            val p = phase
            val brush =
                Brush.linearGradient(
                    colors =
                        listOf(
                            primary.copy(
                                alpha =
                                    intensity * (
                                        0.6f + 0.4f *
                                            kotlin.math
                                                .sin(p * 6.28f)
                                                .toFloat()
                                                .coerceAtLeast(0f)
                                    ),
                            ),
                            secondary.copy(
                                alpha =
                                    intensity * (
                                        0.4f + 0.4f *
                                            kotlin.math
                                                .cos(p * 6.28f + 1f)
                                                .toFloat()
                                                .coerceAtLeast(0f)
                                    ),
                            ),
                            tertiary.copy(
                                alpha =
                                    intensity * (
                                        0.5f + 0.3f *
                                            kotlin.math
                                                .sin(p * 6.28f + 2f)
                                                .toFloat()
                                                .coerceAtLeast(0f)
                                    ),
                            ),
                        ),
                    start = Offset(w * p, 0f),
                    end = Offset(w * (1f - p), h),
                )
            onDrawWithContent {
                drawRect(brush = brush, blendMode = BlendMode.Plus)
                drawContent()
            }
        }
    }

fun Modifier.shimmer(
    highlight: Color = AmoledPalette.accentHot.copy(alpha = 0.20f),
    speedMs: Int = 1400,
): Modifier =
    composed {
        val transition = rememberInfiniteTransition(label = "shimmer")
        val phase by transition.animateFloat(
            initialValue = 0f,
            targetValue = 1f,
            animationSpec =
                infiniteRepeatable(
                    animation = tween(durationMillis = speedMs, easing = LinearEasing),
                    repeatMode = RepeatMode.Restart,
                ),
            label = "phase",
        )
        drawWithCache {
            val w = size.width
            val brush =
                Brush.linearGradient(
                    colors =
                        listOf(
                            Color.Transparent,
                            highlight,
                            Color.Transparent,
                        ),
                    start = Offset(w * (phase - 0.3f), 0f),
                    end = Offset(w * phase, size.height),
                )
            onDrawWithContent {
                drawRect(brush = brush, blendMode = BlendMode.Plus)
                drawContent()
            }
        }
    }
