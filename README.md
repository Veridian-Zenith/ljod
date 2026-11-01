# Ljod

A local-first audio player forged by Veridian Zenith. Ljod reads the music
already on your device, keeps metadata offline, and pairs an amber-on-black
blueprint aesthetic with Material 3 Expressive geometry.

## Features

- MediaStore-backed Android library scan (desktop folders as a dev fallback)
- Embedded tag + cover-art extraction, cached artwork, SQLite library cache
- Background playback and media notification via `just_audio` + `audio_service`
- Queue, shuffle, repeat, favourites, play history
- Synced and plain lyrics: sidecar `.lrc`, embedded tags, and an opt-in
  (off by default) LRCLIB lookup
- True-black OLED surfaces, with only motion, lyrics lookup and
  favourites-first sorting exposed as persistent settings

## Privacy

Everything stays on the device: the library lives in a local SQLite file, and
artwork and lyric caches sit in the app support directory. There is no account,
no analytics, no crash reporting and no ads. The only outbound request is the
LRCLIB lyrics lookup, which is **off by default** and, when enabled, sends just
the track title, artist, album (if set) and duration — never audio or file
paths. Each track is looked up **once**: the answer (including "no lyrics" and
"instrumental") is cached on disk, and nothing is re-requested unless you
refresh it from the lyrics sheet or clear the cache in Settings.

## Stack

- Flutter 3.47+ / Dart 3.13+
- `material_ui` 1.9 (`StyleVariant.material3Expressive`)
- Riverpod 3, `just_audio`, `audio_service`, `sqflite`, `shared_preferences`
- Bundled JetBrains Mono (no runtime font downloads)

## Android

The app targets Android 15+ (`minSdk 35`). `MainActivity` extends
`AudioServiceFragmentActivity` and exposes the `dev.vz.ljod/media` method
channel used to query MediaStore.

```sh
flutter pub get
flutter run          # device build/install
flutter analyze
flutter test
```

Gradle wrapper/AGP/Kotlin versions live under `android/`; builds are run from
your normal Flutter tooling.

## Signing

**The keystore is never committed, and nothing in the repository references a
keystore path.** Release signing takes the key as *content* and the build works
it out from there:

| Input | Used for |
| --- | --- |
| `ANDROID_KEYSTORE_BASE64` | The keystore itself, base64 encoded. CI passes this from a repository secret. |
| `ANDROID_KEYSTORE_PATH` | Optional absolute path to a key kept outside this repository, for local release builds. |
| `ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`, `ANDROID_KEY_PASSWORD` | Credentials; read from the environment first, then `local.properties`. |

When `ANDROID_KEYSTORE_BASE64` is present Gradle decodes it into
`android/.gradle-signing/ljod-upload.p12` (git-ignored, outside `build/` so a
`clean` cannot delete it mid-build) and signs from there. With no key
configured the build still configures, prints that no signing key was found,
and a release build fails rather than shipping unsigned.

### Releasing

1. Bump `version:` in `pubspec.yaml` **and** `LjodAppInfo` in
   `lib/core/app_info.dart`. `test/app_info_test.dart` fails if they disagree.
2. Commit, then push a tag matching the version name: `git tag v0.3.0 && git push origin v0.3.0`.
3. `.github/workflows/release.yml` checks the tag against the pubspec, builds
   and signs the APK from `ANDROID_KEYSTORE_BASE64`, verifies the signature
   with `apksigner`, deletes the decoded key, and uploads the APK.

The repository secrets expected by the workflow are `ANDROID_KEYSTORE_BASE64`,
`ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS` and `ANDROID_KEY_PASSWORD`.
Rotate them with `gh secret set <NAME> --repo Veridian-Zenith/ljod`, piping the
value in rather than passing it as an argument.

To sign a release locally, keep the key outside the checkout and point the
git-ignored `local.properties` at it, so `flutter build apk --release` needs no
extra environment:

```properties
ANDROID_KEYSTORE_PATH=/home/you/.config/ljod/ljod-upload.p12
ANDROID_KEYSTORE_PASSWORD=...
ANDROID_KEY_ALIAS=...
ANDROID_KEY_PASSWORD=...
```

Or pass the same values for one build:

```sh
ANDROID_KEYSTORE_PATH=/absolute/path/to/outside/key.p12 \
ANDROID_KEYSTORE_PASSWORD=... ANDROID_KEY_ALIAS=... ANDROID_KEY_PASSWORD=... \
flutter build apk --release
```

A relative path is resolved from `android/` and then from the repository root.
If the configured path does not resolve to a file, Gradle prints which path it
tried (`Ljod: no signing key. ANDROID_KEYSTORE_PATH='…' does not point at an
existing file.`) instead of only AGP's `Keystore file not set for signing config
release`.
