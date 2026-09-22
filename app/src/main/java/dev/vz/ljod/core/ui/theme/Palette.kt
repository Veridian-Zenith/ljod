package dev.vz.ljod.core.ui.theme

import androidx.compose.runtime.Immutable
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color

@Immutable
data class LjodPalette(
    val accent: Color,
    val accentMuted: Color,
    val accentDim: Color,
    val accentDeep: Color,
    val accentGlow: Color,
    val accentHot: Color,
    val onAccent: Color,
    val bg: Color,
    val bgElevated: Color,
    val surface: Color,
    val surfaceHigh: Color,
    val surfaceHighest: Color,
    val border: Color,
    val borderStrong: Color,
    val textPrimary: Color,
    val textSecondary: Color,
    val textTertiary: Color,
    val success: Color,
    val warning: Color,
    val error: Color,
    val glassLight: Color,
    val glassBorder: Color,
    val glassHighlight: Color,
    val glassScrim: Color,
    val scrim: Color,
)

val AmoledPalette =
    LjodPalette(
        accent = Color(0xFFE11D2E),
        accentMuted = Color(0xFFB11226),
        accentDim = Color(0x33E11D2E),
        accentDeep = Color(0xFF7A0A18),
        accentGlow = Color(0xCCE11D2E),
        accentHot = Color(0xFFFF3344),
        onAccent = Color(0xFFFFFFFF),
        bg = Color(0xFF000000),
        bgElevated = Color(0xFF0A0202),
        surface = Color(0xFF120404),
        surfaceHigh = Color(0xFF1A0606),
        surfaceHighest = Color(0xFF240A0A),
        border = Color(0x33E11D2E),
        borderStrong = Color(0x66E11D2E),
        textPrimary = Color(0xFFF5F2F2),
        textSecondary = Color(0xFFA89A9A),
        textTertiary = Color(0xFF6B5C5C),
        success = Color(0xFF22C55E),
        warning = Color(0xFFF59E0B),
        error = Color(0xFFE11D2E),
        glassLight = Color(0x14FFFFFF),
        glassBorder = Color(0x22FFFFFF),
        glassHighlight = Color(0x1FFFFFFF),
        glassScrim = Color(0x66000000),
        scrim = Color(0xCC000000),
    )

@Immutable
object LjodBlur {
    const val None = 0
    const val Low = 8
    const val Med = 16
    const val High = 28
}

@Immutable
object GlassStyle {
    val verticalSubtle =
        Brush.verticalGradient(
            listOf(
                Color(0x14FFFFFF),
                Color(0x08FFFFFF),
            ),
        )

    val verticalGradient =
        Brush.verticalGradient(
            listOf(
                Color(0x1FFFFFFF),
                Color(0x0AFFFFFF),
            ),
        )

    val accentGradient =
        Brush.verticalGradient(
            listOf(
                AmoledPalette.accent.copy(alpha = 0.40f),
                AmoledPalette.accent.copy(alpha = 0.10f),
            ),
        )

    val surfaceGradient =
        Brush.verticalGradient(
            listOf(
                AmoledPalette.surfaceHighest,
                AmoledPalette.surface,
            ),
        )

    val chipGradient =
        Brush.verticalGradient(
            listOf(
                Color(0x30E11D2E),
                Color(0x12E11D2E),
            ),
        )

    val heroGradient =
        Brush.linearGradient(
            listOf(
                AmoledPalette.accentHot.copy(alpha = 0.22f),
                AmoledPalette.accent.copy(alpha = 0.12f),
                AmoledPalette.accentDeep.copy(alpha = 0.08f),
                AmoledPalette.bg,
            ),
        )

    val cardWarm =
        Brush.horizontalGradient(
            listOf(
                AmoledPalette.accent.copy(alpha = 0.18f),
                AmoledPalette.surfaceHigh,
            ),
        )

    val cardCool =
        Brush.horizontalGradient(
            listOf(
                AmoledPalette.accentHot.copy(alpha = 0.10f),
                AmoledPalette.surfaceHigh,
            ),
        )

    val miniPlayerGradient =
        Brush.verticalGradient(
            listOf(
                AmoledPalette.accent.copy(alpha = 0.18f),
                AmoledPalette.surfaceHighest,
                AmoledPalette.surface,
            ),
        )

    val bottomBarGradient =
        Brush.verticalGradient(
            listOf(
                AmoledPalette.surfaceHighest,
                AmoledPalette.surface,
                AmoledPalette.bg,
            ),
        )

    val activeTabGradient =
        Brush.verticalGradient(
            listOf(
                AmoledPalette.accent.copy(alpha = 0.22f),
                AmoledPalette.accent.copy(alpha = 0.04f),
            ),
        )

    val redBorderGlow =
        Brush.horizontalGradient(
            listOf(
                AmoledPalette.accent.copy(alpha = 0.50f),
                AmoledPalette.accentHot.copy(alpha = 0.25f),
                Color.Transparent,
            ),
        )

    val progressTrack =
        Brush.horizontalGradient(
            listOf(
                AmoledPalette.accentDeep,
                AmoledPalette.accent,
                AmoledPalette.accentHot,
            ),
        )

    val scrim =
        Brush.verticalGradient(
            listOf(
                Color.Transparent,
                AmoledPalette.bg.copy(alpha = 0.6f),
                AmoledPalette.bg,
            ),
        )
}
