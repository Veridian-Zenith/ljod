package dev.vz.ljod

import android.os.Bundle
import android.os.Environment
import android.os.Handler
import android.os.Looper
import android.util.Log
import com.ryanheise.audioservice.AudioServiceFragmentActivity
import io.flutter.embedding.engine.FlutterEngine
import io.flutter.plugin.common.MethodChannel
import java.io.File
import java.text.SimpleDateFormat
import java.util.Date
import java.util.Locale
import kotlin.concurrent.thread

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

        val main = Handler(Looper.getMainLooper())

        // MediaStore cursors and MediaMetadataRetriever decodes are disk work.
        // Running them on the platform main thread stalled the UI for the length
        // of the query, and artwork recovery does that once per batch of
        // tracks. Work happens off the main thread; results are posted back,
        // because MethodChannel.Result may only be called there.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, MEDIA_CHANNEL)
            .setMethodCallHandler { call, result ->
                when (call.method) {
                    "queryAudio" -> {
                        thread {
                            try {
                                val tracks = MusicProvider(applicationContext)
                                    .queryAllAudioFiles()
                                    .map { it.toMap() }
                                main.post { result.success(tracks) }
                            } catch (error: Exception) {
                                main.post {
                                    result.error(
                                        "QUERY_FAILED",
                                        error.message
                                            ?: "Could not read the device music library.",
                                        null
                                    )
                                }
                            }
                        }
                    }

                    "extractArtwork" -> {
                        // Arguments are read on the main thread, where the call
                        // arrived; the decode runs off it.
                        val dir = call.argument<String>("dir") ?: ""
                        val tracks =
                            (call.argument<List<*>>("tracks") ?: emptyList<Any?>())
                                .mapNotNull { it as? Map<*, *> }
                                .map { mapOf("id" to it["id"], "uri" to it["uri"]) }
                        thread {
                            try {
                                val artwork = MusicProvider(applicationContext)
                                    .extractArtwork(dir, tracks)
                                main.post { result.success(artwork) }
                            } catch (error: Exception) {
                                main.post {
                                    result.error(
                                        "ARTWORK_FAILED",
                                        error.message
                                            ?: "Could not read embedded artwork.",
                                        null
                                    )
                                }
                            }
                        }
                    }

                    else -> result.notImplemented()
                }
            }

        // Directory resolution. path_provider_android answers paths through
        // package:jni, and with jni 1.2.0 its generated bindings look the
        // Context class up by type signature ("Landroid/content/Context;")
        // and throw ClassNotFoundException. This channel returns the same
        // directories instead, so the database, the caches and just_audio's
        // asset cache no longer depend on that bridge. Keeping the semantics
        // identical means files from earlier builds are found in place.
        MethodChannel(flutterEngine.dartExecutor.binaryMessenger, PATHS_CHANNEL)
            .setMethodCallHandler { call, result ->
                try {
                    when (call.method) {
                        "temporary", "cache" ->
                            result.success(cacheDir.absolutePath)

                        "support" -> result.success(filesDir.absolutePath)

                        "documents" ->
                            result.success(
                                getDir("flutter", MODE_PRIVATE).absolutePath
                            )

                        "externalStorage" ->
                            result.success(getExternalFilesDir(null)?.absolutePath)

                        "externalCachePaths" ->
                            result.success(
                                externalCacheDirs.mapNotNull { it?.absolutePath }
                            )

                        "externalStoragePaths" ->
                            result.success(
                                getExternalFilesDirs(
                                    storageDirectory(call.argument<String>("type"))
                                ).mapNotNull { it?.absolutePath }
                            )

                        "downloads" ->
                            result.success(
                                getExternalFilesDir(
                                    Environment.DIRECTORY_DOWNLOADS
                                )?.absolutePath
                            )

                        else -> result.notImplemented()
                    }
                } catch (error: Exception) {
                    result.error(
                        "PATH_FAILED",
                        error.message ?: "Could not resolve ${call.method}.",
                        null
                    )
                }
            }
    }

    /** Maps a `StorageDirectory` name to its platform constant. */
    private fun storageDirectory(type: String?): String? = when (type) {
        "music" -> Environment.DIRECTORY_MUSIC
        "podcasts" -> Environment.DIRECTORY_PODCASTS
        "ringtones" -> Environment.DIRECTORY_RINGTONES
        "alarms" -> Environment.DIRECTORY_ALARMS
        "notifications" -> Environment.DIRECTORY_NOTIFICATIONS
        "pictures" -> Environment.DIRECTORY_PICTURES
        "movies" -> Environment.DIRECTORY_MOVIES
        "downloads" -> Environment.DIRECTORY_DOWNLOADS
        "dcim" -> Environment.DIRECTORY_DCIM
        "documents" -> Environment.DIRECTORY_DOCUMENTS
        else -> null
    }

    private companion object {
        const val MEDIA_CHANNEL = "dev.vz.ljod/media"
        const val PATHS_CHANNEL = "dev.vz.ljod/paths"
        const val CRASH_LOG = "ljod-crash.log"
    }
}
