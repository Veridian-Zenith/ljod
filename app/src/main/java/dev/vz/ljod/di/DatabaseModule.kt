package dev.vz.ljod.di

import android.content.Context
import androidx.room.Room
import dagger.Module
import dagger.Provides
import dagger.hilt.InstallIn
import dagger.hilt.android.qualifiers.ApplicationContext
import dagger.hilt.components.SingletonComponent
import dev.vz.ljod.data.database.LjodDatabase
import dev.vz.ljod.data.database.MusicDao
import javax.inject.Singleton

@Module
@InstallIn(SingletonComponent::class)
object DatabaseModule {

    @Provides
    @Singleton
    fun provideDatabase(@ApplicationContext context: Context): LjodDatabase =
        Room.databaseBuilder(context, LjodDatabase::class.java, "ljod.db")
            .fallbackToDestructiveMigration()
            .build()

    @Provides
    fun provideMusicDao(db: LjodDatabase): MusicDao = db.musicDao()
}
