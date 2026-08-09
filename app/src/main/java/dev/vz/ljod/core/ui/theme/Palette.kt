package dev.vz.ljod.core.ui.theme

import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color

data class LjodPalette(
    val accent: Color,
    val accent2: Color,
    val accent3: Color,
    val accentMuted: Color,
    val accentDim: Color,
    val glow: Color,
    val gradient1: Color,
    val gradient2: Color,
    val gradient3: Color,
    val bg: Color,
    val surface: Color,
    val surfaceHigh: Color,
    val surfaceHighest: Color,
    val border: Color,
    val textPrimary: Color,
    val textSecondary: Color,
    val error: Color,
    val glassHighlight: Color,
    val glassBorder: Color,
)

val NordicPalette = LjodPalette(
    accent = Color(0xFFFFB347),
    accent2 = Color(0xFFE85D75),
    accent3 = Color(0xFF7C6BFF),
    accentMuted = Color(0x99FFB347),
    accentDim = Color(0x33FFB347),
    glow = Color(0xCCFFB347),
    gradient1 = Color(0xFFFFB347),
    gradient2 = Color(0xFFE85D75),
    gradient3 = Color(0xFF7C6BFF),
    bg = Color(0xFF050200),
    surface = Color(0xFF0F0A05),
    surfaceHigh = Color(0xFF1A1208),
    surfaceHighest = Color(0xFF251C0E),
    border = Color(0x33FFB347),
    textPrimary = Color(0xFFF3F4F6),
    textSecondary = Color(0xFF9CA3AF),
    error = Color(0xFFEF4444),
    glassHighlight = Color(0x15FFFFFF),
    glassBorder = Color(0x33FFFFFF),
)

object GlassStyle {
    val verticalGradient = Brush.verticalGradient(
        listOf(
            Color(0x25FFFFFF),
            Color(0x10FFFFFF),
        ),
    )

    val accentGradient = Brush.verticalGradient(
        listOf(
            NordicPalette.accent.copy(alpha = 0.3f),
            NordicPalette.accent.copy(alpha = 0.1f),
        ),
    )

    val surfaceGradient = Brush.verticalGradient(
        listOf(
            NordicPalette.surfaceHighest,
            NordicPalette.surfaceHigh,
        ),
    )

    val chipGradient = Brush.verticalGradient(
        listOf(
            Color(0x30FFB347),
            Color(0x12FFB347),
        ),
    )

    val heroGradient = Brush.horizontalGradient(
        listOf(
            NordicPalette.accent.copy(alpha = 0.18f),
            NordicPalette.gradient2.copy(alpha = 0.12f),
            NordicPalette.gradient3.copy(alpha = 0.08f),
            NordicPalette.surface,
        ),
    )

    val cardWarm = Brush.horizontalGradient(
        listOf(
            NordicPalette.accent.copy(alpha = 0.15f),
            NordicPalette.surfaceHigh,
        ),
    )

    val cardCool = Brush.horizontalGradient(
        listOf(
            NordicPalette.gradient3.copy(alpha = 0.12f),
            NordicPalette.surfaceHigh,
        ),
    )

    val miniPlayerGradient = Brush.verticalGradient(
        listOf(
            NordicPalette.accent.copy(alpha = 0.12f),
            NordicPalette.surfaceHighest,
            NordicPalette.surfaceHigh,
        ),
    )

    val bottomBarGradient = Brush.verticalGradient(
        listOf(
            NordicPalette.surfaceHighest,
            NordicPalette.surface,
        ),
    )

    val activeTabGradient = Brush.verticalGradient(
        listOf(
            NordicPalette.accent.copy(alpha = 0.2f),
            NordicPalette.accent.copy(alpha = 0.05f),
        ),
    )

    val warmBorderGlow = Brush.horizontalGradient(
        listOf(
            NordicPalette.accent.copy(alpha = 0.4f),
            NordicPalette.gradient2.copy(alpha = 0.2f),
            Color.Transparent,
        ),
    )
}
