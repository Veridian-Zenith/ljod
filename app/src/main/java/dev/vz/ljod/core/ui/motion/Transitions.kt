package dev.vz.ljod.core.ui.motion

import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.ContentTransform
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInHorizontally
import androidx.compose.animation.slideOutHorizontally
import androidx.compose.animation.togetherWith
import androidx.compose.runtime.Composable
import androidx.compose.ui.Modifier

object LjodTransitions {
    @Composable
    fun <S> Fade(
        targetState: S,
        modifier: Modifier = Modifier,
        content: @Composable (S) -> Unit,
    ) {
        AnimatedContent(
            targetState = targetState,
            transitionSpec = { fadeIn(tween(220)) togetherWith fadeOut(tween(180)) },
            modifier = modifier,
            content = { content(it) },
        )
    }

    @Composable
    fun <S> SlideHorizontal(
        targetState: S,
        forward: Boolean = true,
        modifier: Modifier = Modifier,
        content: @Composable (S) -> Unit,
    ) {
        AnimatedContent(
            targetState = targetState,
            transitionSpec = {
                val dir = if (forward) 1 else -1
                ContentTransform(
                    targetContentEnter = slideInHorizontally(initialOffsetX = { it * dir }) + fadeIn(tween(220)),
                    initialContentExit = slideOutHorizontally(targetOffsetX = { -it * dir }) + fadeOut(tween(180)),
                )
            },
            modifier = modifier,
            content = { content(it) },
        )
    }
}
