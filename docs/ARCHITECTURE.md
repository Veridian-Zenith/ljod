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
│   ├── library/               scan, artwork lookup, providers
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
                                                                 (tags)          └─▶ folder tally
```

* **Source.** On Android a thin `MethodChannel('dev.vz.ljod/media')` bridge
  queries `MediaStore.Audio`; on desktop the service walks conventional music
  folders. `permission_handler` gates the Android scan (`LibraryPermissionException`
  when audio access is denied).
* **Filtering.** `FolderScope` applies `all` / `only` / `exclude` rules
  recursively — selecting `/Music/Rock` also covers `/Music/Rock/Live`.
  `content://` paths expose no folder, so those tracks are always kept.
* **Enrichment.** Tag reading runs in a background isolate (`compute`) in
  batches. No image bytes are decoded or written: covers are resolved later, per
  album, when a tile is painted.
* **Persistence.** `upsertSongs` writes metadata only; `isFavorite`,
  `playCount` and `lastPlayedMs` are deliberately excluded from the update so a
  rescan never erases listening state.
* **One pass.** The rows the scan already holds also produce the folder tally
  that folder rules list, plus counts of what could not be read: files missing
  while their tags were read, unreadable tags, unreadable desktop folders,
  platform rows without a path, and the 5000-file desktop ceiling. A completed
  scan leaves no follow-up platform query behind; `upsertSongs` also writes the
  legacy `artworkPath` column, so no separate table-wide UPDATE is needed.
* **Logging.** A scan writes `scan: started`, one summary line (tracks, albums,
  artists, folders, total minutes, elapsed ms) and a `WARN` per count above
  zero, then the `artwork:` line that records covers resolving online.
* **Per-item refresh.** Settings → Caches re-runs one cache at a time: artwork
  lookups drop the URL memo, cached lyrics drop stored answers, and Rescan
  device rebuilds the index. A single bad cache never needs a full scan.

### Database

`ljod_library.db`, schema version 4, in the first directory that answers:

| Table | Purpose |
| --- | --- |
| `songs` | library cache: id, path, title, artist, album, albumArtist, durationMs, trackNumber, isFavorite, playCount, lastPlayedMs, addedAtMs (plus the legacy `artworkPath` column, no longer written) |
| `artwork_urls` | albumKey, url, fetchedAtMs — the online cover memo |
| `playlists` | id, name, createdAt |
| `playlist_songs` | playlistId, songId, position |

A folder that already holds `ljod_library.db` wins; otherwise the order is the
app documents folder, sqflite's own databases folder, then the app support
folder. A regression in whichever plugin answers for directories therefore moves
the file (and logs it) instead of leaving the app with no library, and a folder
that starts answering again cannot strand the library in another one.

Directories themselves are answered by the app's own channel,
`dev.vz.ljod/paths` (`lib/core/platform/app_paths.dart` and `MainActivity`),
installed as `PathProviderPlatform.instance`. `path_provider_android` 2.3.1
resolves paths through `package:jni`, and with `jni` 1.2.0 its generated bindings
ask the JVM for a class literally named `Landroid/content/Context;`: they were
produced by jnigen 0.16, which emits no `className`, and `JType.jClass` falls
back to the type signature. Both packages are the current releases, so the app
answers the same directories itself — documents is `getDir("flutter")`, support
is `filesDir`, cache is `cacheDir` — and `just_audio`'s asset cache and
`audio_service`'s cache manager go through that instance as well.

Indexes exist on `title`, `artist` and `album`. The library is a rebuildable
cache, so a bump of its schema drops and recreates the tables rather than
migrating; the artwork memo is added in place, since it holds only URLs.

### Artwork

Cover art is not stored on the device. Each album's cover is resolved online
when it is first painted and remembered as a URL in `artwork_urls` — one row of
text per album, holding either the URL or a "none found" mark that is retried
after 14 days. That memo is why the second paint is free and why a library can
show covers on every screen without a byte of image data being written.

Deezer's public API is asked first, because it needs no key and serves 1000 px
covers; the iTunes Search API is the fallback, upscaled from its 100 px
thumbnail to 600 px. Lookups are keyed by normalized artist + album (the track
title when the album tag is missing) and pass through a three-request throttle,
so an album grid cannot burst either API. `Image.network` paints the result and
Flutter's in-memory image cache bounds what is decoded. An album the catalogues
do not know shows initials, and Settings → Caches → Artwork lookups refreshes
every answer so it is asked again.

An earlier design extracted embedded and sidecar pictures into
`<app support>/artwork`. For 1064 tracks that directory reached 1.46 GB, covers
over the 4 MiB ceiling were dropped before they were ever written, and the
scan's own eviction could delete art the library still pointed at. The scan now
deletes that directory if an older build left one behind, and no code path
writes cover images any more.

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
* the notification carries no cover: artwork is a URL painted by the app, and
the media session is not handed a network image.

Playback keeps a fixed working set. A queue entry becomes one `MediaItem`, not
three, the image cache is capped at 48 MiB, a session is not rewritten when
nothing about it changed, and a state broadcast carries a real change
immediately while a position-only tick goes out at most once a second (the media
session interpolates the position itself). Diagnostics records
`memory: N MB rss, M MB decoded covers` per track, so growth across a long
session is visible instead of guessed at.

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
| Image cache | 60 entries / 48 MiB | `main.dart` |
| Diagnostics log | 128 KiB | `DiagnosticsLog.maxBytes` |
| Artwork memo | one text row per album | `artwork_urls` (SQLite) |
| Lyrics disk budget | 6 MiB | `LyricsService` |
| Lyrics memory LRU | 32 entries | `LyricsService` |
| LRCLIB timeouts | 6 s connect / 8 s receive | `LrclibRemote` |
| Android support | `minSdk 35`, `targetSdk 37` | `android/app/build.gradle.kts` |
