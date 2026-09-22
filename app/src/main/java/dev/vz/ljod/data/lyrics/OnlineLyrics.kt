package dev.vz.ljod.data.lyrics

import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import okhttp3.OkHttpClient
import okhttp3.Request
import timber.log.Timber
import java.util.concurrent.TimeUnit

@Serializable
data class LrcLibResponse(
    val id: Long? = null,
    val trackName: String? = null,
    val artistName: String? = null,
    val albumName: String? = null,
    val duration: Double? = null,
    val instrumental: Boolean = false,
    val plainLyrics: String? = null,
    val syncedLyrics: String? = null,
)

class OnlineLyricsSource {
    private val client =
        OkHttpClient
            .Builder()
            .connectTimeout(10, TimeUnit.SECONDS)
            .readTimeout(10, TimeUnit.SECONDS)
            .build()

    private val json = Json { ignoreUnknownKeys = true }

    suspend fun fetchLyrics(
        title: String,
        artist: String,
        durationMs: Long? = null,
    ): LyricsResult? {
        return withContext(Dispatchers.IO) {
            try {
                val durationSec = durationMs?.let { it / 1000.0 }

                val urlBuilder =
                    StringBuilder("https://lrclib.net/api/search?")
                        .append("track_name=${java.net.URLEncoder.encode(title, "UTF-8")}")
                        .append("&artist_name=${java.net.URLEncoder.encode(artist, "UTF-8")}")

                if (durationSec != null) {
                    urlBuilder.append("&duration=${durationSec.toInt()}")
                }

                val request =
                    Request
                        .Builder()
                        .url(urlBuilder.toString())
                        .header("User-Agent", "Ljod/0.1.0 (https://github.com/Veridian-Zenith/ljod)")
                        .build()

                val response = client.newCall(request).execute()
                if (!response.isSuccessful) {
                    Timber.d("lrclib.net returned ${response.code}")
                    return@withContext null
                }

                val body = response.body?.string() ?: return@withContext null
                val results = json.decodeFromString<List<LrcLibResponse>>(body)
                val best = results.firstOrNull() ?: return@withContext null

                val syncedLyrics = best.syncedLyrics
                val plainLyrics = best.plainLyrics

                if (!syncedLyrics.isNullOrBlank()) {
                    val lines = parseSyncedLyrics(syncedLyrics)
                    LyricsResult(lines = lines, source = "lrclib.net", isSynced = true)
                } else if (!plainLyrics.isNullOrBlank()) {
                    val lines =
                        plainLyrics
                            .lines()
                            .filter { it.isNotBlank() }
                            .map { LyricsLine(timeMs = 0, text = it) }
                    LyricsResult(lines = lines, source = "lrclib.net", isSynced = false)
                } else {
                    null
                }
            } catch (e: Exception) {
                Timber.w(e, "Failed to fetch lyrics from lrclib.net")
                null
            }
        }
    }

    suspend fun searchLyrics(
        title: String,
        artist: String,
    ): List<LyricsResult> {
        return withContext(Dispatchers.IO) {
            try {
                val urlBuilder =
                    StringBuilder("https://lrclib.net/api/search?")
                        .append("track_name=${java.net.URLEncoder.encode(title, "UTF-8")}")
                        .append("&artist_name=${java.net.URLEncoder.encode(artist, "UTF-8")}")

                val request =
                    Request
                        .Builder()
                        .url(urlBuilder.toString())
                        .header("User-Agent", "Ljod/0.1.0 (https://github.com/Veridian-Zenith/ljod)")
                        .build()

                val response = client.newCall(request).execute()
                if (!response.isSuccessful) {
                    return@withContext emptyList()
                }

                val body = response.body?.string() ?: return@withContext emptyList()
                val results = json.decodeFromString<List<LrcLibResponse>>(body)

                results.mapNotNull { item ->
                    val syncedLyrics = item.syncedLyrics
                    val plainLyrics = item.plainLyrics
                    val label =
                        buildString {
                            append(item.trackName ?: title)
                            if (!item.artistName.isNullOrBlank()) append(" - ${item.artistName}")
                        }

                    if (!syncedLyrics.isNullOrBlank()) {
                        val lines = parseSyncedLyrics(syncedLyrics)
                        LyricsResult(lines = lines, source = "lrclib.net ($label)", isSynced = true)
                    } else if (!plainLyrics.isNullOrBlank()) {
                        val lines =
                            plainLyrics
                                .lines()
                                .filter { it.isNotBlank() }
                                .map { LyricsLine(timeMs = 0, text = it) }
                        LyricsResult(lines = lines, source = "lrclib.net ($label)", isSynced = false)
                    } else {
                        null
                    }
                }
            } catch (e: Exception) {
                Timber.w(e, "Failed to search lyrics from lrclib.net")
                emptyList()
            }
        }
    }

    private fun parseSyncedLyrics(synced: String): List<LyricsLine> {
        val regex = Regex("""\[(\d{2}):(\d{2})\.(\d{2,3})](.*)""")
        return synced
            .lines()
            .mapNotNull { raw ->
                val match = regex.find(raw.trim()) ?: return@mapNotNull null
                val min = match.groupValues[1].toLongOrNull() ?: return@mapNotNull null
                val sec = match.groupValues[2].toLongOrNull() ?: return@mapNotNull null
                val ms =
                    match.groupValues[3].let { v ->
                        if (v.length == 2) v.toLong() * 10 else v.toLongOrNull() ?: 0L
                    }
                val text = match.groupValues[4].trim()
                if (text.isNotEmpty()) LyricsLine(min * 60_000 + sec * 1000 + ms, text) else null
            }.sortedBy { it.timeMs }
    }
}
