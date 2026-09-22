package dev.vz.ljod

import android.app.Application
import coil3.ImageLoader
import coil3.PlatformContext
import coil3.SingletonImageLoader
import coil3.disk.DiskCache
import coil3.memory.MemoryCache
import coil3.request.CachePolicy
import coil3.request.crossfade
import androidx.hilt.work.HiltWorkerFactory
import dagger.hilt.android.HiltAndroidApp
import javax.inject.Inject
import dev.vz.ljod.data.security.SecureStore
import okio.Path.Companion.toOkioPath
import timber.log.Timber

@HiltAndroidApp
class LjodApp : Application(), SingletonImageLoader.Factory, androidx.work.Configuration.Provider {
    @Inject lateinit var workerFactory: HiltWorkerFactory

    override val workManagerConfiguration: androidx.work.Configuration
        get() = androidx.work.Configuration.Builder()
            .setWorkerFactory(workerFactory)
            .setMinimumLoggingLevel(if (BuildConfig.DEBUG) android.util.Log.DEBUG else android.util.Log.INFO)
            .build()

    override fun newImageLoader(context: PlatformContext): ImageLoader {
        val diskCache = DiskCache.Builder()
            .directory(context.cacheDir.resolve("image_cache").toOkioPath())
            .maxSizeBytes(64L * 1024 * 1024)
            .build()
        val memoryCache = MemoryCache.Builder()
            .maxSizePercent(context, 0.25)
            .build()
        return ImageLoader.Builder(context)
            .memoryCache(memoryCache)
            .diskCache(diskCache)
            .diskCachePolicy(CachePolicy.ENABLED)
            .memoryCachePolicy(CachePolicy.ENABLED)
            .networkCachePolicy(CachePolicy.ENABLED)
            .crossfade(180)
            .build()
    }

    override fun onCreate() {
        super.onCreate()
        if (BuildConfig.DEBUG) Timber.plant(Timber.DebugTree())
        SecureStore.init(this)
        SecureStore.rotateSessionToken()
    }
}
