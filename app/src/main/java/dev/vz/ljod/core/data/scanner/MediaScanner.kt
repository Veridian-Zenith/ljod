package dev.vz.ljod.core.data.scanner

import android.content.ContentUris
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
    val year: Int?,
    val trackNumber: Int?,
    val genre: String?,
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
    val trackNumber: Int? = null,
    val year: Int? = null,
    val genre: String? = null,
    val mimeType: String? = null,
    val sizeBytes: Long? = null,
    val fileTags: FileTags? = null,
) {
    val displayDuration: String get() {
        val totalSec = duration / 1000
        val min = totalSec / 60
        val sec = totalSec % 60
        return "%d:%02d".format(min, sec)
    }

    val albumArtUri: Uri?
        get() =
            if (albumId != null && albumId > 0) {
                ContentUris.withAppendedId(ALBUM_ART_URI, albumId)
            } else {
                null
            }
}

private val ALBUM_ART_URI: Uri = Uri.parse("content://media/external/audio/albumart")

class MediaScanner(
    private val context: Context,
) {
    fun readFileTags(uri: Uri): FileTags? =
        try {
            val retriever = MediaMetadataRetriever()
            retriever.setDataSource(context, uri)
            val year =
                retriever
                    .extractMetadata(MediaMetadataRetriever.METADATA_KEY_YEAR)
                    ?.toIntOrNull()
            val track =
                retriever
                    .extractMetadata(MediaMetadataRetriever.METADATA_KEY_CD_TRACK_NUMBER)
                    ?.substringBefore('/')
                    ?.toIntOrNull()
            val tags =
                FileTags(
                    title = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_TITLE),
                    artist = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_ARTIST),
                    album = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_ALBUM),
                    albumArtist = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_ALBUMARTIST),
                    year = year,
                    trackNumber = track,
                    genre = retriever.extractMetadata(MediaMetadataRetriever.METADATA_KEY_GENRE),
                )
            retriever.release()
            tags
        } catch (e: Exception) {
            Timber.d("Failed to read file tags: ${e.message}")
            null
        }

    fun scan(
        selection: String = "${MediaStore.Audio.Media.IS_MUSIC} != 0",
        minDurationMs: Long = 5_000,
    ): List<AudioItem> {
        val items = mutableListOf<AudioItem>()
        val collection = MediaStore.Audio.Media.EXTERNAL_CONTENT_URI

        val projection =
            arrayOf(
                MediaStore.Audio.Media._ID,
                MediaStore.Audio.Media.TITLE,
                MediaStore.Audio.Media.ARTIST,
                MediaStore.Audio.Media.ALBUM,
                MediaStore.Audio.Media.ALBUM_ARTIST,
                MediaStore.Audio.Media.DURATION,
                MediaStore.Audio.Media.DATE_ADDED,
                MediaStore.Audio.Media.ALBUM_ID,
                MediaStore.Audio.Media.TRACK,
                MediaStore.Audio.Media.YEAR,
                MediaStore.Audio.Media.MIME_TYPE,
                MediaStore.Audio.Media.SIZE,
            )

        context.contentResolver
            .query(
                collection,
                projection,
                selection,
                null,
                "${MediaStore.Audio.Media.TITLE} ASC",
            )?.use { cursor ->
                val id = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media._ID)
                val title = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.TITLE)
                val artist = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.ARTIST)
                val album = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.ALBUM)
                val albumArtist = cursor.getColumnIndex(MediaStore.Audio.Media.ALBUM_ARTIST)
                val duration = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.DURATION)
                val dateAdded = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.DATE_ADDED)
                val albumId = cursor.getColumnIndexOrThrow(MediaStore.Audio.Media.ALBUM_ID)
                val trackCol = cursor.getColumnIndex(MediaStore.Audio.Media.TRACK)
                val yearCol = cursor.getColumnIndex(MediaStore.Audio.Media.YEAR)
                val mimeCol = cursor.getColumnIndex(MediaStore.Audio.Media.MIME_TYPE)
                val sizeCol = cursor.getColumnIndex(MediaStore.Audio.Media.SIZE)

                while (cursor.moveToNext()) {
                    val d = cursor.getLong(duration)
                    if (d < minDurationMs) continue
                    val songId = cursor.getLong(id)
                    val trackRaw = if (trackCol >= 0) cursor.getInt(trackCol) else null
                    items.add(
                        AudioItem(
                            id = songId,
                            title = cursor.getString(title) ?: "Unknown",
                            artist =
                                (if (albumArtist >= 0) cursor.getString(albumArtist) else null)
                                    ?: cursor.getString(artist) ?: "Unknown",
                            album = cursor.getString(album) ?: "Unknown",
                            duration = d,
                            uri =
                                Uri.withAppendedPath(
                                    MediaStore.Audio.Media.EXTERNAL_CONTENT_URI,
                                    "$songId",
                                ),
                            dateAdded = cursor.getLong(dateAdded),
                            albumId = cursor.getLong(albumId),
                            trackNumber = trackRaw?.takeIf { it > 0 },
                            year = if (yearCol >= 0) cursor.getInt(yearCol).takeIf { it > 0 } else null,
                            genre = null,
                            mimeType = if (mimeCol >= 0) cursor.getString(mimeCol) else null,
                            sizeBytes = if (sizeCol >= 0) cursor.getLong(sizeCol) else null,
                        ),
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

        context.contentResolver
            .query(
                collection,
                projection,
                selection,
                null,
                null,
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
