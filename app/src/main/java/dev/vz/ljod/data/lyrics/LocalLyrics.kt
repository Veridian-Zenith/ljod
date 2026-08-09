package dev.vz.ljod.data.lyrics

import android.content.Context
import android.net.Uri
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

        for (line in lrcContent.lines()) {
            parseLine(line.trim())?.let { lines.add(it) }
        }

        return LyricsResult(
            lines = lines.sortedBy { it.timeMs },
            source = "lrc_file",
            isSynced = lines.isNotEmpty(),
        )
    }

    private fun parseLine(trimmed: String): LyricsLine? {
        if (!trimmed.startsWith("[")) return null
        val match = Regex("""\[(\d{2}):(\d{2})\.(\d{2,3})](.*)""").find(trimmed)
            ?: return null
        val min = match.groupValues[1].toLongOrNull() ?: 0L
        val sec = match.groupValues[2].toLongOrNull() ?: 0L
        val ms = match.groupValues[3].let { v ->
            if (v.length == 2) v.toLong() * 10 else v.toLongOrNull() ?: 0L
        }
        val timeMs = min * 60_000 + sec * 1000 + ms
        val text = match.groupValues[4].trim()
        return if (text.isNotEmpty()) LyricsLine(timeMs, text) else null
    }
}

class LocalLyricsSource(@Suppress("UNUSED_PARAMETER") context: Context) {

    private val parser = LrcParser()

    suspend fun fetchLyrics(uri: Uri, title: String, artist: String): LyricsResult? {
        return withContext(Dispatchers.IO) {
            try {
                val docUri = DocumentsContract.getDocumentUri(uri) ?: return@withContext null
                val docFile = File(docUri.path ?: return@withContext null)
                val parentDir = docFile.parentFile ?: return@withContext null

                val baseName = docFile.nameWithoutExtension
                val candidates = listOf(
                    File(parentDir, "$baseName.lrc"),
                    File(parentDir, "$title.lrc"),
                    File(parentDir, "$artist - $title.lrc"),
                )

                for (candidate in candidates) {
                    if (candidate.exists()) {
                        val content = candidate.readText()
                        val result = parser.parse(content)
                        if (result.lines.isNotEmpty()) return@withContext result
                    }
                }

                null
            } catch (e: Exception) {
                Timber.w(e, "Failed to read local lyrics")
                null
            }
        }
    }

    private object DocumentsContract {
        fun getDocumentUri(uri: Uri): Uri? {
            val path = uri.path ?: return null
            val segments = uri.pathSegments
            if (segments.size < 2) return null
            val docId = segments[1]
            val split = docId.split(":")
            if (split.size < 2) return null
            val pathPart = split[1]
            return Uri.parse("file:///storage/emulated/0/$pathPart")
        }
    }
}
