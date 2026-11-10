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

Covers are written to `<app support>/artwork`, one file per unique picture, so
tracks from one album share a file. A cover is looked up in this order:

1. the previously extracted file, when it still exists (no re-read on rescans);
2. the picture embedded in the track's tags, read in the scan isolate;
3. an image beside the track — `cover`, `folder`, `front`, `album`, `albumart`,
   `albumartsmall`, `artwork`, `thumb`, or the track's own file name, in JPEG,
   PNG, WebP, GIF or BMP, matched case-insensitively;
4. on Android, `MediaMetadataRetriever` from the track's content URI, which also
   covers files the isolate cannot open and MediaStore's generated thumbnail.

On Android a cover is cached in two steps. The extraction pass accepts the raw
picture up to 24 MiB and writes it as it came from the tag; a downscaling pass
right after re-encodes it through the platform decoder (`BitmapFactory`) as a
1024 px JPEG, caches the result under its content hash, and lets the scan prune
the full-size original. Without that pass a library of 2000×2000 PNG covers
reached 1.46 GB for 1064 tracks, and covers over the 4 MiB ceiling were refused
before they were ever downscaled — 680 of 1744 tagged tracks showed no artwork
because of it. Elsewhere (desktop) nothing downscales, so a cover above 4 MiB is
skipped rather than stored.

The service reports total usage so Settings can show it, and each scan logs how
many tracks got a cover per source, counting only files that still exist.
Clearing the artwork cache also nulls `artworkPath` so the next scan
re-extracts.

Stored paths are verified against the filesystem when the library loads and
before each scan. That check is necessary because `upsertSongs` keeps an
existing path when a scan produces no art for a track (`COALESCE`), so without
it a path that outlived its file could never be corrected — the row would keep
pointing at a deleted cover forever, and every tile would fail to decode.

Trimming never deletes a cover the library still references. It did once, to
hold the directory under a byte budget: the scan extracted hundreds of covers,
the trim cut them back to the budget, and the database then forgot every path
that was deleted, so most tracks lost their art again. A cover can only be
recreated by reading its audio file, so the budget now applies to unreferenced
leftovers only, and a library's artwork is allowed to use the space it needs.

Every write re-creates the directory if it is missing: clearing a cache deletes
it, and a write that assumed it still existed failed silently, which meant no
cover could ever return. Orphan pruning is skipped when a scan cannot name a
single referenced cover, and covers the database still references are always
kept, so a scan that fails to read tags cannot discard art the library points
at.

Covers paint wherever artwork appears — rows, grids, rails, the queue, the mini
player and the full-screen player — always through `CoverArt`, which decodes at
the size the widget actually paints (`cacheWidth`/`cacheHeight`, capped at
1024 px). Decoding a 2000×2000 cover for a 54 px row was what made scrolling
churn the image cache, and that cost is now bounded per tile. A cover that
cannot be decoded paints the designed initials fallback and writes one
`artwork: could not decode …` line to Diagnostics, so a missing file is not
indistinguishable from an untagged one. The media notification is unaffected —
it points at the cached file through the `MediaItem`'s `artUri`.

## Playback

`LjodAudioHandler` (an `audio_service` `BaseAudioHandler`) owns a `just_audio`
player plus the queue, shuffle, repeat and favourites state, and publishes
`MediaItem`s so the notification, media buttons and lock screen work.

Shuffle is materialised into the queue instead of being delegated to
`just_audio`, whose own shuffle order is private to the plugin: enabling it
deals the base order with a Fisher–Yates shuffle (`shuffle_order.dart`) that
keeps the current track first, then reloads the queue at the same position.
Everything that answers "what plays next" — the up-next strip, the queue sheet
and the notification — reads the queue, so all three agree, and turning shuffle
off restores the stored library order.

The last session (queue ids, track index, position, shuffle, repeat) is written
to `SharedPreferences` on track and state changes and every few seconds while
playing, then restored at launch **paused**: audio that starts by itself on
launch would be a worse surprise than losing the position.

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
`<app support>/diagnostics-2.log`. Dart errors (`FlutterError.onError`,
`PlatformDispatcher.onError`) are appended without replacing Flutter's normal
console reporting. The Android layer writes an uncaught exception to
`ljod-crash.log` before the process dies; that file is folded into the log on
the next launch and then deleted. Settings → Diagnostics can copy or clear it.

## Timing and limits worth knowing

| Limit | Value | Where |
| --- | --- | --- |
| Image cache | 120 entries / 96 MiB | `main.dart` |
| Diagnostics log | 128 KiB | `DiagnosticsLog.maxBytes` |
| Artwork file | 4 MiB (Android: downscaled to 1024 px first) | `ArtworkCache.maxFileBytes` |
| Artwork raw input | 24 MiB, Android only | `LibraryService._maxRawArtworkBytes` |
| Artwork disk budget | 192 MiB (unreferenced files only) | `ArtworkCache.defaultBudgetBytes` |
| Lyrics disk budget | 6 MiB | `LyricsService` |
| Lyrics memory LRU | 32 entries | `LyricsService` |
| LRCLIB timeouts | 6 s connect / 8 s receive | `LrclibRemote` |
| Android support | `minSdk 35`, `targetSdk 37` | `android/app/build.gradle.kts` |
