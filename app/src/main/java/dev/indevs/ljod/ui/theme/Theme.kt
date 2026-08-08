package dev.indevs.ljod.ui.theme

import android.app.Activity
import androidx.compose.foundation.isSystemInDarkTheme
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.lightColorScheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.SideEffect
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.platform.LocalView
import androidx.core.view.WindowCompat

private val DarkColorScheme = darkColorScheme(
    primary = Amber,
    onPrimary = Void,
    primaryContainer = AmberDim,
    onPrimaryContainer = Amber,
    secondary = AmberMuted,
    onSecondary = Void,
    secondaryContainer = VoidSurfaceHigh,
    onSecondaryContainer = TextPrimary,
    tertiary = Gold,
    onTertiary = Void,
    background = Void,
    onBackground = TextPrimary,
    surface = VoidSurface,
    onSurface = TextPrimary,
    surfaceVariant = VoidSurfaceHigh,
    onSurfaceVariant = TextSecondary,
    surfaceContainerHigh = VoidSurfaceHighest,
    error = ErrorRed,
    onError = TextPrimary,
    outline = AmberDim,
    outlineVariant = AmberDim,
)

private val LightColorScheme = lightColorScheme(
    primary = Color(0xFF8B5E00),
    onPrimary = LightBackground,
    primaryContainer = Color(0xFFFFDEA1),
    onPrimaryContainer = Color(0xFF2D1600),
    background = LightBackground,
    onBackground = LightOnBackground,
    surface = LightSurface,
    onSurface = LightOnSurface,
    surfaceVariant = Color(0xFFF5E6D0),
    onSurfaceVariant = Color(0xFF4A3720),
    error = ErrorRed,
    onError = TextPrimary,
    outline = Color(0xFFCC9933),
)

@Composable
fun LjodTheme(
    darkTheme: Boolean = isSystemInDarkTheme(),
    content: @Composable () -> Unit
) {
    val colorScheme = if (darkTheme) DarkColorScheme else LightColorScheme

    val view = LocalView.current
    if (!view.isInEditMode) {
        SideEffect {
            val window = (view.context as Activity).window
            window.statusBarColor = colorScheme.background.toArgb()
            window.navigationBarColor = colorScheme.background.toArgb()
            WindowCompat.getInsetsController(window, view).apply {
                isAppearanceLightStatusBars = !darkTheme
                isAppearanceLightNavigationBars = !darkTheme
            }
        }
    }

    MaterialTheme(
        colorScheme = colorScheme,
        typography = LjodTypography,
        shapes = LjodShapes,
        content = content
    )
}
