package dev.vz.ljod.data.model

import android.net.Uri

data class Artist(
    val name: String,
    val songCount: Int,
    val albumCount: Int,
)

data class Album(
    val id: Long,
    val name: String,
    val artist: String,
    val songCount: Int,
    val totalDurationMs: Long,
    val coverUri: String?,
)

data class Playlist(
    val id: Long,
    val name: String,
    val songCount: Int,
    val coverUri: String?,
    val createdAt: Long,
    val updatedAt: Long,
)

data class PlayHistoryEntry(
    val songId: Long,
    val playedAt: Long,
    val completedMs: Long,
    val durationMs: Long,
)

fun Song.toAudioItem(): dev.vz.ljod.core.data.scanner.AudioItem =
    dev.vz.ljod.core.data.scanner.AudioItem(
        id = id,
        title = title,
        artist = artist,
        album = album,
        duration = duration,
        uri = Uri.parse(uri),
        dateAdded = dateAdded,
        albumId = albumId,
    )
