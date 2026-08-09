package dev.vz.ljod.ui.home

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
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.layout.width
import androidx.compose.foundation.shape.CircleShape
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.MusicNote
import androidx.compose.material.icons.rounded.PlayArrow
import androidx.compose.material.icons.rounded.QueueMusic
import androidx.compose.material.icons.rounded.Search
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
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import androidx.core.content.ContextCompat
import coil3.compose.AsyncImage
import dev.vz.ljod.app.LjodViewModel
import dev.vz.ljod.core.data.scanner.AudioItem
import dev.vz.ljod.core.ui.theme.GlassStyle
import dev.vz.ljod.core.ui.theme.NordicPalette

@Composable
fun HomeScreen(
    viewModel: LjodViewModel,
    onSongClick: (AudioItem) -> Unit = {},
) {
    val context = LocalContext.current
    var hasPermission by remember { mutableStateOf(hasPermission(context)) }
    val songs by viewModel.songs.collectAsState()
    val lastPlayed by viewModel.lastPlayedInfo.collectAsState()

    val permLauncher = rememberLauncherForActivityResult(
        ActivityResultContracts.RequestPermission(),
    ) { granted -> hasPermission = granted }

    Column(
        modifier = Modifier
            .fillMaxSize()
            .padding(horizontal = 20.dp, vertical = 16.dp),
        verticalArrangement = Arrangement.Top,
    ) {
        Spacer(Modifier.height(40.dp))
        HeroBanner()
        Spacer(Modifier.height(24.dp))
        if (!hasPermission) {
            PermissionCard(permLauncher)
        } else {
            val resumeSong = lastPlayed?.let { info ->
                songs.find { it.id == info.songId }
            }
            if (resumeSong != null && lastPlayed != null) {
                ResumeCard(
                    title = lastPlayed!!.title,
                    artist = lastPlayed!!.artist,
                    onClick = { viewModel.resumeLastPlayed() },
                    onDismiss = { viewModel.dismissLastPlayed() },
                )
            }
            TrackCountCard(songs.size)
            songs.lastOrNull()?.let { song ->
                LastScannedCard(song, onSongClick)
            }
        }
    }
}

@Composable
private fun HeroBanner() {
    Box(
        modifier = Modifier
            .fillMaxWidth()
            .shadow(16.dp, RoundedCornerShape(28.dp), ambientColor = NordicPalette.accent.copy(alpha = 0.15f))
            .clip(RoundedCornerShape(28.dp))
            .background(GlassStyle.heroGradient)
            .border(1.dp, NordicPalette.accent.copy(alpha = 0.3f), RoundedCornerShape(28.dp))
            .padding(28.dp),
    ) {
        Column {
            Text(
                "Veridian Zenith",
                style = MaterialTheme.typography.headlineLarge.copy(
                    fontWeight = FontWeight.Bold,
                ),
                color = NordicPalette.accent,
            )
            Spacer(Modifier.height(6.dp))
            Text(
                "Forge your sound.",
                style = MaterialTheme.typography.bodyLarge,
                color = NordicPalette.textSecondary,
            )
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
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .shadow(12.dp, RoundedCornerShape(20.dp), ambientColor = NordicPalette.accent.copy(alpha = 0.1f))
            .clip(RoundedCornerShape(20.dp))
            .background(GlassStyle.cardWarm)
            .border(1.dp, NordicPalette.accent.copy(alpha = 0.35f), RoundedCornerShape(20.dp))
            .clickable(onClick = onClick)
            .padding(16.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Box(
            modifier = Modifier
                .size(48.dp)
                .clip(CircleShape)
                .background(
                    Brush.radialGradient(
                        listOf(NordicPalette.accent, NordicPalette.gradient2),
                    ),
                ),
            contentAlignment = Alignment.Center,
        ) {
            Icon(
                Icons.Rounded.PlayArrow,
                contentDescription = null,
                tint = NordicPalette.bg,
                modifier = Modifier.size(24.dp),
            )
        }
        Spacer(Modifier.width(14.dp))
        Column(modifier = Modifier.weight(1f)) {
            Text(
                "Resume playing",
                style = MaterialTheme.typography.labelMedium.copy(fontWeight = FontWeight.Bold),
                color = NordicPalette.accent,
            )
            Text(
                title,
                style = MaterialTheme.typography.bodyLarge.copy(fontWeight = FontWeight.SemiBold),
                color = NordicPalette.textPrimary,
                maxLines = 1,
            )
            Text(
                artist,
                style = MaterialTheme.typography.bodySmall,
                color = NordicPalette.textSecondary,
                maxLines = 1,
            )
        }
        Text(
            "DISMISS",
            style = MaterialTheme.typography.labelSmall.copy(fontWeight = FontWeight.Bold),
            color = NordicPalette.textSecondary,
            modifier = Modifier
                .clip(RoundedCornerShape(10.dp))
                .background(GlassStyle.verticalGradient)
                .border(1.dp, NordicPalette.glassBorder, RoundedCornerShape(10.dp))
                .clickable(onClick = onDismiss)
                .padding(horizontal = 10.dp, vertical = 6.dp),
        )
    }
}

@Composable
private fun PermissionCard(
    permLauncher: androidx.activity.result.ActivityResultLauncher<String>,
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .shadow(12.dp, RoundedCornerShape(24.dp), ambientColor = NordicPalette.accent.copy(alpha = 0.08f))
            .clip(RoundedCornerShape(24.dp))
            .background(GlassStyle.surfaceGradient)
            .border(1.dp, NordicPalette.accent.copy(alpha = 0.2f), RoundedCornerShape(24.dp))
            .padding(32.dp),
        horizontalAlignment = Alignment.CenterHorizontally,
    ) {
        Icon(
            Icons.Rounded.Search,
            contentDescription = null,
            tint = NordicPalette.accent,
            modifier = Modifier.size(48.dp),
        )
        Spacer(Modifier.height(16.dp))
        Text(
            "Music access needed",
            style = MaterialTheme.typography.titleMedium,
            color = NordicPalette.textPrimary,
        )
        Spacer(Modifier.height(8.dp))
        Text(
            "Grant access to scan your device for audio files.",
            style = MaterialTheme.typography.bodyMedium,
            color = NordicPalette.textSecondary,
        )
        Spacer(Modifier.height(20.dp))
        Text(
            "GRANT ACCESS",
            style = MaterialTheme.typography.labelLarge.copy(
                fontWeight = FontWeight.Bold,
            ),
            color = NordicPalette.accent,
            modifier = Modifier
                .shadow(8.dp, RoundedCornerShape(16.dp), ambientColor = NordicPalette.accent.copy(alpha = 0.2f))
                .clip(RoundedCornerShape(16.dp))
                .background(
                    Brush.horizontalGradient(
                        listOf(NordicPalette.accent, NordicPalette.gradient2),
                    ),
                )
                .clickable {
                    val perm = if (Build.VERSION.SDK_INT >= 33) {
                        Manifest.permission.READ_MEDIA_AUDIO
                    } else {
                        Manifest.permission.READ_EXTERNAL_STORAGE
                    }
                    permLauncher.launch(perm)
                }
                .padding(horizontal = 24.dp, vertical = 12.dp),
        )
    }
}

@Composable
private fun TrackCountCard(songCount: Int) {
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .shadow(10.dp, RoundedCornerShape(20.dp), ambientColor = NordicPalette.accent.copy(alpha = 0.06f))
            .clip(RoundedCornerShape(20.dp))
            .background(GlassStyle.cardCool)
            .border(1.dp, NordicPalette.accent.copy(alpha = 0.15f), RoundedCornerShape(20.dp))
            .padding(20.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        Box(
            modifier = Modifier
                .size(48.dp)
                .clip(CircleShape)
                .background(
                    Brush.radialGradient(
                        listOf(NordicPalette.gradient3, NordicPalette.accent),
                    ),
                ),
            contentAlignment = Alignment.Center,
        ) {
            Icon(
                Icons.Rounded.QueueMusic,
                contentDescription = null,
                tint = NordicPalette.bg,
                modifier = Modifier.size(24.dp),
            )
        }
        Spacer(Modifier.width(16.dp))
        Column {
            Text(
                "$songCount tracks",
                style = MaterialTheme.typography.titleMedium.copy(
                    fontWeight = FontWeight.Bold,
                ),
                color = NordicPalette.textPrimary,
            )
            Text(
                "Ready to play",
                style = MaterialTheme.typography.bodySmall,
                color = NordicPalette.textSecondary,
            )
        }
    }
}

@Composable
private fun LastScannedCard(
    song: AudioItem,
    onSongClick: (AudioItem) -> Unit,
) {
    Spacer(Modifier.height(20.dp))
    Text(
        "Last scanned",
        style = MaterialTheme.typography.labelLarge.copy(
            fontWeight = FontWeight.SemiBold,
        ),
        color = NordicPalette.textSecondary,
    )
    Spacer(Modifier.height(10.dp))
    Row(
        modifier = Modifier
            .fillMaxWidth()
            .shadow(10.dp, RoundedCornerShape(20.dp), ambientColor = NordicPalette.gradient2.copy(alpha = 0.06f))
            .clip(RoundedCornerShape(20.dp))
            .background(GlassStyle.cardWarm)
            .border(1.dp, NordicPalette.gradient2.copy(alpha = 0.2f), RoundedCornerShape(20.dp))
            .clickable { onSongClick(song) }
            .padding(16.dp),
        verticalAlignment = Alignment.CenterVertically,
    ) {
        if (song.albumArtUri != null) {
            AsyncImage(
                model = song.albumArtUri,
                contentDescription = null,
                modifier = Modifier
                    .size(52.dp)
                    .clip(RoundedCornerShape(14.dp)),
            )
        } else {
            Box(
                modifier = Modifier
                    .size(52.dp)
                    .clip(RoundedCornerShape(14.dp))
                    .background(
                        Brush.radialGradient(
                            listOf(
                                NordicPalette.accent.copy(alpha = 0.4f),
                                NordicPalette.gradient2.copy(alpha = 0.2f),
                            ),
                        ),
                    ),
                contentAlignment = Alignment.Center,
            ) {
                Icon(
                    Icons.Rounded.MusicNote,
                    contentDescription = null,
                    tint = NordicPalette.accent,
                    modifier = Modifier.size(24.dp),
                )
            }
        }
        Spacer(Modifier.width(14.dp))
        Column(modifier = Modifier.weight(1f)) {
            Text(
                song.title,
                style = MaterialTheme.typography.bodyLarge.copy(
                    fontWeight = FontWeight.SemiBold,
                ),
                color = NordicPalette.textPrimary,
                maxLines = 1,
            )
            Text(
                song.artist,
                style = MaterialTheme.typography.bodySmall,
                color = NordicPalette.textSecondary,
                maxLines = 1,
            )
        }
    }
}

private fun hasPermission(context: android.content.Context): Boolean {
    return if (Build.VERSION.SDK_INT >= 33) {
        ContextCompat.checkSelfPermission(
            context, Manifest.permission.READ_MEDIA_AUDIO,
        ) == PackageManager.PERMISSION_GRANTED
    } else {
        ContextCompat.checkSelfPermission(
            context, Manifest.permission.READ_EXTERNAL_STORAGE,
        ) == PackageManager.PERMISSION_GRANTED
    }
}
