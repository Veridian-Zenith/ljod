package dev.vz.ljod.core.ui.theme

import android.app.Activity
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.SideEffect
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.platform.LocalView
import androidx.core.view.WindowCompat

val LocalLjodPalette = staticCompositionLocalOf { LjodPalettes.Nordic }

@Composable
fun LjodTheme(
    palette: LjodPalette = LjodPalettes.Nordic,
    content: @Composable () -> Unit
) {
    val scheme = darkColorScheme(
        primary = palette.accent,
        onPrimary = palette.bg,
        primaryContainer = palette.accentDim,
        onPrimaryContainer = palette.accent,
        secondary = palette.accentMuted,
        onSecondary = palette.bg,
        background = palette.bg,
        onBackground = palette.textPrimary,
        surface = palette.surface,
        onSurface = palette.textPrimary,
        surfaceVariant = palette.surfaceHigh,
        onSurfaceVariant = palette.textSecondary,
        surfaceContainerHigh = palette.surfaceHighest,
        error = palette.error,
        onError = palette.textPrimary,
        outline = palette.accentDim,
    )

    val view = LocalView.current
    if (!view.isInEditMode) {
        SideEffect {
            val window = (view.context as Activity).window
            window.statusBarColor = palette.bg.toArgb()
            window.navigationBarColor = palette.surface.toArgb()
            WindowCompat.getInsetsController(window, view).apply {
                isAppearanceLightStatusBars = false
                isAppearanceLightNavigationBars = false
            }
        }
    }

    androidx.compose.runtime.CompositionLocalProvider(LocalLjodPalette provides palette) {
        MaterialTheme(colorScheme = scheme, content = content)
    }
}

object LjodTheme {
    val palette: LjodPalette
        @Composable get() = LocalLjodPalette.current
}
