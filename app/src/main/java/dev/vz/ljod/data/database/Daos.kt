package dev.vz.ljod.data.database

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import androidx.room.Transaction
import dev.vz.ljod.data.model.AlbumEntity
import dev.vz.ljod.data.model.ArtistEntity
import dev.vz.ljod.data.model.FavoriteEntity
import dev.vz.ljod.data.model.PlayCountEntity
import dev.vz.ljod.data.model.PlayHistoryEntity
import dev.vz.ljod.data.model.PlaylistEntity
import dev.vz.ljod.data.model.PlaylistEntry
import dev.vz.ljod.data.model.Song
import kotlinx.coroutines.flow.Flow

@Dao
interface MusicDao {
    @Query("SELECT * FROM songs ORDER BY title COLLATE NOCASE ASC")
    fun observeAll(): Flow<List<Song>>

    @Query("SELECT * FROM songs ORDER BY date_added DESC LIMIT :limit")
    fun observeRecentlyAdded(limit: Int = 50): Flow<List<Song>>

    @Query("SELECT * FROM songs WHERE id = :id")
    suspend fun getById(id: Long): Song?

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsertAll(songs: List<Song>)

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsertSong(song: Song)

    @Query("DELETE FROM songs")
    suspend fun deleteAll()

    @Query("DELETE FROM songs WHERE id NOT IN (:keepIds)")
    suspend fun deleteMissing(keepIds: List<Long>)

    @Query("SELECT COUNT(*) FROM songs")
    suspend fun count(): Int

    @Query(
        "SELECT * FROM songs WHERE LOWER(title) LIKE '%' || LOWER(:q) || '%' OR LOWER(artist) LIKE '%' || LOWER(:q) || '%' OR LOWER(album) LIKE '%' || LOWER(:q) || '%' ORDER BY title ASC",
    )
    suspend fun search(q: String): List<Song>
}

@Dao
interface AlbumDao {
    @Query("SELECT * FROM albums ORDER BY name COLLATE NOCASE ASC")
    fun observeAll(): Flow<List<AlbumEntity>>

    @Query("SELECT * FROM albums WHERE id = :id")
    suspend fun getById(id: Long): AlbumEntity?

    @Query("SELECT * FROM songs WHERE album_id = :albumId ORDER BY track_number ASC, title ASC")
    suspend fun songsForAlbum(albumId: Long): List<Song>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsertAll(albums: List<AlbumEntity>)

    @Query("DELETE FROM albums")
    suspend fun deleteAll()

    @Query("DELETE FROM albums WHERE id NOT IN (:keepIds)")
    suspend fun deleteMissing(keepIds: List<Long>)
}

@Dao
interface ArtistDao {
    @Query("SELECT * FROM artists ORDER BY name COLLATE NOCASE ASC")
    fun observeAll(): Flow<List<ArtistEntity>>

    @Query("SELECT * FROM songs WHERE LOWER(artist) = LOWER(:name) ORDER BY title ASC")
    suspend fun songsForArtist(name: String): List<Song>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsertAll(artists: List<ArtistEntity>)

    @Query("DELETE FROM artists")
    suspend fun deleteAll()
}

@Dao
interface FavoriteDao {
    @Query("SELECT s.* FROM songs s INNER JOIN favorites f ON s.id = f.song_id ORDER BY f.added_at DESC")
    fun observeFavorites(): Flow<List<Song>>

    @Query("SELECT song_id FROM favorites")
    fun observeFavoriteIds(): Flow<List<Long>>

    @Query("SELECT EXISTS(SELECT 1 FROM favorites WHERE song_id = :songId)")
    suspend fun isFavorite(songId: Long): Boolean

    @Query("SELECT EXISTS(SELECT 1 FROM favorites WHERE song_id = :songId)")
    fun observeIsFavorite(songId: Long): Flow<Boolean>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun add(favorite: FavoriteEntity)

    @Query("DELETE FROM favorites WHERE song_id = :songId")
    suspend fun remove(songId: Long)

    @Transaction
    suspend fun toggle(songId: Long) {
        if (isFavorite(songId)) {
            remove(songId)
        } else {
            add(FavoriteEntity(songId, System.currentTimeMillis()))
        }
    }
}

@Suppress("TooManyFunctions")
@Dao
interface PlaylistDao {
    @Query("SELECT * FROM playlists ORDER BY updated_at DESC")
    fun observeAll(): Flow<List<PlaylistEntity>>

    @Query("SELECT * FROM playlists WHERE id = :id")
    suspend fun getById(id: Long): PlaylistEntity?

    @Query("SELECT COUNT(*) FROM playlist_entries WHERE playlist_id = :playlistId")
    suspend fun songCount(playlistId: Long): Int

    @Query(
        "SELECT s.* FROM songs s INNER JOIN playlist_entries pe ON s.id = pe.song_id WHERE pe.playlist_id = :playlistId ORDER BY pe.position ASC",
    )
    fun observeSongs(playlistId: Long): Flow<List<Song>>

    @Query(
        "SELECT s.* FROM songs s INNER JOIN playlist_entries pe ON s.id = pe.song_id WHERE pe.playlist_id = :playlistId ORDER BY pe.position ASC",
    )
    suspend fun songsOnce(playlistId: Long): List<Song>

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun insert(playlist: PlaylistEntity): Long

    @Query("UPDATE playlists SET name = :name, updated_at = :now WHERE id = :id")
    suspend fun rename(
        id: Long,
        name: String,
        now: Long,
    )

    @Query("DELETE FROM playlists WHERE id = :id")
    suspend fun delete(id: Long)

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun addEntry(entry: PlaylistEntry)

    @Query("DELETE FROM playlist_entries WHERE playlist_id = :playlistId AND song_id = :songId")
    suspend fun removeEntry(
        playlistId: Long,
        songId: Long,
    )

    @Query("DELETE FROM playlist_entries WHERE playlist_id = :playlistId")
    suspend fun clearEntries(playlistId: Long)

    @Query("SELECT COALESCE(MAX(position), -1) FROM playlist_entries WHERE playlist_id = :playlistId")
    suspend fun maxPosition(playlistId: Long): Int
}

@Dao
interface HistoryDao {
    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun addHistory(entry: PlayHistoryEntity)

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsertCount(count: PlayCountEntity)

    @Query("SELECT * FROM play_history ORDER BY played_at DESC LIMIT :limit")
    fun observeRecent(limit: Int = 100): Flow<List<PlayHistoryEntity>>

    @Query("SELECT * FROM play_counts ORDER BY last_played_at DESC LIMIT :limit")
    fun observeMostPlayed(limit: Int = 50): Flow<List<PlayCountEntity>>

    @Query("SELECT count FROM play_counts WHERE song_id = :songId")
    suspend fun getCount(songId: Long): Int?

    @Query("DELETE FROM play_history WHERE played_at < :olderThan")
    suspend fun prune(olderThan: Long)
}
