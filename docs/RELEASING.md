# Releasing

A release is a tag push. The workflow builds a signed APK, verifies the
signature, and publishes it as a release on git.gay through the Forgejo API. No
keystore ever lives in the repository.

## 1. Bump the version

Edit both places (see [BUILDING.md](BUILDING.md#versioning)):

```yaml
# pubspec.yaml
version: 0.3.2+5
```

```dart
// lib/core/app_info.dart
static const String version = '0.3.2+5';
static const String versionName = '0.3.2';
static const int buildNumber = 4;
```

```sh
flutter test test/app_info_test.dart   # fails if the two drifted
```

## 2. Commit, tag, push

The tag must be `v<versionName>` — no build number. The workflow enforces this.

```sh
git commit -am "Release 0.3.2"
git push origin main
git tag v0.3.2
git push origin v0.3.2
```

A tag push is not the only way: the workflow can also be run by hand to rebuild
and republish a version that already exists — see
[Re-running a release](#re-running-a-release-without-a-new-tag).

## 3. What the workflow does

`.github/workflows/release.yml`, triggered by `v*` tags (and manual dispatch):

1. **Resolve the version** — a tag push must equal `v<pubspec name>` or the run
   stops; a manual run publishes the `version` input, or pubspec's version when
   that is left empty.
2. **Signing check** — decodes the keystore, then uses `keytool` to prove the
   store password opens it, that the alias exists, and that the key password
   unlocks the private key. A failure names the offending secret in seconds
   instead of after a full build.
3. **Build** — `flutter build apk --release --split-per-abi
   --target-platform android-arm64,android-arm --split-debug-info=build/symbols`
   with the four signing secrets as environment variables. One APK per ABI,
   never a universal one — see [Why two APKs](#why-two-apks).
4. **Verify** — `apksigner verify --verbose` on every per-ABI APK that was
   produced.
5. **Clean up** — deletes the decoded keystore (`if: always()`, so it happens
   even on failure).
6. **Publish release** — creates the Forgejo release for the tag with
   `ljod-<versionName>-arm64-v8a.apk` and `ljod-<versionName>-armeabi-v7a.apk`
   attached, using the REST API and the per-run job token (Forgejo has no
   `gh release`). Re-running the workflow replaces the assets rather than
   failing, and clears the old single-APK name so a previous universal build
   cannot sit beside them. Nothing is uploaded as a workflow artifact: this
   runner has no artifact service, so the release assets are the only copy.

### Re-running a release without a new tag

Because the workflow also has a manual trigger, a version can be rebuilt and
republished without moving a tag or bumping the version:

**Actions → Release Build → Run workflow**, on the branch you want to build from.

Leave `version` empty to publish whatever `pubspec.yaml` declares, or type a
version (`0.3.2` and `v0.3.2` both work) to publish that release instead. The APK
is built from the selected ref; the asset on that tag's release is replaced, and
the release is created — with the tag pointing at the built commit — if it does
not exist yet.

Only users who can run workflows see that button, and publishing still needs the
job token to have write access through Authorized Integrations, exactly as a tag
push does.

## Signing contract

Signing material is passed as **content**, never as a path into the checkout, so
nothing has to exist in the repository and nothing can be committed by accident.

Resolution order in `android/app/build.gradle.kts`:

| Priority | Input | Use |
| --- | --- | --- |
| 1 | `ANDROID_KEYSTORE_BASE64` | the keystore itself, base64 — what CI uses |
| 2 | `ANDROID_KEYSTORE_PATH` | absolute path outside the repository, for local builds |
| 3 | — | no key: the build configures, logs that fact, and a release build fails |

Credentials (`ANDROID_KEYSTORE_PASSWORD`, `ANDROID_KEY_ALIAS`,
`ANDROID_KEY_PASSWORD`) come from the environment first, then from the
git-ignored `local.properties`.

The base64 value is decoded into `android/.gradle-signing/ljod.p12`
(mode 0600, git-ignored). It deliberately sits outside `build/` so a
`gradle clean` cannot delete it between configuration and signing.

### Repository secrets

| Secret | Purpose |
| --- | --- |
| `ANDROID_KEYSTORE_BASE64` | the keystore, base64-encoded |
| `ANDROID_KEYSTORE_PASSWORD` | store password |
| `ANDROID_KEY_ALIAS` | key alias inside the keystore |
| `ANDROID_KEY_PASSWORD` | key password |

They live in the repository: **Settings → Actions → Secrets → Add secret**.
Paste values into the web form rather than a shell history or chat. The keystore
secret is the base64 **content**, so it is the one worth generating locally and
copying straight to the clipboard:

```sh
base64 -w0 /path/outside/repo/ljod.p12 | xclip -selection clipboard
```

The API equivalent is
`PUT /api/v1/repos/Veridian-Zenith/ljod/actions/secrets/{name}`.

`ANDROID_KEYSTORE` (an older secret) is no longer read by anything.

### If the build cannot read the key

`Failed to read key <alias> from store "...": null` from `packageRelease` means
the keystore opened but the private key did not, which in practice is a wrong or
empty `ANDROID_KEY_PASSWORD`. This keystore is PKCS12, so its key password is the
same string as `ANDROID_KEYSTORE_PASSWORD` — paste the two from the same source.

The `Verify the signing secrets` step catches this before the build starts. On a
tag that predates that step, check by hand:

```sh
keytool -list -keystore ljod.p12 -storepass "$ANDROID_KEYSTORE_PASSWORD"
keytool -certreq -keystore ljod.p12 -storepass "$ANDROID_KEYSTORE_PASSWORD" \
  -alias ljod -keypass "$ANDROID_KEY_PASSWORD" -file /tmp/check.csr
```

The first must list `ljod`; the second writes a certificate request only when
the key password is right.

### Local signed build

Keep the key outside the checkout and point the root `local.properties` at it:

```properties
ANDROID_KEYSTORE_PATH=/home/you/.config/ljod/ljod.p12
ANDROID_KEYSTORE_PASSWORD=...
ANDROID_KEY_ALIAS=...
ANDROID_KEY_PASSWORD=...
```

```sh
flutter build apk --release \
  --split-per-abi \
  --target-platform android-arm64,android-arm \
  --split-debug-info=build/symbols
```

To confirm what Gradle resolved without building:

```sh
cd android && ./gradlew :app:signingReport
```

The release variant should show your keystore path, alias and certificate.

## Why two APKs

A universal `flutter build apk --release` packs every ABI into one file. For
0.3.2 that was a 70 MiB download made of three near-identical copies:

| component | size |
| --- | --- |
| `lib/x86_64` | 24.0 MiB |
| `lib/arm64-v8a` | 22.5 MiB |
| `lib/armeabi-v7a` | 20.3 MiB |
| `classes.dex`, resources, Dart assets | 3.6 MiB |

`--split-per-abi` with `--target-platform android-arm64,android-arm` drops the
emulator-only x86_64 copy and ships one APK per phone architecture, so a device
downloads roughly 20–26 MiB (arm64) or 18–24 MiB (armv7) instead of 70. `minSdk` is 35, so no
32-bit-only hardware runs this; armv7 is kept for 64-bit devices running a 32-bit
userspace.

`--split-debug-info=build/symbols` moves DWARF out of the shipped `libapp.so`,
which is where several MiB per ABI were going. The symbol files are written to
`build/symbols` and are **not** published: this runner has no artifact service,
so keeping them means downloading them from a workflow log you still have. If a
release ever needs symbolised crash traces, attach them as release assets — that
is the only durable place this project has.

## Verifying a release

```sh
# signature and identity
apksigner verify --print-certs --verbose \
  build/app/outputs/flutter-apk/app-arm64-v8a-release.apk

# compare with the expected upload certificate
keytool -list -v -keystore /path/to/ljod.p12 -alias ljod | grep SHA256
```

The APK's `V2 Signer: certificate SHA-256 digest` must match the keystore's
`SHA256:` fingerprint, or the build is signed with the wrong key.

Also worth checking after a release:

```sh
curl -sS https://git.gay/api/v1/repos/Veridian-Zenith/ljod/releases/tags/v0.3.2 \
  | python3 -m json.tool | head -30
```

or open <https://git.gay/Veridian-Zenith/ljod/releases>.

## Re-tagging an existing version

A tag is a pointer, and the workflow file is read from the tagged commit. If a
tag was pushed before a workflow change, re-pushing the *same* tag re-runs the
*old* workflow. Move the tag instead:

```sh
# Forgejo has no gh: delete the release in the web UI, or via
# DELETE /api/v1/repos/Veridian-Zenith/ljod/releases/{id}, then move the tag.
git tag -d v0.3.2
git tag v0.3.2 <commit>
git push origin v0.3.2
```

## Known history

`v0.3.0` was tagged at `cc698cc`, which predates the release-publishing step, so
that tag push produced only a tag. Its release was published manually from the
signed artifact. Tags created after commit `9e6a965` publish automatically.
