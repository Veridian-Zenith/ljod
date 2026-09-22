package dev.vz.ljod.ui.shell

import androidx.compose.animation.AnimatedVisibility
import androidx.compose.animation.fadeIn
import androidx.compose.animation.fadeOut
import androidx.compose.animation.slideInVertically
import androidx.compose.animation.slideOutVertically
import androidx.compose.foundation.layout.Box
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.runtime.Composable
import androidx.compose.runtime.collectAsState
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.saveable.rememberSaveable
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import dev.vz.ljod.app.LjodViewModel
import dev.vz.ljod.ui.favorites.FavoritesScreen
import dev.vz.ljod.ui.home.HomeScreen
import dev.vz.ljod.ui.library.LibraryScreen
import dev.vz.ljod.ui.search.SearchScreen
import dev.vz.ljod.data.model.toAudioItem
import dev.vz.ljod.ui.settings.SettingsScreen

@Composable
fun MainScaffold(viewModel: LjodViewModel) {
    var selected by rememberSaveable { mutableStateOf(BottomNavTab.Home) }
    val title by viewModel.controller.title.collectAsState()
    val artist by viewModel.controller.artist.collectAsState()
    val isPlaying by viewModel.controller.isPlaying.collectAsState()
    val position by viewModel.controller.position.collectAsState()
    val duration by viewModel.controller.duration.collectAsState()
    val albumId by viewModel.controller.albumId.collectAsState()

    Box(modifier = Modifier.fillMaxSize()) {
        Column(modifier = Modifier.fillMaxSize()) {
            Box(modifier = Modifier.weight(1f)) {
                when (selected) {
                    BottomNavTab.Home -> {
                        HomeScreen(
                            viewModel = viewModel,
                            onSongClick = { viewModel.playSong(it) },
                        )
                    }

                    BottomNavTab.Search -> {
                        SearchEntry(viewModel)
                    }

                    BottomNavTab.Library -> {
                        LibraryScreen(
                            viewModel = viewModel,
                            onSongClick = { viewModel.playSong(it) },
                        )
                    }

                    BottomNavTab.Favorites -> {
                        FavoritesScreen(viewModel)
                    }

                    BottomNavTab.Settings -> {
                        SettingsScreen()
                    }
                }
            }
            AnimatedVisibility(
                visible = title != null,
                enter = slideInVertically(initialOffsetY = { it }) + fadeIn(),
                exit = slideOutVertically(targetOffsetY = { it }) + fadeOut(),
            ) {
                MiniPlayerBar(
                    title = title,
                    artist = artist,
                    isPlaying = isPlaying,
                    progress = if (duration > 0) position.toFloat() / duration.toFloat() else 0f,
                    albumId = albumId,
                    onPlayPause = { viewModel.controller.togglePlayPause() },
                    onClick = {
                        val song =
                            viewModel.songs.value.find { it.id == albumId }
                                ?: viewModel.songs.value.firstOrNull()
                        if (song != null) viewModel.playSong(song, startPositionMs = position)
                    },
                )
            }
            BottomNav(
                selected = selected,
                onSelect = { selected = it },
            )
        }
    }
}

@Composable
private fun SearchEntry(viewModel: LjodViewModel) {
    val query by viewModel.searchQuery.collectAsState()
    val results by viewModel.searchResultsDb.collectAsState()
    SearchScreen(
        query = query,
        results = results,
        onSearch = { q -> viewModel.setSearchQuery(q) },
        onBack = { viewModel.setSearchQuery("") },
        onSongClick = { song: dev.vz.ljod.data.model.Song -> viewModel.playSong(song.toAudioItem()) },
    )
}
