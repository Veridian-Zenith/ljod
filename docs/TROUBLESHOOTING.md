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

* Covers are looked up per album online. Deezer's public API is asked first and
  the iTunes Search API second; neither needs a key, and the result is remembered
  as a URL, so no image files are stored on the device.
* An album whose tags do not match a catalogue entry shows initials. That answer
  is retried after 14 days, and clearing Settings → Artwork lookups forgets every
  answer so it is asked again immediately.
* Lookups need a network connection. Offline, tracks still list and play, but
  tiles show initials until a connection returns.
* Settings → Diagnostics writes one `scan:` line per pass — tracks, albums,
  artists, folders, total minutes and elapsed ms — and `artwork: lookup failed
  (...)` when a catalogue could not be reached.
* A tile that still shows initials while another screen shows the cover is
  usually a failed download: look for `artwork: could not load <url>` in
  Diagnostics, which records the URL and the loader error.

## Lyrics are missing

Resolution order is sidecar → embedded tags → LRCLIB.

* **Sidecar**: the file must sit next to the audio file with the same stem and a
  `.lrc`, `.LRC` or `.txt` extension (`Song.flac` → `Song.lrc`).
* **Embedded**: `USLT`/`SYLT` frames must actually be present; many "lyrics"
  tagged by other tools are not.
* **LRCLIB**: requires Settings → Lyrics lookup to be on, and a title and artist.
  Tracks without both are skipped, since there is nothing safe to search.

Answers are cached, including negative ones. If lyrics were added since the last
lookup, open the lyrics sheet and use **Refresh**, or refresh the cache in
Settings → Caches.

## A cache looks wrong

Each cache has its own refresh in Settings → Caches, so one bad answer never
needs a full library rescan:

* **Artwork lookups** drops every remembered cover link and any cover files an
  older build left; covers are looked up again as tiles appear.
* **Cached lyrics** drops stored answers; sidecar and embedded lyrics are read
  again, and the online lookup runs once more if it is enabled.
* **Rescan device** rebuilds the index itself — tags, folder rules and the
  missing-row prune — in one pass.

Every refresh leaves a line in Diagnostics: `artwork: cleared N remembered
lookup(s)`, `lyrics: cleared N cached answer(s) (M bytes)`, or the `scan:`
summary with its warnings for anything that could not be read.

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

### The build used the wrong JDK, an old daemon, or too much memory

`android/gradle/gradle-daemon-jvm.properties` pins the Gradle daemon to a JDK 21
from Adoptium, and daemon JVM criteria take precedence over `JAVA_HOME` and
`org.gradle.java.home` — a build launched with `JAVA_HOME` pointing at another
JDK still runs its daemon on Temurin 21. Check what a daemon is really using:

```sh
ps -eo args | grep -o '/[^ ]*/bin/java' | sort -u
```

Android Studio hands Gradle its own JDK through the Tooling API, so a build
started from the IDE uses **Settings → Build, Execution, Deployment → Build
Tools → Gradle → Gradle JDK**; set that to Temurin 21 as well.

Gradle keeps one daemon per JVM for three hours by default; this project sets
`org.gradle.daemon.idletimeout=600000` (ten minutes) and caps the Kotlin daemon
at 1 GiB, because it otherwise inherits the Gradle heap. After a wrapper bump
the previous version's daemon can still be running, and `./gradlew --stop` only
stops the current version — stop the old one with its own distribution, or
delete `~/.gradle/daemon/<version>`.

### Gradle native-access warnings

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
