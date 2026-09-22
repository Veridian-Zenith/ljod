package dev.vz.ljod.ui.shell

import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxHeight
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.MusicNote
import androidx.compose.material.icons.rounded.Pause
import androidx.compose.material.icons.rounded.PlayArrow
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.IconButtonDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import coil3.compose.AsyncImage
import dev.vz.ljod.core.ui.theme.LjodDimens
import dev.vz.ljod.core.ui.theme.LjodTheme
import androidx.core.net.toUri

@Composable
fun MiniPlayerBar(
    title: String?,
    artist: String?,
    isPlaying: Boolean,
    progress: Float,
    albumId: Long?,
    onPlayPause: () -> Unit,
    onClick: () -> Unit,
    modifier: Modifier = Modifier,
) {
    val palette = LjodTheme.palette
    val animatedProgress by animateFloatAsState(
        targetValue = progress.coerceIn(0f, 1f),
        label = "miniProgress",
    )
    Box(
        modifier =
            modifier
                .fillMaxWidth()
                .padding(horizontal = 12.dp)
                .shadow(LjodDimens.elevationLg, RoundedCornerShape(LjodDimens.radiusXxl), ambientColor = palette.accent.copy(alpha = 0.4f))
                .clip(RoundedCornerShape(LjodDimens.radiusXxl))
                .background(
                    Brush.verticalGradient(
                        listOf(
                            palette.surfaceHighest.copy(alpha = 0.95f),
                            palette.surface.copy(alpha = 0.98f),
                        ),
                    ),
                ).border(
                    LjodDimens.strokeThin,
                    palette.accent.copy(alpha = 0.25f),
                    RoundedCornerShape(LjodDimens.radiusXxl),
                ).clickable(onClick = onClick)
                .padding(horizontal = 12.dp, vertical = 10.dp),
    ) {
        Column {
            Row(
                verticalAlignment = Alignment.CenterVertically,
                horizontalArrangement = Arrangement.spacedBy(12.dp)
            ) {
                Box(
                    modifier =
                        Modifier
                            .size(48.dp)
                            .shadow(8.dp, CircleShape, ambientColor = palette.accent.copy(alpha = 0.5f))
                            .clip(CircleShape)
                            .background(Brush.verticalGradient(listOf(palette.accent, palette.accentDeep))),
                    contentAlignment = Alignment.Center,
                ) {
                    if (albumId != null && albumId > 0) {
                        AsyncImage(
                            model = "content://media/external/audio/albumart/$albumId".toUri(),
                            contentDescription = null,
                            contentScale = ContentScale.Crop,
                            modifier =
                                Modifier
                                    .size(48.dp)
                                    .clip(CircleShape),
                        )
                    } else {
                        Icon(
                            Icons.Rounded.MusicNote,
                            contentDescription = null,
                            tint = palette.onAccent,
                            modifier = Modifier.size(24.dp),
                        )
                    }
                }
                Column(modifier = Modifier.weight(1f)) {
                    Text(
                        text = title ?: "Not Playing",
                        style = MaterialTheme.typography.titleSmall.copy(fontWeight = FontWeight.Bold),
                        color = palette.textPrimary,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                    )
                    Text(
                        text = artist ?: "Veridian Zenith",
                        style = MaterialTheme.typography.labelSmall,
                        color = palette.accent,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                    )
                }
                IconButton(
                    onClick = onPlayPause,
                    colors = IconButtonDefaults.iconButtonColors(
                        containerColor = palette.accent.copy(alpha = 0.1f),
                        contentColor = palette.accentHot
                    ),
                    modifier = Modifier.size(44.dp)
                ) {
                    Icon(
                        if (isPlaying) Icons.Rounded.Pause else Icons.Rounded.PlayArrow,
                        contentDescription = if (isPlaying) "Pause" else "Play",
                        modifier = Modifier.size(28.dp),
                    )
                }
            }
            Spacer(Modifier.height(8.dp))
            Box(
                modifier = Modifier
                    .fillMaxWidth()
                    .height(4.dp)
                    .clip(CircleShape)
                    .background(palette.surfaceHigh)
            ) {
                Box(
                    modifier = Modifier
                        .fillMaxWidth(animatedProgress)
                        .fillMaxHeight()
                        .background(
                            Brush.horizontalGradient(
                                listOf(palette.accentDeep, palette.accentHot)
                            )
                        )
                )
            }
        }
    }
}
