package dev.vz.ljod.core.ui.glass

import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.animateDpAsState
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.offset
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.ripple.rememberRipple
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Switch
import androidx.compose.material3.SwitchDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.Dp
import androidx.compose.ui.unit.IntOffset
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import dev.vz.ljod.core.ui.motion.LjodMotion
import dev.vz.ljod.core.ui.theme.AmoledPalette
import dev.vz.ljod.core.ui.theme.LjodDimens
import dev.vz.ljod.core.ui.theme.LjodTheme

enum class GlassTone { Subtle, Warm, Accent, Danger }

@Composable
fun LjodSwitch(
    checked: Boolean,
    onCheckedChange: (Boolean) -> Unit,
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
) {
    val palette = LjodTheme.palette
    val trackWidth = 44.dp
    val trackHeight = 24.dp
    val thumbSize = 18.dp
    val padding = 3.dp

    val thumbOffset by animateDpAsState(
        targetValue = if (checked) trackWidth - thumbSize - padding else padding,
        animationSpec = LjodMotion.spring(),
        label = "thumb_offset",
    )

    val trackColor by animateColorAsState(
        targetValue = if (checked) palette.accent.copy(alpha = 0.35f) else palette.surfaceHigh,
        animationSpec = LjodMotion.tween(200),
        label = "track_color",
    )

    val thumbColor by animateColorAsState(
        targetValue = if (checked) palette.accentHot else palette.textSecondary,
        animationSpec = LjodMotion.tween(200),
        label = "thumb_color",
    )
    val borderColor by animateColorAsState(
        targetValue = if (checked) palette.accent.copy(alpha = 0.5f) else palette.border,
        animationSpec = LjodMotion.tween(200),
        label = "border_color",
    )

    Box(
        modifier =
            modifier
                .size(trackWidth, trackHeight)
                .clip(CircleShape)
                .background(trackColor)
                .border(LjodDimens.strokeThin, borderColor, CircleShape)
                .clickable(enabled = enabled, interactionSource = remember { MutableInteractionSource() }, indication = null) {
                    onCheckedChange(!checked)
                },
        contentAlignment = Alignment.CenterStart,
    ) {
        Box(
            modifier =
                Modifier
                    .offset { IntOffset(x = thumbOffset.roundToPx(), y = 0) }
                    .size(thumbSize)
                    .shadow(if (checked) 4.dp else 0.dp, CircleShape, ambientColor = palette.accentHot.copy(alpha = 0.5f))
                    .clip(CircleShape)
                    .background(
                        if (checked) {
                            Brush.verticalGradient(listOf(palette.accentHot, palette.accent))
                        } else {
                            Brush.verticalGradient(listOf(palette.textSecondary, palette.textTertiary))
                        },
                    )
                    .border(1.dp, thumbColor, CircleShape)
        )
    }
}

@Composable
fun GlassSurface(
    modifier: Modifier = Modifier,
    tone: GlassTone = GlassTone.Subtle,
    cornerRadius: Dp = LjodDimens.radiusXl,
    elevation: Dp = LjodDimens.elevationMd,
    border: Boolean = true,
    onClick: (() -> Unit)? = null,
    content: @Composable () -> Unit,
) {
    val palette = LjodTheme.palette
    val brush: Brush =
        when (tone) {
            GlassTone.Subtle -> {
                Brush.verticalGradient(
                    listOf(palette.surfaceHighest, palette.surface),
                )
            }

            GlassTone.Warm -> {
                GlassStyleOverride.cardWarm
            }

            GlassTone.Accent -> {
                GlassStyleOverride.accentGradient
            }

            GlassTone.Danger -> {
                Brush.verticalGradient(
                    listOf(palette.accent.copy(alpha = 0.45f), palette.accentDeep.copy(alpha = 0.20f), palette.surface),
                )
            }
        }
    val baseModifier =
        modifier
            .shadow(elevation, RoundedCornerShape(cornerRadius), ambientColor = palette.accent.copy(alpha = 0.12f))
            .clip(RoundedCornerShape(cornerRadius))
            .background(brush)
    val withBorder =
        if (border) {
            baseModifier.border(
                LjodDimens.strokeThin,
                palette.accent.copy(alpha = if (tone == GlassTone.Subtle) 0.18f else 0.35f),
                RoundedCornerShape(cornerRadius),
            )
        } else {
            baseModifier
        }

    val withClick =
        if (onClick != null) {
            withBorder.clickable(
                interactionSource = remember { MutableInteractionSource() },
                indication = null,
                onClick = onClick,
            )
        } else {
            withBorder
        }

    Box(modifier = withClick) { content() }
}

private object GlassStyleOverride {
    val cardWarm: Brush =
        Brush.horizontalGradient(
            listOf(AmoledPalette.accent.copy(alpha = 0.18f), AmoledPalette.surfaceHigh),
        )
    val accentGradient: Brush =
        Brush.verticalGradient(
            listOf(AmoledPalette.accent.copy(alpha = 0.40f), AmoledPalette.accent.copy(alpha = 0.10f)),
        )
}

@Composable
fun GlassButton(
    text: String,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    icon: ImageVector? = null,
    enabled: Boolean = true,
    tone: GlassTone = GlassTone.Accent,
    compact: Boolean = false,
) {
    val palette = LjodTheme.palette
    val brush: Brush =
        when {
            !enabled -> {
                Brush.verticalGradient(listOf(palette.surface, palette.surfaceHigh))
            }

            tone == GlassTone.Accent -> {
                Brush.verticalGradient(
                    listOf(palette.accent, palette.accentDeep, palette.accentDeep),
                )
            }

            tone == GlassTone.Danger -> {
                Brush.verticalGradient(
                    listOf(palette.accentHot, palette.accent),
                )
            }

            else -> {
                Brush.verticalGradient(
                    listOf(palette.surfaceHighest, palette.surfaceHigh),
                )
            }
        }
    val textColor =
        when {
            !enabled -> palette.textTertiary
            tone == GlassTone.Subtle -> palette.textPrimary
            else -> palette.onAccent
        }
    val border =
        if (enabled) {
            palette.accentHot.copy(alpha = if (tone == GlassTone.Subtle) 0.15f else 0.45f)
        } else {
            palette.border
        }

    Row(
        modifier =
            modifier
                .shadow(
                    if (enabled) LjodDimens.elevationMd else LjodDimens.elevationNone,
                    RoundedCornerShape(LjodDimens.radiusMd),
                    ambientColor = palette.accent.copy(alpha = if (enabled) 0.4f else 0f),
                ).clip(RoundedCornerShape(LjodDimens.radiusMd))
                .background(brush)
                .border(LjodDimens.strokeThin, border, RoundedCornerShape(LjodDimens.radiusMd))
                .clickable(enabled = enabled, onClick = onClick)
                .padding(
                    horizontal = if (compact) LjodDimens.spacing else LjodDimens.spacingLg,
                    vertical = if (compact) LjodDimens.spacingSm else LjodDimens.spacing,
                ),
        verticalAlignment = Alignment.CenterVertically,
        horizontalArrangement = Arrangement.Center,
    ) {
        if (icon != null) {
            Icon(icon, contentDescription = null, tint = textColor, modifier = Modifier.size(LjodDimens.iconMd))
            Spacer(Modifier.width(LjodDimens.spacingSm))
        }
        Text(
            text,
            style =
                MaterialTheme.typography.labelLarge.copy(
                    fontWeight = FontWeight.Bold,
                    letterSpacing = 1.sp,
                ),
            color = textColor,
        )
    }
}

@Composable
fun GlassIconButton(
    icon: ImageVector,
    contentDescription: String?,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    tone: GlassTone = GlassTone.Subtle,
    size: Dp = LjodDimens.minTouchTarget,
    iconSize: Dp = LjodDimens.iconLg,
    enabled: Boolean = true,
) {
    val palette = LjodTheme.palette
    val brush: Brush =
        when (tone) {
            GlassTone.Subtle -> Brush.verticalGradient(listOf(palette.surfaceHigh, palette.surface))
            GlassTone.Warm -> Brush.verticalGradient(listOf(palette.accent.copy(alpha = 0.20f), palette.surface))
            GlassTone.Accent -> Brush.verticalGradient(listOf(palette.accent, palette.accentDeep))
            GlassTone.Danger -> Brush.verticalGradient(listOf(palette.accentHot, palette.accent))
        }
    val tint =
        when {
            !enabled -> palette.textTertiary
            tone == GlassTone.Subtle -> palette.textPrimary
            else -> palette.onAccent
        }
    Box(
        modifier =
            modifier
                .size(size)
                .shadow(
                    LjodDimens.elevationSm,
                    RoundedCornerShape(LjodDimens.radiusLg),
                    ambientColor = palette.accent.copy(alpha = if (enabled) 0.25f else 0f),
                ).clip(RoundedCornerShape(LjodDimens.radiusLg))
                .background(brush)
                .border(
                    LjodDimens.strokeThin,
                    palette.accent.copy(alpha = if (tone == GlassTone.Subtle) 0.20f else 0.45f),
                    RoundedCornerShape(LjodDimens.radiusLg),
                ).clickable(enabled = enabled, onClick = onClick),
        contentAlignment = Alignment.Center,
    ) {
        Icon(icon, contentDescription = contentDescription, tint = tint, modifier = Modifier.size(iconSize))
    }
}

@Composable
fun GlassChip(
    text: String,
    selected: Boolean = false,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
    enabled: Boolean = true,
) {
    val palette = LjodTheme.palette
    val bg = if (selected) palette.accent.copy(alpha = 0.30f) else palette.surface
    val border = if (selected) palette.accentHot else palette.border
    val labelColor = if (selected) palette.textPrimary else palette.textSecondary

    Box(
        modifier =
            modifier
                .clip(RoundedCornerShape(LjodDimens.radiusPill))
                .background(bg)
                .border(LjodDimens.strokeThin, border, RoundedCornerShape(LjodDimens.radiusPill))
                .clickable(enabled = enabled, onClick = onClick)
                .padding(horizontal = LjodDimens.spacing, vertical = LjodDimens.spacingSm),
        contentAlignment = Alignment.Center,
    ) {
        Text(
            text,
            style =
                MaterialTheme.typography.labelMedium.copy(
                    fontWeight = FontWeight.SemiBold,
                    letterSpacing = 0.5.sp,
                ),
            color = labelColor,
        )
    }
}

@Composable
fun GlassDivider(
    modifier: Modifier = Modifier,
    height: Dp = LjodDimens.strokeThin,
) {
    Spacer(
        modifier =
            modifier
                .height(height)
                .background(
                    Brush.horizontalGradient(
                        listOf(
                            Color.Transparent,
                            AmoledPalette.accent.copy(alpha = 0.30f),
                            Color.Transparent,
                        ),
                    ),
                ),
    )
}

@Composable
fun GlassSectionHeader(
    title: String,
    modifier: Modifier = Modifier,
    trailing: @Composable (() -> Unit)? = null,
) {
    Row(
        modifier =
            modifier
                .fillMaxWidth()
                .padding(horizontal = LjodDimens.spacing, vertical = LjodDimens.spacingSm),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Text(
            title.uppercase(),
            style =
                MaterialTheme.typography.labelLarge.copy(
                    fontWeight = FontWeight.Bold,
                    letterSpacing = 2.sp,
                ),
            color = LjodTheme.palette.textSecondary,
            modifier = Modifier.weight(1f),
        )
        trailing?.invoke()
    }
}
