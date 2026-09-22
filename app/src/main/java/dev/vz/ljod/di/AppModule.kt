package dev.vz.ljod.di

import android.content.Context
import dagger.Module
import dagger.Provides
import dagger.hilt.InstallIn
import dagger.hilt.android.qualifiers.ApplicationContext
import dagger.hilt.components.SingletonComponent
import dev.vz.ljod.core.data.scanner.MediaScanner
import javax.inject.Singleton

@Module
@InstallIn(SingletonComponent::class)
object AppModule {
    @Provides
    @Singleton
    fun provideMediaScanner(
        @ApplicationContext context: Context,
    ): MediaScanner = MediaScanner(context)
}
