package dev.vz.ljod.data.lyrics

import android.content.Context
import android.net.Uri
import android.provider.MediaStore
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import timber.log.Timber
import java.io.File

data class LyricsLine(
    val timeMs: Long,
    val text: String,
    val romanized: String? = null,
    val translated: String? = null,
)

data class LyricsResult(
    val lines: List<LyricsLine>,
    val source: String,
    val isSynced: Boolean,
)

class LrcParser {
    fun parse(lrcContent: String): LyricsResult {
        val lines = mutableListOf<LyricsLine>()
        val metaTags = mutableMapOf<String, String>()
        for (raw in lrcContent.lines()) {
            val line = raw.trim()
            if (line.isEmpty()) continue
            tryParseLrcLine(line, metaTags, lines)
        }
        return LyricsResult(
            lines = lines.sortedBy { it.timeMs },
            source = metaTags["ar"]?.let { "lrc_file ($it)" } ?: "lrc_file",
            isSynced = lines.isNotEmpty(),
        )
    }

    private fun tryParseLrcLine(line: String, metaTags: MutableMap<String, String>, lines: MutableList<LyricsLine>): Boolean {
        if (!line.startsWith("[")) return false
        val end = line.indexOf(']')
        if (end <= 1) return false
        val tag = line.substring(1, end)
        return when {
            tag.matches(Regex("""\d{1,2}:\d{1,2}(\.\d{1,3})?""")) -> {
                parseLine(line)?.let { lines.add(it) }
                true
            }
            tag.contains(":") -> {
                metaTags[tag.lowercase()] = line.substring(end + 1)
                true
            }
            else -> false
        }
    }

    private fun parseLine(trimmed: String): LyricsLine? {
        if (!trimmed.startsWith("[")) return null
        val match =
            Regex("""\[(\d{1,2}):(\d{1,2})\.(\d{1,3})](.*)""").find(trimmed)
                ?: return null
        val min = match.groupValues[1].toLongOrNull() ?: 0L
        val sec = match.groupValues[2].toLongOrNull() ?: 0L
        val ms =
            match.groupValues[3].let { v ->
                if (v.length == 2) v.toLong() * 10 else v.toLongOrNull() ?: 0L
            }
        val timeMs = min * 60_000 + sec * 1000 + ms
        val text = match.groupValues[4].trim()
        return if (text.isNotEmpty()) LyricsLine(timeMs, text) else null
    }
}

class LocalLyricsSource(
    private val context: Context,
) {
    private val parser = LrcParser()

    suspend fun fetchLyrics(
        audioUri: Uri,
        title: String,
        artist: String,
    ): LyricsResult? {
        return withContext(Dispatchers.IO) {
            try {
                val audioPath = resolveLocalPath(audioUri) ?: return@withContext null
                val audioFile = File(audioPath)
                val parent = audioFile.parentFile ?: return@withContext null
                val baseName = audioFile.nameWithoutExtension

                val candidates =
                    listOf(
                        File(parent, "$baseName.lrc"),
                        File(parent, "$title.lrc"),
                        File(parent, "$artist - $title.lrc"),
                    )
                for (candidate in candidates) {
                    if (candidate.exists() && candidate.canRead()) {
                        val content = candidate.readText()
                        val parsed = parser.parse(content)
                        if (parsed.lines.isNotEmpty()) return@withContext parsed
                    }
                }
                null
            } catch (e: Exception) {
                Timber.w(e, "Failed to read local lyrics")
                null
            }
        }
    }

    private fun resolveLocalPath(uri: Uri): String? {
        if (uri.scheme == "file") return uri.path
        if (uri.scheme == "content" && uri.authority == MediaStore.Audio.Media.EXTERNAL_CONTENT_URI.authority) {
            val projection = arrayOf(MediaStore.Audio.Media.DATA)
            context.contentResolver.query(uri, projection, null, null, null)?.use { c ->
                if (c.moveToFirst()) {
                    val idx = c.getColumnIndexOrThrow(MediaStore.Audio.Media.DATA)
                    return c.getString(idx)
                }
            }
        }
        return uri.path
    }
}
