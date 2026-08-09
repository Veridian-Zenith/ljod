package dev.vz.ljod.app

import android.widget.Toast
import androidx.compose.animation.animateColorAsState
import androidx.compose.animation.core.Spring
import androidx.compose.animation.core.spring
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.interaction.MutableInteractionSource
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
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.material.icons.Icons
import androidx.compose.material.icons.rounded.MusicNote
import androidx.compose.material.icons.rounded.Pause
import androidx.compose.material.icons.rounded.PlayArrow
import androidx.compose.material3.Icon
import androidx.compose.material3.IconButton
import androidx.compose.material3.IconButtonDefaults
import androidx.compose.material3.LinearProgressIndicator
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.Text
import androidx.activity.compose.BackHandler
import androidx.compose.foundation.pager.HorizontalPager
import androidx.compose.foundation.pager.rememberPagerState
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.remember
import androidx.compose.runtime.rememberCoroutineScope
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.draw.shadow
import androidx.compose.ui.graphics.Brush
import androidx.compose.ui.graphics.Color
import androidx.compose.ui.graphics.vector.ImageVector
import androidx.compose.ui.platform.LocalContext
import androidx.compose.ui.res.vectorResource
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.text.style.TextOverflow
import androidx.compose.ui.unit.dp
import androidx.hilt.navigation.compose.hiltViewModel
import dev.vz.ljod.R
import dev.vz.ljod.core.ui.theme.GlassStyle
import dev.vz.ljod.core.ui.theme.LjodTheme
import dev.vz.ljod.core.ui.theme.NordicPalette
import dev.vz.ljod.ui.home.HomeScreen
import dev.vz.ljod.ui.library.LibraryScreen
import dev.vz.ljod.ui.lyrics.LyricsScreen
import dev.vz.ljod.ui.lyrics.LyricsSearchScreen
import dev.vz.ljod.ui.metadata.MetadataEditScreen
import dev.vz.ljod.ui.player.PlayerScreen
import dev.vz.ljod.ui.settings.SettingsScreen
import kotlinx.coroutines.launch

@Composable
fun LjodShell(viewModel: LjodViewModel = hiltViewModel()) {
    val screenState by viewModel.screenState.collectAsState()
    val context = LocalContext.current
    val userMessage by viewModel.userMessage.collectAsState()

    LaunchedEffect(userMessage) {
        userMessage?.let {
            Toast.makeText(context, it, Toast.LENGTH_SHORT).show()
            viewModel.clearUserMessage()
        }
    }

    BackHandler(enabled = screenState !is ScreenState.Main) {
        viewModel.navigateBack()
    }

    LjodTheme {
        when (val state = screenState) {
            is ScreenState.Main -> MainNavigation(viewModel)
            is ScreenState.Player -> {
                val artUri = viewModel.albumArtUri(state.song)
                PlayerScreen(
                    controller = viewModel.controller,
                    albumArtUri = artUri,
                    onLyricsClick = { viewModel.loadLyrics(state.song) },
                    onMetadataEdit = {
                        viewModel.navigateTo(ScreenState.MetadataEdit(state.song))
                    },
                    onBack = { viewModel.navigateBack() },
                    onShuffleToggle = { viewModel.toggleShuffle() },
                    shuffleEnabled = viewModel.shuffleMode.collectAsState().value,
                )
            }
            is ScreenState.Lyrics -> {
                val lyrics by viewModel.lyrics.collectAsState()
                val isTranslating by viewModel.isTranslating.collectAsState()
                val isRomanizing by viewModel.isRomanizing.collectAsState()
                val romanizationEnabled by viewModel.romanizationEnabled.collectAsState()
                val targetLanguage by viewModel.targetLanguage.collectAsState()
                LyricsScreen(
                    controller = viewModel.controller,
                    lyrics = lyrics,
                    isTranslating = isTranslating,
                    isRomanizing = isRomanizing,
                    romanizationEnabled = romanizationEnabled,
                    targetLanguage = targetLanguage,
                    onSearchLyrics = {
                        viewModel.navigateTo(ScreenState.LyricsSearch(state.song))
                    },
                    onTranslate = { viewModel.translateLyrics(state.song) },
                    onRomanize = { viewModel.romanizeLyrics(state.song) },
                    onGenerateWithAI = { viewModel.generateLyricsWithAI(state.song) },
                    onToggleRomanization = { viewModel.setRomanization(it) },
                    onSetTargetLanguage = { viewModel.setTargetLanguage(it) },
                    onBack = { viewModel.navigateTo(ScreenState.Player(state.song)) },
                )
            }
            is ScreenState.LyricsSearch -> {
                val searchResults by viewModel.searchResults.collectAsState()
                LyricsSearchScreen(
                    title = state.song.title,
                    artist = state.song.artist,
                    searchResults = searchResults,
                    onSearch = { title, artist -> viewModel.searchLyrics(title, artist) },
                    onResultClick = { viewModel.loadLyricsFromResult(it, state.song) },
                    onBack = { viewModel.navigateTo(ScreenState.Player(state.song)) },
                )
            }
            is ScreenState.MetadataEdit -> {
                MetadataEditScreen(
                    songId = state.song.id,
                    initialTitle = state.song.title,
                    initialArtist = state.song.artist,
                    initialAlbum = state.song.album,
                    onSaved = { viewModel.navigateTo(ScreenState.Player(state.song)) },
                    onBack = { viewModel.navigateTo(ScreenState.Player(state.song)) },
                )
            }
        }
    }
}

@Composable
private fun MainNavigation(viewModel: LjodViewModel) {
    val pagerState = rememberPagerState(pageCount = { 3 })
    val coroutineScope = rememberCoroutineScope()
    val isPlaying by viewModel.controller.isPlaying.collectAsState()
    val title by viewModel.controller.title.collectAsState()
    val artist by viewModel.controller.artist.collectAsState()
    val position by viewModel.controller.position.collectAsState()
    val duration by viewModel.controller.duration.collectAsState()

    Column(modifier = Modifier.fillMaxSize().background(NordicPalette.bg)) {
        Box(modifier = Modifier.weight(1f)) {
            HorizontalPager(state = pagerState, beyondViewportPageCount = 1) { page ->
                when (page) {
                    0 -> HomeScreen(viewModel = viewModel, onSongClick = { viewModel.playSong(it) })
                    1 -> LibraryScreen(viewModel = viewModel, onSongClick = { viewModel.playSong(it) })
                    2 -> SettingsScreen()
                }
            }
        }

        if (title != null) {
            MiniPlayer(
                title = title,
                artist = artist,
                isPlaying = isPlaying,
                progress = if (duration > 0) position.toFloat() / duration.toFloat() else 0f,
                onPlayPause = { viewModel.controller.togglePlayPause() },
                onClick = {
                    val song = viewModel.songs.value.find {
                        it.title == title && it.artist == artist
                    } ?: viewModel.songs.value.firstOrNull()
                    if (song != null) viewModel.navigateTo(ScreenState.Player(song))
                },
            )
        }

        BottomNavBar(pagerState, coroutineScope)
    }
}

@Composable
private fun MiniPlayer(
    title: String?,
    artist: String?,
    isPlaying: Boolean,
    progress: Float,
    onPlayPause: () -> Unit,
    onClick: () -> Unit,
) {
    Column(
        modifier = Modifier
            .fillMaxWidth()
            .shadow(12.dp, RoundedCornerShape(topStart = 16.dp, topEnd = 16.dp), ambientColor = NordicPalette.accent.copy(alpha = 0.08f))
            .clip(RoundedCornerShape(topStart = 16.dp, topEnd = 16.dp))
            .background(GlassStyle.miniPlayerGradient)
            .border(1.dp, NordicPalette.accent.copy(alpha = 0.15f), RoundedCornerShape(topStart = 16.dp, topEnd = 16.dp))
            .clickable(onClick = onClick)
            .padding(horizontal = 16.dp, vertical = 10.dp),
    ) {
        Row(
            verticalAlignment = Alignment.CenterVertically,
            modifier = Modifier.fillMaxWidth(),
        ) {
            Box(
                modifier = Modifier
                    .size(36.dp)
                    .clip(RoundedCornerShape(8.dp))
                    .background(
                        Brush.verticalGradient(
                            listOf(NordicPalette.accent, NordicPalette.gradient2),
                        ),
                    ),
                contentAlignment = Alignment.Center,
            ) {
                Icon(
                    Icons.Rounded.MusicNote,
                    contentDescription = null,
                    tint = NordicPalette.bg,
                    modifier = Modifier.size(18.dp),
                )
            }
            Spacer(Modifier.width(12.dp))
            Column(modifier = Modifier.weight(1f)) {
                Text(
                    title ?: "",
                    style = MaterialTheme.typography.bodyMedium.copy(fontWeight = FontWeight.SemiBold),
                    color = NordicPalette.textPrimary,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
                Text(
                    artist ?: "",
                    style = MaterialTheme.typography.bodySmall,
                    color = NordicPalette.textSecondary,
                    maxLines = 1,
                    overflow = TextOverflow.Ellipsis,
                )
            }
            IconButton(
                onClick = onPlayPause,
                colors = IconButtonDefaults.iconButtonColors(
                    contentColor = NordicPalette.accent,
                ),
            ) {
                Icon(
                    if (isPlaying) Icons.Rounded.Pause else Icons.Rounded.PlayArrow,
                    contentDescription = if (isPlaying) "Pause" else "Play",
                    modifier = Modifier.size(28.dp),
                )
            }
        }
        LinearProgressIndicator(
            progress = { progress.coerceIn(0f, 1f) },
            modifier = Modifier
                .fillMaxWidth()
                .height(2.dp)
                .padding(top = 8.dp)
                .clip(RoundedCornerShape(1.dp)),
            color = NordicPalette.accent,
            trackColor = NordicPalette.surfaceHighest,
        )
    }
}

@Composable
private fun BottomNavBar(
    pagerState: androidx.compose.foundation.pager.PagerState,
    scope: kotlinx.coroutines.CoroutineScope,
) {
    val tabs = listOf(
        R.drawable.ic_home to "Home",
        R.drawable.ic_library to "Library",
        R.drawable.ic_settings to "Settings",
    )

    Row(
        modifier = Modifier
            .fillMaxWidth()
            .shadow(8.dp, RoundedCornerShape(topStart = 24.dp, topEnd = 24.dp), ambientColor = NordicPalette.accent.copy(alpha = 0.05f))
            .clip(RoundedCornerShape(topStart = 24.dp, topEnd = 24.dp))
            .background(GlassStyle.bottomBarGradient)
            .border(1.dp, NordicPalette.accent.copy(alpha = 0.1f), RoundedCornerShape(topStart = 24.dp, topEnd = 24.dp))
            .padding(horizontal = 12.dp, vertical = 12.dp),
        horizontalArrangement = Arrangement.SpaceEvenly,
        verticalAlignment = Alignment.CenterVertically,
    ) {
        tabs.forEachIndexed { index, (iconRes, label) ->
            val isSelected = pagerState.currentPage == index
            val iconTint by animateColorAsState(
                targetValue = if (isSelected) NordicPalette.accent else NordicPalette.textSecondary,
                animationSpec = spring(stiffness = Spring.StiffnessLow),
                label = "tabTint",
            )
            val textColor by animateColorAsState(
                targetValue = if (isSelected) {
                    NordicPalette.accent
                } else {
                    NordicPalette.textSecondary.copy(alpha = 0.7f)
                },
                animationSpec = spring(stiffness = Spring.StiffnessLow),
                label = "tabText",
            )

            Column(
                modifier = Modifier
                    .weight(1f)
                    .clip(RoundedCornerShape(16.dp))
                    .background(
                        if (isSelected) GlassStyle.activeTabGradient else Brush.verticalGradient(listOf(Color.Transparent, Color.Transparent)),
                    )
                    .clickable(
                        indication = null,
                        interactionSource = remember { MutableInteractionSource() },
                    ) {
                        scope.launch { pagerState.animateScrollToPage(index) }
                    }
                    .padding(vertical = 10.dp),
                horizontalAlignment = Alignment.CenterHorizontally,
            ) {
                Icon(
                    imageVector = ImageVector.vectorResource(iconRes),
                    contentDescription = label,
                    tint = iconTint,
                    modifier = Modifier.size(24.dp),
                )
                Text(
                    text = label,
                    style = MaterialTheme.typography.labelSmall,
                    color = textColor,
                    modifier = Modifier.padding(top = 4.dp),
                )
            }
        }
    }
}
