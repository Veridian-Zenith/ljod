package dev.vz.ljod.di

import android.content.Context
import androidx.room.Room
import dagger.Module
import dagger.Provides
import dagger.hilt.InstallIn
import dagger.hilt.android.qualifiers.ApplicationContext
import dagger.hilt.components.SingletonComponent
import dev.vz.ljod.data.database.AlbumDao
import dev.vz.ljod.data.database.ArtistDao
import dev.vz.ljod.data.database.FavoriteDao
import dev.vz.ljod.data.database.HistoryDao
import dev.vz.ljod.data.database.LjodDatabase
import dev.vz.ljod.data.database.MusicDao
import dev.vz.ljod.data.database.PlaylistDao
import javax.inject.Singleton

@Module
@InstallIn(SingletonComponent::class)
object DatabaseModule {
    @Provides
    @Singleton
    fun provideDatabase(
        @ApplicationContext context: Context,
    ): LjodDatabase =
        Room
            .databaseBuilder(context, LjodDatabase::class.java, "ljod.db")
            .fallbackToDestructiveMigration()
            .build()

    @Provides fun provideMusicDao(db: LjodDatabase): MusicDao = db.musicDao()

    @Provides fun provideAlbumDao(db: LjodDatabase): AlbumDao = db.albumDao()

    @Provides fun provideArtistDao(db: LjodDatabase): ArtistDao = db.artistDao()

    @Provides fun provideFavoriteDao(db: LjodDatabase): FavoriteDao = db.favoriteDao()

    @Provides fun providePlaylistDao(db: LjodDatabase): PlaylistDao = db.playlistDao()

    @Provides fun provideHistoryDao(db: LjodDatabase): HistoryDao = db.historyDao()
}
