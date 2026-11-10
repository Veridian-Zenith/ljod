# Troubleshooting

Start with **Settings → Diagnostics**: it shows the app's log (including native
crash traces captured on the previous launch) and has Copy and Clear actions.

## The library is empty

1. Check the permission prompt was accepted: Settings shows the indexed track
   count, and a denied scan raises a permission error rather than pretending the
   device is empty. Re-grant via Settings → Rescan device.
2. Check folder rules — Settings → Folder rules. In `only` mode, nothing outside
   the selected folders is indexed; `only` with an empty list indexes nothing.
3. Ringtones, notification sounds and alarms are excluded by design, as are
   zero-length entries.
4. On Android, the scan is `MediaStore`-based. If a freshly copied file is
   missing, wait for the media scanner or reboot — Ljod reads the system index,
   it does not crawl the filesystem itself.

## Tracks appear but have no cover art

* Covers come from the track's own tags first, then from an image stored beside
  it: `cover`, `folder`, `front`, `album`, `albumart`, `artwork`, `thumb`, or a
  file named after the track, in JPEG, PNG, WebP, GIF or BMP. Nothing is
  fetched online.
* On Android every cover is downscaled to a 1024 px JPEG before it is cached,
  in whichever format it arrived (JPEG, PNG, WebP, GIF, BMP). A full-size PNG
  cover is 2–8 MiB; downscaled, the same art is a few hundred kilobytes. Covers
  cached before this existed are converted on the next scan.
* Outside Android nothing downscales, so a cover above 4 MiB is skipped rather
  than stored.
* Settings → Diagnostics writes an `artwork:` line per scan that says how many
  tracks got a cover and whether it came from embedded art, a sidecar image, the
  platform bridge, or the existing cache.
* Covers show in rows, grids, rails, the queue, the mini player and the player.
  A tile that still shows initials while another screen shows the cover is a
  decode failure, not a missing image: look for
  `artwork: could not decode <path>` in Diagnostics, which now records the file
  and the decoder error instead of failing silently.
* A stored path whose file has disappeared is caught when the app loads and
  before every scan: the dead path is forgotten and its cover is extracted
  again in the background. `artwork: N cached cover(s) were missing;
  re-extracting` in Diagnostics means this repair ran.
* After clearing the artwork cache, covers reappear on the next scan. Force one
  with Settings → Rescan device.

## Lyrics are missing

Resolution order is sidecar → embedded tags → LRCLIB.

* **Sidecar**: the file must sit next to the audio file with the same stem and a
  `.lrc`, `.LRC` or `.txt` extension (`Song.flac` → `Song.lrc`).
* **Embedded**: `USLT`/`SYLT` frames must actually be present; many "lyrics"
  tagged by other tools are not.
* **LRCLIB**: requires Settings → Lyrics lookup to be on, and a title and artist.
  Tracks without both are skipped, since there is nothing safe to search.

Answers are cached, including negative ones. If lyrics were added since the last
lookup, open the lyrics sheet and use **Refresh**, or clear the cache in
Settings.

## Playback stops in the background

* Android may kill background apps aggressively. Exempt Ljod from battery
  optimisation in system settings.
* Dismissing the notification does not stop the service, but force-stopping the
  app from system settings does.
* If a track will not start, the failure is shown in the player and recorded in
  Diagnostics; the usual cause is a file that has been moved or deleted since the
  last scan. Rescan to reindex.

## The app closed and I want to know why

Settings → Diagnostics keeps a bounded log across launches. Native crashes are
written by `MainActivity` to `ljod-crash.log` before the process dies and folded
into the log on the next start. Copy it before clearing.

## Build failures

### `Keystore file not set for signing config release`

The release variant has no signing material. Either provide
`ANDROID_KEYSTORE_BASE64` / `ANDROID_KEYSTORE_PATH`, or run a debug build.

The build log above the failure names the cause explicitly:

```
Ljod: no signing key. ANDROID_KEYSTORE_PATH='/tmp/x.p12' does not point at an existing file.
```

Debug builds are unaffected — they always use the generated debug keystore.

### `Could not find or load main class org.gradle.wrapper.GradleWrapperMain`

You are running the repository-root `gradlew`, which has no wrapper JAR. Use
`android/gradlew` or the Flutter tooling.

### `flutter pub get` or resolution errors

```sh
flutter clean
flutter pub get
```

### Gradle 9.8.2 native-access warnings

```
WARNING: A restricted method in java.lang.System has been called
```

This is the JDK 21 native-access notice from Gradle's native platform library.
It is a warning, not a failure; `android/gradle.properties` already passes
`--enable-native-access=ALL-UNNAMED` to Gradle's JVM.

### `flutter.sdk not set in local.properties`

`android/settings.gradle.kts` requires `android/local.properties`. Let Flutter
generate it (`flutter pub get` or `flutter run` from the repo root) rather than
creating it by hand.

## CI

* Push builds run on `main` and `master` only; pull requests build on any branch.
* `Analyze` and `Test` gate `Debug APK` — a red analyze job means the APK was
  never attempted, which is intentional.
* Fork PRs work for CI because nothing in it needs a secret; release signing is
  tag-only.
* The `Release Build` workflow needs `permissions: contents: write` to publish.
  If a release is missing after a tag push, check the tag was created *after*
  commit `9e6a965` — earlier tags run the older workflow that only uploads an
  artifact. See [RELEASING.md](RELEASING.md#re-tagging-an-existing-version).
