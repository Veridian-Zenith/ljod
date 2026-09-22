# ProGuard / R8 rules for Ljod

# Strip logging in release
-assumenosideeffects class android.util.Log {
    public static int v(...);
    public static int d(...);
    public static int i(...);
}

# Kotlinx Serialization
-keepattributes *Annotation*, InnerClasses
-dontnote kotlinx.serialization.AnnotationsKt
-keepclassmembers class kotlinx.serialization.json.** {
    *** Companion;
}
-keepclasseswithmembers class kotlinx.serialization.json.** {
    kotlinx.serialization.KSerializer serializer(...);
}
-keep,includedescriptorclasses class dev.vz.ljod.**$$serializer { *; }
-keepclassmembers class dev.vz.ljod.** {
    *** Companion;
}
-keepclasseswithmembers class dev.vz.ljod.** {
    kotlinx.serialization.KSerializer serializer(...);
}

# Room
-keep class * extends androidx.room.RoomDatabase
-dontwarn androidx.room.paging.**

# Media3
-keep class androidx.media3.** { *; }
-dontwarn androidx.media3.**

# Hilt
-keep class dagger.hilt.** { *; }
-keep class * extends dagger.hilt.android.internal.managers.* { *; }
-keep,allowobfuscation @interface dagger.hilt.android.lifecycle.HiltViewModel

# Coil
-keep class coil3.** { *; }
-dontwarn coil3.**

# Retrofit / OkHttp
-keepattributes Signature, Exceptions
-keep class retrofit2.** { *; }
-keepclasseswithmembers class * {
    @retrofit2.http.* <methods>;
}
-keep class okhttp3.** { *; }
-keep class okio.** { *; }

# Compose
-keep class androidx.compose.** { *; }
-dontwarn androidx.compose.**

# Glance
-keep class androidx.glance.** { *; }
-dontwarn androidx.glance.**

# Domain models — for serialization
-keep class dev.vz.ljod.data.model.** { *; }
-keep class dev.vz.ljod.core.data.scanner.** { *; }
-keep class dev.vz.ljod.data.lyrics.** { *; }

# Hilt-generated code
-keep class hilt_aggregated_deps.** { *; }
-keep class dagger.hilt.internal.aggregatedroot.codegen.** { *; }
-keep class dagger.hilt.android.internal.lifecycle.HiltViewModelFactory$* { *; }

# Services — required for MediaSessionService discovery
-keep class dev.vz.ljod.playback.PlaybackService { *; }
-keep class dev.vz.ljod.widget.LjodWidgetReceiver { *; }

# WorkManager
-keep class androidx.work.impl.background.systemjob.SystemJobService
-keep class * extends androidx.work.Worker
-keep class * extends androidx.work.ListenableWorker
-keep class * extends androidx.work.CoroutineWorker

# Keep ViewModels for Hilt
-keep class * extends androidx.lifecycle.ViewModel { *; }
