package dev.vz.ljod.ui.library

import android.Manifest
import android.content.pm.PackageManager
import android.os.Build
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.border
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
import androidx.compose.foundation.lazy.LazyRow
import androidx.compose.foundation.lazy.grid.GridCells
import androidx.compose.foundation.lazy.grid.LazyVerticalGrid
import androidx.compose.foundation.lazy.grid.items
import androidx.compose.foundation.lazy.items
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.automirrored.rounded.PlaylistPlay
import androidx.compose.material.icons.rounded.Add
import androidx.compose.material.icons.rounded.Album
import androidx.compose.material.icons.rounded.MusicNote
import androidx.compose.material.icons.rounded.PlayArrow
import androidx.compose.material3.AlertDialog
import androidx.compose.material3.Icon
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
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
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextAlign
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.core.content.ContextCompat
import coil3.compose.AsyncImage
import dev.vz.ljod.app.LjodViewModel
import dev.vz.ljod.app.ScreenState
import dev.vz.ljod.core.data.scanner.AudioItem
import dev.vz.ljod.core.ui.glass.GlassButton
import dev.vz.ljod.core.ui.glass.GlassChip
import dev.vz.ljod.core.ui.glass.GlassIconButton
import dev.vz.ljod.core.ui.glass.GlassSurface
import dev.vz.ljod.core.ui.glass.GlassTone
import dev.vz.ljod.core.ui.theme.LjodDimens
import dev.vz.ljod.core.ui.theme.LjodTheme

private enum class LibraryTab(
    val label: String,
) {
    Tracks("Tracks"),
    Albums("Albums"),
    Artists("Artists"),
    Playlists("Playlists"),
}

@Composable
fun LibraryScreen(
    viewModel: LjodViewModel,
    onSongClick: (AudioItem) -> Unit = {},
) {
    val context = LocalContext.current
    var hasPermission by remember { mutableStateOf(hasPermission(context)) }
    val songs by viewModel.songs.collectAsState()
    val albums by viewModel.albums.collectAsState()
    val artists by viewModel.artists.collectAsState()
    val playlists by viewModel.playlists.collectAsState()
    var tab by remember { mutableStateOf(LibraryTab.Tracks) }
    var showCreate by remember { mutableStateOf(false) }

    val permLauncher =
        rememberLauncherForActivityResult(
            ActivityResultContracts.RequestPermission(),
        ) { granted -> hasPermission = granted }

    Column(
        modifier =
            Modifier
                .fillMaxSize()
                .padding(horizontal = 18.dp),
    ) {
        Spacer(Modifier.height(40.dp))
        Text(
            "Library",
            style = MaterialTheme.typography.displaySmall.copy(fontWeight = FontWeight.Black),
            color = LjodTheme.palette.accent,
        )
        Spacer(Modifier.height(12.dp))
        LazyRow(
            horizontalArrangement = Arrangement.spacedBy(8.dp),
            contentPadding = PaddingValues(bottom = 8.dp)
        ) {
            items(LibraryTab.entries.toList()) { entry ->
                GlassChip(text = entry.label, selected = tab == entry, onClick = { tab = entry })
            }
            item {
                GlassIconButton(
                    icon = Icons.Rounded.Add,
                    contentDescription = "New playlist",
                    onClick = { showCreate = true },
                    size = 36.dp,
                    iconSize = 18.dp,
                    tone = GlassTone.Subtle
                )
            }
        }
        
        when {
            !hasPermission -> {
                PermissionContent(permLauncher)
            }

            else -> {
                Box(modifier = Modifier.weight(1f)) {
                    when (tab) {
                        LibraryTab.Tracks -> TrackList(songs, onSongClick)
                        LibraryTab.Albums -> AlbumGrid(albums, onClick = { viewModel.navigateTo(ScreenState.AlbumDetail(it.id)) })
                        LibraryTab.Artists -> ArtistList(artists, onClick = { viewModel.navigateTo(ScreenState.ArtistDetail(it.name)) })
                        LibraryTab.Playlists -> PlaylistList(
                            playlists,
                            onClick = { viewModel.navigateTo(ScreenState.PlaylistDetail(it.id)) },
                            onPlay = { viewModel.playPlaylist(it.id) },
                        )
                    }
                }
            }
        }
    }

    if (showCreate) {
        NewPlaylistDialog(
            onDismiss = { showCreate = false },
            onCreate = { name ->
                viewModel.createPlaylist(name) { id ->
                    showCreate = false
                    viewModel.navigateTo(ScreenState.PlaylistDetail(id))
                }
            },
        )
    }
}

@Composable
private fun TrackList(
    songs: List<AudioItem>,
    onClick: (AudioItem) -> Unit,
) {
    if (songs.isEmpty()) {
        EmptyMessage("No tracks found in your library.")
        return
    }
    LazyColumn(
        verticalArrangement = Arrangement.spacedBy(8.dp),
        contentPadding = PaddingValues(top = 8.dp, bottom = 120.dp)
    ) {
        items(songs, key = { it.id }, contentType = { "song" }) { song ->
            SongRow(song, onClick = { onClick(song) })
        }
    }
}

@Composable
private fun AlbumGrid(
    albums: List<dev.vz.ljod.data.model.Album>,
    onClick: (dev.vz.ljod.data.model.Album) -> Unit,
) {
    if (albums.isEmpty()) {
        EmptyMessage("No albums discovered yet.")
        return
    }
    LazyVerticalGrid(
        columns = GridCells.Fixed(2),
        verticalArrangement = Arrangement.spacedBy(16.dp),
        horizontalArrangement = Arrangement.spacedBy(16.dp),
        contentPadding = PaddingValues(top = 8.dp, bottom = 120.dp)
    ) {
        items(albums, key = { it.id }) { album ->
            Column(
                modifier =
                    Modifier
                        .clip(RoundedCornerShape(LjodDimens.radiusLg))
                        .clickable { onClick(album) }
                        .padding(4.dp),
            ) {
                Box(
                    modifier =
                        Modifier
                            .fillMaxWidth()
                            .aspectRatio(1f)
                            .shadow(12.dp, RoundedCornerShape(LjodDimens.radiusLg), ambientColor = LjodTheme.palette.accent.copy(alpha = 0.3f))
                            .clip(RoundedCornerShape(LjodDimens.radiusLg))
                            .background(Brush.verticalGradient(listOf(LjodTheme.palette.surfaceHighest, LjodTheme.palette.surface)))
                            .border(1.dp, LjodTheme.palette.accent.copy(alpha = 0.2f), RoundedCornerShape(LjodDimens.radiusLg)),
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
                        Icon(
                            Icons.Rounded.Album,
                            contentDescription = null,
                            tint = LjodTheme.palette.accent.copy(alpha = 0.5f),
                            modifier = Modifier.size(64.dp),
                        )
                    }
                }
                Spacer(Modifier.height(8.dp))
                Text(
                    album.name,
                    style = MaterialTheme.typography.titleSmall.copy(fontWeight = FontWeight.Bold),
                    color = LjodTheme.palette.textPrimary,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis
                )
                Text(
                    album.artist,
                    style = MaterialTheme.typography.labelSmall,
                    color = LjodTheme.palette.accent,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis
                )
            }
        }
    }
}

@Composable
private fun ArtistList(
    artists: List<dev.vz.ljod.data.model.Artist>,
    onClick: (dev.vz.ljod.data.model.Artist) -> Unit,
) {
    if (artists.isEmpty()) {
        EmptyMessage("No artists identified yet.")
        return
    }
    LazyColumn(
        verticalArrangement = Arrangement.spacedBy(8.dp),
        contentPadding = PaddingValues(top = 8.dp, bottom = 120.dp)
    ) {
        items(artists, key = { it.name }) { artist ->
            GlassSurface(
                tone = GlassTone.Subtle,
                modifier = Modifier.fillMaxWidth(),
                cornerRadius = LjodDimens.radiusLg,
                onClick = { onClick(artist) },
            ) {
                Row(modifier = Modifier.padding(12.dp), verticalAlignment = Alignment.CenterVertically) {
                    Box(
                        modifier =
                            Modifier
                                .size(52.dp)
                                .clip(CircleShape)
                                .background(Brush.radialGradient(listOf(LjodTheme.palette.accentHot, LjodTheme.palette.accentDeep)))
                                .border(2.dp, LjodTheme.palette.onAccent.copy(alpha = 0.1f), CircleShape),
                        contentAlignment = Alignment.Center,
                    ) {
                        Text(
                            artist.name.take(1).uppercase(),
                            style = MaterialTheme.typography.titleLarge.copy(fontWeight = FontWeight.Black),
                            color = LjodTheme.palette.onAccent,
                        )
                    }
                    Spacer(Modifier.width(16.dp))
                    Column(modifier = Modifier.weight(1f)) {
                        Text(
                            artist.name,
                            style = MaterialTheme.typography.titleMedium.copy(fontWeight = FontWeight.Bold),
                            color = LjodTheme.palette.textPrimary,
                            maxLines = 1,
                        )
                        Text(
                            "${artist.songCount} tracks • ${artist.albumCount} albums",
                            style = MaterialTheme.typography.labelSmall,
                            color = LjodTheme.palette.accent,
                        )
                    }
                    Icon(
                        Icons.Rounded.PlayArrow,
                        contentDescription = null,
                        tint = LjodTheme.palette.accent.copy(alpha = 0.4f),
                        modifier = Modifier.size(20.dp)
                    )
                }
            }
        }
    }
}

@Composable
private fun PlaylistList(
    playlists: List<dev.vz.ljod.data.model.Playlist>,
    onClick: (dev.vz.ljod.data.model.Playlist) -> Unit,
    onPlay: (dev.vz.ljod.data.model.Playlist) -> Unit,
) {
    LazyColumn(
        verticalArrangement = Arrangement.spacedBy(10.dp),
        contentPadding = PaddingValues(top = 8.dp, bottom = 120.dp)
    ) {
        items(playlists, key = { it.id }) { p ->
            GlassSurface(
                tone = GlassTone.Subtle,
                modifier = Modifier.fillMaxWidth(),
                cornerRadius = LjodDimens.radiusLg,
                onClick = { onClick(p) },
            ) {
                Row(modifier = Modifier.padding(14.dp), verticalAlignment = Alignment.CenterVertically) {
                    Box(
                        modifier =
                            Modifier
                                .size(48.dp)
                                .clip(RoundedCornerShape(LjodDimens.radiusMd))
                                .background(Brush.verticalGradient(listOf(LjodTheme.palette.accentDeep, LjodTheme.palette.surfaceHigh))),
                        contentAlignment = Alignment.Center,
                    ) {
                        Icon(Icons.AutoMirrored.Rounded.PlaylistPlay, contentDescription = null, tint = LjodTheme.palette.accent, modifier = Modifier.size(28.dp))
                    }
                    Spacer(Modifier.width(16.dp))
                    Column(modifier = Modifier.weight(1f)) {
                        Text(
                            p.name,
                            style = MaterialTheme.typography.titleMedium.copy(fontWeight = FontWeight.Bold),
                            color = LjodTheme.palette.textPrimary,
                            maxLines = 1,
                        )
                        Text("${p.songCount} tracks", style = MaterialTheme.typography.labelSmall, color = LjodTheme.palette.accent)
                    }
                    GlassIconButton(
                        icon = Icons.Rounded.PlayArrow,
                        contentDescription = "Play playlist",
                        onClick = { onPlay(p) },
                        tone = GlassTone.Accent,
                        size = 40.dp,
                        iconSize = 24.dp
                    )
                }
            }
        }
    }
}

@Composable
internal fun SongRow(
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
        Row(modifier = Modifier.padding(10.dp), verticalAlignment = Alignment.CenterVertically) {
            Box(
                modifier =
                    Modifier
                        .size(46.dp)
                        .clip(RoundedCornerShape(LjodDimens.radiusMd))
                        .background(Brush.verticalGradient(listOf(palette.accent, palette.accentDeep))),
                contentAlignment = Alignment.Center,
            ) {
                if (song.albumArtUri != null) {
                    AsyncImage(
                        model = song.albumArtUri,
                        contentDescription = null,
                        contentScale = ContentScale.Crop,
                        modifier =
                            Modifier
                                .size(46.dp)
                                .clip(RoundedCornerShape(LjodDimens.radiusMd)),
                    )
                } else {
                    Icon(Icons.Rounded.MusicNote, contentDescription = null, tint = palette.onAccent, modifier = Modifier.size(22.dp))
                }
            }
            Spacer(Modifier.width(14.dp))
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    song.title,
                    style = MaterialTheme.typography.bodyLarge.copy(fontWeight = FontWeight.Bold),
                    color = palette.textPrimary,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis
                )
                Text(
                    song.artist,
                    style = MaterialTheme.typography.bodySmall,
                    color = palette.accent,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis
                )
            }
            Text(
                song.displayDuration,
                style = MaterialTheme.typography.labelSmall,
                color = palette.textTertiary,
                modifier = Modifier.padding(start = 8.dp)
            )
        }
    }
}

@Composable
private fun PermissionContent(permLauncher: androidx.activity.result.ActivityResultLauncher<String>) {
    Column(
        modifier = Modifier.fillMaxSize(),
        verticalArrangement = Arrangement.Center,
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Box(
            modifier = Modifier.size(100.dp).clip(CircleShape).background(LjodTheme.palette.accent.copy(alpha = 0.1f)),
            contentAlignment = Alignment.Center
        ) {
            Icon(Icons.Rounded.MusicNote, contentDescription = null, tint = LjodTheme.palette.accent, modifier = Modifier.size(48.dp))
        }
        Spacer(Modifier.height(24.dp))
        Text("Music access needed", style = MaterialTheme.typography.headlineSmall, color = LjodTheme.palette.textPrimary)
        Spacer(Modifier.height(8.dp))
        Text(
            "Grant permission to scan your local storage for audio files.",
            style = MaterialTheme.typography.bodyMedium,
            color = LjodTheme.palette.textSecondary,
            textAlign = TextAlign.Center,
            modifier = Modifier.padding(horizontal = 32.dp)
        )
        Spacer(Modifier.height(24.dp))
        GlassButton(
            text = "Grant access",
            onClick = {
                val perm =
                    if (Build.VERSION.SDK_INT >= 33) {
                        Manifest.permission.READ_MEDIA_AUDIO
                    } else {
                        Manifest.permission.READ_EXTERNAL_STORAGE
                    }
                permLauncher.launch(perm)
            },
        )
    }
}

@Composable
private fun EmptyMessage(text: String) {
    Box(modifier = Modifier.fillMaxSize(), contentAlignment = Alignment.Center) {
        Column(horizontalAlignment = Alignment.CenterHorizontally) {
            Icon(
                Icons.Rounded.MusicNote,
                contentDescription = null,
                tint = LjodTheme.palette.textTertiary,
                modifier = Modifier.size(48.dp)
            )
            Spacer(Modifier.height(12.dp))
            Text(
                text,
                style = MaterialTheme.typography.titleMedium,
                color = LjodTheme.palette.textSecondary,
                textAlign = TextAlign.Center
            )
        }
    }
}

@Composable
private fun NewPlaylistDialog(
    onDismiss: () -> Unit,
    onCreate: (String) -> Unit,
) {
    var name by remember { mutableStateOf("") }
    val palette = LjodTheme.palette
    AlertDialog(
        onDismissRequest = onDismiss,
        containerColor = palette.surface,
        titleContentColor = palette.accent,
        textContentColor = palette.textPrimary,
        title = { Text("New playlist", style = MaterialTheme.typography.headlineSmall) },
        text = {
            Column {
                Text("Enter a name for your new collection.", style = MaterialTheme.typography.bodyMedium, color = palette.textSecondary)
                Spacer(Modifier.height(16.dp))
                OutlinedTextField(
                    value = name,
                    onValueChange = { name = it },
                    placeholder = { Text("Playlist name") },
                    singleLine = true,
                    colors =
                        OutlinedTextFieldDefaults.colors(
                            focusedTextColor = palette.textPrimary,
                            unfocusedTextColor = palette.textPrimary,
                            focusedBorderColor = palette.accent,
                            unfocusedBorderColor = palette.border,
                            focusedLabelColor = palette.accent,
                            cursorColor = palette.accent,
                        ),
                    modifier = Modifier.fillMaxWidth()
                )
            }
        },
        confirmButton = {
            GlassButton(text = "Create", onClick = { onCreate(name) }, tone = GlassTone.Accent, compact = true)
        },
        dismissButton = {
            TextButton(onClick = onDismiss) { Text("Cancel", color = palette.textSecondary) }
        },
    )
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
