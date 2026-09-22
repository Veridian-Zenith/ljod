package dev.vz.ljod.core.ui.theme

import android.app.Activity
import android.os.Build
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.darkColorScheme
import androidx.compose.material3.Typography
import androidx.compose.runtime.Composable
import androidx.compose.runtime.CompositionLocalProvider
import androidx.compose.runtime.SideEffect
import androidx.compose.runtime.staticCompositionLocalOf
import androidx.compose.ui.graphics.toArgb
import androidx.compose.ui.platform.LocalView
import androidx.compose.ui.text.TextStyle
import androidx.compose.ui.text.font.FontFamily
import androidx.compose.ui.text.font.FontWeight
import androidx.core.view.WindowCompat

val LocalLjodPalette = staticCompositionLocalOf { AmoledPalette }
val LocalAnimationsEnabled = staticCompositionLocalOf { true }

val LjodTypography =
    Typography(
        displayLarge = TextStyle(fontFamily = FontFamily.SansSerif, fontWeight = FontWeight.Black, fontSize = LjodType.displayLarge),
        displayMedium = TextStyle(fontFamily = FontFamily.SansSerif, fontWeight = FontWeight.Black, fontSize = LjodType.displayMedium),
        displaySmall = TextStyle(fontFamily = FontFamily.SansSerif, fontWeight = FontWeight.Black, fontSize = LjodType.displaySmall),
        headlineLarge = TextStyle(fontFamily = FontFamily.SansSerif, fontWeight = FontWeight.Bold, fontSize = LjodType.headlineLarge),
        headlineMedium = TextStyle(fontFamily = FontFamily.SansSerif, fontWeight = FontWeight.Bold, fontSize = LjodType.headlineMedium),
        headlineSmall = TextStyle(fontFamily = FontFamily.SansSerif, fontWeight = FontWeight.Bold, fontSize = LjodType.headlineSmall),
        titleLarge = TextStyle(fontFamily = FontFamily.SansSerif, fontWeight = FontWeight.SemiBold, fontSize = LjodType.titleLarge),
        titleMedium = TextStyle(fontFamily = FontFamily.SansSerif, fontWeight = FontWeight.SemiBold, fontSize = LjodType.titleMedium),
        titleSmall = TextStyle(fontFamily = FontFamily.SansSerif, fontWeight = FontWeight.SemiBold, fontSize = LjodType.titleSmall),
        bodyLarge = TextStyle(fontFamily = FontFamily.SansSerif, fontWeight = FontWeight.Normal, fontSize = LjodType.bodyLarge),
        bodyMedium = TextStyle(fontFamily = FontFamily.SansSerif, fontWeight = FontWeight.Normal, fontSize = LjodType.bodyMedium),
        bodySmall = TextStyle(fontFamily = FontFamily.SansSerif, fontWeight = FontWeight.Normal, fontSize = LjodType.bodySmall),
        labelLarge = TextStyle(fontFamily = FontFamily.SansSerif, fontWeight = FontWeight.Medium, fontSize = LjodType.labelLarge),
        labelMedium = TextStyle(fontFamily = FontFamily.SansSerif, fontWeight = FontWeight.Medium, fontSize = LjodType.labelMedium),
        labelSmall = TextStyle(fontFamily = FontFamily.SansSerif, fontWeight = FontWeight.Medium, fontSize = LjodType.labelSmall),
    )

@Composable
fun LjodTheme(
    pureBlack: Boolean = true,
    animationsEnabled: Boolean = true,
    content: @Composable () -> Unit,
) {
    val palette = if (pureBlack) AmoledPalette else AmoledPalette
    val scheme =
        darkColorScheme(
            primary = palette.accent,
            onPrimary = palette.onAccent,
            primaryContainer = palette.accentDeep,
            onPrimaryContainer = palette.textPrimary,
            secondary = palette.accentHot,
            onSecondary = palette.onAccent,
            tertiary = palette.accentMuted,
            background = palette.bg,
            onBackground = palette.textPrimary,
            surface = palette.surface,
            onSurface = palette.textPrimary,
            surfaceVariant = palette.surfaceHigh,
            onSurfaceVariant = palette.textSecondary,
            surfaceContainer = palette.surface,
            surfaceContainerHigh = palette.surfaceHigh,
            surfaceContainerHighest = palette.surfaceHighest,
            outline = palette.border,
            outlineVariant = palette.border,
            error = palette.error,
            onError = palette.onAccent,
        )

    val view = LocalView.current
    if (!view.isInEditMode) {
        SideEffect {
            val window = (view.context as Activity).window
            @Suppress("DEPRECATION")
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.VANILLA_ICE_CREAM) {
                window.statusBarColor = palette.bg.toArgb()
                window.navigationBarColor = palette.bg.toArgb()
            } else {
                window.statusBarColor = palette.bg.toArgb()
                window.navigationBarColor = palette.bg.toArgb()
            }
            WindowCompat.getInsetsController(window, view).apply {
                isAppearanceLightStatusBars = false
                isAppearanceLightNavigationBars = false
            }
        }
    }

    CompositionLocalProvider(
        LocalLjodPalette provides palette,
        LocalAnimationsEnabled provides animationsEnabled,
    ) {
        MaterialTheme(colorScheme = scheme, typography = LjodTypography, content = content)
    }
}

object LjodTheme {
    val palette: LjodPalette
        @Composable get() = LocalLjodPalette.current

    val animationsEnabled: Boolean
        @Composable get() = LocalAnimationsEnabled.current
}
