# Privacy

Ljod is local-first. There is no account, no sign-in, no analytics, no crash
reporting service and no ads. Nothing is uploaded, and no usage data leaves the
device unless you explicitly turn on lyrics lookup.

## What is stored, and where

| Data | Location | Notes |
| --- | --- | --- |
| Library index, favourites, play counts | `ljod_library.db` (app documents) | rebuildable cache |
| Artwork lookups | `artwork_urls` (same database) | one row per album: the cover URL, or a "none found" mark retried after 14 days |
| Cached lyrics | `<app support>/lyrics/` | includes "no lyrics" answers |
| Settings | `SharedPreferences` | motion, lyrics lookup, folder rules, sorting |
| Diagnostics | `<app support>/diagnostics-2.log` | capped at 128 KiB |

All of it is inside the app's private storage. Uninstalling the app removes it.
"Clear library cache", "Cached lyrics" and "Artwork lookups" in Settings delete the
corresponding data at any time.

## Permissions

| Permission | Why |
| --- | --- |
| `READ_MEDIA_AUDIO` | read the music library through `MediaStore` |
| `POST_NOTIFICATIONS` | show the playback notification (Android 13+) |
| `FOREGROUND_SERVICE`, `FOREGROUND_SERVICE_MEDIA_PLAYBACK` | keep playback alive in the background |
| `WAKE_LOCK` | keep the CPU awake while playing |
| `INTERNET`, `ACCESS_NETWORK_STATE` | only used for the opt-in LRCLIB lookup |

Audio is never uploaded. The scan reads metadata and tags locally; playback
reads your files directly.

## The one outbound request

**Off by default.** When you enable "Lyrics lookup" in Settings, Ljod asks
[LRCLIB](https://lrclib.net) for lyrics that are not available locally.

Sent per lookup:

* track title, artist, album (if set) and duration in seconds
* a `User-Agent` of `Ljod/<version> (dev.vz.ljod)` — LRCLIB's usage policy asks
  clients to identify themselves

Never sent: audio data, file paths, your library contents, device identifiers,
or anything about other tracks.

Each track is looked up **once**. The answer — including "no lyrics" and
"instrumental" — is cached on disk, so reopening a track does not re-request it.
Use *Refresh* in the lyrics sheet to deliberately retry, or clear the cache in
Settings. If LRCLIB returns a rate limit, Ljod honours `Retry-After` and waits
before asking again.

Turn the setting off and lyrics lookups stop; sidecar `.lrc` files and embedded
lyrics keep working. Cover artwork is still resolved online, because it is the
only source of artwork — see *Cover art lookups* below.

## Diagnostics

The log is a local breadcrumb trail for crashes and playback failures. It is only
read when you open Settings → Diagnostics, and only leaves the device if you tap
Copy and paste it somewhere yourself. There is no automatic upload and no
telemetry endpoint.

## Children and ads

No ads, no ad SDKs, no third-party analytics or attribution libraries. The
dependency list in `pubspec.yaml` is the complete set of code that ships.

## Cover art lookups

Cover art is fetched, not stored. Finding an album's cover sends its artist and
album names to Deezer and to Apple's iTunes Search API; nothing else about the
track, its file or the device is included, no account is needed and no key is
used. The answer is kept locally only as a URL. Clearing the library, or
Settings → Artwork lookups, removes those rows; the images themselves stay on the
catalogue's servers and are fetched again on demand.
