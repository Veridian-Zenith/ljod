package dev.vz.ljod.core.data.scanner

import android.content.Context
import android.net.Uri
import android.provider.MediaStore

data class AudioItem(
    val id: Long,
    val title: String,
    val artist: String,
    val album: String,
    val duration: Long,
    val uri: Uri,
    val dateAdded: Long,
    val albumId: Long?,
) {
    val displayDuration: String get() {
        val totalSec = duration / 1000
        val min = totalSec / 60
        val sec = totalSec % 60
        return "%d:%02d".format(min, sec)
    }
}

class MediaScanner(private val context: Context) {

    fun scan(
        selection: String = "${MediaStore.Audio.Media.IS_MUSIC} != 0",
        minDurationMs: Long = 30_000,
    ): List<AudioItem> {
        val items = mutableListOf<AudioItem>()
        val collection = MediaStore.Audio.Media.EXTERNAL_CONTENT_URI

        val projection = arrayOf(
            MediaStore.Audio.Media._ID,
            MediaStore.Audio.Media.TITLE,
            MediaStore.Audio.Media.ARTIST,
            MediaStore.Audio.Media.ALBUM,
            MediaStore.Audio.Media.DURATION,
            MediaStore.Audio.Media.DATE_ADDED,
            MediaStore.Audio.Media.ALBUM_ID,
        )

        context.contentResolver.query(
            collection, projection, selection, null,
            "${MediaStore.Audio.Media.TITLE} ASC"
        )?.use { cursor ->
            val id = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media._ID)
            val title = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.TITLE)
            val artist = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.ARTIST)
            val album = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.ALBUM)
            val duration = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.DURATION)
            val dateAdded = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.DATE_ADDED)
            val albumId = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.ALBUM_ID)

            while (cursor.moveToNext()) {
                val d = cursor.getLong(duration)
                if (d < minDurationMs) continue
                val songId = cursor.getLong(id)
                items.add(
                    AudioItem(
                        id = songId,
                        title = cursor.getString(title),
                        artist = cursor.getString(artist),
                        album = cursor.getString(album),
                        duration = d,
                        uri = Uri.withAppendedPath(MediaStore.Audio.Media.EXTERNAL_CONTENT_URI, "$songId"),
                        dateAdded = cursor.getLong(dateAdded),
                        albumId = cursor.getLong(albumId),
                    )
                )
            }
        }
        return items
    }

    fun albumArtUri(albumId: Long): Uri {
        return Uri.parse("content://media/external/audio/albumart/$albumId")
    }
}
