package dev.vz.ljod.app

import android.widget.Toast
import androidx.activity.compose.BackHandler
import androidx.compose.animation.AnimatedContent
import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.core.tween
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.scaleIn
import androidx.compose.animation.scaleOut
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutVertically
import androidx.compose.foundation.background
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.material3.MaterialTheme
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.platform.LocalContext
import androidx.hilt.navigation.compose.hiltViewModel
import dev.vz.ljod.core.ui.theme.AmoledPalette
import dev.vz.ljod.core.ui.theme.LjodTheme
import dev.vz.ljod.ui.album.AlbumDetailScreen
import dev.vz.ljod.ui.artist.ArtistDetailScreen
import dev.vz.ljod.ui.equalizer.EqualizerScreen
import dev.vz.ljod.ui.favorites.FavoritesScreen
import dev.vz.ljod.ui.home.HomeScreen
import dev.vz.ljod.ui.library.LibraryScreen
import dev.vz.ljod.ui.lyrics.LyricsScreen
import dev.vz.ljod.ui.lyrics.LyricsSearchScreen
import dev.vz.ljod.ui.metadata.MetadataEditScreen
import dev.vz.ljod.ui.player.PlayerScreen
import dev.vz.ljod.ui.playlist.PlaylistDetailScreen
import dev.vz.ljod.ui.queue.QueueScreen
import dev.vz.ljod.data.model.toAudioItem
import dev.vz.ljod.ui.search.SearchScreen
import dev.vz.ljod.ui.settings.SettingsScreen
import dev.vz.ljod.ui.shell.BottomNav
import dev.vz.ljod.ui.shell.BottomNavTab
import dev.vz.ljod.ui.shell.MainScaffold
import dev.vz.ljod.ui.shell.MiniPlayerBar

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

    BackHandler(enabled = screenState !is ScreenState.Main && !viewModel.isPermissionPromptOpen.value) {
        viewModel.navigateBack()
    }

    Box(
        modifier =
            Modifier
                .fillMaxSize()
                .background(AmoledPalette.bg),
    ) {
        MainScaffold(viewModel)
        AnimatedVisibility(
            visible = screenState !is ScreenState.Main,
            enter = fadeIn(tween(280)) + scaleIn(initialScale = 0.96f, animationSpec = tween(280)),
            exit = fadeOut(tween(220)) + scaleOut(targetScale = 0.96f, animationSpec = tween(220)),
        ) {
                when (val state = screenState) {
                    is ScreenState.Player -> {
                        PlayerScreen(
                            controller = viewModel.controller,
                            albumArtUri = viewModel.albumArtUri(state.song),
                            onLyricsClick = { viewModel.loadLyrics(state.song) },
                            onMetadataEdit = { viewModel.navigateTo(ScreenState.MetadataEdit(state.song)) },
                            onQueue = { viewModel.navigateTo(ScreenState.Queue(true)) },
                            onEqualizer = { viewModel.navigateTo(ScreenState.Equalizer(true)) },
                            onBack = { viewModel.navigateBack() },
                            onShuffleToggle = { viewModel.toggleShuffle() },
                            onRepeatToggle = {
                                val next =
                                    when (viewModel.repeatMode.value) {
                                        dev.vz.ljod.data.settings.RepeatMode.Off -> dev.vz.ljod.data.settings.RepeatMode.All
                                        dev.vz.ljod.data.settings.RepeatMode.All -> dev.vz.ljod.data.settings.RepeatMode.One
                                        dev.vz.ljod.data.settings.RepeatMode.One -> dev.vz.ljod.data.settings.RepeatMode.Off
                                    }
                                viewModel.setRepeatMode(next)
                            },
                            shuffleEnabled = viewModel.shuffleMode.collectAsState().value,
                            repeatMode = viewModel.repeatMode.collectAsState().value,
                            isFavorite =
                                viewModel.favorites
                                    .collectAsState()
                                    .value
                                    .any { it.id == state.song.id },
                            sleepRemainingMs = viewModel.sleepRemaining.collectAsState().value,
                            onFavoriteToggle = {
                                viewModel.toggleFavorite(state.song.id)
                            },
                            onSleepTimer = { ms -> viewModel.setSleepTimer(ms) },
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
                            onSearchLyrics = { viewModel.navigateTo(ScreenState.LyricsSearch(state.song)) },
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

                    is ScreenState.AlbumDetail -> {
                        AlbumDetailScreen(
                            albumId = state.albumId,
                            viewModel = viewModel,
                            onBack = { viewModel.navigateTo(ScreenState.Main) },
                        )
                    }

                    is ScreenState.ArtistDetail -> {
                        ArtistDetailScreen(
                            artistName = state.artistName,
                            viewModel = viewModel,
                            onBack = { viewModel.navigateTo(ScreenState.Main) },
                        )
                    }

                    is ScreenState.PlaylistDetail -> {
                        PlaylistDetailScreen(
                            playlistId = state.playlistId,
                            viewModel = viewModel,
                            onBack = { viewModel.navigateTo(ScreenState.Main) },
                        )
                    }

                    is ScreenState.Queue -> {
                        QueueScreen(
                            controller = viewModel.controller,
                            onBack = { viewModel.navigateBack() },
                        )
                    }

                    is ScreenState.Equalizer -> {
                        EqualizerScreen(
                            controller = viewModel.controller,
                            onBack = { viewModel.navigateBack() },
                        )
                    }

                    is ScreenState.Search -> {
                        SearchScreen(
                            query = viewModel.searchQuery.collectAsState().value,
                            results = viewModel.searchResultsDb.collectAsState().value,
                            onSearch = { q -> viewModel.setSearchQuery(q) },
                            onBack = { viewModel.navigateTo(ScreenState.Main) },
                            onSongClick = { song -> viewModel.playSong(song.toAudioItem()) },
                        )
                    }

                    ScreenState.Main -> {
                        Unit
                    }
                }
            }
        }
}
