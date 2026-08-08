package dev.vz.ljod.playback

import android.content.ComponentName
import android.content.Context
import androidx.media3.common.MediaItem
import androidx.media3.common.Player
import androidx.media3.session.MediaController
import androidx.media3.session.SessionToken
import com.google.common.util.concurrent.ListenableFuture
import com.google.common.util.concurrent.MoreExecutors
import kotlinx.coroutines.flow.MutableStateFlow
import kotlinx.coroutines.flow.StateFlow
import kotlinx.coroutines.flow.asStateFlow
import timber.log.Timber

class PlaybackController(context: Context, serviceClass: Class<*>) {

    private val controllerFuture: ListenableFuture<MediaController>
    private var controller: MediaController? = null

    private val _isConnected = MutableStateFlow(false)
    val isConnected: StateFlow<Boolean> = _isConnected.asStateFlow()

    private val _isPlaying = MutableStateFlow(false)
    val isPlaying: StateFlow<Boolean> = _isPlaying.asStateFlow()

    private val _title = MutableStateFlow<String?>(null)
    val title: StateFlow<String?> = _title.asStateFlow()

    private val _artist = MutableStateFlow<String?>(null)
    val artist: StateFlow<String?> = _artist.asStateFlow()

    private val _position = MutableStateFlow(0L)
    val position: StateFlow<Long> = _position.asStateFlow()

    private val _duration = MutableStateFlow(0L)
    val duration: StateFlow<Long> = _duration.asStateFlow()

    private val _mediaItems = MutableStateFlow<List<MediaItem>>(emptyList())
    val mediaItems: StateFlow<List<MediaItem>> = _mediaItems.asStateFlow()

    init {
        val token = SessionToken.Builder(context, ComponentName(context, serviceClass)).build()
        controllerFuture = MediaController.Builder(context, token).buildAsync()
        controllerFuture.addListener({
            controller = controllerFuture.get()
            _isConnected.value = true
            controller?.addListener(listener)
            Timber.d("PlaybackController connected")
        }, MoreExecutors.directExecutor())
    }

    private val listener = object : Player.Listener {
        override fun onIsPlayingChanged(playing: Boolean) {
            _isPlaying.value = playing
        }

        override fun onMediaItemTransition(item: MediaItem?, reason: Int) {
            _title.value = item?.mediaMetadata?.title?.toString()
            _artist.value = item?.mediaMetadata?.artist?.toString()
        }

        override fun onPlaybackStateChanged(state: Int) {
            controller?.let { c ->
                _duration.value = c.duration.coerceAtLeast(0)
                _position.value = c.currentPosition.coerceAtLeast(0)
            }
        }
    }

    fun play() { controller?.play() }
    fun pause() { controller?.pause() }
    fun togglePlayPause() { if (_isPlaying.value) pause() else play() }
    fun seekTo(position: Long) { controller?.seekTo(position) }
    fun skipToNext() { controller?.seekToNext() }
    fun skipToPrevious() { controller?.seekToPrevious() }

    fun setMediaItems(items: List<MediaItem>, startIndex: Int = 0) {
        controller?.setMediaItems(items, startIndex, 0)
        _mediaItems.value = items
    }

    fun release() {
        controller?.removeListener(listener)
        MediaController.releaseFuture(controllerFuture)
    }
}
