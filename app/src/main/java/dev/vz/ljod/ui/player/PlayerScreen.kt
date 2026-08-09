package dev.vz.ljod.ui.player

import android.net.Uri
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.ArrowBack
import androidx.compose.material.icons.filled.MusicNote
import androidx.compose.material.icons.rounded.Forward30
import androidx.compose.material.icons.rounded.Pause
import androidx.compose.material.icons.rounded.PlayArrow
import androidx.compose.material.icons.rounded.Replay10
import androidx.compose.material.icons.rounded.SkipNext
import androidx.compose.material.icons.rounded.SkipPrevious
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.IconButtonDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Slider
import androidx.compose.material3.SliderDefaults
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import coil3.compose.AsyncImage
import dev.vz.ljod.core.ui.theme.NordicPalette
import dev.vz.ljod.playback.PlaybackController
import kotlin.math.max

@Composable
fun PlayerScreen(
    controller: PlaybackController,
    albumArtUri: Uri? = null,
    onLyricsClick: () -> Unit = {},
    onMetadataEdit: () -> Unit = {},
    onBack: () -> Unit = {},
    onShuffleToggle: () -> Unit = {},
    shuffleEnabled: Boolean = false,
) {
    val isPlaying by controller.isPlaying.collectAsState()
    val title by controller.title.collectAsState()
    val artist by controller.artist.collectAsState()
    val position by controller.position.collectAsState()
    val duration by controller.duration.collectAsState()

    val safeDuration = max(duration, 1L)
    var userSeeking by remember { mutableStateOf(false) }
    var seekPosition by remember { mutableFloatStateOf(0f) }

    val displayPosition = if (userSeeking) seekPosition.toLong() else position
    val progress = displayPosition.toFloat() / safeDuration.toFloat()

    Column(
        modifier = Modifier
            .fillMaxSize()
            .background(
                Brush.verticalGradient(
                    listOf(NordicPalette.bg, NordicPalette.surface, NordicPalette.bg),
                ),
            )
            .padding(horizontal = 28.dp, vertical = 16.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        BackButton(onBack)
        Spacer(Modifier.height(4.dp))
        AlbumArt(albumArtUri)
        Spacer(Modifier.height(24.dp))
        TrackInfo(title, artist)
        Spacer(Modifier.height(16.dp))
        ProgressSection(
            progress = progress,
            displayPosition = displayPosition,
            duration = duration,
            onSeekStart = { userSeeking = true },
            onSeekChange = { seekPosition = it * safeDuration },
            onSeekFinished = {
                controller.seekTo(seekPosition.toLong())
                userSeeking = false
            },
        )
        Spacer(Modifier.height(8.dp))
        PlaybackControls(
            isPlaying = isPlaying,
            position = position,
            duration = duration,
            controller = controller,
        )
        Spacer(Modifier.weight(1f))
        PlayerActions(shuffleEnabled, onShuffleToggle, onLyricsClick, onMetadataEdit)
        Spacer(Modifier.height(16.dp))
    }
}

@Composable
private fun BackButton(onBack: () -> Unit) {
    Row(modifier = Modifier.fillMaxWidth()) {
        Icon(
            Icons.AutoMirrored.Rounded.ArrowBack,
            contentDescription = "Back",
            tint = NordicPalette.textSecondary,
            modifier = Modifier
                .size(36.dp)
                .clip(CircleShape)
                .background(NordicPalette.surfaceHigh)
                .clickable(onClick = onBack)
                .padding(6.dp),
        )
    }
}

@Composable
private fun AlbumArt(albumArtUri: Uri?) {
    Box(
        modifier = Modifier
            .fillMaxWidth(0.82f)
            .aspectRatio(1f)
            .clip(RoundedCornerShape(28.dp))
            .background(
                Brush.verticalGradient(
                    listOf(NordicPalette.surfaceHighest, NordicPalette.surfaceHigh),
                ),
            )
            .border(1.dp, NordicPalette.border, RoundedCornerShape(28.dp)),
        contentAlignment = Alignment.Center,
    ) {
        if (albumArtUri != null) {
            AsyncImage(
                model = albumArtUri,
                contentDescription = "Album art",
                contentScale = ContentScale.Crop,
                modifier = Modifier.fillMaxSize(),
            )
        } else {
            Box(
                modifier = Modifier
                    .size(80.dp)
                    .clip(CircleShape)
                    .background(
                        Brush.radialGradient(
                            listOf(NordicPalette.accent.copy(alpha = 0.2f), NordicPalette.surface),
                        ),
                    ),
                contentAlignment = Alignment.Center,
            ) {
                Icon(
                    Icons.Filled.MusicNote,
                    contentDescription = null,
                    tint = NordicPalette.accent.copy(alpha = 0.6f),
                    modifier = Modifier.size(40.dp),
                )
            }
        }
    }
}

@Composable
private fun TrackInfo(title: String?, artist: String?) {
    Text(
        text = title ?: "No track",
        style = MaterialTheme.typography.headlineSmall.copy(fontWeight = FontWeight.Bold),
        color = NordicPalette.textPrimary,
        maxLines = 1,
        overflow = TextOverflow.Ellipsis,
        modifier = Modifier.fillMaxWidth(),
    )
    Spacer(Modifier.height(4.dp))
    Text(
        text = artist ?: "Unknown artist",
        style = MaterialTheme.typography.bodyMedium,
        color = NordicPalette.textSecondary,
        maxLines = 1,
        overflow = TextOverflow.Ellipsis,
        modifier = Modifier.fillMaxWidth(),
    )
}

@Composable
private fun ProgressSection(
    progress: Float,
    displayPosition: Long,
    duration: Long,
    onSeekStart: () -> Unit,
    onSeekChange: (Float) -> Unit,
    onSeekFinished: () -> Unit,
) {
    Slider(
        value = progress,
        onValueChange = { onSeekStart(); onSeekChange(it) },
        onValueChangeFinished = onSeekFinished,
        colors = SliderDefaults.colors(
            thumbColor = NordicPalette.accent,
            activeTrackColor = NordicPalette.accent,
            inactiveTrackColor = NordicPalette.surfaceHigh,
        ),
        modifier = Modifier.fillMaxWidth(),
    )
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.SpaceBetween,
    ) {
        Text(
            formatTime(displayPosition),
            style = MaterialTheme.typography.bodySmall,
            color = NordicPalette.textSecondary,
        )
        Text(
            formatTime(duration),
            style = MaterialTheme.typography.bodySmall,
            color = NordicPalette.textSecondary,
        )
    }
}

@Composable
private fun PlaybackControls(
    isPlaying: Boolean,
    position: Long,
    duration: Long,
    controller: PlaybackController,
) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.SpaceEvenly,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        IconButton(
            onClick = { controller.skipToPrevious() },
            colors = IconButtonDefaults.iconButtonColors(
                contentColor = NordicPalette.textPrimary,
            ),
        ) {
            Icon(Icons.Rounded.SkipPrevious, contentDescription = "Previous", modifier = Modifier.size(32.dp))
        }
        IconButton(
            onClick = { controller.seekTo(max(0L, position - 10_000)) },
            colors = IconButtonDefaults.iconButtonColors(
                contentColor = NordicPalette.textSecondary,
            ),
        ) {
            Icon(Icons.Rounded.Replay10, contentDescription = "Rewind 10s", modifier = Modifier.size(28.dp))
        }
        Box(
            modifier = Modifier
                .size(72.dp)
                .clip(CircleShape)
                .background(
                    Brush.radialGradient(
                        listOf(NordicPalette.accent, NordicPalette.gradient2),
                    ),
                ),
            contentAlignment = Alignment.Center,
        ) {
            IconButton(
                onClick = { controller.togglePlayPause() },
                colors = IconButtonDefaults.iconButtonColors(
                    contentColor = NordicPalette.bg,
                ),
            ) {
                Icon(
                    if (isPlaying) Icons.Rounded.Pause else Icons.Rounded.PlayArrow,
                    contentDescription = if (isPlaying) "Pause" else "Play",
                    modifier = Modifier.size(40.dp),
                )
            }
        }
        IconButton(
            onClick = { controller.seekTo(minOf(position + 30_000, duration)) },
            colors = IconButtonDefaults.iconButtonColors(
                contentColor = NordicPalette.textSecondary,
            ),
        ) {
            Icon(Icons.Rounded.Forward30, contentDescription = "Forward 30s", modifier = Modifier.size(28.dp))
        }
        IconButton(
            onClick = { controller.skipToNext() },
            colors = IconButtonDefaults.iconButtonColors(
                contentColor = NordicPalette.textPrimary,
            ),
        ) {
            Icon(Icons.Rounded.SkipNext, contentDescription = "Next", modifier = Modifier.size(32.dp))
        }
    }
}

@Composable
private fun PlayerActions(
    shuffleEnabled: Boolean,
    onShuffleToggle: () -> Unit,
    onLyricsClick: () -> Unit,
    onMetadataEdit: () -> Unit,
) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.SpaceEvenly,
    ) {
        ActionChip(
            label = "SHUFFLE",
            isActive = shuffleEnabled,
            activeColor = NordicPalette.accent,
            onClick = onShuffleToggle,
        )
        ActionChip(
            label = "LYRICS",
            isActive = false,
            activeColor = NordicPalette.accent,
            onClick = onLyricsClick,
        )
        ActionChip(
            label = "EDIT",
            isActive = false,
            activeColor = NordicPalette.textSecondary,
            onClick = onMetadataEdit,
        )
    }
}

@Composable
private fun ActionChip(
    label: String,
    isActive: Boolean,
    activeColor: Color,
    onClick: () -> Unit,
) {
    Text(
        label,
        style = MaterialTheme.typography.labelMedium.copy(fontWeight = FontWeight.Bold),
        color = if (isActive) activeColor else NordicPalette.textSecondary,
        modifier = Modifier
            .clip(RoundedCornerShape(14.dp))
            .background(
                if (isActive) NordicPalette.accentDim else NordicPalette.surfaceHigh,
            )
            .border(1.dp, NordicPalette.border, RoundedCornerShape(14.dp))
            .clickable(onClick = onClick)
            .padding(horizontal = 18.dp, vertical = 10.dp),
    )
}

private fun formatTime(ms: Long): String {
    val totalSec = ms / 1000
    return "%d:%02d".format(totalSec / 60, totalSec % 60)
}
