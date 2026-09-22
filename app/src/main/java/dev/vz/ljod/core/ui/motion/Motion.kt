package dev.vz.ljod.core.ui.motion

import androidx.compose.animation.core.AnimationSpec
import androidx.compose.animation.core.CubicBezierEasing
import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.spring as composeSpring
import androidx.compose.animation.core.tween as composeTween
import androidx.compose.runtime.Composable
import dev.vz.ljod.core.ui.theme.LjodTheme

object LjodEasing {
    val Emphasized = CubicBezierEasing(0.20f, 0.00f, 0.00f, 1.00f)
    val Standard = CubicBezierEasing(0.20f, 0.00f, 0.00f, 1.00f)
    val Decelerate = CubicBezierEasing(0.00f, 0.00f, 0.00f, 1.00f)
    val Accelerate = CubicBezierEasing(0.30f, 0.00f, 1.00f, 1.00f)
    val Sharp = CubicBezierEasing(0.40f, 0.00f, 0.20f, 1.00f)
    val Liquid = CubicBezierEasing(0.32f, 0.72f, 0.00f, 1.00f)
    val Glow = CubicBezierEasing(0.4f, 0.0f, 0.2f, 1.0f)
}

object LjodMotion {
    const val DurationFast = 150
    const val DurationMed = 280
    const val DurationSlow = 450
    const val DurationHero = 700

    @Composable
    fun <T> spring(
        damping: Float = 0.78f,
        stiffness: Float = Spring.StiffnessMediumLow,
    ): AnimationSpec<T> =
        if (LjodTheme.animationsEnabled) {
            composeSpring(dampingRatio = damping, stiffness = stiffness)
        } else {
            composeTween(durationMillis = 0)
        }

    @Composable
    fun <T> tween(
        durationMillis: Int,
        easing: androidx.compose.animation.core.Easing = LjodEasing.Emphasized,
    ): AnimationSpec<T> =
        if (LjodTheme.animationsEnabled && durationMillis > 0) {
            composeTween(durationMillis = durationMillis, easing = easing)
        } else {
            composeTween(durationMillis = 0)
        }
}

object LjodSpring {
    val Snappy = Spring.StiffnessHigh to 0.6f
    val Bouncy = Spring.StiffnessMedium to 0.45f
    val Smooth = Spring.StiffnessMediumLow to 0.85f
    val Gentle = Spring.StiffnessLow to 0.92f
}
