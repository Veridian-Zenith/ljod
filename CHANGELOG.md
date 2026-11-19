# Changelog

All notable changes to Ljod are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versions use
`MAJOR.MINOR.PATCH+BUILD` as they do in `pubspec.yaml`.

## [Unreleased]

## [0.5.0] — 2026-11-19

### Fixed

- The `ClassNotFoundException: Didn't find class "Landroid/content/Context;"`
  crash is fixed. `path_provider_android` 2.3.1 asks `package:jni` for that
  class, whose bindings were generated without a `className`, so jni 1.2.0
  falls back to the type signature. Both are the latest releases, so Android
  directories are now answered by the app's own channel and registered as
  `PathProviderPlatform.instance`; `just_audio`'s asset cache and the artwork
  cache manager use the same paths, and nothing in the app touches that bridge
  any more.
- The library can no longer vanish behind a directory fault. The database path
  comes from the folder that already holds `ljod_library.db`, otherwise the
  first of the documents folder, sqflite's own databases folder and the support
  folder that resolves, so a regression in one plugin costs a path instead of
  the whole library, and a database that cannot be read is named in Diagnostics
  instead of looking like an empty library.
- Setup can no longer sit on "Building your library" for a library that is
  already indexed: replaying it reports the existing tracks, and **Try again**
  always starts a scan instead of being skipped because the old library was
  still present.
- Folder rules saved during setup are applied. The scan that should follow was
  skipped whenever the library was not empty, so new rules looked ignored.
- The last setup step reports what actually happened: a scan that finds nothing
  names the supported formats and offers folder rules plus a rescan, a failed
  scan says the library was left unchanged and offers a retry, and missing
  access offers app settings beside the permission request.
- Access granted from Android settings is picked up as soon as the app
  resumes, so the access step no longer waits for a second tap.
- Settings no longer keeps a "Scanning" row after a scan finishes, and the
  library's empty state no longer asks for access that was already granted.

### Added

- **Settings → Caches** re-runs one cache at a time. Artwork lookups and cached
  lyrics each have their own refresh — with the count they dropped written to
  Diagnostics — so a single bad answer no longer needs a full library rescan to
  clear it.

### Changed

- The Android toolchain is on its current releases: Gradle 9.9.1 (wrapper, both
  distribution checksums updated), AGP 9.5.1 on the new AGP DSL with the legacy
  opt-out removed. Kotlin stays 2.4.21 — the latest stable, since 2.5.0 is only
  a release candidate.
- Builds run on one predictable JVM: daemon JVM criteria pin Gradle to a JDK 21
  from Adoptium (so `JAVA_HOME` or Android Studio's bundled JBR no longer decide
  it), the Kotlin daemon is capped at 1 GiB instead of inheriting the Gradle
  heap, workers are capped at four, and a daemon idles out after ten minutes
  instead of three hours.
- Dependencies are on their current releases with no version pins — `jni`
  1.2.0, `material_ui` 1.11, `riverpod` 3.5, `sqflite` 2.4.6 and the rest — and
  `pubspec.yaml` carries no overrides.
- A library scan is one pass again. The rows it already holds produce the folder
  list that folder rules show, so opening folder rules no longer repeats the
  platform query over every file, and the table-wide cover-path UPDATE before
  each scan is gone (the upsert already writes that column).
- Scan logging reports the whole picture instead of a track count: one line with
  tracks, albums, artists, folders, total minutes and elapsed time, plus a
  warning for each missing file, unreadable tag, unreadable folder, pathless
  platform row and the desktop 5000-file ceiling.
- Setup lists artwork lookups alongside the optional lyrics lookup instead of
  promising that artwork stays on the device, and describes the scan as reading
  tags rather than tags and artwork.

## [0.4.0] — 2026-11-05

### Added

- A real shuffle engine: the queue is dealt with a Fisher–Yates shuffle that
  keeps the playing track first, instead of trusting `just_audio`'s private
  shuffle order. Up-next, the queue sheet and the notification now show the
  order that will actually play, in both shuffle states, and toggling shuffle
  off restores library order at the same position.
- **Play all** and **Shuffle** buttons in the library, acting on the current
  filter, album selection and sort.
- The last session is remembered across restarts: queue, track, position,
  shuffle and repeat come back paused, so the mini player and the full player
  resume where they were.

### Changed

- Cover art is no longer extracted or stored on the device. Each album's cover
  is looked up online (Deezer first, then iTunes; both need no key) and
  remembered as a URL, so the artwork directory that grew past a gigabyte is
  gone, covers appear on every screen that shows a track, and clearing them
  costs nothing. The old directory is deleted on the next scan.
- Playback holds a smaller, steadier working set: the decoded-cover cache is
  48 MiB instead of 96, each queue entry is one `MediaItem` instead of three,
  the saved session is no longer re-encoded every three seconds, and state
  broadcasts carry position at most once a second instead of five times.
  Diagnostics gains a per-track `memory:` line so long-session growth can be
  confirmed rather than guessed.
- Library rows no longer keep a stale cover path: the scan clears the legacy
  column, so nothing points at a deleted file even on a device that still has
  the old artwork directory.
- The library no longer stays empty after the setup scan. A scan finishing while
  the provider was still reading the database was overwritten by that pre-scan
  (empty) read, and setup could start a second scan for a library it had just
  indexed; the newer state now wins and a populated library is never rescanned
  by setup. A scan that unexpectedly returns no tracks keeps the existing rows
  instead of deleting them.

### Build

- Releases are built per ABI for `arm64-v8a` and `armeabi-v7a` with debug
  information split out, and no longer include x86_64: a download is a single-
  architecture file of roughly 20–26 MiB instead of one 70 MiB APK carrying
  three architectures, two of which the device cannot run. The rolling
  `debug` prerelease is built the same way, publishing
  `ljod-debug-arm64-v8a.apk` and `ljod-debug-armeabi-v7a.apk` in place of
  the single `ljod-debug.apk`.

## [0.3.2] — 2026-11-02

### Fixed

- Text no longer fails to lay out when the system reports an unusable font scale
  (`Unsupported operation: Infinity or NaN toInt` out of `scaleFontSize`), which
  left every affected screen unrendered with `RenderBox was not laid out` behind
  it: the scale is now sanitised once at the top of the app and falls back to no
  scaling.
- Lyrics follow the track they belong to: the sheet updates when the next song
  starts instead of holding the one it was opened with, and the active line is
  kept in view for lines the list has not built yet.
- A manual lyrics refresh forces a single lookup instead of every later rebuild,
  which had been re-fetching and re-flowing the lines mid-playback.
- LRCLIB `502`/`503` answers are retried once and no longer look like a
  permanent rate limit, and requests are paced so bursts stop causing them.
- Romanization works per script — Chinese through pinyin, Japanese kana through
  Hepburn, Korean, Russian, Thai and Vietnamese — and a line containing kana is
  treated as Japanese rather than run through pinyin.
- Embedded artwork is read through the platform bridge when MediaStore only
  exposes a content URI, so tracks whose files cannot be opened directly still
  get covers.

### Build

- The seek bar follows the theme's expressive slider instead of overriding it
  with a capsule thumb and a 5px track.
- The equaliser capsule over the album art in the full player is gone.
- Online lyrics lookup stays off by default: the setting had been read as
  missing and defaulted to on, while every document, the sheet and the setup
  step promised an opt-in. The toggle still turns it on.

## [0.3.1] — 2026-11-02

### Added

- CI workflow (`.github/workflows/ci.yml`) that runs formatting, `flutter analyze`,
  the test suite and a debug APK build on every push to `main`/`master` and on
  every pull request; the APK job is gated on the cheap checks.
- Release workflow publishes a Forgejo release on git.gay with the signed
  `ljod-<version>.apk` attached, replacing the asset when re-run.

### Build

- Release signing reads the keystore as base64 **content**
  (`ANDROID_KEYSTORE_BASE64`), decoded to a git-ignored path outside `build/`;
  the previous in-repository keystore path is no longer used anywhere.
- Gradle wrapper updated to 9.8.2 with pinned distribution checksums.
- CI and release workflows run on Forgejo Actions: the Flutter setup action is
  referenced by absolute URL (`https://github.com/subosito/flutter-action@v2`)
  because the instance's action mirror does not carry it, and the release step
  uses the Forgejo REST API because `gh` only speaks github.com.
- The GitHub-only CodeQL workflow is replaced by `.github/workflows/security.yml`:
  `flutter analyze --fatal-warnings --fatal-infos`, a check that no keystore or
  `key.properties` is ever tracked, and a weekly `flutter pub outdated` report.
- Dependabot configuration removed: Forgejo has no Dependabot, so dependency
  updates are manual (or a self-hosted Renovate against the same repo).

### Fixed

- Gradle now reports which signing path it tried when no keystore resolves,
  instead of only surfacing AGP's `Keystore file not set for signing config
  release`.
- Tag builds no longer finish with only a workflow artifact that expires.

## [0.3.0] — 2026-11-01

### Added

- Home, library, search, player and settings surfaces built on Material 3
  Expressive with a true-black palette and bundled JetBrains Mono.
- Lyrics: sidecar `.lrc`/`.txt`, embedded tags, and opt-in LRCLIB lookup with
  on-disk caching of positive *and* negative answers.
- Synced lyrics view with romanisation, plus a lyrics sheet with refresh.
- Listening insights: totals, favourites, most-played tracks and top artists.
- Diagnostics screen with a bounded on-device log, including native crash
  traces captured before process death.
- First-run setup flow and folder rules (`all` / `only` / `exclude`, recursive).
- Single source of truth for release identity (`lib/core/app_info.dart`), with a
  test that fails when it drifts from `pubspec.yaml`.

### Build

- Library indexing moved to a batched background isolate with a SQLite cache that
  preserves favourites and play counts across rescans.
- Artwork cache bounded per file (2 MiB) and reported in Settings.
- Android package renamed to `dev.vz.ljod` throughout Gradle, manifest and Kotlin.

### Fixed

- Cached-storage figures refresh after a lyrics lookup instead of going stale.

## [0.1.0] — 2026-09-23

Initial scaffold: bundle metadata, theme shell and placeholder screens.

[Unreleased]: https://git.gay/Veridian-Zenith/ljod/compare/v0.5.0...HEAD
[0.5.0]: https://git.gay/Veridian-Zenith/ljod/releases/tag/v0.5.0
[0.4.0]: https://git.gay/Veridian-Zenith/ljod/releases/tag/v0.4.0
[0.3.2]: https://git.gay/Veridian-Zenith/ljod/releases/tag/v0.3.2
[0.3.1]: https://git.gay/Veridian-Zenith/ljod/releases/tag/v0.3.1
[0.3.0]: https://git.gay/Veridian-Zenith/ljod/releases/tag/v0.3.0
