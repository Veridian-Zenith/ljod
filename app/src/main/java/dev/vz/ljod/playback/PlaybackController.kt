package dev.vz.ljod.playback

import android.content.ComponentName
import android.content.Context
import android.media.audiofx.Equalizer
import androidx.media3.common.AudioAttributes
import androidx.media3.common.C
import androidx.media3.common.MediaItem
import androidx.media3.common.PlaybackParameters
import androidx.media3.common.Player
import androidx.media3.session.MediaController
import androidx.media3.session.SessionToken
import com.google.common.util.concurrent.ListenableFuture
import com.google.common.util.concurrent.MoreExecutors
import dagger.hilt.android.qualifiers.ApplicationContext
import dev.vz.ljod.data.settings.RepeatMode
import dev.vz.ljod.data.settings.SettingsRepository
import kotlinx.coroutines.CoroutineScope
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.Job
import kotlinx.coroutines.SupervisorJob
import kotlinx.coroutines.delay
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.launchIn
import kotlinx.coroutines.flow.onEach
import kotlinx.coroutines.launch
import kotlinx.coroutines.withContext
import timber.log.Timber
import java.util.concurrent.atomic.AtomicInteger
import javax.inject.Inject
import javax.inject.Singleton
import kotlin.math.max

@Singleton
class PlaybackController
    @Inject
    constructor(
        @ApplicationContext private val context: Context,
        private val settings: SettingsRepository,
    ) {
        private var controllerFuture: ListenableFuture<MediaController>? = null
        private var controller: MediaController? = null
        private val scope = CoroutineScope(SupervisorJob() + Dispatchers.Main)
        private var positionJob: Job? = null
        private var equalizer: Equalizer? = null
        private val audioSessionId = AtomicInteger(C.AUDIO_SESSION_ID_UNSET)

        private val _isConnected = MutableStateFlow(false)
        val isConnected: StateFlow<Boolean> = _isConnected.asStateFlow()

        private val _isPlaying = MutableStateFlow(false)
        val isPlaying: StateFlow<Boolean> = _isPlaying.asStateFlow()

        private val _title = MutableStateFlow<String?>(null)
        val title: StateFlow<String?> = _title.asStateFlow()

        private val _artist = MutableStateFlow<String?>(null)
        val artist: StateFlow<String?> = _artist.asStateFlow()

        private val _album = MutableStateFlow<String?>(null)
        val album: StateFlow<String?> = _album.asStateFlow()

        private val _albumId = MutableStateFlow<Long?>(null)
        val albumId: StateFlow<Long?> = _albumId.asStateFlow()

        private val _duration = MutableStateFlow(0L)
        val duration: StateFlow<Long> = _duration.asStateFlow()

        private val _position = MutableStateFlow(0L)
        val position: StateFlow<Long> = _position.asStateFlow()

        private val _currentIndex = MutableStateFlow(0)
        val currentIndex: StateFlow<Int> = _currentIndex.asStateFlow()

        private val _mediaItems = MutableStateFlow<List<MediaItem>>(emptyList())
        val mediaItems: StateFlow<List<MediaItem>> = _mediaItems.asStateFlow()

        private val _repeatMode = MutableStateFlow(RepeatMode.Off)
        val repeatMode: StateFlow<RepeatMode> = _repeatMode.asStateFlow()

        private val _shuffleMode = MutableStateFlow(false)
        val shuffleMode: StateFlow<Boolean> = _shuffleMode.asStateFlow()

        private val _volume = MutableStateFlow(1f)
        val volume: StateFlow<Float> = _volume.asStateFlow()

        private val _sleepRemainingMs = MutableStateFlow(0L)
        val sleepRemainingMs: StateFlow<Long> = _sleepRemainingMs.asStateFlow()

        private val _audioSession = MutableStateFlow(C.AUDIO_SESSION_ID_UNSET)
        val audioSession: StateFlow<Int> = _audioSession.asStateFlow()

        init {
            settings.repeatMode
                .onEach { mode ->
                    _repeatMode.value = mode
                    applyRepeat(mode)
                }.launchIn(scope)
            settings.shuffleMode
                .onEach { enabled ->
                    _shuffleMode.value = enabled
                    controller?.shuffleModeEnabled = enabled
                }.launchIn(scope)
            settings.volume
                .onEach { v ->
                    _volume.value = v
                    controller?.volume = v
                }.launchIn(scope)
            settings.audioFocus
                .onEach { _ ->
                    // audioAttributes is immutable on MediaController; configured at session level in PlaybackService
                }.launchIn(scope)
            settings.gapless
                .onEach { _ ->
                    // gapless playback is configured at the ExoPlayer builder level
                }.launchIn(scope)
            settings.eqEnabled
                .onEach { enabled ->
                    if (enabled) initEqualizer() else equalizer?.release()
                    equalizer = null
                }.launchIn(scope)
        }

        private fun ensureConnected() {
            if (controllerFuture != null) return
            val token = SessionToken(context, ComponentName(context, PlaybackService::class.java))
            controllerFuture = MediaController.Builder(context, token).buildAsync()
            controllerFuture!!.addListener({
                controller = controllerFuture!!.get()
                _isConnected.value = true
                controller?.addListener(listener)
                controller?.let { applyAllSettings(it) }
                val session = controller?.audioSessionId ?: C.AUDIO_SESSION_ID_UNSET
                audioSessionId.set(session)
                _audioSession.value = session
                initEqualizer()
                Timber.d("PlaybackController connected (session=$session)")
            }, MoreExecutors.directExecutor())
        }

        private fun applyAllSettings(c: MediaController) {
            c.repeatMode =
                when (_repeatMode.value) {
                    RepeatMode.Off -> Player.REPEAT_MODE_OFF
                    RepeatMode.One -> Player.REPEAT_MODE_ONE
                    RepeatMode.All -> Player.REPEAT_MODE_ALL
                }
            c.shuffleModeEnabled = _shuffleMode.value
            c.volume = _volume.value
        }

        private fun applyRepeat(mode: RepeatMode) {
            controller?.repeatMode =
                when (mode) {
                    RepeatMode.Off -> Player.REPEAT_MODE_OFF
                    RepeatMode.One -> Player.REPEAT_MODE_ONE
                    RepeatMode.All -> Player.REPEAT_MODE_ALL
                }
        }

        private val listener =
            object : Player.Listener {
                override fun onIsPlayingChanged(playing: Boolean) {
                    _isPlaying.value = playing
                    if (playing) startPositionUpdates() else stopPositionUpdates()
                }

                override fun onMediaItemTransition(
                    item: MediaItem?,
                    reason: Int,
                ) {
                    _title.value = item?.mediaMetadata?.title?.toString()
                    _artist.value = item?.mediaMetadata?.artist?.toString()
                    _album.value = item?.mediaMetadata?.albumTitle?.toString()
                    _albumId.value = item?.mediaId?.toLongOrNull()
                    controller?.let { c ->
                        _duration.value = c.duration.coerceAtLeast(0)
                        _position.value = c.currentPosition.coerceAtLeast(0)
                        _currentIndex.value = c.currentMediaItemIndex
                    }
                }

                override fun onPlaybackStateChanged(state: Int) {
                    controller?.let { c ->
                        _duration.value = c.duration.coerceAtLeast(0)
                        _position.value = c.currentPosition.coerceAtLeast(0)
                        if (state == Player.STATE_READY) {
                            val session = c.audioSessionId
                            if (session != audioSessionId.getAndSet(session)) {
                                _audioSession.value = session
                            }
                        }
                    }
                }

                override fun onAudioSessionIdChanged(sessionId: Int) {
                    _audioSession.value = sessionId
                    audioSessionId.set(sessionId)
                    initEqualizer()
                }
            }

        private fun startPositionUpdates() {
            stopPositionUpdates()
            positionJob =
                scope.launch {
                    while (true) {
                        controller?.let { c ->
                            _position.value = c.currentPosition.coerceAtLeast(0)
                            val s = settings.sleepTimerEpoch.first()
                            if (s > 0L) {
                                val remaining = s - System.currentTimeMillis()
                                _sleepRemainingMs.value = max(0L, remaining)
                                if (remaining <= 0L) {
                                    c.pause()
                                    settings.setSleepTimerEpoch(0L)
                                }
                            } else {
                                _sleepRemainingMs.value = 0L
                            }
                        }
                        delay(250)
                    }
                }
        }

        private fun stopPositionUpdates() {
            positionJob?.cancel()
            positionJob = null
        }

        fun play() {
            ensureConnected()
            controller?.play()
        }

        fun pause() {
            controller?.pause()
        }

        fun togglePlayPause() {
            if (_isPlaying.value) pause() else play()
        }

        fun seekTo(position: Long) {
            controller?.seekTo(position.coerceAtLeast(0))
        }

        fun skipToNext() {
            controller?.seekToNext()
        }

        fun skipToPrevious() {
            controller?.seekToPrevious()
        }

        fun seekBy(deltaMs: Long) {
            val c = controller ?: return
            c.seekTo((c.currentPosition + deltaMs).coerceAtLeast(0))
        }

        fun setMediaItems(
            items: List<MediaItem>,
            startIndex: Int = 0,
            startPositionMs: Long = 0,
        ) {
            ensureConnected()
            val withIds = items.map { it.buildWithId() }
            controller?.setMediaItems(withIds, startIndex, startPositionMs)
            _mediaItems.value = withIds
            _currentIndex.value = startIndex
        }

        fun setQueue(
            mediaIds: List<String>,
            startMediaId: String,
            startPositionMs: Long = 0,
        ) {
            ensureConnected()
            val resolved = mediaIds.mapNotNull { id -> _mediaItems.value.find { it.mediaId == id } }
            if (resolved.isEmpty()) return
            val startIndex = resolved.indexOfFirst { it.mediaId == startMediaId }.coerceAtLeast(0)
            controller?.setMediaItems(resolved, startIndex, startPositionMs)
            _mediaItems.value = resolved
            _currentIndex.value = startIndex
        }

        fun addToQueue(item: MediaItem) {
            ensureConnected()
            val withId = item.buildWithId()
            controller?.addMediaItem(withId)
            _mediaItems.value = _mediaItems.value + withId
        }

        fun removeFromQueue(index: Int) {
            val c = controller ?: return
            if (index in 0 until c.mediaItemCount) {
                c.removeMediaItem(index)
                _mediaItems.value = _mediaItems.value.toMutableList().also { it.removeAt(index) }
            }
        }

        fun moveInQueue(
            from: Int,
            to: Int,
        ) {
            val c = controller ?: return
            if (from in 0 until c.mediaItemCount && to in 0..c.mediaItemCount) {
                c.moveMediaItem(from, to)
                val list = _mediaItems.value.toMutableList()
                val item = list.removeAt(from)
                list.add(to, item)
                _mediaItems.value = list
            }
        }

        fun clearQueue() {
            val c = controller ?: return
            c.clearMediaItems()
            _mediaItems.value = emptyList()
        }

        fun setVolume(value: Float) {
            val v = value.coerceIn(0f, 1f)
            controller?.volume = v
            _volume.value = v
            scope.launch { settings.setVolume(v) }
        }

        fun setShuffleMode(enabled: Boolean) {
            _shuffleMode.value = enabled
            controller?.shuffleModeEnabled = enabled
            scope.launch { settings.setShuffleMode(enabled) }
        }

        fun setRepeatMode(mode: RepeatMode) {
            _repeatMode.value = mode
            applyRepeat(mode)
            scope.launch { settings.setRepeatMode(mode) }
        }

        fun setPlaybackSpeed(speed: Float) {
            val s = speed.coerceIn(0.5f, 2.0f)
            controller?.playbackParameters = PlaybackParameters(s)
        }

        fun setSleepTimer(durationMs: Long) {
            scope.launch {
                if (durationMs <= 0L) {
                    settings.setSleepTimerEpoch(0L)
                    _sleepRemainingMs.value = 0L
                } else {
                    settings.setSleepTimerEpoch(System.currentTimeMillis() + durationMs)
                }
            }
        }

        fun initEqualizer() {
            scope.launch {
                val enabled = settings.eqEnabled.first()
                if (!enabled) return@launch
                val session = _audioSession.value
                if (session == C.AUDIO_SESSION_ID_UNSET) return@launch
                withContext(Dispatchers.IO) {
                    try {
                        equalizer?.release()
                        val eq = Equalizer(0, session)
                        eq.enabled = true
                        equalizer = eq
                    } catch (e: Exception) {
                        Timber.w(e, "Equalizer init failed")
                    }
                }
            }
        }

        fun setEqualizerBand(
            level: Int,
            band: Int,
        ) {
            try {
                equalizer?.setBandLevel(band.toShort(), level.toShort().coerceIn(-15, 15))
            } catch (e: Exception) {
                Timber.w(e, "EQ band set failed")
            }
        }

        fun equalizerBandCount(): Int =
            try {
                equalizer?.numberOfBands?.toInt() ?: 0
            } catch (e: Exception) {
                Timber.w(e, "EQ count failed")
                0
            }

        fun equalizerBandLevelRange(): Pair<Short, Short> =
            try {
                val r = equalizer?.bandLevelRange ?: shortArrayOf(-15, 15)
                (r[0] to r[1]) as Pair<Short, Short>
            } catch (e: Exception) {
                Timber.w(e, "EQ range failed")
                (-15).toShort() to 15.toShort()
            }

        fun release() {
            stopPositionUpdates()
            equalizer?.release()
            equalizer = null
            controller?.removeListener(listener)
            controllerFuture?.let { MediaController.releaseFuture(it) }
        }

        private fun MediaItem.buildWithId(): MediaItem {
            if (!mediaId.isNullOrBlank()) return this
            val uriString = localConfiguration?.uri?.toString() ?: return this
            return buildUpon().setMediaId(uriString).build()
        }
    }
