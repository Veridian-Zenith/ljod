package dev.vz.ljod.playback
import android.content.Context
import android.media.audiofx.Equalizer
import androidx.media3.common.Player
import dagger.hilt.android.qualifiers.ApplicationContext
import timber.log.Timber
import javax.inject.Inject
import javax.inject.Singleton
@Singleton
class EqualizerController
    @Inject
    constructor(
        @ApplicationContext private val appCtx: Context,
    ) {
        private var equalizer: Equalizer? = null
        val playerListener =
            object : Player.Listener {
                override fun onAudioSessionIdChanged(audioSessionId: Int) {
                    attach(audioSessionId)
                }
            }
        private fun attach(audioSessionId: Int) {
            if (audioSessionId == 0) return
            try {
                equalizer?.release()
                equalizer = Equalizer(0, audioSessionId).apply { enabled = true }
                Timber.d("Equalizer attached (session=$audioSessionId, ctx=${appCtx.packageName})")
            } catch (e: Exception) {
                Timber.w(e, "Equalizer attach failed")
            }
        }
        init { Timber.d("EqualizerController init using $appCtx") }
    }
