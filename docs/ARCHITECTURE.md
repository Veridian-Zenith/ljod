# Architecture

Ljod is a local-first Flutter app. Everything that matters — the library index,
artwork, lyrics, play history — lives on the device; the only outbound request
is an opt-in lyrics lookup.

## Layers

```
lib/
├── main.dart                 app bootstrap: diagnostics, audio session, theme
├── core/                     shared, feature-agnostic
│   ├── app_info.dart          release identity (version, tag, package id)
│   ├── database/              sqflite library cache
│   ├── diagnostics/           bounded on-device log
│   ├── models/                SongModel, FolderScope
│   ├── theme/                 true-black Material 3 Expressive theme
│   ├── utils/                 formatters (duration, counts)
│   └── widgets/               reusable VZ components, logo
├── services/                  state + platform work
│   ├── audio/                 just_audio + audio_service handler
│   ├── library/               scan, artwork cache, providers
│   ├── lyrics/                sidecar/embedded/LRCLIB resolution + cache
│   ├── settings/              persisted preferences
│   └── stats/                 derived listening statistics
└── features/                  screens, one folder per surface
    ├── setup/                 first-run flow
    ├── shell/                 navigation + mini player
    ├── home/  search/  library/  player/  settings/  stats/
```

The dependency direction is one-way: `features` → `services` → `core`. Nothing in
`core` imports a screen, and no service reaches into a widget.

## State

Riverpod 3 provides both state and dependency injection. Two providers are
overridden at startup in `main()`:

| Provider | Value |
| --- | --- |
| `sharedPreferencesProvider` | resolved `SharedPreferences` instance |
| `audioHandlerProvider` | the `audio_service` handler (or an in-process fallback) |

Everything else derives from those, so tests can override either without
touching the platform. Settings are a `Notifier` backed by `SharedPreferences`;
library and lyrics state are `AsyncNotifier`s built on the services below.

## Startup order

1. `WidgetsFlutterBinding.ensureInitialized()`, and the image cache is capped
   (120 entries / 96 MiB) so large embedded covers cannot exhaust memory.
2. `DiagnosticsLog.initialize()` and `installDiagnosticsHandlers()` run before
   any UI, so early failures are recorded.
3. `SharedPreferences` is loaded and the audio session configured — but **not**
   activated, because `just_audio` takes audio focus when playback starts, and
   doing it at launch would interrupt whatever the user is already playing.
4. `AudioService.init()` builds `LjodAudioHandler`. If the native plugin is
   unavailable (desktop run, unit test) an in-process handler is used instead of
   crashing.
5. `runApp` shows the setup flow on first launch, otherwise the shell.

## Library pipeline

```
MediaStore (Android)  ──┐
desktop folders       ──┴─▶ raw tracks ─▶ FolderScope filter ─▶ isolate enrich ─▶ SQLite upsert
                                                                 (tags, artwork)
```

* **Source.** On Android a thin `MethodChannel('dev.vz.ljod/media')` bridge
  queries `MediaStore.Audio`; on desktop the service walks conventional music
  folders. `permission_handler` gates the Android scan (`LibraryPermissionException`
  when audio access is denied).
* **Filtering.** `FolderScope` applies `all` / `only` / `exclude` rules
  recursively — selecting `/Music/Rock` also covers `/Music/Rock/Live`.
  `content://` paths expose no folder, so those tracks are always kept.
* **Enrichment.** Tag and cover extraction runs in a background isolate
  (`compute`) in batches, and only the current batch's known-artwork map crosses
  the isolate boundary.
* **Persistence.** `upsertSongs` writes metadata only; `isFavorite`,
  `playCount` and `lastPlayedMs` are deliberately excluded from the update so a
  rescan never erases listening state.

### Database

`ljod_library.db` in the application documents directory, schema version 3:

| Table | Purpose |
| --- | --- |
| `songs` | library cache: id, path, title, artist, album, albumArtist, durationMs, trackNumber, artworkPath, isFavorite, playCount, lastPlayedMs, addedAtMs |
| `playlists` | id, name, createdAt |
| `playlist_songs` | playlistId, songId, position |

Indexes exist on `title`, `artist` and `album`. The library is a rebuildable
cache, so a schema bump drops and recreates the tables rather than migrating.

### Artwork

Covers are written to `<app support>/artwork`, one file per song id. Files above
2 MiB are skipped rather than stored, and the service reports total usage so
Settings can show it. Clearing the artwork cache also nulls `artworkPath` so the
next scan re-extracts.

## Playback

`LjodAudioHandler` (an `audio_service` `BaseAudioHandler`) owns a `just_audio`
player plus the queue, shuffle, repeat and favourites state, and publishes
`MediaItem`s so the notification, media buttons and lock screen work.

Notification behaviour is deliberate:

* the service stays foreground when paused, so a media-button resume is not
  blocked by Android's background-start restrictions;
* the notification is therefore dismissible (`androidNotificationOngoing: false`);
* artwork is downscaled to 512 px before it reaches the notification.

## Lyrics

Resolution order, first hit wins:

1. **Sidecar** — `<track>.lrc`, `<track>.LRC` or `<track>.txt` next to the audio
   file (synced or plain).
2. **Embedded tags** — via `audio_metadata_reader`.
3. **LRCLIB** — only when the user enabled lyrics lookup in Settings. Base URL
   `https://lrclib.net`, one metadata lookup per track with a single search
   fallback, `Retry-After` honoured. The `User-Agent` is
   `Ljod/<version> (dev.vz.ljod)`, built from `LjodAppInfo` so it cannot drift.

Answers are cached on disk in `<app support>/lyrics`, including negative answers:
"no lyrics" and "instrumental" are stored, so a track is asked about once.
Refresh from the lyrics sheet or clear the cache in Settings to retry.

The cache is bounded: 32 entries in memory (LRU), a 6 MiB disk budget trimmed
every 25 writes, and legacy `.lrc` files written by older builds are removed.

## Diagnostics

`DiagnosticsLog` keeps a 128 KiB ring of timestamped lines in
`<app support>/diagnostics.log`. Dart errors (`FlutterError.onError`,
`PlatformDispatcher.onError`) are appended without replacing Flutter's normal
console reporting. The Android layer writes an uncaught exception to
`ljod-crash.log` before the process dies; that file is folded into the log on
the next launch and then deleted. Settings → Diagnostics can copy or clear it.

## Timing and limits worth knowing

| Limit | Value | Where |
| --- | --- | --- |
| Image cache | 120 entries / 96 MiB | `main.dart` |
| Diagnostics log | 128 KiB | `DiagnosticsLog.maxBytes` |
| Artwork file | 2 MiB | `ArtworkCache.maxFileBytes` |
| Lyrics disk budget | 6 MiB | `LyricsService` |
| Lyrics memory LRU | 32 entries | `LyricsService` |
| LRCLIB timeouts | 6 s connect / 8 s receive | `LrclibRemote` |
| Android support | `minSdk 35`, `targetSdk 37` | `android/app/build.gradle.kts` |
