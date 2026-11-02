# Changelog

All notable changes to Ljod are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and versions use
`MAJOR.MINOR.PATCH+BUILD` as they do in `pubspec.yaml`.

## [Unreleased]

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

[Unreleased]: https://git.gay/Veridian-Zenith/ljod/compare/v0.3.0...HEAD
[0.3.0]: https://git.gay/Veridian-Zenith/ljod/releases/tag/v0.3.0
