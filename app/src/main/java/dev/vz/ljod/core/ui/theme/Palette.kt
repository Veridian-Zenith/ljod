package dev.vz.ljod.core.ui.theme

import androidx.compose.ui.graphics.Color

// ============================================================
// Veridian Zenith — Nordic Void palettes
// Extracted from vzdev.indevs.in. 4 switchable atmospheres.
// ============================================================

data class LjodPalette(
    val accent: Color,
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
)

object LjodPalettes {
    val Nordic = LjodPalette(
        accent = Color(0xFFFFB347),
        accentMuted = Color(0x99FFB347),
        accentDim = Color(0x33FFB347),
        glow = Color(0xCCFFB347),
        gradient1 = Color(0xFFFFB347),
        gradient2 = Color(0xFFD72638),
        gradient3 = Color(0xFFFFB347),
        bg = Color(0xFF050200),
        surface = Color(0xFF0F0A05),
        surfaceHigh = Color(0xFF1A1208),
        surfaceHighest = Color(0xFF251C0E),
        border = Color(0x33FFB347),
        textPrimary = Color(0xFFF3F4F6),
        textSecondary = Color(0xFFD1D5DB),
        error = Color(0xFFEF4444),
    )

    val Midnight = LjodPalette(
        accent = Color(0xFF818CF8),
        accentMuted = Color(0x99818CF8),
        accentDim = Color(0x338B5CF6),
        glow = Color(0xCC8B5CF6),
        gradient1 = Color(0xFF818CF8),
        gradient2 = Color(0xFFC084FC),
        gradient3 = Color(0xFF818CF8),
        bg = Color(0xFF020008),
        surface = Color(0xFF0C0A1F),
        surfaceHigh = Color(0xFF161330),
        surfaceHighest = Color(0xFF1F1B3E),
        border = Color(0x338B5CF6),
        textPrimary = Color(0xFFF3F4F6),
        textSecondary = Color(0xFFA78BFA),
        error = Color(0xFFEF4444),
    )

    val BloodMoon = LjodPalette(
        accent = Color(0xFFEF4444),
        accentMuted = Color(0x99EF4444),
        accentDim = Color(0x33DC2626),
        glow = Color(0xCCDC2626),
        gradient1 = Color(0xFFEF4444),
        gradient2 = Color(0xFF7F1D1D),
        gradient3 = Color(0xFFEF4444),
        bg = Color(0xFF080000),
        surface = Color(0xFF1A0808),
        surfaceHigh = Color(0xFF260C0C),
        surfaceHighest = Color(0xFF331212),
        border = Color(0x33DC2626),
        textPrimary = Color(0xFFF3F4F6),
        textSecondary = Color(0xFFF87171),
        error = Color(0xFFEF4444),
    )

    val Golden = LjodPalette(
        accent = Color(0xFFFFD700),
        accentMuted = Color(0x99FFD700),
        accentDim = Color(0x4DFFD700),
        glow = Color(0xCCFFD700),
        gradient1 = Color(0xFFFFD700),
        gradient2 = Color(0xFFB45309),
        gradient3 = Color(0xFFFFD700),
        bg = Color(0xFF0A0800),
        surface = Color(0xFF1A1205),
        surfaceHigh = Color(0xFF261C08),
        surfaceHighest = Color(0xFF33260C),
        border = Color(0x4DFFD700),
        textPrimary = Color(0xFFF3F4F6),
        textSecondary = Color(0xFFE6C895),
        error = Color(0xFFEF4444),
    )
}
