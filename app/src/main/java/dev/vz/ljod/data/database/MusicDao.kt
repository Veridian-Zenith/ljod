package dev.vz.ljod.data.database

import androidx.room.Dao
import androidx.room.Insert
import androidx.room.OnConflictStrategy
import androidx.room.Query
import dev.vz.ljod.data.model.Song
import kotlinx.coroutines.flow.Flow

@Dao
interface MusicDao {
    @Query("SELECT * FROM songs ORDER BY title ASC")
    fun getAll(): Flow<List<Song>>

    @Query("SELECT * FROM songs WHERE id = :id")
    suspend fun getById(id: Long): Song?

    @Insert(onConflict = OnConflictStrategy.REPLACE)
    suspend fun upsertAll(songs: List<Song>)

    @Query("DELETE FROM songs")
    suspend fun deleteAll()
}
