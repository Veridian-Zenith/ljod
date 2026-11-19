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

# package:jni backs path_provider and shared_preferences with FFI + JNI, and its
# bridge classes are found by name at runtime. Its AAR ships consumer rules, but
# they are the only thing keeping them in a minified build; keep them here too
# so a future release without those rules fails loudly in review rather than in
# a release APK with a ClassNotFoundException.
-keep class com.github.dart_lang.jni.** { *; }
-keep class com.github.dart_lang.jni_flutter.** { *; }
-dontwarn com.github.dart_lang.**
