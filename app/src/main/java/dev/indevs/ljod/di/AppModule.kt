package dev.indevs.ljod.di

import android.content.Context
import dagger.Module
import dagger.Provides
import dagger.hilt.InstallIn
import dagger.hilt.android.qualifiers.ApplicationContext
import dagger.hilt.components.SingletonComponent
import dev.indevs.ljod.playback.PlaybackConnection
import javax.inject.Singleton

@Module
@InstallIn(SingletonComponent::class)
object AppModule {

    @Provides
    @Singleton
    fun providePlaybackConnection(
        @ApplicationContext context: Context
    ): PlaybackConnection {
        return PlaybackConnection(context)
    }
}
