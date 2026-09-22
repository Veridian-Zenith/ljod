package dev.vz.ljod.data.model

import androidx.room.ColumnInfo
import androidx.room.Entity
import androidx.room.ForeignKey
import androidx.room.Index
import androidx.room.PrimaryKey

@Entity(tableName = "songs")
data class Song(
    @PrimaryKey val id: Long,
    val title: String,
    val artist: String,
    val album: String,
    val duration: Long,
    val uri: String,
    @ColumnInfo(name = "date_added") val dateAdded: Long,
    @ColumnInfo(name = "album_id") val albumId: Long?,
    @ColumnInfo(name = "track_number") val trackNumber: Int? = null,
    @ColumnInfo(name = "year") val year: Int? = null,
    @ColumnInfo(name = "genre") val genre: String? = null,
    @ColumnInfo(name = "mime_type") val mimeType: String? = null,
    @ColumnInfo(name = "size_bytes") val sizeBytes: Long? = null,
)

@Entity(
    tableName = "albums",
    foreignKeys = [],
    indices = [Index(value = ["name", "artist"], unique = true)],
)
data class AlbumEntity(
    @PrimaryKey val id: Long,
    val name: String,
    val artist: String,
    @ColumnInfo(name = "song_count") val songCount: Int,
    @ColumnInfo(name = "total_duration_ms") val totalDurationMs: Long,
    @ColumnInfo(name = "cover_uri") val coverUri: String?,
)

@Entity(
    tableName = "artists",
    indices = [Index(value = ["name"], unique = true)],
)
data class ArtistEntity(
    @PrimaryKey(autoGenerate = true) val id: Long = 0,
    val name: String,
    @ColumnInfo(name = "song_count") val songCount: Int,
    @ColumnInfo(name = "album_count") val albumCount: Int,
)

@Entity(tableName = "favorites")
data class FavoriteEntity(
    @PrimaryKey @ColumnInfo(name = "song_id") val songId: Long,
    @ColumnInfo(name = "added_at") val addedAt: Long,
)

@Entity(
    tableName = "playlists",
    indices = [Index(value = ["name"], unique = true)],
)
data class PlaylistEntity(
    @PrimaryKey(autoGenerate = true) val id: Long = 0,
    val name: String,
    @ColumnInfo(name = "created_at") val createdAt: Long,
    @ColumnInfo(name = "updated_at") val updatedAt: Long,
    @ColumnInfo(name = "cover_uri") val coverUri: String? = null,
)

@Entity(
    tableName = "playlist_entries",
    primaryKeys = ["playlist_id", "song_id"],
    foreignKeys = [
        ForeignKey(
            entity = PlaylistEntity::class,
            parentColumns = ["id"],
            childColumns = ["playlist_id"],
            onDelete = ForeignKey.CASCADE,
        ),
        ForeignKey(
            entity = Song::class,
            parentColumns = ["id"],
            childColumns = ["song_id"],
            onDelete = ForeignKey.CASCADE,
        ),
    ],
    indices = [Index("playlist_id"), Index("song_id")],
)
data class PlaylistEntry(
    @ColumnInfo(name = "playlist_id") val playlistId: Long,
    @ColumnInfo(name = "song_id") val songId: Long,
    val position: Int,
    @ColumnInfo(name = "added_at") val addedAt: Long,
)

@Entity(tableName = "play_history")
data class PlayHistoryEntity(
    @PrimaryKey(autoGenerate = true) val id: Long = 0,
    @ColumnInfo(name = "song_id") val songId: Long,
    @ColumnInfo(name = "played_at") val playedAt: Long,
    @ColumnInfo(name = "completed_ms") val completedMs: Long,
    @ColumnInfo(name = "duration_ms") val durationMs: Long,
)

@Entity(tableName = "play_counts")
data class PlayCountEntity(
    @PrimaryKey @ColumnInfo(name = "song_id") val songId: Long,
    val count: Int,
    @ColumnInfo(name = "last_played_at") val lastPlayedAt: Long,
)
