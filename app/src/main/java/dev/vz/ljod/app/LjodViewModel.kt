package dev.vz.ljod.app

import android.net.Uri
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import androidx.media3.common.MediaItem
import androidx.media3.common.MediaMetadata
import dagger.hilt.android.lifecycle.HiltViewModel
import dev.vz.ljod.core.data.scanner.AudioItem
import dev.vz.ljod.core.data.scanner.MediaScanner
import dev.vz.ljod.data.library.LibraryRepository
import dev.vz.ljod.data.lyrics.LyricsRepository
import dev.vz.ljod.data.lyrics.LyricsResult
import dev.vz.ljod.data.model.Album
import dev.vz.ljod.data.model.Artist
import dev.vz.ljod.data.model.Playlist
import dev.vz.ljod.data.model.Song
import dev.vz.ljod.data.settings.LastPlayedData
import dev.vz.ljod.data.settings.SettingsRepository
import dev.vz.ljod.playback.PlaybackController
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.SharingStarted
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.map
import kotlinx.coroutines.flow.stateIn
import kotlinx.coroutines.launch
import timber.log.Timber
import javax.inject.Inject

sealed class ScreenState {
    data object Main : ScreenState()

    data class Player(
        val song: AudioItem,
    ) : ScreenState()

    data class Lyrics(
        val song: AudioItem,
    ) : ScreenState()

    data class LyricsSearch(
        val song: AudioItem,
    ) : ScreenState()

    data class MetadataEdit(
        val song: AudioItem,
    ) : ScreenState()

    data class AlbumDetail(
        val albumId: Long,
    ) : ScreenState()

    data class ArtistDetail(
        val artistName: String,
    ) : ScreenState()

    data class PlaylistDetail(
        val playlistId: Long,
    ) : ScreenState()

    data class Queue(
        val fromPlayer: Boolean,
    ) : ScreenState()

    data class Equalizer(
        val fromPlayer: Boolean,
    ) : ScreenState()

    data object Search : ScreenState()
}

data class LastPlayedInfo(
    val songId: Long,
    val uri: String,
    val title: String,
    val artist: String,
    val album: String,
    val position: Long,
    val albumId: Long,
)

@HiltViewModel
class LjodViewModel
    @Inject
    constructor(
        val controller: PlaybackController,
        private val scanner: MediaScanner,
        private val library: LibraryRepository,
        private val scanCoordinator: dev.vz.ljod.data.library.LibraryScanCoordinator,
        private val lyricsRepo: LyricsRepository,
        private val settingsRepo: SettingsRepository,
    ) : ViewModel() {
        private val _screenState = MutableStateFlow<ScreenState>(ScreenState.Main)
        val screenState: StateFlow<ScreenState> = _screenState.asStateFlow()

        val songsDb: StateFlow<List<Song>> =
            library
                .observeSongs()
                .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), emptyList())

        val songs: StateFlow<List<AudioItem>> =
            songsDb
                .map { list -> list.map { it.toAudioItem() } }
                .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), emptyList())

        val albums: StateFlow<List<Album>> =
            library
                .observeAlbums()
                .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), emptyList())
        val artists: StateFlow<List<Artist>> =
            library
                .observeArtists()
                .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), emptyList())
        val favorites: StateFlow<List<Song>> =
            library
                .observeFavorites()
                .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), emptyList())
        val playlists: StateFlow<List<Playlist>> =
            library
                .observePlaylists()
                .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), emptyList())
        val recentHistory =
            library
                .observeRecentHistory(50)
                .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), emptyList())

        val pureBlack: StateFlow<Boolean> =
            settingsRepo.pureBlack
                .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), true)
        val animationsEnabled: StateFlow<Boolean> =
            settingsRepo.animations
                .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), true)

        val crossfadeMs: StateFlow<Int> =
            settingsRepo.crossfadeMs
                .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), 0)

        val eqEnabled: StateFlow<Boolean> =
            settingsRepo.eqEnabled
                .stateIn(viewModelScope, SharingStarted.WhileSubscribed(5_000), false)

        val repeatMode: StateFlow<dev.vz.ljod.data.settings.RepeatMode> = controller.repeatMode
        val shuffleMode: StateFlow<Boolean> = controller.shuffleMode
        val volume: StateFlow<Float> = controller.volume
        val sleepRemaining: StateFlow<Long> = controller.sleepRemainingMs

        private val _isPermissionPromptOpen = MutableStateFlow(false)
        val isPermissionPromptOpen: StateFlow<Boolean> = _isPermissionPromptOpen.asStateFlow()

        private val _isScanning = MutableStateFlow(false)
        val isScanning: StateFlow<Boolean> = _isScanning.asStateFlow()

        private val _lyrics = MutableStateFlow<LyricsResult?>(null)
        val lyrics: StateFlow<LyricsResult?> = _lyrics.asStateFlow()

        private val _searchResults = MutableStateFlow<List<LyricsResult>>(emptyList())
        val searchResults: StateFlow<List<LyricsResult>> = _searchResults.asStateFlow()

        private val _isTranslating = MutableStateFlow(false)
        val isTranslating: StateFlow<Boolean> = _isTranslating.asStateFlow()

        private val _userMessage = MutableStateFlow<String?>(null)
        val userMessage: StateFlow<String?> = _userMessage.asStateFlow()

        fun clearUserMessage() {
            _userMessage.value = null
        }

        private val _isRomanizing = MutableStateFlow(false)
        val isRomanizing: StateFlow<Boolean> = _isRomanizing.asStateFlow()

        private val _romanizationEnabled = MutableStateFlow(false)
        val romanizationEnabled: StateFlow<Boolean> = _romanizationEnabled.asStateFlow()

        private val _targetLanguage = MutableStateFlow("English")
        val targetLanguage: StateFlow<String> = _targetLanguage.asStateFlow()

        private val _lastPlayedInfo = MutableStateFlow<LastPlayedInfo?>(null)
        val lastPlayedInfo: StateFlow<LastPlayedInfo?> = _lastPlayedInfo.asStateFlow()

        private val _searchQuery = MutableStateFlow("")
        val searchQuery: StateFlow<String> = _searchQuery.asStateFlow()

        private val _searchResultsDb = MutableStateFlow<List<Song>>(emptyList())
        val searchResultsDb: StateFlow<List<Song>> = _searchResultsDb.asStateFlow()

        init {
            loadSettings()
            restoreLastPlayed()
            rescan()
            observeScanState()
        }

        private fun observeScanState() {
            viewModelScope.launch {
                scanCoordinator.state.collect { state ->
                    _scanStatus.value = when (state) {
                        is dev.vz.ljod.data.library.LibraryScanState.Idle -> "Ready"
                        is dev.vz.ljod.data.library.LibraryScanState.Scanning -> "Scanning… (${state.itemsProcessed} processed)"
                        is dev.vz.ljod.data.library.LibraryScanState.Indexed -> "Indexed ${state.songCount} songs, ${state.albumCount} albums, ${state.artistCount} artists"
                        is dev.vz.ljod.data.library.LibraryScanState.Failed -> "Scan failed: ${state.reason}"
                    }
                }
            }
        }

        private fun loadSettings() {
            viewModelScope.launch {
                _romanizationEnabled.value = settingsRepo.romanization.first()
                _targetLanguage.value = settingsRepo.targetLanguage.first()
            }
        }

        fun setRomanization(enabled: Boolean) {
            _romanizationEnabled.value = enabled
            viewModelScope.launch { settingsRepo.setRomanization(enabled) }
        }

        fun setTargetLanguage(lang: String) {
            _targetLanguage.value = lang
            viewModelScope.launch { settingsRepo.setTargetLanguage(lang) }
        }

        fun setSearchQuery(q: String) {
            _searchQuery.value = q
            viewModelScope.launch { _searchResultsDb.value = library.search(q) }
        }

        private val _scanStatus = MutableStateFlow("Ready")
        val scanStatus: StateFlow<String> = _scanStatus.asStateFlow()

        val scanState: StateFlow<dev.vz.ljod.data.library.LibraryScanState> = scanCoordinator.state

        private val _libraryStats = MutableStateFlow(mapOf("songs" to 0, "albums" to 0))
        val libraryStats: StateFlow<Map<String, Int>> = _libraryStats.asStateFlow()

        fun refreshStats() {
            viewModelScope.launch {
                val songs = library.observeSongs().first()
                val albums = library.observeAlbums().first()
                _libraryStats.value = mapOf("songs" to songs.size, "albums" to albums.size)
                _scanStatus.value = "Scanned ${songs.size} songs, ${albums.size} albums"
            }
        }

        fun rescan() {
            viewModelScope.launch {
                _isScanning.value = true
                try {
                    scanCoordinator.rescan()
                } catch (e: Exception) {
                    Timber.w(e, "Scan failed")
                } finally {
                    _isScanning.value = false
                }
            }
        }

        private fun restoreLastPlayed() {
            viewModelScope.launch {
                val songId = settingsRepo.lastPlayedSongId.first()
                if (songId > 0) {
                    _lastPlayedInfo.value =
                        LastPlayedInfo(
                            songId = songId,
                            uri = settingsRepo.lastPlayedUri.first(),
                            title = settingsRepo.lastPlayedTitle.first(),
                            artist = settingsRepo.lastPlayedArtist.first(),
                            album = settingsRepo.lastPlayedAlbum.first(),
                            position = settingsRepo.lastPlayedPosition.first(),
                            albumId = settingsRepo.lastPlayedAlbumId.first(),
                        )
                }
            }
        }

        fun resumeLastPlayed() {
            val info = _lastPlayedInfo.value ?: return
            val item = songs.value.find { it.id == info.songId } ?: return
            playSong(item, startPositionMs = info.position)
        }

        fun dismissLastPlayed() {
            _lastPlayedInfo.value = null
        }

        fun navigateTo(screen: ScreenState) {
            _screenState.value = screen
        }

        fun navigateBack() {
            _screenState.value =
                when (val current = _screenState.value) {
                    is ScreenState.Queue -> {
                        if (current.fromPlayer) {
                            val item = currentPlayingSong()
                            if (item != null) ScreenState.Player(item) else ScreenState.Main
                        } else {
                            ScreenState.Main
                        }
                    }

                    is ScreenState.Equalizer -> {
                        if (current.fromPlayer) {
                            val item = currentPlayingSong()
                            if (item != null) ScreenState.Player(item) else ScreenState.Main
                        } else {
                            ScreenState.Main
                        }
                    }

                    is ScreenState.LyricsSearch -> {
                        ScreenState.Lyrics(current.song)
                    }

                    is ScreenState.Lyrics -> {
                        ScreenState.Player(current.song)
                    }

                    is ScreenState.MetadataEdit -> {
                        ScreenState.Player(current.song)
                    }

                    is ScreenState.AlbumDetail -> {
                        ScreenState.Main
                    }

                    is ScreenState.ArtistDetail -> {
                        ScreenState.Main
                    }

                    is ScreenState.PlaylistDetail -> {
                        ScreenState.Main
                    }

                    is ScreenState.Player -> {
                        ScreenState.Main
                    }

                    ScreenState.Search -> {
                        ScreenState.Main
                    }

                    ScreenState.Main -> {
                        ScreenState.Main
                    }
                }
        }

        private fun currentPlayingSong(): AudioItem? {
            val id = controller.albumId.value ?: return null
            return songs.value.find { it.id == id }
        }

        fun playSong(
            song: AudioItem,
            startPositionMs: Long = 0,
        ) {
            val item =
                MediaItem
                    .Builder()
                    .setMediaId(song.id.toString())
                    .setUri(song.uri)
                    .setMediaMetadata(
                        MediaMetadata
                            .Builder()
                            .setTitle(song.title)
                            .setArtist(song.artist)
                            .setAlbumTitle(song.album)
                            .build(),
                    ).build()

            val queue: List<MediaItem> =
                if (controller.shuffleMode.value) {
                    val others = songs.value.filter { it.id != song.id }.shuffled()
                    (listOf(song) + others).map { it.toMediaItem() }
                } else {
                    songs.value.map { it.toMediaItem() }
                }
            val startIndex = queue.indexOfFirst { it.mediaId == song.id.toString() }.coerceAtLeast(0)
            controller.setMediaItems(queue, startIndex, startPositionMs)
            controller.play()
            _screenState.value = ScreenState.Player(song)
            saveLastPlayed(song, startPositionMs)
        }

        fun playPlaylist(playlistId: Long) {
            viewModelScope.launch {
                val items = library.songsInPlaylist(playlistId)
                if (items.isEmpty()) return@launch
                val mediaItems = items.map { it.toMediaItem() }
                controller.setMediaItems(mediaItems, 0, 0)
                controller.play()
                val first = items.first()
                val audio = first.toAudioItem()
                _screenState.value = ScreenState.Player(audio)
                saveLastPlayed(audio, 0)
            }
        }

        fun playAlbum(albumId: Long) {
            viewModelScope.launch {
                val items = library.songsForAlbum(albumId)
                if (items.isEmpty()) return@launch
                val mediaItems = items.map { it.toMediaItem() }
                controller.setMediaItems(mediaItems, 0, 0)
                controller.play()
                val first = items.first()
                _screenState.value = ScreenState.Player(first.toAudioItem())
                saveLastPlayed(first.toAudioItem(), 0)
            }
        }

        fun playArtist(artistName: String) {
            viewModelScope.launch {
                val items = library.songsForArtist(artistName)
                if (items.isEmpty()) return@launch
                val mediaItems = items.map { it.toMediaItem() }
                controller.setMediaItems(mediaItems, 0, 0)
                controller.play()
                val first = items.first()
                _screenState.value = ScreenState.Player(first.toAudioItem())
                saveLastPlayed(first.toAudioItem(), 0)
            }
        }

        fun playFavorites() {
            val items = favorites.value
            if (items.isEmpty()) return
            val mediaItems = items.map { it.toMediaItem() }
            controller.setMediaItems(mediaItems, 0, 0)
            controller.play()
            val first = items.first()
            _screenState.value = ScreenState.Player(first.toAudioItem())
            saveLastPlayed(first.toAudioItem(), 0)
        }

        fun shuffleAll() {
            val list = songs.value.shuffled()
            if (list.isEmpty()) return
            val mediaItems = list.map { it.toMediaItem() }
            controller.setMediaItems(mediaItems, 0, 0)
            controller.play()
            val first = list.first()
            _screenState.value = ScreenState.Player(first)
            saveLastPlayed(first, 0)
        }

        fun toggleShuffle() {
            controller.setShuffleMode(!controller.shuffleMode.value)
        }

        fun setRepeatMode(mode: dev.vz.ljod.data.settings.RepeatMode) = controller.setRepeatMode(mode)

        fun setVolume(v: Float) = controller.setVolume(v)

        fun sortLibrary(mode: String) {
            viewModelScope.launch {
                Timber.d("Sort mode: $mode")
                _searchResultsDb.value = library.observeSongs().first()
            }
        }
        fun setSleepTimer(durationMs: Long) = controller.setSleepTimer(durationMs)

        fun loadLyrics(song: AudioItem) {
            viewModelScope.launch {
                val fileTags = scanner.readFileTags(song.uri)
                val title = fileTags?.title?.takeIf { it.isNotBlank() } ?: song.title
                val artist = fileTags?.artist?.takeIf { it.isNotBlank() } ?: song.artist
                val album = fileTags?.album?.takeIf { it.isNotBlank() } ?: song.album
                var result =
                    lyricsRepo.fetchLyrics(
                        uri = song.uri,
                        title = title,
                        artist = artist,
                        album = album,
                        durationMs = song.duration,
                    )
                if (result != null && settingsRepo.romanization.first()) {
                    result = lyricsRepo.romanizeLyrics(result)
                }
                _lyrics.value = result
                _screenState.value = ScreenState.Lyrics(song)
            }
        }

        fun albumArtUri(song: AudioItem): Uri? = song.albumArtUri

        fun searchLyrics(
            title: String,
            artist: String,
        ) {
            viewModelScope.launch {
                val src =
                    dev.vz.ljod.data.lyrics
                        .OnlineLyricsSource()
                _searchResults.value = src.searchLyrics(title, artist)
            }
        }

        fun loadLyricsFromResult(
            result: LyricsResult,
            song: AudioItem,
        ) {
            viewModelScope.launch {
                var lyrics = result
                if (settingsRepo.romanization.first()) {
                    lyrics = lyricsRepo.romanizeLyrics(lyrics)
                }
                _lyrics.value = lyrics
                _screenState.value = ScreenState.Lyrics(song)
            }
        }

        fun translateLyrics(song: AudioItem) {
            val currentLyrics = _lyrics.value ?: return
            viewModelScope.launch {
                val targetLang = lyricsRepo.getTargetLanguage()
                val apiKey = lyricsRepo.getApiKey()
                if (apiKey.isBlank()) {
                    _userMessage.value = "Add a Gemini API key in Settings to translate"
                    return@launch
                }
                _isTranslating.value = true
                val plainText = currentLyrics.lines.joinToString("\n") { it.text }
                val translated = lyricsRepo.translateLyrics(plainText, targetLang, song.title, song.artist)
                if (translated != null) {
                    _lyrics.value = translated
                } else {
                    _userMessage.value = "Translation failed — check your API key"
                }
                _isTranslating.value = false
            }
        }

        fun generateLyricsWithAI(song: AudioItem) {
            viewModelScope.launch {
                val apiKey = lyricsRepo.getApiKey()
                if (apiKey.isBlank()) {
                    _userMessage.value = "Add a Gemini API key in Settings to generate lyrics"
                    return@launch
                }
                _lyrics.value = lyricsRepo.generateLyrics(song.title, song.artist, song.album)
                if (_lyrics.value == null) {
                    _userMessage.value = "AI generation failed — check your API key"
                }
                _screenState.value = ScreenState.Lyrics(song)
            }
        }

        fun romanizeLyrics(
            @Suppress("UNUSED_PARAMETER") song: AudioItem,
        ) {
            val currentLyrics = _lyrics.value ?: return
            viewModelScope.launch {
                _isRomanizing.value = true
                val romanized = lyricsRepo.romanizeLyrics(currentLyrics)
                _lyrics.value = romanized
                _isRomanizing.value = false
            }
        }

        fun toggleFavorite(songId: Long) {
            viewModelScope.launch { library.toggleFavorite(songId) }
        }

        fun recordPlay(
            songId: Long,
            completedMs: Long,
            durationMs: Long,
        ) {
            viewModelScope.launch { library.recordPlay(songId, completedMs, durationMs) }
        }

        fun createPlaylist(
            name: String,
            onCreated: (Long) -> Unit = {},
        ) {
            viewModelScope.launch {
                val id = library.createPlaylist(name.ifBlank { "New Playlist" })
                onCreated(id)
            }
        }

        fun addToPlaylist(
            playlistId: Long,
            songId: Long,
        ) {
            viewModelScope.launch { library.addToPlaylist(playlistId, songId) }
        }

        fun removeFromPlaylist(
            playlistId: Long,
            songId: Long,
        ) {
            viewModelScope.launch { library.removeFromPlaylist(playlistId, songId) }
        }

        fun deletePlaylist(id: Long) {
            viewModelScope.launch { library.deletePlaylist(id) }
        }

        suspend fun songsInAlbum(albumId: Long): List<Song> = library.songsForAlbum(albumId)

        suspend fun songsInArtist(name: String): List<Song> = library.songsForArtist(name)

        suspend fun songsInPlaylist(id: Long): List<Song> = library.songsInPlaylist(id)

        fun setGeminiApiKey(key: String) {
            viewModelScope.launch { settingsRepo.setGeminiApiKey(key) }
        }

        fun setPureBlack(enabled: Boolean) {
            viewModelScope.launch { settingsRepo.setPureBlack(enabled) }
        }

        fun setAnimationsEnabled(enabled: Boolean) {
            viewModelScope.launch { settingsRepo.setAnimations(enabled) }
        }

        fun setCrossfadeMs(ms: Int) {
            viewModelScope.launch { settingsRepo.setCrossfadeMs(ms) }
        }

        fun setEqEnabled(enabled: Boolean) {
            viewModelScope.launch { settingsRepo.setEqEnabled(enabled) }
        }

        fun fetchAvailableModels(onResult: (List<dev.vz.ljod.data.gemini.AvailableModel>) -> Unit) {
            viewModelScope.launch {
                val key = settingsRepo.readGeminiApiKey()
                if (key.isBlank()) {
                    onResult(emptyList())
                    return@launch
                }
                val src =
                    dev.vz.ljod.data.gemini
                        .GeminiLyricsSource()
                onResult(src.fetchAvailableModels(key))
            }
        }

        private fun saveLastPlayed(
            song: AudioItem,
            positionMs: Long,
        ) {
            viewModelScope.launch {
                val data =
                    LastPlayedData(
                        songId = song.id,
                        uri = song.uri.toString(),
                        title = song.title,
                        artist = song.artist,
                        album = song.album,
                        position = positionMs,
                        duration = song.duration,
                        albumId = song.albumId ?: -1L,
                    )
                settingsRepo.saveLastPlayed(data)
                _lastPlayedInfo.value =
                    LastPlayedInfo(
                        songId = song.id,
                        uri = song.uri.toString(),
                        title = song.title,
                        artist = song.artist,
                        album = song.album,
                        position = positionMs,
                        albumId = song.albumId ?: -1L,
                    )
            }
        }
    }

private fun Song.toAudioItem(): AudioItem =
    AudioItem(
        id = id,
        title = title,
        artist = artist,
        album = album,
        duration = duration,
        uri = Uri.parse(uri),
        dateAdded = dateAdded,
        albumId = albumId,
        trackNumber = trackNumber,
        year = year,
        genre = genre,
        mimeType = mimeType,
        sizeBytes = sizeBytes,
    )

private fun Song.toMediaItem(): MediaItem =
    MediaItem
        .Builder()
        .setMediaId(id.toString())
        .setUri(Uri.parse(uri))
        .setMediaMetadata(
            MediaMetadata
                .Builder()
                .setTitle(title)
                .setArtist(artist)
                .setAlbumTitle(album)
                .build(),
        ).build()

private fun AudioItem.toMediaItem(): MediaItem =
    MediaItem
        .Builder()
        .setMediaId(id.toString())
        .setUri(uri)
        .setMediaMetadata(
            MediaMetadata
                .Builder()
                .setTitle(title)
                .setArtist(artist)
                .setAlbumTitle(album)
                .build(),
        ).build()
