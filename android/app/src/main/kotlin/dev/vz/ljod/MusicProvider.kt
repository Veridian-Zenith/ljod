package dev.vz.ljod

import android.content.ContentUris
import android.content.Context
import android.graphics.Bitmap
import android.graphics.BitmapFactory
import android.media.MediaMetadataRetriever
import android.net.Uri
import android.os.Build
import android.provider.MediaStore
import android.util.Size
import java.io.ByteArrayOutputStream
import java.io.File

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
                        contentUri = contentUri,
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

    /**
     * Decodes embedded cover art through [MediaMetadataRetriever].
     *
     * The Dart tag reader needs a readable file path; this works from the
     * MediaStore content URI, so a library whose `DATA` column is empty (or
     * whose files the reader cannot open) still gets its covers. Each picture is
     * written to [targetDir] and the Dart side moves it into the shared artwork
     * cache, which owns hashing, de-duplication and the size ceiling.
     *
     * Returns ids that produced a picture, mapped to the staged file.
     */
    fun extractArtwork(
        targetDir: String,
        items: List<Map<String, Any?>>
    ): Map<String, String> {
        val output = mutableMapOf<String, String>()
        val directory = File(targetDir).apply { mkdirs() }

        for (item in items) {
            val id = item["id"] as? String ?: continue
            val uri = item["uri"] as? String ?: continue
            val retriever = MediaMetadataRetriever()
            try {
                retriever.setDataSource(context, Uri.parse(uri))
                // Embedded art first, in whatever format the file carries
                // (JPEG, PNG, WebP, GIF, BMP); then MediaStore's generated
                // thumbnail, for libraries that keep covers beside the tracks.
                var picture = retriever.embeddedPicture ?: thumbnailBytes(uri)
                if (picture == null || picture.isEmpty() || picture.size > MAX_RAW_BYTES) {
                    continue
                }
                // Re-encode oversized art instead of dropping it: a 3000×3000
                // cover is routinely 2–6 MiB and used to be discarded, which
                // made a tagged track look like it had no artwork at all.
                if (picture.size > MAX_PICTURE_BYTES) {
                    picture = shrink(picture) ?: continue
                }
                val file = File(directory, "$id.img")
                file.writeBytes(picture)
                output[id] = file.path
            } catch (_: Exception) {
                // No embedded picture, or an unreadable track: skip it.
            } finally {
                try {
                    retriever.release()
                } catch (_: Exception) {
                    // Nothing to release.
                }
            }
        }

        return output
    }

    /** MediaStore's generated art for [uri], or null when there is none. */
    private fun thumbnailBytes(uri: String): ByteArray? {
        return try {
            val bitmap = context.contentResolver.loadThumbnail(
                Uri.parse(uri),
                Size(1024, 1024),
                null
            )
            val stream = ByteArrayOutputStream()
            bitmap.compress(Bitmap.CompressFormat.JPEG, 92, stream)
            bitmap.recycle()
            stream.toByteArray()
        } catch (_: Exception) {
            null
        }
    }

    /** Re-encodes [bytes] as a JPEG small enough for the Dart cache. */
    private fun shrink(bytes: ByteArray): ByteArray? {
        return try {
            val bounds = BitmapFactory.Options().apply { inJustDecodeBounds = true }
            BitmapFactory.decodeByteArray(bytes, 0, bytes.size, bounds)
            var sample = 1
            val longest = maxOf(bounds.outWidth, bounds.outHeight)
            while (longest / sample > MAX_EDGE_PX) sample *= 2

            val options = BitmapFactory.Options().apply { inSampleSize = sample }
            val bitmap = BitmapFactory.decodeByteArray(bytes, 0, bytes.size, options)
                ?: return null
            val stream = ByteArrayOutputStream()
            bitmap.compress(Bitmap.CompressFormat.JPEG, 90, stream)
            bitmap.recycle()
            stream.toByteArray()
        } catch (_: Throwable) {
            null
        }
    }

    private companion object {
        /** Matches the Dart cache ceiling: art above this is downscaled first. */
        const val MAX_PICTURE_BYTES = 4 * 1024 * 1024

        /** Coarse guard against a pathological tag; the ceiling above is the real one. */
        const val MAX_RAW_BYTES = 32 * 1024 * 1024

        /** Longest edge kept when re-encoding a large cover. */
        const val MAX_EDGE_PX = 1024
    }

    data class AudioFile(
        val id: String,
        val contentUri: String,
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
            "contentUri" to contentUri,
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
