# Changelog

All notable changes to Ljod are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versions use
`MAJOR.MINOR.PATCH+BUILD` as they do in `pubspec.yaml`.

## [Unreleased]

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

### Fixed

- Cover art is downscaled on Android before it is cached, so the artwork
  directory no longer grows to gigabytes. Applies to embedded art, sidecar
  images and platform extraction alike; the full-size original is pruned after
  the 1024 px JPEG is written. Covers large enough to hit the old 4 MiB ceiling
  are now accepted and shrunk instead of being dropped, which is why so many
  tagged tracks had no artwork.
- A song row can no longer keep pointing at a cover file that no longer exists.
  Opening the app with such rows showed no artwork and logged a decode failure
  per track; rescans could not repair them either, because the upsert preserved
  the old path. Stored paths are now checked once at load and before every scan,
  the dead ones are forgotten, and a background scan re-extracts those covers
  without asking for permission.
- Extracted covers are no longer thrown away by the artwork cache. Trimming cut
  the directory back to a 192 MiB budget *including* covers the library pointed
  at, and every deleted path was then cleared in the database, so a scan could
  extract hundreds of covers and still leave most tracks with no art. Trimming
  now only removes files nothing references; a multi-megabyte artwork library is
  allowed to keep its covers. The diagnostics line counts only files that are
  actually on disk, so its number matches what the app shows.
- Artwork is visible everywhere, not just in the full-screen player. Every list,
  grid, rail, queue row and the mini player left `CoverArt.showArtwork` at its
  default of `false`, so a cached cover was replaced by the initials tile no
  matter how well the extraction worked. Decoding is capped to the painted size,
  so showing covers in lists does not reintroduce the scrolling stutter, and a
  cover that fails to decode now logs to Diagnostics instead of silently
  painting the fallback.
- Artwork no longer disappears for good. Writing a cover re-creates the cache
  directory when "Clear artwork cache" or "Clear library cache" deleted it
  (every write had been failing silently, so no cover could come back); a scan
  that cannot re-read tags no longer prunes covers the database still points at;
  and clearing the cache stores "no artwork" as null instead of an empty path,
  which the notification tried to decode as a directory.
- Artwork is found in far more libraries. Embedded pictures are read in the
  scan isolate and, on Android, through `MediaMetadataRetriever` from the
  content URI; when a track has no embedded picture the scan uses an image
  beside it (`cover`, `folder`, `front`, `album`, `artwork`, `thumb`, or the
  track's own name) in JPEG, PNG, WebP, GIF or BMP. The per-file ceiling rose
  from 2 to 4 MiB and oversized art is downscaled instead of dropped. The
  diagnostics line now reports how many covers each source produced, replacing
  a warning that claimed "no cover" before those fallbacks had run.
- The library no longer stays empty after the setup scan. A scan finishing while
  the provider was still reading the database was overwritten by that pre-scan
  (empty) read, and setup could start a second scan for a library it had just
  indexed; the newer state now wins and a populated library is never rescanned
  by setup. A scan that unexpectedly returns no tracks keeps the existing rows
  instead of deleting them.

### Changed

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

### Changed

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

### Changed

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

### Changed

- Library indexing moved to a batched background isolate with a SQLite cache that
  preserves favourites and play counts across rescans.
- Artwork cache bounded per file (2 MiB) and reported in Settings.
- Android package renamed to `dev.vz.ljod` throughout Gradle, manifest and Kotlin.

### Fixed

- Cached-storage figures refresh after a lyrics lookup instead of going stale.

## [0.1.0] — 2026-09-23

Initial scaffold: bundle metadata, theme shell and placeholder screens.

[Unreleased]: https://git.gay/Veridian-Zenith/ljod/compare/v0.4.0...HEAD
[0.4.0]: https://git.gay/Veridian-Zenith/ljod/releases/tag/v0.4.0
[0.3.2]: https://git.gay/Veridian-Zenith/ljod/releases/tag/v0.3.2
[0.3.1]: https://git.gay/Veridian-Zenith/ljod/releases/tag/v0.3.1
[0.3.0]: https://git.gay/Veridian-Zenith/ljod/releases/tag/v0.3.0
