package dev.vz.ljod.data.database

import androidx.room.Database
import androidx.room.RoomDatabase
import dev.vz.ljod.data.model.AlbumEntity
import dev.vz.ljod.data.model.ArtistEntity
import dev.vz.ljod.data.model.FavoriteEntity
import dev.vz.ljod.data.model.PlayCountEntity
import dev.vz.ljod.data.model.PlayHistoryEntity
import dev.vz.ljod.data.model.PlaylistEntity
import dev.vz.ljod.data.model.PlaylistEntry
import dev.vz.ljod.data.model.Song

@Database(
    entities = [
        Song::class,
        AlbumEntity::class,
        ArtistEntity::class,
        FavoriteEntity::class,
        PlaylistEntity::class,
        PlaylistEntry::class,
        PlayHistoryEntity::class,
        PlayCountEntity::class,
    ],
    version = 2,
    exportSchema = false,
)
abstract class LjodDatabase : RoomDatabase() {
    abstract fun musicDao(): MusicDao

    abstract fun albumDao(): AlbumDao

    abstract fun artistDao(): ArtistDao

    abstract fun favoriteDao(): FavoriteDao

    abstract fun playlistDao(): PlaylistDao

    abstract fun historyDao(): HistoryDao
}
