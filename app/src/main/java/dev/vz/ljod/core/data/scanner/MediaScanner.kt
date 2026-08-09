package dev.vz.ljod.core.data.scanner

import android.content.Context
import android.media.MediaMetadataRetriever
import android.net.Uri
import android.provider.MediaStore
import timber.log.Timber

data class FileTags(
    val title: String?,
    val artist: String?,
    val album: String?,
    val albumArtist: String?,
)

data class AudioItem(
    val id: Long,
    val title: String,
    val artist: String,
    val album: String,
    val duration: Long,
    val uri: Uri,
    val dateAdded: Long,
    val albumId: Long?,
    val fileTags: FileTags? = null,
) {
    val displayDuration: String get() {
        val totalSec = duration / 1000
        val min = totalSec / 60
        val sec = totalSec % 60
        return "%d:%02d".format(min, sec)
    }

    val albumArtUri: Uri?
        get() = if (albumId != null && albumId > 0) {
            Uri.parse("content://media/external/audio/albumart/$albumId")
        } else {
            null
        }
}

class MediaScanner(private val context: Context) {

    fun readFileTags(uri: Uri): FileTags? {
        return try {
            val retriever = MediaMetadataRetriever()
            retriever.setDataSource(context, uri)
            val tags = FileTags(
                title = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_TITLE),
                artist = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_ARTIST),
                album = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_ALBUM),
                albumArtist = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_ALBUMARTIST),
            )
            retriever.release()
            tags
        } catch (e: Exception) {
            Timber.d("Failed to read file tags: ${e.message}")
            null
        }
    }

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
            MediaStore.Audio.Media.DATA,
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
                        uri = Uri.withAppendedPath(
                            MediaStore.Audio.Media.EXTERNAL_CONTENT_URI, "$songId",
                        ),
                        dateAdded = cursor.getLong(dateAdded),
                        albumId = cursor.getLong(albumId),
                    )
                )
            }
        }
        return items
    }

    fun scanFolders(): List<String> {
        val folders = mutableSetOf<String>()
        val collection = MediaStore.Audio.Media.EXTERNAL_CONTENT_URI
        val projection = arrayOf(MediaStore.Audio.Media.DATA)
        val selection = "${MediaStore.Audio.Media.IS_MUSIC} != 0"

        context.contentResolver.query(
            collection, projection, selection, null, null,
        )?.use { cursor ->
            val data = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.DATA)
            while (cursor.moveToNext()) {
                val path = cursor.getString(data) ?: continue
                val folder = path.substringBeforeLast("/")
                folders.add(folder)
            }
        }
        return folders.sorted()
    }
}
