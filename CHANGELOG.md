# Changelog

All notable changes to Ljod are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versions use
`MAJOR.MINOR.PATCH+BUILD` as they do in `pubspec.yaml`.

## [Unreleased]

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
- Online lyrics lookup is on by default; the Settings toggle still turns it off.

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

[Unreleased]: https://git.gay/Veridian-Zenith/ljod/compare/v0.3.1...HEAD
[0.3.1]: https://git.gay/Veridian-Zenith/ljod/releases/tag/v0.3.1
[0.3.0]: https://git.gay/Veridian-Zenith/ljod/releases/tag/v0.3.0
