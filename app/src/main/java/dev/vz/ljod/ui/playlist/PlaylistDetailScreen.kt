package dev.vz.ljod.ui.playlist

import androidx.compose.foundation.background
import androidx.compose.foundation.clickable
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.lazy.LazyColumn
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.ArrowBack
import androidx.compose.material.icons.rounded.Delete
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
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import dev.vz.ljod.app.LjodViewModel
import dev.vz.ljod.core.ui.glass.GlassButton
import dev.vz.ljod.core.ui.glass.GlassIconButton
import dev.vz.ljod.core.ui.glass.GlassSurface
import dev.vz.ljod.core.ui.glass.GlassTone
import dev.vz.ljod.core.ui.theme.LjodDimens
import dev.vz.ljod.core.ui.theme.LjodTheme
import dev.vz.ljod.data.model.Song
import dev.vz.ljod.data.model.toAudioItem

@Composable
fun PlaylistDetailScreen(
    playlistId: Long,
    viewModel: LjodViewModel,
    onBack: () -> Unit,
) {
    val playlists by viewModel.playlists.collectAsState()
    val playlist = playlists.find { it.id == playlistId }
    var songs by remember { mutableStateOf<List<Song>>(emptyList()) }
    LaunchedEffect(playlistId) {
        songs = viewModel.songsInPlaylist(playlistId)
    }

    Column(modifier = Modifier.fillMaxSize().padding(horizontal = 18.dp)) {
        Spacer(Modifier.height(40.dp))
        Row(verticalAlignment = Alignment.CenterVertically) {
            GlassIconButton(
                icon = Icons.AutoMirrored.Rounded.ArrowBack,
                contentDescription = "Back",
                onClick = onBack,
            )
            Spacer(Modifier.width(8.dp))
            Text(
                playlist?.name ?: "Playlist",
                style = MaterialTheme.typography.titleMedium.copy(fontWeight = FontWeight.Bold),
                color = LjodTheme.palette.textPrimary,
                maxLines = 1,
                overflow = TextOverflow.Ellipsis,
                modifier = Modifier.weight(1f),
            )
            GlassIconButton(
                icon = Icons.Rounded.Delete,
                contentDescription = "Delete",
                onClick = {
                    viewModel.deletePlaylist(playlistId)
                    onBack()
                },
                tone = GlassTone.Danger,
            )
        }
        Spacer(Modifier.height(16.dp))
        GlassSurface(tone = GlassTone.Warm, modifier = Modifier.fillMaxWidth(), cornerRadius = LjodDimens.radiusHero) {
            Row(modifier = Modifier.padding(16.dp), verticalAlignment = Alignment.CenterVertically) {
                Box(
                    modifier =
                        Modifier
                            .size(96.dp)
                            .shadow(12.dp, RoundedCornerShape(LjodDimens.radiusLg))
                            .clip(RoundedCornerShape(LjodDimens.radiusLg))
                            .background(Brush.verticalGradient(listOf(LjodTheme.palette.accent, LjodTheme.palette.accentDeep))),
                    contentAlignment = Alignment.Center,
                ) {
                    Icon(Icons.Rounded.MusicNote, contentDescription = null, tint = LjodTheme.palette.onAccent)
                }
                Spacer(Modifier.width(14.dp))
                Column(modifier = Modifier.weight(1f)) {
                    Text(
                        playlist?.name ?: "Playlist",
                        style = MaterialTheme.typography.titleLarge.copy(fontWeight = FontWeight.Bold),
                        color = LjodTheme.palette.textPrimary,
                    )
                    Text("${songs.size} songs", style = MaterialTheme.typography.bodySmall, color = LjodTheme.palette.textSecondary)
                }
                GlassButton(
                    text = "Play",
                    onClick = { viewModel.playPlaylist(playlistId) },
                    tone = GlassTone.Accent,
                    enabled = songs.isNotEmpty(),
                )
            }
        }
        Spacer(Modifier.height(12.dp))
        LazyColumn(verticalArrangement = Arrangement.spacedBy(6.dp)) {
            items(songs, key = { it.id }) { song ->
                val item = song.toAudioItem()
                Row(
                    modifier =
                        Modifier
                            .fillMaxWidth()
                            .clip(RoundedCornerShape(LjodDimens.radiusMd))
                            .background(LjodTheme.palette.surface)
                            .clickable { viewModel.playSong(item) }
                            .padding(10.dp),
                    verticalAlignment = Alignment.CenterVertically,
                ) {
                    Text(
                        text = song.title,
                        style = MaterialTheme.typography.bodyMedium.copy(fontWeight = FontWeight.Medium),
                        color = LjodTheme.palette.textPrimary,
                        modifier = Modifier.weight(1f),
                        maxLines = 1,
                    )
                    Text(
                        text = formatDuration(song.duration),
                        style = MaterialTheme.typography.bodySmall,
                        color = LjodTheme.palette.textTertiary,
                    )
                    Spacer(Modifier.width(8.dp))
                    GlassIconButton(
                        icon = Icons.Rounded.Delete,
                        contentDescription = "Remove",
                        onClick = { viewModel.removeFromPlaylist(playlistId, song.id) },
                        size = 36.dp,
                        iconSize = LjodDimens.iconSm,
                    )
                }
            }
        }
    }
}

private fun formatDuration(duration: Long): String {
    val totalSec = duration / 1000
    return "%d:%02d".format(totalSec / 60, totalSec % 60)
}
