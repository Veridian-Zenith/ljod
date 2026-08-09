package dev.vz.ljod.app

import android.net.Uri
import androidx.lifecycle.ViewModel
import androidx.lifecycle.viewModelScope
import androidx.media3.common.MediaItem
import androidx.media3.common.MediaMetadata
import dagger.hilt.android.lifecycle.HiltViewModel
import dev.vz.ljod.core.data.scanner.AudioItem
import dev.vz.ljod.core.data.scanner.MediaScanner
import dev.vz.ljod.data.lyrics.LyricsRepository
import dev.vz.ljod.data.lyrics.LyricsResult
import dev.vz.ljod.data.lyrics.OnlineLyricsSource
import dev.vz.ljod.data.settings.LastPlayedData
import dev.vz.ljod.data.settings.SettingsRepository
import dev.vz.ljod.playback.PlaybackController
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.launch
import javax.inject.Inject

sealed class ScreenState {
    data object Main : ScreenState()
    data class Player(val song: AudioItem) : ScreenState()
    data class Lyrics(val song: AudioItem) : ScreenState()
    data class LyricsSearch(val song: AudioItem) : ScreenState()
    data class MetadataEdit(val song: AudioItem) : ScreenState()
}

@HiltViewModel
class LjodViewModel @Inject constructor(
    val controller: PlaybackController,
    private val scanner: MediaScanner,
    private val lyricsRepo: LyricsRepository,
    private val settingsRepo: SettingsRepository,
) : ViewModel() {

    private val _screenState = MutableStateFlow<ScreenState>(ScreenState.Main)
    val screenState: StateFlow<ScreenState> = _screenState.asStateFlow()

    private val _songs = MutableStateFlow<List<AudioItem>>(emptyList())
    val songs: StateFlow<List<AudioItem>> = _songs.asStateFlow()

    private val _lyrics = MutableStateFlow<LyricsResult?>(null)
    val lyrics: StateFlow<LyricsResult?> = _lyrics.asStateFlow()

    private val _shuffleMode = MutableStateFlow(false)
    val shuffleMode: StateFlow<Boolean> = _shuffleMode.asStateFlow()

    private val _searchResults = MutableStateFlow<List<LyricsResult>>(emptyList())
    val searchResults: StateFlow<List<LyricsResult>> = _searchResults.asStateFlow()

    private val _isTranslating = MutableStateFlow(false)
    val isTranslating: StateFlow<Boolean> = _isTranslating.asStateFlow()

    private val _userMessage = MutableStateFlow<String?>(null)
    val userMessage: StateFlow<String?> = _userMessage.asStateFlow()

    fun clearUserMessage() { _userMessage.value = null }

    private val _isRomanizing = MutableStateFlow(false)
    val isRomanizing: StateFlow<Boolean> = _isRomanizing.asStateFlow()

    private val _romanizationEnabled = MutableStateFlow(false)
    val romanizationEnabled: StateFlow<Boolean> = _romanizationEnabled.asStateFlow()

    private val _targetLanguage = MutableStateFlow("English")
    val targetLanguage: StateFlow<String> = _targetLanguage.asStateFlow()

    private val _lastPlayedInfo = MutableStateFlow<LastPlayedInfo?>(null)
    val lastPlayedInfo: StateFlow<LastPlayedInfo?> = _lastPlayedInfo.asStateFlow()

    private val onlineSource = OnlineLyricsSource()

    init {
        loadSongs()
        restoreLastPlayed()
        loadSettings()
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

    fun loadSongs() {
        viewModelScope.launch {
            _songs.value = scanner.scan()
        }
    }

    private fun restoreLastPlayed() {
        viewModelScope.launch {
            val songId = settingsRepo.lastPlayedSongId.first()
            if (songId > 0) {
                _lastPlayedInfo.value = LastPlayedInfo(
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
        val song = _songs.value.find { it.id == info.songId } ?: return
        playSong(song)
    }

    fun dismissLastPlayed() {
        _lastPlayedInfo.value = null
    }

    fun navigateTo(screen: ScreenState) { _screenState.value = screen }
    fun navigateBack() { _screenState.value = ScreenState.Main }

    fun playSong(song: AudioItem) {
        val item = MediaItem.Builder()
            .setMediaId(song.id.toString())
            .setUri(song.uri)
            .setMediaMetadata(
                MediaMetadata.Builder()
                    .setTitle(song.title)
                    .setArtist(song.artist)
                    .setAlbumTitle(song.album)
                    .build()
            )
            .build()

        if (_shuffleMode.value) {
            controller.setMediaItems(listOf(item), startIndex = 0)
        } else {
            val allItems = _songs.value.map { s ->
                MediaItem.Builder()
                    .setMediaId(s.id.toString())
                    .setUri(s.uri)
                    .setMediaMetadata(
                        MediaMetadata.Builder()
                            .setTitle(s.title)
                            .setArtist(s.artist)
                            .setAlbumTitle(s.album)
                            .build()
                    )
                    .build()
            }
            val idx = _songs.value.indexOfFirst { it.id == song.id }.coerceAtLeast(0)
            controller.setMediaItems(allItems, startIndex = idx)
        }
        controller.play()
        _screenState.value = ScreenState.Player(song)
        saveLastPlayed(song)
    }

    private fun saveLastPlayed(song: AudioItem) {
        viewModelScope.launch {
            val data = LastPlayedData(
                songId = song.id,
                uri = song.uri.toString(),
                title = song.title,
                artist = song.artist,
                album = song.album,
                position = 0L,
                duration = song.duration,
                albumId = song.albumId ?: -1L,
            )
            settingsRepo.saveLastPlayed(data)
            _lastPlayedInfo.value = LastPlayedInfo(
                songId = song.id,
                uri = song.uri.toString(),
                title = song.title,
                artist = song.artist,
                album = song.album,
                position = 0L,
                albumId = song.albumId ?: -1L,
            )
        }
    }

    fun toggleShuffle() { _shuffleMode.value = !_shuffleMode.value }

    fun loadLyrics(song: AudioItem) {
        viewModelScope.launch {
            val fileTags = scanner.readFileTags(song.uri)
            val title = fileTags?.title?.takeIf { it.isNotBlank() } ?: song.title
            val artist = fileTags?.artist?.takeIf { it.isNotBlank() } ?: song.artist
            val album = fileTags?.album?.takeIf { it.isNotBlank() } ?: song.album
            var result = lyricsRepo.fetchLyrics(
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

    fun albumArtUri(song: AudioItem): Uri? {
        return song.albumId?.let {
            if (it > 0) Uri.parse("content://media/external/audio/albumart/$it") else null
        }
    }

    fun searchLyrics(title: String, artist: String) {
        viewModelScope.launch {
            val results = onlineSource.searchLyrics(title, artist)
            _searchResults.value = results
        }
    }

    fun loadLyricsFromResult(result: LyricsResult, song: AudioItem) {
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

    fun romanizeLyrics(@Suppress("UNUSED_PARAMETER") song: AudioItem) {
        val currentLyrics = _lyrics.value ?: return
        viewModelScope.launch {
            _isRomanizing.value = true
            val romanized = lyricsRepo.romanizeLyrics(currentLyrics)
            _lyrics.value = romanized
            _isRomanizing.value = false
        }
    }
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
