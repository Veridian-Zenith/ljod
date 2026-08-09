package dev.vz.ljod.di

import android.content.Context
import dagger.Module
import dagger.Provides
import dagger.hilt.InstallIn
import dagger.hilt.android.qualifiers.ApplicationContext
import dagger.hilt.components.SingletonComponent
import dev.vz.ljod.core.data.scanner.MediaScanner
import dev.vz.ljod.data.lyrics.LyricsRepository
import dev.vz.ljod.data.settings.SettingsRepository
import dev.vz.ljod.playback.PlaybackController
import dev.vz.ljod.playback.PlaybackService
import javax.inject.Singleton

@Module
@InstallIn(SingletonComponent::class)
object AppModule {

    @Provides
    @Singleton
    fun provideMediaScanner(@ApplicationContext context: Context): MediaScanner = MediaScanner(context)

    @Provides
    @Singleton
    fun providePlaybackController(@ApplicationContext context: Context): PlaybackController =
        PlaybackController(context, PlaybackService::class.java)

    @Provides
    @Singleton
    fun provideSettingsRepository(@ApplicationContext context: Context): SettingsRepository =
        SettingsRepository(context)

    @Provides
    @Singleton
    fun provideLyricsRepository(
        @ApplicationContext context: Context,
        settings: SettingsRepository,
    ): LyricsRepository = LyricsRepository(context, settings)
}
