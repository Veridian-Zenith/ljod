package dev.vz.ljod

import android.os.Bundle
import android.util.Log
import com.ryanheise.audioservice.AudioServiceFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale

/**
 * Hosts Flutter plus the small MediaStore bridge used by the Dart library
 * service. Extends [AudioServiceFragmentActivity] so media-button and
 * notification intents reach `audio_service`.
 */
class MainActivity : AudioServiceFragmentActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        // Android-side failures (a bad foreground-service start, a crashed
        // plugin) kill the process before Dart ever hears about them. Write the
        // stack to app storage so the next launch can show it in Diagnostics.
        val previous = Thread.getDefaultUncaughtExceptionHandler()
        Thread.setDefaultUncaughtExceptionHandler { thread, error ->
            try {
                val stamp = SimpleDateFormat(
                    "yyyy-MM-dd HH:mm:ss",
                    Locale.US
                ).format(Date())
                File(filesDir, CRASH_LOG).writeText(
                    "$stamp thread=${thread.name}\n" +
                        Log.getStackTraceString(error)
                )
            } catch (_: Throwable) {
                // Never mask the original crash.
            }
            previous?.uncaughtException(thread, error)
        }
        super.onCreate(savedInstanceState)
    }

    override fun configureFlutterEngine(flutterEngine: FlutterEngine) {
        super.configureFlutterEngine(flutterEngine)

        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, MEDIA_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "queryAudio" -> {
                        try {
                            val tracks = MusicProvider(applicationContext)
                                .queryAllAudioFiles()
                                .map { it.toMap() }
                            result.success(tracks)
                        } catch (error: Exception) {
                            result.error(
                                "QUERY_FAILED",
                                error.message ?: "Could not read the device music library.",
                                null
                            )
                        }
                    }

                    else -> result.notImplemented()
                }
            }
    }

    private companion object {
        const val MEDIA_CHANNEL = "dev.vz.ljod/media"
        const val CRASH_LOG = "ljod-crash.log"
    }
}
