package dev.vz.ljod.data.settings

import android.content.Context
import androidx.datastore.core.DataStore
import androidx.datastore.preferences.core.Preferences
import androidx.datastore.preferences.core.booleanPreferencesKey
import androidx.datastore.preferences.core.edit
import androidx.datastore.preferences.core.longPreferencesKey
import androidx.datastore.preferences.core.stringPreferencesKey
import androidx.datastore.preferences.preferencesDataStore
import dagger.hilt.android.qualifiers.ApplicationContext
import kotlinx.coroutines.flow.Flow
import kotlinx.coroutines.flow.map
import javax.inject.Inject
import javax.inject.Singleton

private val Context.dataStore: DataStore<Preferences> by preferencesDataStore(name = "ljod_settings")

@Singleton
class SettingsRepository @Inject constructor(
    @ApplicationContext private val context: Context,
) {
    private object Keys {
        val GEMINI_API_KEY = stringPreferencesKey("gemini_api_key")
        val GEMINI_PROVIDER = stringPreferencesKey("gemini_provider")
        val GEMINI_MODEL = stringPreferencesKey("gemini_model")
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
    }

    val geminiApiKey: Flow<String> = context.dataStore.data.map { it[Keys.GEMINI_API_KEY] ?: "" }
    val geminiProvider: Flow<String> = context.dataStore.data.map { it[Keys.GEMINI_PROVIDER] ?: "nano" }
    val geminiModel: Flow<String> = context.dataStore.data.map { it[Keys.GEMINI_MODEL] ?: "gemini-2.0-flash" }
    val targetLanguage: Flow<String> = context.dataStore.data.map { it[Keys.TARGET_LANGUAGE] ?: "English" }
    val romanization: Flow<Boolean> = context.dataStore.data.map { it[Keys.ROMANIZATION] ?: false }

    val lastPlayedSongId: Flow<Long> = context.dataStore.data.map { it[Keys.LAST_PLAYED_SONG_ID] ?: -1L }
    val lastPlayedUri: Flow<String> = context.dataStore.data.map { it[Keys.LAST_PLAYED_URI] ?: "" }
    val lastPlayedTitle: Flow<String> = context.dataStore.data.map { it[Keys.LAST_PLAYED_TITLE] ?: "" }
    val lastPlayedArtist: Flow<String> = context.dataStore.data.map { it[Keys.LAST_PLAYED_ARTIST] ?: "" }
    val lastPlayedAlbum: Flow<String> = context.dataStore.data.map { it[Keys.LAST_PLAYED_ALBUM] ?: "" }
    val lastPlayedPosition: Flow<Long> = context.dataStore.data.map { it[Keys.LAST_PLAYED_POSITION] ?: 0L }
    val lastPlayedDuration: Flow<Long> = context.dataStore.data.map { it[Keys.LAST_PLAYED_DURATION] ?: 0L }
    val lastPlayedAlbumId: Flow<Long> = context.dataStore.data.map { it[Keys.LAST_PLAYED_ALBUM_ID] ?: -1L }

    suspend fun setGeminiApiKey(key: String) {
        context.dataStore.edit { it[Keys.GEMINI_API_KEY] = key }
    }

    suspend fun setGeminiProvider(provider: String) {
        context.dataStore.edit { it[Keys.GEMINI_PROVIDER] = provider }
    }

    suspend fun setGeminiModel(model: String) {
        context.dataStore.edit { it[Keys.GEMINI_MODEL] = model }
    }

    suspend fun setTargetLanguage(lang: String) {
        context.dataStore.edit { it[Keys.TARGET_LANGUAGE] = lang }
    }

    suspend fun setRomanization(enabled: Boolean) {
        context.dataStore.edit { it[Keys.ROMANIZATION] = enabled }
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
