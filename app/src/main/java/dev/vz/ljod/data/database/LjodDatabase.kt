package dev.vz.ljod.data.database

import androidx.room.Database
import androidx.room.RoomDatabase
import dev.vz.ljod.data.model.Song

@Database(entities = [Song::class], version = 1, exportSchema = false)
abstract class LjodDatabase : RoomDatabase() {
    abstract fun musicDao(): MusicDao
}
