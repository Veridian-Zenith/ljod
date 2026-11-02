# Building and running

## Requirements

| Tool | Version | Notes |
| --- | --- | --- |
| Flutter | 3.47.9 (stable) | CI pins this exact version |
| Dart | 3.13+ | shipped with Flutter 3.47 |
| JDK | 21 | Gradle, AGP and Kotlin all target 21 |
| Android SDK | platform 37 | `compileSdk`/`targetSdk` 37, `minSdk` 35 |
| Gradle | 9.8.2 | provided by the wrapper in `android/` |

A physical or emulated device running Android 15 (API 35) or newer is required;
the library scan relies on `MediaStore` and scoped storage.

## First run

```sh
flutter --version          # expect 3.47.9
flutter pub get
flutter run                # builds, installs and launches on a device
```

`flutter run` generates `android/local.properties` (SDK locations) on demand —
do not create it by hand and never commit it.

## Checks

```sh
flutter analyze                                   # no issues expected
flutter test                                      # full suite, ~40 cases
dart format --output=none --set-exit-if-changed lib test
```

These three, plus a debug APK build, are what CI runs on Forgejo Actions (git.gay)
for every push to `main` or `master` and every pull request
(`.github/workflows/ci.yml`).

## Android builds

```sh
flutter build apk --debug        # build/app/outputs/flutter-apk/app-debug.apk
flutter build apk --release      # needs signing material, see docs/RELEASING.md
```

Debug builds sign with the generated debug keystore, so they need no secrets.

### Gradle

The real wrapper lives in `android/`:

```sh
cd android
./gradlew :app:compileDebugKotlin
./gradlew :app:lintDebug
./gradlew :app:signingReport      # prints the resolved release signing config
```

The `gradlew` at the repository root has no wrapper JAR, so invoking it fails
with `Could not find or load main class org.gradle.wrapper.GradleWrapperMain`.
Use `android/gradlew` (or Flutter, which does exactly that).

## The two `local.properties` files

Both are git-ignored, and they do different jobs:

| File | Written by | Contains |
| --- | --- | --- |
| `android/local.properties` | Flutter tooling | `flutter.sdk`, `sdk.dir` — required by `android/settings.gradle.kts` |
| `local.properties` (repo root) | you | release signing credentials, read by `android/app/build.gradle.kts` |

Only the root one is optional, and only for release builds.

## Versioning

The version lives in exactly two places, and a test keeps them honest:

1. `pubspec.yaml` → `version: 0.3.0+3`
2. `lib/core/app_info.dart` → `LjodAppInfo.version`, `versionName`, `buildNumber`

`test/app_info_test.dart` fails if they disagree, or if the derived tag is not
`v<versionName>`. Android's `versionCode`/`versionName` come from the pubspec via
the Flutter Gradle plugin, so nothing Kotlin-side needs editing on a bump.

## Troubleshooting

See [TROUBLESHOOTING.md](TROUBLESHOOTING.md) for build failures, signing errors
and device-side problems.
