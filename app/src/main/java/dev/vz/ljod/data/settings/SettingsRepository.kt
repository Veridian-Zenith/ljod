package dev.vz.ljod.data.settings

import android.content.Context
import java.util.Locale
import java.util.Locale.LanguageRange
import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.booleanPreferencesKey
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.floatPreferencesKey
import androidx.datastore.preferences.core.intPreferencesKey
import androidx.datastore.preferences.core.longPreferencesKey
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import dagger.hilt.android.qualifiers.ApplicationContext
import dev.vz.ljod.data.security.SecureStore
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.first
import kotlinx.coroutines.flow.map
import javax.inject.Inject
import javax.inject.Singleton

private val Context.dataStore: DataStore<Preferences> by preferencesDataStore(name = "ljod_settings")

@Singleton
class SettingsRepository
    @Inject
    constructor(
        @ApplicationContext private val context: Context,
    ) {
        private object Keys {
            val TARGET_LANGUAGE = stringPreferencesKey("target_language")
            val ROMANIZATION = booleanPreferencesKey("romanization")
            val LAST_PLAYED_SONG_ID = longPreferencesKey("last_played_song_id")
            val LAST_PLAYED_URI = stringPreferencesKey("last_played_uri")
            val LAST_PLAYED_TITLE = stringPreferencesKey("last_played_title")
            val LAST_PLAYED_ARTIST = stringPreferencesKey("last_played_artist")
            val LAST_PLAYED_ALBUM = stringPreferencesKey("last_played_album")
            val LAST_PLAYED_POSITION = longPreferencesKey("last_played_position")
            val LAST_PLAYED_DURATION = longPreferencesKey("last_played_duration")
            val LAST_PLAYED_ALBUM_ID = longPreferencesKey("last_played_album_id")
            val REPEAT_MODE = stringPreferencesKey("repeat_mode")
            val SHUFFLE_MODE = booleanPreferencesKey("shuffle_mode")
            val VOLUME = floatPreferencesKey("volume")
            val PURE_BLACK = booleanPreferencesKey("pure_black")
            val ANIMATIONS = booleanPreferencesKey("animations")
            val BLUR = intPreferencesKey("blur")
            val BIOMETRIC = booleanPreferencesKey("biometric")
            val CROSSFADE_MS = intPreferencesKey("crossfade_ms")
            val AUDIO_FOCUS = booleanPreferencesKey("audio_focus")
            val GAPLESS = booleanPreferencesKey("gapless")
            val EQ_ENABLED = booleanPreferencesKey("eq_enabled")
            val EQ_BANDS = stringPreferencesKey("eq_bands")
            val EQ_PRESET = stringPreferencesKey("eq_preset")
            val SLEEP_TIMER_EPOCH = longPreferencesKey("sleep_timer_epoch")
            val WIDGET_THEME = stringPreferencesKey("widget_theme")
            val PROFILE = stringPreferencesKey("profile")
        }

        private object SecureKeys {
            const val GEMINI_API_KEY = "gemini_api_key"
            const val SESSION_TOKEN = "session_token"
        }

    fun detectFromDeviceLocale(): String {
        val locale = Locale.getDefault()
        val lang = locale.language
        val country = locale.country
        return when {
            lang == "nb" || lang == "no" || country == "NO" || country == "NB" -> "Norwegian Bokmål"
            lang == "ru" -> "Russian"
            lang == "de" -> "German"
            lang == "ja" -> "Japanese"
            lang == "zh" -> "Chinese"
            lang == "ko" -> "Korean"
            else -> "English"
        }
    }

    val targetLanguage: Flow<String> = context.dataStore.data.map { it[Keys.TARGET_LANGUAGE] ?: detectFromDeviceLocale() }
        val romanization: Flow<Boolean> = context.dataStore.data.map { it[Keys.ROMANIZATION] ?: false }

        val lastPlayedSongId: Flow<Long> = context.dataStore.data.map { it[Keys.LAST_PLAYED_SONG_ID] ?: -1L }
        val lastPlayedUri: Flow<String> = context.dataStore.data.map { it[Keys.LAST_PLAYED_URI] ?: "" }
        val lastPlayedTitle: Flow<String> = context.dataStore.data.map { it[Keys.LAST_PLAYED_TITLE] ?: "" }
        val lastPlayedArtist: Flow<String> = context.dataStore.data.map { it[Keys.LAST_PLAYED_ARTIST] ?: "" }
        val lastPlayedAlbum: Flow<String> = context.dataStore.data.map { it[Keys.LAST_PLAYED_ALBUM] ?: "" }
        val lastPlayedPosition: Flow<Long> = context.dataStore.data.map { it[Keys.LAST_PLAYED_POSITION] ?: 0L }
        val lastPlayedDuration: Flow<Long> = context.dataStore.data.map { it[Keys.LAST_PLAYED_DURATION] ?: 0L }
        val lastPlayedAlbumId: Flow<Long> = context.dataStore.data.map { it[Keys.LAST_PLAYED_ALBUM_ID] ?: -1L }

        val repeatMode: Flow<RepeatMode> =
            context.dataStore.data.map {
                RepeatMode.fromKey(it[Keys.REPEAT_MODE])
            }
        val shuffleMode: Flow<Boolean> = context.dataStore.data.map { it[Keys.SHUFFLE_MODE] ?: false }
        val volume: Flow<Float> = context.dataStore.data.map { it[Keys.VOLUME] ?: 1f }
        val pureBlack: Flow<Boolean> = context.dataStore.data.map { it[Keys.PURE_BLACK] ?: true }
        val animations: Flow<Boolean> = context.dataStore.data.map { it[Keys.ANIMATIONS] ?: true }
        val blur: Flow<Int> = context.dataStore.data.map { it[Keys.BLUR] ?: 16 }
        val biometric: Flow<Boolean> = context.dataStore.data.map { it[Keys.BIOMETRIC] ?: false }
        val crossfadeMs: Flow<Int> = context.dataStore.data.map { it[Keys.CROSSFADE_MS] ?: 0 }
        val audioFocus: Flow<Boolean> = context.dataStore.data.map { it[Keys.AUDIO_FOCUS] ?: true }
        val gapless: Flow<Boolean> = context.dataStore.data.map { it[Keys.GAPLESS] ?: true }
        val eqEnabled: Flow<Boolean> = context.dataStore.data.map { it[Keys.EQ_ENABLED] ?: false }
        val eqBands: Flow<String> = context.dataStore.data.map { it[Keys.EQ_BANDS] ?: "" }
        val eqPreset: Flow<String> = context.dataStore.data.map { it[Keys.EQ_PRESET] ?: "Flat" }
        val sleepTimerEpoch: Flow<Long> = context.dataStore.data.map { it[Keys.SLEEP_TIMER_EPOCH] ?: 0L }
        val profile: Flow<String> = context.dataStore.data.map { it[Keys.PROFILE] ?: "default" }

        val geminiApiKey: Flow<String> =
            kotlinx.coroutines.flow.flow {
                emit(SecureStore.getString(SecureKeys.GEMINI_API_KEY).orEmpty())
            }
        val geminiProvider: Flow<String> = kotlinx.coroutines.flow.flowOf("nano")
        val geminiModel: Flow<String> = kotlinx.coroutines.flow.flowOf("gemini-2.0-flash")

        suspend fun setTargetLanguage(lang: String) {
            context.dataStore.edit { it[Keys.TARGET_LANGUAGE] = lang }
        }

        suspend fun setRomanization(enabled: Boolean) {
            context.dataStore.edit { it[Keys.ROMANIZATION] = enabled }
        }

        suspend fun setRepeatMode(mode: RepeatMode) {
            context.dataStore.edit { it[Keys.REPEAT_MODE] = mode.key }
        }

        suspend fun setShuffleMode(enabled: Boolean) {
            context.dataStore.edit { it[Keys.SHUFFLE_MODE] = enabled }
        }

        suspend fun setVolume(v: Float) {
            context.dataStore.edit { it[Keys.VOLUME] = v.coerceIn(0f, 1f) }
        }

        suspend fun setPureBlack(enabled: Boolean) {
            context.dataStore.edit { it[Keys.PURE_BLACK] = enabled }
        }

        suspend fun setAnimations(enabled: Boolean) {
            context.dataStore.edit { it[Keys.ANIMATIONS] = enabled }
        }

        suspend fun setBlur(amount: Int) {
            context.dataStore.edit { it[Keys.BLUR] = amount.coerceIn(0, 28) }
        }

        suspend fun setBiometric(enabled: Boolean) {
            context.dataStore.edit { it[Keys.BIOMETRIC] = enabled }
        }

        suspend fun setCrossfadeMs(ms: Int) {
            context.dataStore.edit { it[Keys.CROSSFADE_MS] = ms.coerceIn(0, 12_000) }
        }

        suspend fun setAudioFocus(enabled: Boolean) {
            context.dataStore.edit { it[Keys.AUDIO_FOCUS] = enabled }
        }

        suspend fun setGapless(enabled: Boolean) {
            context.dataStore.edit { it[Keys.GAPLESS] = enabled }
        }

        suspend fun setEqEnabled(enabled: Boolean) {
            context.dataStore.edit { it[Keys.EQ_ENABLED] = enabled }
        }

        suspend fun setEqBands(encoded: String) {
            context.dataStore.edit { it[Keys.EQ_BANDS] = encoded }
        }

        suspend fun setEqPreset(name: String) {
            context.dataStore.edit { it[Keys.EQ_PRESET] = name }
        }

        suspend fun setSleepTimerEpoch(epoch: Long) {
            context.dataStore.edit { it[Keys.SLEEP_TIMER_EPOCH] = epoch }
        }

        suspend fun setProfile(name: String) {
            context.dataStore.edit { it[Keys.PROFILE] = name }
        }

        suspend fun saveLastPlayed(info: LastPlayedData) {
            context.dataStore.edit {
                it[Keys.LAST_PLAYED_SONG_ID] = info.songId
                it[Keys.LAST_PLAYED_URI] = info.uri
                it[Keys.LAST_PLAYED_TITLE] = info.title
                it[Keys.LAST_PLAYED_ARTIST] = info.artist
                it[Keys.LAST_PLAYED_ALBUM] = info.album
                it[Keys.LAST_PLAYED_POSITION] = info.position
                it[Keys.LAST_PLAYED_DURATION] = info.duration
                it[Keys.LAST_PLAYED_ALBUM_ID] = info.albumId
            }
        }

        suspend fun clearLastPlayed() {
            context.dataStore.edit {
                it.remove(Keys.LAST_PLAYED_SONG_ID)
                it.remove(Keys.LAST_PLAYED_URI)
                it.remove(Keys.LAST_PLAYED_TITLE)
                it.remove(Keys.LAST_PLAYED_ARTIST)
                it.remove(Keys.LAST_PLAYED_ALBUM)
                it.remove(Keys.LAST_PLAYED_POSITION)
                it.remove(Keys.LAST_PLAYED_DURATION)
                it.remove(Keys.LAST_PLAYED_ALBUM_ID)
            }
        }

        suspend fun setGeminiApiKey(key: String) {
            SecureStore.putString(SecureKeys.GEMINI_API_KEY, key.ifBlank { null })
        }

        suspend fun rotateSessionToken(): String {
            val token = SecureStore.randomToken(24)
            SecureStore.putString(SecureKeys.SESSION_TOKEN, token)
            return token
        }

        suspend fun readGeminiApiKey(): String = SecureStore.getString(SecureKeys.GEMINI_API_KEY).orEmpty()

        suspend fun hasGeminiKey(): Boolean = readGeminiApiKey().isNotBlank()
    }

data class LastPlayedData(
    val songId: Long,
    val uri: String,
    val title: String,
    val artist: String,
    val album: String,
    val position: Long,
    val duration: Long,
    val albumId: Long,
)

enum class RepeatMode(
    val key: String,
) {
    Off("off"),
    One("one"),
    All("all"),
    ;

    companion object {
        fun fromKey(key: String?): RepeatMode = entries.firstOrNull { it.key == key } ?: Off
    }
}
