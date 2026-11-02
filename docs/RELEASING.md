# Releasing

A release is a tag push. The workflow builds a signed APK, verifies the
signature, and publishes it as a GitHub release. No keystore ever lives in the
repository.

## 1. Bump the version

Edit both places (see [BUILDING.md](BUILDING.md#versioning)):

```yaml
# pubspec.yaml
version: 0.3.1+4
```

```dart
// lib/core/app_info.dart
static const String version = '0.3.1+4';
static const String versionName = '0.3.1';
static const int buildNumber = 4;
```

```sh
flutter test test/app_info_test.dart   # fails if the two drifted
```

## 2. Commit, tag, push

The tag must be `v<versionName>` — no build number. The workflow enforces this.

```sh
git commit -am "Release 0.3.1"
git push origin main
git tag v0.3.1
git push origin v0.3.1
```

## 3. What the workflow does

`.github/workflows/release.yml`, triggered by `v*` tags (and manual dispatch):

1. **Tag guard** — compares the tag with `pubspec.yaml` and stops on a mismatch.
2. **Build** — `flutter build apk --release` with the four signing secrets as
   environment variables; aborts if `ANDROID_KEYSTORE_BASE64` is empty rather
   than shipping an unsigned APK.
3. **Verify** — `apksigner verify --verbose` on the produced APK.
4. **Clean up** — deletes the decoded keystore (`if: always()`, so it happens
   even on failure).
5. **Upload artifact** — `ljod-<version>`, kept 30 days.
6. **Publish release** — creates the GitHub release for the tag with
   `ljod-<versionName>.apk` attached. Re-running the workflow replaces the
   asset rather than failing.

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

The base64 value is decoded into `android/.gradle-signing/ljod-upload.p12`
(mode 0600, git-ignored). It deliberately sits outside `build/` so a
`gradle clean` cannot delete it between configuration and signing.

### Repository secrets

| Secret | Purpose |
| --- | --- |
| `ANDROID_KEYSTORE_BASE64` | the keystore, base64-encoded |
| `ANDROID_KEYSTORE_PASSWORD` | store password |
| `ANDROID_KEY_ALIAS` | key alias inside the keystore |
| `ANDROID_KEY_PASSWORD` | key password |

Set or rotate them without pasting values into a shell history or chat:

```sh
base64 -w0 /path/outside/repo/ljod-upload.p12 | gh secret set ANDROID_KEYSTORE_BASE64 --repo Veridian-Zenith/ljod
gh secret set ANDROID_KEYSTORE_PASSWORD --repo Veridian-Zenith/ljod   # then paste at the prompt
```

`ANDROID_KEYSTORE` (an older secret) is no longer read by anything.

### Local signed build

Keep the key outside the checkout and point the root `local.properties` at it:

```properties
ANDROID_KEYSTORE_PATH=/home/you/.config/ljod/ljod-upload.p12
ANDROID_KEYSTORE_PASSWORD=...
ANDROID_KEY_ALIAS=...
ANDROID_KEY_PASSWORD=...
```

```sh
flutter build apk --release
```

To confirm what Gradle resolved without building:

```sh
cd android && ./gradlew :app:signingReport
```

The release variant should show your keystore path, alias and certificate.

## Verifying a release

```sh
# signature and identity
apksigner verify --print-certs --verbose build/app/outputs/flutter-apk/app-release.apk

# compare with the expected upload certificate
keytool -list -v -keystore /path/to/ljod-upload.p12 -alias ljod | grep SHA256
```

The APK's `V2 Signer: certificate SHA-256 digest` must match the keystore's
`SHA256:` fingerprint, or the build is signed with the wrong key.

Also worth checking after a release:

```sh
gh release view v0.3.1 --json tagName,isDraft,assets
```

## Re-tagging an existing version

A tag is a pointer, and the workflow file is read from the tagged commit. If a
tag was pushed before a workflow change, re-pushing the *same* tag re-runs the
*old* workflow. Move the tag instead:

```sh
gh release delete v0.3.1 --yes --cleanup-tag
git tag -d v0.3.1
git tag v0.3.1 <commit>
git push origin v0.3.1
```

## Known history

`v0.3.0` was tagged at `cc698cc`, which predates the release-publishing step, so
that tag push produced only a tag. Its release was published manually from the
signed artifact. Tags created after commit `9e6a965` publish automatically.
