package dev.vz.ljod.ui.album

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.PaddingValues
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.aspectRatio
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.ArrowBack
import androidx.compose.material.icons.rounded.MusicNote
import androidx.compose.material.icons.rounded.PlayArrow
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.compose.ui.unit.sp
import coil3.compose.AsyncImage
import dev.vz.ljod.app.LjodViewModel
import dev.vz.ljod.core.ui.glass.GlassIconButton
import dev.vz.ljod.core.ui.glass.GlassSurface
import dev.vz.ljod.core.ui.glass.GlassTone
import dev.vz.ljod.core.ui.theme.LjodDimens
import dev.vz.ljod.core.ui.theme.LjodTheme
import dev.vz.ljod.data.model.Song
import dev.vz.ljod.data.model.toAudioItem

@Composable
fun AlbumDetailScreen(
    albumId: Long,
    viewModel: LjodViewModel,
    onBack: () -> Unit,
) {
    val albums by viewModel.albums.collectAsState()
    val album = albums.find { it.id == albumId }
    var songs by remember { mutableStateOf<List<Song>>(emptyList()) }
    val palette = LjodTheme.palette

    LaunchedEffect(albumId) {
        songs = viewModel.songsInAlbum(albumId)
    }

    Column(modifier = Modifier.fillMaxSize().padding(horizontal = 18.dp)) {
        Spacer(Modifier.height(40.dp))
        Row(verticalAlignment = Alignment.CenterVertically) {
            GlassIconButton(
                icon = Icons.AutoMirrored.Rounded.ArrowBack,
                contentDescription = "Back",
                onClick = onBack,
                size = 40.dp,
                iconSize = 20.dp
            )
            Spacer(Modifier.width(12.dp))
            Text(
                "ALBUM DETAIL",
                style = MaterialTheme.typography.labelSmall.copy(letterSpacing = 2.sp),
                color = palette.textSecondary,
            )
        }
        Spacer(Modifier.height(16.dp))
        if (album != null) {
            GlassSurface(tone = GlassTone.Warm, modifier = Modifier.fillMaxWidth(), cornerRadius = LjodDimens.radiusHero) {
                Row(modifier = Modifier.padding(16.dp), verticalAlignment = Alignment.CenterVertically) {
                    Box(
                        modifier =
                            Modifier
                                .size(100.dp)
                                .shadow(16.dp, RoundedCornerShape(LjodDimens.radiusLg), ambientColor = palette.accent.copy(alpha = 0.5f))
                                .clip(RoundedCornerShape(LjodDimens.radiusLg))
                                .background(Brush.verticalGradient(listOf(palette.accentDeep, palette.surfaceHigh))),
                        contentAlignment = Alignment.Center,
                    ) {
                        if (album.coverUri != null) {
                            AsyncImage(
                                model = album.coverUri,
                                contentDescription = null,
                                contentScale = ContentScale.Crop,
                                modifier = Modifier.fillMaxSize(),
                            )
                        } else {
                            Icon(Icons.Rounded.MusicNote, contentDescription = null, tint = palette.accent, modifier = Modifier.size(48.dp))
                        }
                    }
                    Spacer(Modifier.width(16.dp))
                    Column(modifier = Modifier.weight(1f)) {
                        Text(
                            album.name,
                            style = MaterialTheme.typography.titleLarge.copy(fontWeight = FontWeight.Bold),
                            color = palette.textPrimary,
                            maxLines = 2,
                            overflow = TextOverflow.Ellipsis
                        )
                        Text(album.artist, style = MaterialTheme.typography.bodyMedium, color = palette.accent)
                        Text(
                            "${album.songCount} tracks",
                            style = MaterialTheme.typography.labelSmall,
                            color = palette.textSecondary,
                        )
                    }
                    GlassIconButton(
                        icon = Icons.Rounded.PlayArrow,
                        contentDescription = "Play album",
                        onClick = { viewModel.playAlbum(albumId) },
                        tone = GlassTone.Accent,
                        size = 48.dp,
                        iconSize = 28.dp
                    )
                }
            }
            Spacer(Modifier.height(16.dp))
            LazyColumn(
                verticalArrangement = Arrangement.spacedBy(8.dp),
                contentPadding = PaddingValues(bottom = 120.dp)
            ) {
                items(songs, key = { it.id }) { song ->
                    AlbumSongRow(song) { viewModel.playSong(song.toAudioItem()) }
                }
            }
        }
    }
}

@Composable
private fun AlbumSongRow(
    song: Song,
    onClick: () -> Unit
) {
    val palette = LjodTheme.palette
    GlassSurface(
        tone = GlassTone.Subtle,
        modifier = Modifier.fillMaxWidth(),
        cornerRadius = LjodDimens.radiusLg,
        onClick = onClick
    ) {
        Row(
            modifier = Modifier.padding(12.dp),
            verticalAlignment = Alignment.CenterVertically
        ) {
            Box(
                modifier = Modifier
                    .size(32.dp)
                    .clip(CircleShape)
                    .background(palette.accent.copy(alpha = 0.1f)),
                contentAlignment = Alignment.Center
            ) {
                Text(
                    text = (song.trackNumber ?: 0).toString(),
                    style = MaterialTheme.typography.labelMedium.copy(fontWeight = FontWeight.Bold),
                    color = palette.accent,
                )
            }
            Spacer(Modifier.width(12.dp))
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    text = song.title,
                    style = MaterialTheme.typography.bodyLarge.copy(fontWeight = FontWeight.SemiBold),
                    color = palette.textPrimary,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis
                )
            }
            Text(
                text = formatDuration(song.duration),
                style = MaterialTheme.typography.labelSmall,
                color = palette.textTertiary,
            )
        }
    }
}

private fun formatDuration(duration: Long): String {
    val totalSec = duration / 1000
    return "%d:%02d".format(totalSec / 60, totalSec % 60)
}
