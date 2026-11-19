# FAQ

### Does Ljod stream or download music?

No. It indexes audio files that are already on the device and plays them from
there. There is no catalogue, no account and no cloud library.

### Does it work offline?

Playback, indexing and sidecar or embedded lyrics do. Album artwork needs a
connection: covers are looked up by artist and album name (Deezer, then the
iTunes catalogue) and kept as a link. Offline, tracks still list and play and
tiles show initials. The LRCLIB lyrics lookup is opt-in and off by default.

### What audio formats are supported?

Whatever the platform decoder and `just_audio` handle on your device — typically
MP3, AAC/M4A, FLAC, OGG/Vorbis, Opus and WAV. Tag and cover reading goes through
Tag reading goes through `audio_metadata_reader`, so ID3v2, Vorbis comments and
MP4 atoms are understood.

### Which Android versions?

Android 15 (API 35) and newer. `minSdk` is 35 because the library scan and
notification behaviour rely on modern `MediaStore` and foreground-service rules.

### Why is my music folder missing from the library?

Check Settings → Folder rules. In `only` mode only the selected folders are
indexed; in `exclude` mode the listed ones are skipped. Rules apply recursively,
so `/Music/Rock` includes `/Music/Rock/Live`. Files exposed as `content://` URIs
have no folder to match, so they are always kept.

### Can I use my own `.lrc` files?

Yes — put them beside the audio file with the same name (`Song.flac` →
`Song.lrc`). They take priority over embedded lyrics and over LRCLIB, and synced
timestamps are used when present.

### Why did a track show "no lyrics" and never retry?

Lookups are cached deliberately, including negative results, so a library scan
does not hammer LRCLIB. Use **Refresh** in the lyrics sheet, or refresh the
lyrics cache in Settings → Caches, to retry.

### Is my listening data uploaded anywhere?

No. Favourites, play counts, last-played times and statistics are stored in the
local SQLite database. See [PRIVACY.md](PRIVACY.md).

### Where are favourites and play counts stored? Will a rescan lose them?

In the `songs` table of the local database. A rescan upserts metadata only and
deliberately leaves `isFavorite`, `playCount` and `lastPlayedMs` untouched.
"Clear library cache" does reset them, by design.

### Can I back up or export my library?

Not yet. The database and caches are inside the app's private storage; the
indexed files themselves are untouched and can always be rescanned.

### Why is the interface always dark?

The design is deliberately true-black for OLED displays. Only motion, sorting and
lyrics lookup are user-configurable — see [ARCHITECTURE.md](ARCHITECTURE.md).

### How do I get the APK?

Releases are published on the
[releases page](https://git.gay/Veridian-Zenith/ljod/releases) with one signed
APK per phone architecture — `ljod-<version>-arm64-v8a.apk` and
`ljod-<version>-armeabi-v7a.apk`. Install the arm64 one unless the device is
32-bit only. Builds from source are covered in [BUILDING.md](BUILDING.md).

### What licence is Ljod under?

The Open Software License 3.0 (OSL-3.0). See [LICENSE](../LICENSE). In short: you
may use, modify and redistribute it, including commercially, provided
distributed copies and derivative works stay under the same licence and
attribution notices are kept.
