package dev.vz.ljod.ui.shell

import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.spring
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.Favorite
import androidx.compose.material.icons.rounded.Home
import androidx.compose.material.icons.rounded.LibraryMusic
import androidx.compose.material.icons.rounded.Search
import androidx.compose.material.icons.rounded.Settings
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
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
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import dev.vz.ljod.core.ui.motion.LjodMotion
import dev.vz.ljod.core.ui.theme.AmoledPalette
import dev.vz.ljod.core.ui.theme.LjodDimens
import dev.vz.ljod.core.ui.theme.LjodTheme

enum class BottomNavTab(
    val label: String,
    val icon: ImageVector,
) {
    Home("Home", Icons.Rounded.Home),
    Search("Search", Icons.Rounded.Search),
    Library("Library", Icons.Rounded.LibraryMusic),
    Favorites("Favorites", Icons.Rounded.Favorite),
    Settings("Settings", Icons.Rounded.Settings),
}

@Composable
fun BottomNav(
    selected: BottomNavTab,
    onSelect: (BottomNavTab) -> Unit,
    modifier: Modifier = Modifier,
) {
    val palette = LjodTheme.palette
    Row(
        modifier =
            modifier
                .fillMaxWidth()
                .padding(horizontal = 16.dp, vertical = 8.dp)
                .shadow(LjodDimens.elevationLg, RoundedCornerShape(LjodDimens.radiusXxl), ambientColor = palette.accent.copy(alpha = 0.25f))
                .clip(RoundedCornerShape(LjodDimens.radiusXxl))
                .background(
                    Brush.verticalGradient(
                        listOf(palette.surfaceHighest, palette.surface),
                    ),
                ).border(
                    LjodDimens.strokeThin,
                    palette.accent.copy(alpha = 0.15f),
                    RoundedCornerShape(LjodDimens.radiusXxl),
                ).padding(horizontal = 10.dp, vertical = 8.dp),
        horizontalArrangement = Arrangement.SpaceBetween,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        BottomNavTab.entries.forEach { tab ->
            NavItem(
                tab = tab,
                isSelected = tab == selected,
                onClick = { onSelect(tab) },
            )
        }
    }
}

@Composable
private fun NavItem(
    tab: BottomNavTab,
    isSelected: Boolean,
    onClick: () -> Unit,
) {
    val palette = LjodTheme.palette
    val scale by animateFloatAsState(
        targetValue = if (isSelected) 1.15f else 1.0f,
        animationSpec = LjodMotion.spring(stiffness = Spring.StiffnessLow),
        label = "scale",
    )
    val tint by animateColorAsState(
        targetValue = if (isSelected) palette.accentHot else palette.textTertiary,
        animationSpec = LjodMotion.tween(250),
        label = "tint",
    )

    Column(
        modifier =
            Modifier
                .clip(RoundedCornerShape(LjodDimens.radiusXl))
                .clickable(
                    indication = null,
                    interactionSource = remember { MutableInteractionSource() },
                    onClick = onClick,
                ).padding(horizontal = 12.dp, vertical = 6.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
        verticalArrangement = Arrangement.Center,
    ) {
        Box(
            modifier =
                Modifier
                    .size(36.dp),
            contentAlignment = Alignment.Center,
        ) {
            if (isSelected) {
                Box(
                    modifier =
                        Modifier
                            .size(28.dp)
                            .shadow(8.dp, CircleShape, ambientColor = palette.accentHot.copy(alpha = 0.6f))
                            .background(palette.accent.copy(alpha = 0.15f), CircleShape),
                )
            }
            Icon(
                imageVector = tab.icon,
                contentDescription = tab.label,
                tint = tint,
                modifier =
                    Modifier
                        .size(LjodDimens.iconLg)
                        .graphicsLayer {
                            scaleX = scale
                            scaleY = scale
                        },
            )
        }
        Text(
            text = tab.label,
            style =
                MaterialTheme.typography.labelSmall.copy(
                    fontWeight = if (isSelected) FontWeight.Bold else FontWeight.Medium,
                    fontSize = 10.sp,
                    letterSpacing = 0.5.sp,
                ),
            color = if (isSelected) palette.accent else palette.textTertiary,
            modifier = Modifier.padding(top = 2.dp),
        )
    }
}
