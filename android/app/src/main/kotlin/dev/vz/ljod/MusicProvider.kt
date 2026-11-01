package dev.vz.ljod

import android.content.ContentUris
import android.content.Context
import android.os.Build
import android.provider.MediaStore

/**
 * Reads the device music library through MediaStore.
 *
 * Scoped storage means [MediaStore.MediaColumns.DATA] may be null on some
 * devices; in that case the content URI is returned and playback still works.
 * The Dart side only reads tags/artwork from real file paths and otherwise
 * relies on the MediaStore metadata returned here.
 */
class MusicProvider(private val context: Context) {

    fun queryAllAudioFiles(): List<AudioFile> {
        val collection = MediaStore.Audio.Media.EXTERNAL_CONTENT_URI
        val projection = buildList {
            add(MediaStore.Audio.Media._ID)
            add(MediaStore.Audio.Media.DATA)
            add(MediaStore.Audio.Media.TITLE)
            add(MediaStore.Audio.Media.ARTIST)
            add(MediaStore.Audio.Media.ALBUM)
            add(MediaStore.Audio.Media.DURATION)
            add(MediaStore.Audio.Media.TRACK)
            add(MediaStore.Audio.Media.DATE_ADDED)
            if (Build.VERSION.SDK_INT >= Build.VERSION_CODES.R) {
                add(MediaStore.Audio.Media.ALBUM_ARTIST)
            }
        }.toTypedArray()

        val selection = buildString {
            append(MediaStore.Audio.Media.DURATION).append(" > 0")
            append(" AND ").append(MediaStore.Audio.Media.IS_RINGTONE).append(" = 0")
            append(" AND ").append(MediaStore.Audio.Media.IS_NOTIFICATION).append(" = 0")
            append(" AND ").append(MediaStore.Audio.Media.IS_ALARM).append(" = 0")
        }

        val files = mutableListOf<AudioFile>()

        context.contentResolver.query(
            collection,
            projection,
            selection,
            null,
            "${MediaStore.Audio.Media.TITLE} COLLATE NOCASE ASC"
        )?.use { cursor ->
            val idColumn = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media._ID)
            val dataColumn = cursor.getColumnIndex(MediaStore.Audio.Media.DATA)
            val titleColumn = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.TITLE)
            val artistColumn = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.ARTIST)
            val albumColumn = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.ALBUM)
            val albumArtistColumn = cursor.getColumnIndex(MediaStore.Audio.Media.ALBUM_ARTIST)
            val durationColumn = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.DURATION)
            val trackColumn = cursor.getColumnIndex(MediaStore.Audio.Media.TRACK)
            val addedColumn = cursor.getColumnIndex(MediaStore.Audio.Media.DATE_ADDED)

            while (cursor.moveToNext()) {
                val id = cursor.getLong(idColumn)
                val data = if (dataColumn >= 0) cursor.getString(dataColumn) else null
                val contentUri = ContentUris.withAppendedId(collection, id).toString()
                val artist = cursor.getString(artistColumn) ?: ""

                files.add(
                    AudioFile(
                        id = id.toString(),
                        path = if (!data.isNullOrBlank()) data else contentUri,
                        title = cursor.getString(titleColumn) ?: "",
                        artist = artist,
                        album = cursor.getString(albumColumn) ?: "",
                        albumArtist = if (albumArtistColumn >= 0) {
                            cursor.getString(albumArtistColumn) ?: artist
                        } else {
                            artist
                        },
                        durationMs = cursor.getLong(durationColumn),
                        trackNumber = if (trackColumn >= 0) {
                            cursor.getInt(trackColumn).rem(1000)
                        } else {
                            0
                        },
                        addedAtMs = if (addedColumn >= 0) {
                            cursor.getLong(addedColumn) * 1000L
                        } else {
                            0L
                        }
                    )
                )
            }
        }

        return files
    }

    data class AudioFile(
        val id: String,
        val path: String,
        val title: String,
        val artist: String,
        val album: String,
        val albumArtist: String,
        val durationMs: Long,
        val trackNumber: Int,
        val addedAtMs: Long
    ) {
        fun toMap(): Map<String, Any?> = mapOf(
            "id" to id,
            "path" to path,
            "title" to title,
            "artist" to artist,
            "album" to album,
            "albumArtist" to albumArtist,
            "durationMs" to durationMs,
            "trackNumber" to trackNumber,
            "addedAtMs" to addedAtMs
        )
    }
}
