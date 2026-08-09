package dev.vz.ljod.data.gemini

import dev.vz.ljod.data.lyrics.LyricsLine
import dev.vz.ljod.data.lyrics.LyricsResult
import kotlinx.coroutines.Dispatchers
import kotlinx.coroutines.withContext
import okhttp3.MediaType.Companion.toMediaType
import okhttp3.OkHttpClient
import okhttp3.Request
import okhttp3.RequestBody.Companion.toRequestBody
import kotlinx.serialization.Serializable
import kotlinx.serialization.json.Json
import kotlinx.serialization.json.JsonPrimitive
import kotlinx.serialization.json.buildJsonArray
import kotlinx.serialization.json.buildJsonObject
import kotlinx.serialization.json.jsonArray
import kotlinx.serialization.json.jsonObject
import kotlinx.serialization.json.jsonPrimitive
import timber.log.Timber
import java.util.concurrent.TimeUnit

@Serializable
data class GeminiResponse(
    val candidates: List<Candidate>? = null,
)

@Serializable
data class Candidate(
    val content: Content? = null,
)

@Serializable
data class Content(
    val parts: List<Part>? = null,
)

@Serializable
data class Part(
    val text: String? = null,
)

@Serializable
data class GeminiModelInfo(
    val name: String? = null,
    val displayName: String? = null,
    val supportedGenerationMethods: List<String>? = null,
    val inputTokenLimit: Int? = null,
    val outputTokenLimit: Int? = null,
)

@Serializable
data class ListModelsResponse(
    val models: List<GeminiModelInfo>? = null,
)

data class AvailableModel(
    val id: String,
    val displayName: String,
    val isFree: Boolean,
    val inputTokenLimit: Int,
    val outputTokenLimit: Int,
)

object PromptTemplates {

    fun lyricsGeneration(title: String, artist: String, album: String = ""): String = buildString {
        appendLine("You are a music metadata expert.")
        appendLine("Generate the lyrics for this song.")
        appendLine("Song: $title")
        appendLine("Artist: $artist")
        if (album.isNotEmpty()) appendLine("Album: $album")
        appendLine()
        appendLine("Output ONLY the lyrics. No titles, no metadata headers, no explanations, no markdown formatting.")
    }

    fun lyricsTranslation(lyrics: String, targetLanguage: String, title: String = "", artist: String = ""): String = buildString {
        appendLine("Translate the following song lyrics to $targetLanguage.")
        appendLine("Preserve the original line structure exactly.")
        if (title.isNotEmpty()) appendLine("Song: $title by $artist")
        appendLine()
        appendLine("Output ONLY the translated lyrics. No explanations, no headers, no markdown.")
        appendLine()
        appendLine(lyrics)
    }

    fun custom(task: String, title: String = "", artist: String = ""): String = buildString {
        appendLine("You are a music metadata expert.")
        appendLine(task)
        if (title.isNotEmpty()) appendLine("Song: $title")
        if (artist.isNotEmpty()) appendLine("Artist: $artist")
        appendLine()
        appendLine("Output only the relevant content, no explanations.")
    }
}

class GeminiLyricsSource {

    private val client = OkHttpClient.Builder()
        .connectTimeout(30, TimeUnit.SECONDS)
        .readTimeout(60, TimeUnit.SECONDS)
        .build()

    private val json = Json { ignoreUnknownKeys = true }

    suspend fun fetchAvailableModels(apiKey: String): List<AvailableModel> {
        return withContext(Dispatchers.IO) {
            try {
                val request = Request.Builder()
                    .url("https://generativelanguage.googleapis.com/v1beta/models?key=$apiKey")
                    .get()
                    .build()

                val response = client.newCall(request).execute()
                if (!response.isSuccessful) {
                    Timber.e("Gemini models API error: ${response.code}")
                    return@withContext emptyList()
                }

                val body = response.body?.string() ?: return@withContext emptyList()
                val parsed = json.decodeFromString<ListModelsResponse>(body)

                parsed.models
                    ?.filter { model ->
                        val methods = model.supportedGenerationMethods ?: emptyList()
                        methods.contains("generateContent") &&
                            model.name?.startsWith("models/gemini") == true
                    }
                    ?.map { model ->
                        val rawId = model.name?.removePrefix("models/") ?: ""
                        val outputLimit = model.outputTokenLimit ?: 0
                        val isFree = outputLimit <= 8192
                        AvailableModel(
                            id = rawId,
                            displayName = buildString {
                                append(model.displayName ?: rawId)
                                if (isFree) append(" (free)") else append(" (paid)")
                            },
                            isFree = isFree,
                            inputTokenLimit = model.inputTokenLimit ?: 0,
                            outputTokenLimit = outputLimit,
                        )
                    }
                    ?.sortedByDescending { it.isFree }
                    ?: emptyList()
            } catch (e: Exception) {
                Timber.w(e, "Failed to fetch Gemini models")
                emptyList()
            }
        }
    }

    suspend fun generateLyrics(
        apiKey: String,
        model: String,
        title: String,
        artist: String,
        album: String = "",
    ): LyricsResult? {
        return withContext(Dispatchers.IO) {
            try {
                val prompt = PromptTemplates.lyricsGeneration(title, artist, album)
                val response = callGemini(apiKey, model, prompt) ?: return@withContext null
                val cleaned = stripMarkdownFences(response)
                val lines = cleaned.lines()
                    .filter { it.isNotBlank() }
                    .map { LyricsLine(timeMs = 0, text = it.trim()) }
                if (lines.isEmpty()) null
                else LyricsResult(lines = lines, source = "gemini ($model)", isSynced = false)
            } catch (e: Exception) {
                Timber.w(e, "Gemini lyrics generation failed")
                null
            }
        }
    }

    suspend fun translateLyrics(
        apiKey: String,
        model: String,
        lyrics: String,
        targetLanguage: String,
        title: String = "",
        artist: String = "",
    ): LyricsResult? {
        return withContext(Dispatchers.IO) {
            try {
                val prompt = PromptTemplates.lyricsTranslation(lyrics, targetLanguage, title, artist)
                val response = callGemini(apiKey, model, prompt) ?: return@withContext null
                val cleaned = stripMarkdownFences(response)
                val lines = cleaned.lines()
                    .filter { it.isNotBlank() }
                    .map { LyricsLine(timeMs = 0, text = it.trim()) }
                if (lines.isEmpty()) null
                else LyricsResult(lines = lines, source = "gemini_translation ($model)", isSynced = false)
            } catch (e: Exception) {
                Timber.w(e, "Gemini lyrics translation failed")
                null
            }
        }
    }

    private fun stripMarkdownFences(text: String): String {
        var result = text.trim()
        if (result.startsWith("```")) {
            val firstNewline = result.indexOf('\n')
            if (firstNewline > 0) {
                result = result.substring(firstNewline + 1)
            }
        }
        if (result.endsWith("```")) {
            result = result.removeSuffix("```").trimEnd()
        }
        return result
    }

    private suspend fun callGemini(apiKey: String, model: String, prompt: String): String? {
        val requestBody = buildJsonObject {
            put("contents", buildJsonArray {
                add(buildJsonObject {
                    put("parts", buildJsonArray {
                        add(buildJsonObject {
                            put("text", JsonPrimitive(prompt))
                        })
                    })
                })
            })
            put("generationConfig", buildJsonObject {
                put("temperature", JsonPrimitive(0.7))
                put("maxOutputTokens", JsonPrimitive(2048))
            })
        }.toString()

        val request = Request.Builder()
            .url("https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent?key=$apiKey")
            .post(requestBody.toRequestBody("application/json".toMediaType()))
            .build()

        val response = client.newCall(request).execute()
        if (!response.isSuccessful) {
            Timber.e("Gemini API error: ${response.code}")
            return null
        }

        val body = response.body?.string() ?: return null
        val geminiResponse = json.decodeFromString<GeminiResponse>(body)
        return geminiResponse.candidates?.firstOrNull()?.content?.parts?.firstOrNull()?.text
    }
}
