package dev.vz.ljod.ui.home

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.animation.core.LinearEasing
import androidx.compose.animation.core.RepeatMode
import androidx.compose.animation.core.animateFloat
import androidx.compose.animation.core.infiniteRepeatable
import androidx.compose.animation.core.rememberInfiniteTransition
import androidx.compose.animation.core.tween
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.MusicNote
import androidx.compose.material.icons.rounded.PlayArrow
import androidx.compose.material.icons.rounded.QueueMusic
import androidx.compose.material.icons.rounded.Refresh
import androidx.compose.material.icons.rounded.Search
import androidx.compose.material.icons.rounded.Shuffle
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.rotate
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.stringResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import androidx.core.content.ContextCompat
import coil3.compose.AsyncImage
import dev.vz.ljod.R
import dev.vz.ljod.app.LjodViewModel
import dev.vz.ljod.app.ScreenState
import dev.vz.ljod.core.data.scanner.AudioItem
import dev.vz.ljod.core.ui.glass.GlassButton
import dev.vz.ljod.core.ui.glass.GlassIconButton
import dev.vz.ljod.core.ui.glass.GlassSectionHeader
import dev.vz.ljod.core.ui.glass.GlassSurface
import dev.vz.ljod.core.ui.glass.GlassTone
import dev.vz.ljod.core.ui.theme.AmoledPalette
import dev.vz.ljod.core.ui.theme.LjodDimens
import dev.vz.ljod.core.ui.theme.LjodTheme

@Composable
fun HomeScreen(
    viewModel: LjodViewModel,
    onSongClick: (AudioItem) -> Unit = {},
) {
    val context = LocalContext.current
    var hasPermission by remember { mutableStateOf(hasPermission(context)) }
    val songs by viewModel.songs.collectAsState()
    val albums by viewModel.albums.collectAsState()
    val artists by viewModel.artists.collectAsState()
    val lastPlayed by viewModel.lastPlayedInfo.collectAsState()
    val isScanning by viewModel.isScanning.collectAsState()

    val permLauncher =
        rememberLauncherForActivityResult(
            ActivityResultContracts.RequestPermission(),
        ) { granted -> hasPermission = granted }

    LazyColumn(
        modifier =
            Modifier
                .fillMaxSize()
                .padding(horizontal = 18.dp),
        verticalArrangement = Arrangement.spacedBy(14.dp),
    ) {
        item { Spacer(Modifier.height(36.dp)) }
        item { HeroBanner(isScanning, onRescan = { viewModel.rescan() }) }
        if (!hasPermission) {
            item { PermissionCard(permLauncher) }
        } else {
            if (songs.isEmpty() && !isScanning) {
                item { EmptyState() }
            } else {
                val resumeSong = lastPlayed?.let { info -> songs.find { it.id == info.songId } }
                if (resumeSong != null) {
                    item {
                        ResumeCard(
                            title = lastPlayed!!.title,
                            artist = lastPlayed!!.artist,
                            onClick = { viewModel.resumeLastPlayed() },
                            onDismiss = { viewModel.dismissLastPlayed() },
                        )
                    }
                }
                item { StatsRow(songs.size, albums.size, artists.size) }
                item {
                    GlassSurface(
                        tone = GlassTone.Warm,
                        modifier = Modifier.fillMaxWidth(),
                    ) {
                        Row(
                            modifier = Modifier.padding(16.dp),
                            verticalAlignment = Alignment.CenterVertically,
                        ) {
                            Column(modifier = Modifier.weight(1f)) {
                                Text(
                                    "Quick play",
                                    style =
                                        MaterialTheme.typography.labelMedium.copy(
                                            fontWeight = FontWeight.Bold,
                                            letterSpacing = 2.sp,
                                        ),
                                    color = LjodTheme.palette.accent,
                                )
                                Spacer(Modifier.height(4.dp))
                                Text(
                                    "Shuffle your entire library",
                                    style = MaterialTheme.typography.bodyMedium,
                                    color = LjodTheme.palette.textPrimary,
                                )
                            }
                            GlassIconButton(
                                icon = Icons.Rounded.Shuffle,
                                contentDescription = "Shuffle all",
                                onClick = { viewModel.shuffleAll() },
                                tone = GlassTone.Accent,
                            )
                        }
                    }
                }

                if (albums.isNotEmpty()) {
                    item {
                        GlassSectionHeader(title = "Albums")
                    }
                    item { AlbumCarousel(albums, onAlbumClick = { viewModel.navigateTo(ScreenState.AlbumDetail(it.id)) }) }
                }

                if (artists.isNotEmpty()) {
                    item {
                        GlassSectionHeader(title = "Artists")
                    }
                    item {
                        ArtistRow(
                            artists = artists.take(10),
                            onClick = { viewModel.navigateTo(ScreenState.ArtistDetail(it.name)) },
                        )
                    }
                }

                item { GlassSectionHeader(title = "Recent") }
                items(songs.takeLast(15).reversed(), key = { it.id }) { song ->
                    HomeSongRow(song, onClick = { onSongClick(song) })
                }
            }
        }
        item { Spacer(Modifier.height(120.dp)) }
    }
}

@Composable
private fun HeroBanner(
    isScanning: Boolean,
    onRescan: () -> Unit,
) {
    val palette = LjodTheme.palette
    val transition = rememberInfiniteTransition(label = "hero")
    val phase by transition.animateFloat(
        initialValue = 0f,
        targetValue = 1f,
        animationSpec = infiniteRepeatable(tween(10000, easing = LinearEasing), RepeatMode.Reverse),
        label = "phase",
    )
    GlassSurface(
        tone = GlassTone.Warm,
        modifier =
            Modifier
                .fillMaxWidth(),
        cornerRadius = LjodDimens.radiusHero,
        elevation = LjodDimens.elevationLg,
    ) {
        Box(
            modifier =
                Modifier
                    .background(
                        Brush.linearGradient(
                            0.0f to palette.accentHot.copy(alpha = 0.15f + 0.10f * phase),
                            0.5f to palette.accent.copy(alpha = 0.08f),
                            1.0f to palette.bg,
                        ),
                    ).padding(LjodDimens.spacingLg),
        ) {
            Column {
                Row(verticalAlignment = Alignment.CenterVertically) {
                    Text(
                        text = "Ljod",
                        style =
                            MaterialTheme.typography.displayMedium.copy(
                                fontWeight = FontWeight.Black,
                                letterSpacing = (-3).sp,
                            ),
                        color = palette.textPrimary,
                        modifier = Modifier.weight(1f),
                    )
                    GlassIconButton(
                        icon = Icons.Rounded.Refresh,
                        contentDescription = "Rescan",
                        onClick = onRescan,
                        tone = if (isScanning) GlassTone.Accent else GlassTone.Subtle,
                        size = 40.dp,
                        iconSize = 20.dp,
                    )
                }
                Text(
                    text = stringResource(R.string.app_subtitle),
                    style = MaterialTheme.typography.titleMedium,
                    color = palette.accent,
                )
                Spacer(Modifier.height(LjodDimens.spacing))
                Box(
                    modifier =
                        Modifier
                            .clip(LjodDimens.radiusSm.let { RoundedCornerShape(it) })
                            .background(if (isScanning) palette.accent.copy(alpha = 0.15f) else palette.surfaceHigh)
                            .padding(horizontal = 12.dp, vertical = 6.dp),
                ) {
                    Text(
                        text = if (isScanning) "Scanning library..." else "Library synced",
                        style = MaterialTheme.typography.labelMedium.copy(fontWeight = FontWeight.Bold),
                        color = if (isScanning) palette.accentHot else palette.textSecondary,
                    )
                }
            }
        }
    }
}

@Composable
private fun ResumeCard(
    title: String,
    artist: String,
    onClick: () -> Unit,
    onDismiss: () -> Unit,
) {
    val palette = LjodTheme.palette
    GlassSurface(
        tone = GlassTone.Warm,
        modifier = Modifier.fillMaxWidth(),
        onClick = onClick,
    ) {
        Row(
            modifier = Modifier.padding(16.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Box(
                modifier =
                    Modifier
                        .size(54.dp)
                        .clip(CircleShape)
                        .background(Brush.radialGradient(listOf(palette.accentHot, palette.accentDeep))),
                contentAlignment = Alignment.Center,
            ) {
                Icon(Icons.Rounded.PlayArrow, contentDescription = null, tint = palette.onAccent, modifier = Modifier.size(28.dp))
            }
            Spacer(Modifier.width(14.dp))
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    "RESUME",
                    style =
                        MaterialTheme.typography.labelSmall.copy(
                            fontWeight = FontWeight.Bold,
                            letterSpacing = 2.sp,
                        ),
                    color = palette.accent,
                )
                Text(
                    title,
                    style = MaterialTheme.typography.bodyLarge.copy(fontWeight = FontWeight.SemiBold),
                    color = palette.textPrimary,
                    maxLines = 1,
                )
                Text(artist, style = MaterialTheme.typography.bodySmall, color = palette.textSecondary, maxLines = 1)
            }
            GlassButton(text = "Dismiss", onClick = onDismiss, compact = true, tone = GlassTone.Subtle)
        }
    }
}

@Composable
private fun StatsRow(
    songCount: Int,
    albumCount: Int,
    artistCount: Int,
) {
    Row(
        modifier = Modifier.fillMaxWidth(),
        horizontalArrangement = Arrangement.spacedBy(10.dp),
    ) {
        StatCard("Tracks", songCount.toString(), modifier = Modifier.weight(1f))
        StatCard("Albums", albumCount.toString(), modifier = Modifier.weight(1f))
        StatCard("Artists", artistCount.toString(), modifier = Modifier.weight(1f))
    }
}

@Composable
private fun StatCard(
    label: String,
    value: String,
    modifier: Modifier = Modifier,
) {
    val palette = LjodTheme.palette
    GlassSurface(
        tone = GlassTone.Subtle,
        modifier = modifier,
        cornerRadius = LjodDimens.radiusLg,
        elevation = LjodDimens.elevationSm,
    ) {
        Column(
            modifier =
                Modifier
                    .background(
                        Brush.verticalGradient(
                            listOf(palette.accent.copy(alpha = 0.05f), Color.Transparent),
                        ),
                    ).padding(LjodDimens.spacing),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Text(
                value,
                style = MaterialTheme.typography.titleLarge.copy(fontWeight = FontWeight.Black),
                color = palette.textPrimary,
            )
            Text(
                label.uppercase(),
                style =
                    MaterialTheme.typography.labelSmall.copy(
                        letterSpacing = 1.sp,
                        fontWeight = FontWeight.Bold,
                    ),
                color = palette.accent,
            )
        }
    }
}

@Composable
private fun EmptyState() {
    val palette = LjodTheme.palette
    GlassSurface(
        modifier = Modifier.fillMaxWidth(),
        tone = GlassTone.Subtle,
        cornerRadius = LjodDimens.radiusXl,
    ) {
        Column(
            modifier = Modifier.padding(LjodDimens.spacingLg),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Box(
                modifier =
                    Modifier
                        .size(80.dp)
                        .clip(CircleShape)
                        .background(palette.accent.copy(alpha = 0.1f))
                        .border(LjodDimens.strokeThin, palette.accent.copy(alpha = 0.2f), CircleShape),
                contentAlignment = Alignment.Center,
            ) {
                Icon(
                    Icons.Rounded.MusicNote,
                    contentDescription = null,
                    tint = palette.accent,
                    modifier = Modifier.size(LjodDimens.iconHero),
                )
            }
            Spacer(Modifier.height(LjodDimens.spacing))
            Text(
                "Your library is waiting",
                style = MaterialTheme.typography.headlineSmall,
                color = palette.textPrimary,
                textAlign = TextAlign.Center,
            )
            Spacer(Modifier.height(LjodDimens.spacingSm))
            Text(
                "Drop your audio files anywhere on your device to start your musical journey.",
                style = MaterialTheme.typography.bodyMedium,
                color = palette.textSecondary,
                textAlign = TextAlign.Center,
            )
        }
    }
}

@Composable
private fun AlbumCarousel(
    albums: List<dev.vz.ljod.data.model.Album>,
    onAlbumClick: (dev.vz.ljod.data.model.Album) -> Unit,
) {
    LazyRow(horizontalArrangement = Arrangement.spacedBy(12.dp)) {
        items(albums, key = { it.id }) { album ->
            Column(
                modifier =
                    Modifier
                        .width(140.dp)
                        .clip(RoundedCornerShape(LjodDimens.radiusLg))
                        .clickable { onAlbumClick(album) }
                        .padding(4.dp),
            ) {
                Box(
                    modifier =
                        Modifier
                            .size(132.dp)
                            .shadow(
                                12.dp,
                                RoundedCornerShape(LjodDimens.radiusLg),
                                ambientColor = LjodTheme.palette.accent.copy(alpha = 0.4f),
                            ).clip(RoundedCornerShape(LjodDimens.radiusLg))
                            .background(Brush.verticalGradient(listOf(LjodTheme.palette.accentDeep, LjodTheme.palette.surface))),
                    contentAlignment = Alignment.Center,
                ) {
                    if (album.coverUri != null) {
                        AsyncImage(
                            model = album.coverUri,
                            contentDescription = null,
                            modifier =
                                Modifier
                                    .size(132.dp)
                                    .clip(RoundedCornerShape(LjodDimens.radiusLg)),
                        )
                    } else {
                        Icon(
                            Icons.Rounded.MusicNote,
                            contentDescription = null,
                            tint = LjodTheme.palette.accent,
                            modifier = Modifier.size(40.dp),
                        )
                    }
                }
                Spacer(Modifier.height(8.dp))
                Text(
                    album.name,
                    style = MaterialTheme.typography.bodyMedium.copy(fontWeight = FontWeight.SemiBold),
                    color = LjodTheme.palette.textPrimary,
                    maxLines = 1,
                )
                Text(
                    album.artist,
                    style = MaterialTheme.typography.bodySmall,
                    color = LjodTheme.palette.textSecondary,
                    maxLines = 1,
                )
            }
        }
    }
}

@Composable
private fun ArtistRow(
    artists: List<dev.vz.ljod.data.model.Artist>,
    onClick: (dev.vz.ljod.data.model.Artist) -> Unit,
) {
    LazyRow(
        horizontalArrangement = Arrangement.spacedBy(LjodDimens.spacing),
        contentPadding = PaddingValues(horizontal = 4.dp),
    ) {
        items(artists, key = { it.name }) { artist ->
            Column(
                horizontalAlignment = Alignment.CenterHorizontally,
                modifier =
                    Modifier
                        .width(84.dp)
                        .clickable(
                            interactionSource = remember { MutableInteractionSource() },
                            indication = null,
                            onClick = { onClick(artist) },
                        ),
            ) {
                Box(
                    modifier =
                        Modifier
                            .size(72.dp)
                            .shadow(8.dp, CircleShape, ambientColor = LjodTheme.palette.accent.copy(alpha = 0.5f))
                            .clip(CircleShape)
                            .background(
                                Brush.verticalGradient(
                                    listOf(LjodTheme.palette.accentHot, LjodTheme.palette.accentDeep),
                                ),
                            ).border(LjodDimens.strokeThick, LjodTheme.palette.onAccent.copy(alpha = 0.1f), CircleShape),
                    contentAlignment = Alignment.Center,
                ) {
                    Text(
                        artist.name.take(1).uppercase(),
                        style = MaterialTheme.typography.headlineSmall.copy(fontWeight = FontWeight.Black),
                        color = LjodTheme.palette.onAccent,
                    )
                }
                Spacer(Modifier.height(8.dp))
                Text(
                    artist.name,
                    style = MaterialTheme.typography.labelSmall.copy(fontWeight = FontWeight.Bold),
                    color = LjodTheme.palette.textPrimary,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                    textAlign = TextAlign.Center,
                )
            }
        }
    }
}

@Composable
private fun HomeSongRow(
    song: AudioItem,
    onClick: () -> Unit,
) {
    val palette = LjodTheme.palette
    GlassSurface(
        tone = GlassTone.Subtle,
        modifier = Modifier.fillMaxWidth(),
        cornerRadius = LjodDimens.radiusLg,
        onClick = onClick,
    ) {
        Row(
            modifier = Modifier.padding(10.dp),
            verticalAlignment = Alignment.CenterVertically,
        ) {
            Box(
                modifier =
                    Modifier
                        .size(44.dp)
                        .clip(RoundedCornerShape(LjodDimens.radiusMd))
                        .background(Brush.verticalGradient(listOf(palette.accent, palette.accentDeep))),
                contentAlignment = Alignment.Center,
            ) {
                if (song.albumArtUri != null) {
                    AsyncImage(
                        model = song.albumArtUri,
                        contentDescription = null,
                        modifier =
                            Modifier
                                .size(44.dp)
                                .clip(RoundedCornerShape(LjodDimens.radiusMd)),
                    )
                } else {
                    Icon(Icons.Rounded.MusicNote, contentDescription = null, tint = palette.onAccent, modifier = Modifier.size(20.dp))
                }
            }
            Spacer(Modifier.width(12.dp))
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    song.title,
                    style = MaterialTheme.typography.bodyMedium.copy(fontWeight = FontWeight.SemiBold),
                    color = palette.textPrimary,
                    maxLines = 1,
                )
                Text(
                    song.artist,
                    style = MaterialTheme.typography.bodySmall,
                    color = palette.textSecondary,
                    maxLines = 1,
                )
            }
            Text(
                song.displayDuration,
                style = MaterialTheme.typography.bodySmall,
                color = palette.textTertiary,
            )
        }
    }
}

@Composable
private fun PermissionCard(permLauncher: androidx.activity.result.ActivityResultLauncher<String>) {
    GlassSurface(tone = GlassTone.Subtle, modifier = Modifier.fillMaxWidth()) {
        Column(
            modifier = Modifier.padding(28.dp),
            horizontalAlignment = Alignment.CenterHorizontally,
        ) {
            Icon(
                Icons.Rounded.Search,
                contentDescription = null,
                tint = LjodTheme.palette.accent,
                modifier = Modifier.size(48.dp),
            )
            Spacer(Modifier.height(12.dp))
            Text(
                "Music access needed",
                style = MaterialTheme.typography.titleLarge,
                color = LjodTheme.palette.textPrimary,
            )
            Spacer(Modifier.height(4.dp))
            Text(
                "Grant access to scan your device for audio files.",
                style = MaterialTheme.typography.bodyMedium,
                color = LjodTheme.palette.textSecondary,
            )
            Spacer(Modifier.height(20.dp))
            GlassButton(
                text = "Grant access",
                icon = Icons.Rounded.Search,
                onClick = {
                    val perm =
                        if (Build.VERSION.SDK_INT >= 33) {
                            Manifest.permission.READ_MEDIA_AUDIO
                        } else {
                            Manifest.permission.READ_EXTERNAL_STORAGE
                        }
                    permLauncher.launch(perm)
                },
                tone = GlassTone.Accent,
            )
        }
    }
}

private fun hasPermission(context: android.content.Context): Boolean =
    if (Build.VERSION.SDK_INT >= 33) {
        ContextCompat.checkSelfPermission(
            context,
            Manifest.permission.READ_MEDIA_AUDIO,
        ) == PackageManager.PERMISSION_GRANTED
    } else {
        ContextCompat.checkSelfPermission(
            context,
            Manifest.permission.READ_EXTERNAL_STORAGE,
        ) == PackageManager.PERMISSION_GRANTED
    }
