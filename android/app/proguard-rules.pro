# Add ProGuard rules here.
# By default, keep all serialization and public classes.

-keep class dev.vz.ljod.** { *; }
-dontwarn dev.vz.ljod.**

# Audio plugins are reached through the manifest and Flutter's plugin
# registrant; keep them safe under R8 full mode.
-keep class com.ryanheise.audioservice.** { *; }
-keep class com.ryanheise.just_audio.** { *; }
-dontwarn com.ryanheise.audioservice.**
-dontwarn com.ryanheise.just_audio.**
