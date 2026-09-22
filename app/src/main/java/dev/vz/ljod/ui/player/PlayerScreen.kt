package dev.vz.ljod.ui.player

import android.net.Uri
import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.animateFloatAsState
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.spring
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.gestures.detectDragGestures
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.WindowInsets
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.statusBars
import androidx.compose.foundation.layout.systemBars
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.layout.windowInsetsPadding
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.QueueMusic
import androidx.compose.material.icons.rounded.ArrowBack
import androidx.compose.material.icons.rounded.Bedtime
import androidx.compose.material.icons.rounded.Favorite
import androidx.compose.material.icons.rounded.FavoriteBorder
import androidx.compose.material.icons.rounded.Forward30
import androidx.compose.material.icons.rounded.GraphicEq
import androidx.compose.material.icons.rounded.MoreVert
import androidx.compose.material.icons.rounded.MusicNote
import androidx.compose.material.icons.rounded.Pause
import androidx.compose.material.icons.rounded.PlayArrow
import androidx.compose.material.icons.rounded.Repeat
import androidx.compose.material.icons.rounded.RepeatOne
import androidx.compose.material.icons.rounded.Replay10
import androidx.compose.material.icons.rounded.Shuffle
import androidx.compose.material.icons.rounded.SkipNext
import androidx.compose.material.icons.rounded.SkipPrevious
import androidx.compose.material.icons.rounded.Tune
import androidx.compose.material.icons.rounded.VolumeDown
import androidx.compose.material.icons.rounded.VolumeUp
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Slider
import androidx.compose.material3.SliderDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableFloatStateOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.geometry.Offset
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.graphicsLayer
import androidx.compose.ui.input.pointer.pointerInput
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import coil3.compose.AsyncImage
import dev.vz.ljod.core.ui.glass.GlassButton
import dev.vz.ljod.core.ui.glass.GlassIconButton
import dev.vz.ljod.core.ui.glass.GlassSurface
import dev.vz.ljod.core.ui.glass.GlassTone
import dev.vz.ljod.core.ui.theme.AmoledPalette
import dev.vz.ljod.core.ui.theme.LjodDimens
import dev.vz.ljod.core.ui.theme.LjodTheme
import dev.vz.ljod.data.settings.RepeatMode
import dev.vz.ljod.playback.PlaybackController
import kotlin.math.abs
import kotlin.math.max

private val SLEEP_OPTIONS = listOf(0L, 5 * 60_000L, 10 * 60_000L, 15 * 60_000L, 30 * 60_000L, 45 * 60_000L, 60 * 60_000L, 90 * 60_000L)

@Composable
fun PlayerScreen(
    controller: PlaybackController,
    albumArtUri: Uri? = null,
    onLyricsClick: () -> Unit,
    onMetadataEdit: () -> Unit,
    onQueue: () -> Unit,
    onEqualizer: () -> Unit,
    onBack: () -> Unit,
    onShuffleToggle: () -> Unit,
    onRepeatToggle: () -> Unit,
    shuffleEnabled: Boolean,
    repeatMode: RepeatMode,
    isFavorite: Boolean,
    sleepRemainingMs: Long,
    onFavoriteToggle: () -> Unit,
    onSleepTimer: (Long) -> Unit,
) {
    val palette = LjodTheme.palette
    val isPlaying by controller.isPlaying.collectAsState()
    val title by controller.title.collectAsState()
    val artist by controller.artist.collectAsState()
    val position by controller.position.collectAsState()
    val duration by controller.duration.collectAsState()
    val volume by controller.volume.collectAsState()

    val safeDuration = max(duration, 1L)
    var userSeeking by remember { mutableStateOf(false) }
    var seekPosition by remember { mutableFloatStateOf(0f) }
    var showSleep by remember { mutableStateOf(false) }
    var showMore by remember { mutableStateOf(false) }

    val displayPosition = if (userSeeking) seekPosition.toLong() else position
    val progress = displayPosition.toFloat() / safeDuration.toFloat()

    Box(
        modifier =
            Modifier
                .fillMaxSize()
                .background(
                    Brush.verticalGradient(
                        listOf(palette.bg, palette.surface, palette.bg),
                    ),
                ).windowInsetsPadding(WindowInsets.systemBars)
                .padding(horizontal = 22.dp, vertical = 12.dp),
    ) {
        Column(modifier = Modifier.fillMaxSize()) {
            Row(verticalAlignment = Alignment.CenterVertically) {
                GlassIconButton(
                    icon = Icons.Rounded.ArrowBack,
                    contentDescription = "Back",
                    onClick = onBack,
                )
                Spacer(Modifier.width(12.dp))
                Column(modifier = Modifier.weight(1f)) {
                    Text(
                        "PLAYING FROM LIBRARY",
                        style = MaterialTheme.typography.labelSmall.copy(letterSpacing = 2.sp),
                        color = palette.textSecondary,
                    )
                    Text(
                        artist ?: "Unknown",
                        style = MaterialTheme.typography.titleSmall.copy(fontWeight = FontWeight.SemiBold),
                        color = palette.accent,
                        maxLines = 1,
                    )
                }
                GlassIconButton(
                    icon = Icons.Rounded.MoreVert,
                    contentDescription = "More",
                    onClick = { showMore = !showMore },
                )
            }
            Spacer(Modifier.height(16.dp))
            Box(
                modifier =
                    Modifier
                        .fillMaxWidth()
                        .aspectRatio(1f)
                        .swipeGesture(onLeft = { controller.skipToNext() }, onRight = { controller.skipToPrevious() }),
                contentAlignment = Alignment.Center,
            ) {
                RotatingAlbumArt(albumArtUri, isPlaying)
            }
            Spacer(Modifier.height(20.dp))
            Row(verticalAlignment = Alignment.CenterVertically) {
                Column(modifier = Modifier.weight(1f)) {
                    Text(
                        title ?: "No track",
                        style = MaterialTheme.typography.headlineSmall.copy(fontWeight = FontWeight.Black),
                        color = palette.textPrimary,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                    )
                    Text(
                        artist ?: "Unknown artist",
                        style = MaterialTheme.typography.bodyMedium,
                        color = palette.textSecondary,
                        maxLines = 1,
                        overflow = TextOverflow.Ellipsis,
                    )
                }
                GlassIconButton(
                    icon = if (isFavorite) Icons.Rounded.Favorite else Icons.Rounded.FavoriteBorder,
                    contentDescription = if (isFavorite) "Unfavorite" else "Favorite",
                    onClick = onFavoriteToggle,
                    tone = if (isFavorite) GlassTone.Danger else GlassTone.Subtle,
                )
            }
            Spacer(Modifier.height(12.dp))
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
            Spacer(Modifier.height(10.dp))
            VolumeRow(volume, onChange = { controller.setVolume(it) })
            Spacer(Modifier.weight(1f))
            PlayerActions(
                shuffleEnabled = shuffleEnabled,
                repeatMode = repeatMode,
                onShuffleToggle = onShuffleToggle,
                onRepeatToggle = onRepeatToggle,
                onLyricsClick = onLyricsClick,
                onQueue = onQueue,
                onEqualizer = onEqualizer,
                onMetadata = onMetadataEdit,
                onSleep = { showSleep = true },
                sleepActive = sleepRemainingMs > 0,
            )
        }
    }

    if (showSleep) {
        SleepTimerDialog(
            current = sleepRemainingMs,
            options = SLEEP_OPTIONS,
            onSelect = { ms ->
                onSleepTimer(ms)
                showSleep = false
            },
            onDismiss = { showSleep = false },
        )
    }
    if (showMore) {
        MoreSheet(
            onLyrics = {
                showMore = false
                onLyricsClick()
            },
            onMetadata = {
                showMore = false
                onMetadataEdit()
            },
            onQueue = {
                showMore = false
                onQueue()
            },
            onEqualizer = {
                showMore = false
                onEqualizer()
            },
            onDismiss = { showMore = false },
        )
    }
}

@Composable
private fun RotatingAlbumArt(
    albumArtUri: Uri?,
    isPlaying: Boolean,
) {
    val palette = LjodTheme.palette
    val transition = rememberInfiniteTransition(label = "album")
    val angle by transition.animateFloat(
        initialValue = 0f,
        targetValue = 360f,
        animationSpec =
            infiniteRepeatable(
                animation = tween(25000, easing = LinearEasing),
                repeatMode = androidx.compose.animation.core.RepeatMode.Restart,
            ),
        label = "angle",
    )
    val targetScale = if (isPlaying) 1.0f else 0.85f
    val scale by animateFloatAsState(targetScale, spring(dampingRatio = 0.6f, stiffness = 150f), label = "scale")

    Box(
        modifier =
            Modifier
                .fillMaxWidth(0.92f)
                .aspectRatio(1f),
        contentAlignment = Alignment.Center,
    ) {
        // Glow effect
        Box(
            modifier =
                Modifier
                    .fillMaxSize(0.85f)
                    .graphicsLayer {
                        scaleX = scale * 1.2f
                        scaleY = scale * 1.2f
                    }.shadow(
                        48.dp,
                        CircleShape,
                        ambientColor = palette.accentHot.copy(alpha = if (isPlaying) 0.5f else 0.2f),
                        spotColor = palette.accent.copy(alpha = if (isPlaying) 0.8f else 0.3f),
                    ),
        )

        Box(
            modifier =
                Modifier
                    .fillMaxSize()
                    .graphicsLayer {
                        scaleX = scale
                        scaleY = scale
                        rotationZ = if (isPlaying) angle else 0f
                    }.clip(CircleShape)
                    .background(Brush.sweepGradient(listOf(palette.accentDeep, palette.surface, palette.accentDeep)))
                    .border(LjodDimens.strokeThick, palette.accent.copy(alpha = 0.4f), CircleShape),
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
                Icon(
                    Icons.Rounded.MusicNote,
                    contentDescription = null,
                    tint = palette.accent.copy(alpha = 0.8f),
                    modifier = Modifier.size(120.dp),
                )
            }
            // Vinyl hole
            Box(
                modifier =
                    Modifier
                        .size(32.dp)
                        .clip(CircleShape)
                        .background(palette.bg)
                        .border(1.dp, palette.accent.copy(alpha = 0.3f), CircleShape),
            )
        }
    }
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
    val palette = LjodTheme.palette
    Slider(
        value = progress,
        onValueChange = {
            onSeekStart()
            onSeekChange(it)
        },
        onValueChangeFinished = onSeekFinished,
        colors =
            SliderDefaults.colors(
                thumbColor = palette.accentHot,
                activeTrackColor = palette.accentHot,
                inactiveTrackColor = palette.surfaceHigh,
            ),
        modifier = Modifier.fillMaxWidth(),
    )
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.SpaceBetween,
    ) {
        Text(formatTime(displayPosition), style = MaterialTheme.typography.bodySmall, color = palette.textSecondary)
        Text(formatTime(duration), style = MaterialTheme.typography.bodySmall, color = palette.textSecondary)
    }
}

@Composable
@Suppress("UnusedParameter")
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
        GlassIconButton(
            icon = Icons.Rounded.SkipPrevious,
            contentDescription = "Previous",
            onClick = { controller.skipToPrevious() },
            iconSize = LjodDimens.iconXl,
        )
        GlassIconButton(
            icon = Icons.Rounded.Replay10,
            contentDescription = "Rewind 10s",
            onClick = { controller.seekBy(-10_000) },
            iconSize = LjodDimens.iconLg,
        )
        GlassIconButton(
            icon = if (isPlaying) Icons.Rounded.Pause else Icons.Rounded.PlayArrow,
            contentDescription = if (isPlaying) "Pause" else "Play",
            onClick = { controller.togglePlayPause() },
            size = 78.dp,
            iconSize = 40.dp,
            tone = GlassTone.Accent,
        )
        GlassIconButton(
            icon = Icons.Rounded.Forward30,
            contentDescription = "Forward 30s",
            onClick = { controller.seekBy(30_000) },
            iconSize = LjodDimens.iconLg,
        )
        GlassIconButton(
            icon = Icons.Rounded.SkipNext,
            contentDescription = "Next",
            onClick = { controller.skipToNext() },
            iconSize = LjodDimens.iconXl,
        )
    }
}

@Composable
private fun VolumeRow(
    volume: Float,
    onChange: (Float) -> Unit,
) {
    val palette = LjodTheme.palette
    Row(verticalAlignment = Alignment.CenterVertically) {
        Icon(Icons.Rounded.VolumeDown, contentDescription = null, tint = palette.textSecondary)
        Slider(
            value = volume,
            onValueChange = onChange,
            colors =
                SliderDefaults.colors(
                    thumbColor = palette.accent,
                    activeTrackColor = palette.accent,
                    inactiveTrackColor = palette.surfaceHigh,
                ),
            modifier = Modifier.weight(1f).padding(horizontal = 8.dp),
        )
        Icon(Icons.Rounded.VolumeUp, contentDescription = null, tint = palette.textSecondary)
    }
}

@Composable
private fun PlayerActions(
    shuffleEnabled: Boolean,
    repeatMode: RepeatMode,
    onShuffleToggle: () -> Unit,
    onRepeatToggle: () -> Unit,
    onLyricsClick: () -> Unit,
    onQueue: () -> Unit,
    onEqualizer: () -> Unit,
    onMetadata: () -> Unit,
    onSleep: () -> Unit,
    sleepActive: Boolean,
) {
    val palette = LjodTheme.palette
    onMetadata() // use param
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.SpaceEvenly,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        ActionToggle(
            icon = Icons.Rounded.Shuffle,
            active = shuffleEnabled,
            onClick = onShuffleToggle,
        )
        ActionToggle(
            icon =
                when (repeatMode) {
                    RepeatMode.Off -> Icons.Rounded.Repeat
                    RepeatMode.All -> Icons.Rounded.Repeat
                    RepeatMode.One -> Icons.Rounded.RepeatOne
                },
            active = repeatMode != RepeatMode.Off,
            onClick = onRepeatToggle,
        )
        ActionToggle(icon = Icons.AutoMirrored.Rounded.QueueMusic, active = false, onClick = onQueue)
        ActionToggle(icon = Icons.Rounded.Tune, active = false, onClick = onLyricsClick)
        ActionToggle(icon = Icons.Rounded.GraphicEq, active = false, onClick = onEqualizer)
        ActionToggle(
            icon = Icons.Rounded.Bedtime,
            active = sleepActive,
            onClick = onSleep,
        )
    }
}

@Composable
private fun ActionToggle(
    icon: androidx.compose.ui.graphics.vector.ImageVector,
    active: Boolean,
    onClick: () -> Unit,
) {
    GlassIconButton(
        icon = icon,
        contentDescription = null,
        onClick = onClick,
        size = 44.dp,
        iconSize = LjodDimens.iconMd,
        tone = if (active) GlassTone.Accent else GlassTone.Subtle,
    )
}

@Composable
private fun MoreSheet(
    onLyrics: () -> Unit,
    onMetadata: () -> Unit,
    onQueue: () -> Unit,
    onEqualizer: () -> Unit,
    onDismiss: () -> Unit,
) {
    AlertDialog(
        onDismissRequest = onDismiss,
        containerColor = LjodTheme.palette.surface,
        titleContentColor = LjodTheme.palette.accent,
        textContentColor = LjodTheme.palette.textPrimary,
        title = { Text("More") },
        text = {
            Column {
                SheetItem("Lyrics", onLyrics)
                SheetItem("Queue", onQueue)
                SheetItem("Equalizer", onEqualizer)
                SheetItem("Edit metadata", onMetadata)
            }
        },
        confirmButton = {
            TextButton(onClick = onDismiss) { Text("Close", color = LjodTheme.palette.accent) }
        },
    )
}

@Composable
private fun SheetItem(
    label: String,
    onClick: () -> Unit,
) {
    Text(
        text = label,
        color = LjodTheme.palette.textPrimary,
        style = MaterialTheme.typography.bodyLarge,
        modifier =
            Modifier
                .fillMaxWidth()
                .clickable(onClick = onClick)
                .padding(vertical = 12.dp),
    )
}

@Composable
private fun SleepTimerDialog(
    current: Long,
    options: List<Long>,
    onSelect: (Long) -> Unit,
    onDismiss: () -> Unit,
) {
    AlertDialog(
        onDismissRequest = onDismiss,
        containerColor = LjodTheme.palette.surface,
        titleContentColor = LjodTheme.palette.accent,
        textContentColor = LjodTheme.palette.textPrimary,
        title = { Text("Sleep timer") },
        text = {
            Column {
                if (current > 0) {
                    Text(
                        "Active: ${formatRemaining(current)}",
                        style = MaterialTheme.typography.bodyMedium,
                        color = LjodTheme.palette.accent,
                    )
                    Spacer(Modifier.height(8.dp))
                }
                options.forEach { ms ->
                    val label =
                        when (ms) {
                            0L -> "Off"
                            else -> "${ms / 60_000} minutes"
                        }
                    Text(
                        text = label,
                        style = MaterialTheme.typography.bodyLarge,
                        color = LjodTheme.palette.textPrimary,
                        modifier =
                            Modifier
                                .fillMaxWidth()
                                .clickable { onSelect(ms) }
                                .padding(vertical = 10.dp),
                    )
                }
            }
        },
        confirmButton = {
            TextButton(onClick = onDismiss) { Text("Done", color = LjodTheme.palette.accent) }
        },
    )
}

private fun formatRemaining(ms: Long): String {
    val totalSec = ms / 1000
    val min = totalSec / 60
    val sec = totalSec % 60
    return "%d:%02d".format(min, sec)
}

private fun formatTime(ms: Long): String {
    val totalSec = ms / 1000
    return "%d:%02d".format(totalSec / 60, totalSec % 60)
}

private fun Modifier.swipeGesture(
    onLeft: () -> Unit,
    onRight: () -> Unit,
): Modifier =
    this.pointerInput(Unit) {
        var totalDx = 0f
        detectDragGestures(
            onDragStart = { totalDx = 0f },
            onDragEnd = {
                if (totalDx > 80f) {
                    onRight()
                } else if (totalDx < -80f) {
                    onLeft()
                }
            },
        ) { change, dragAmount ->
            change.consume()
            totalDx += dragAmount.x
        }
    }
