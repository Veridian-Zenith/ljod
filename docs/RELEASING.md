# Releasing

A release is a tag push. The workflow builds a signed APK, verifies the
signature, and publishes it as a release on git.gay through the Forgejo API. No
keystore ever lives in the repository.

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
2. **Signing check** — decodes the keystore, then uses `keytool` to prove the
   store password opens it, that the alias exists, and that the key password
   unlocks the private key. A failure names the offending secret in seconds
   instead of after a full build.
3. **Build** — `flutter build apk --release` with the four signing secrets as
   environment variables.
4. **Verify** — `apksigner verify --verbose` on the produced APK.
5. **Clean up** — deletes the decoded keystore (`if: always()`, so it happens
   even on failure).
6. **Publish release** — creates the Forgejo release for the tag with
   `ljod-<versionName>.apk` attached, using the REST API and the per-run job
   token (Forgejo has no `gh release`). Re-running the workflow replaces the
   asset rather than failing. Nothing is uploaded as a workflow artifact: this
   runner has no artifact service, so the release asset is the only copy.

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

They live in the repository: **Settings → Actions → Secrets → Add secret**.
Paste values into the web form rather than a shell history or chat. The keystore
secret is the base64 **content**, so it is the one worth generating locally and
copying straight to the clipboard:

```sh
base64 -w0 /path/outside/repo/ljod-upload.p12 | xclip -selection clipboard
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
keytool -list -keystore ljod-upload.p12 -storepass "$ANDROID_KEYSTORE_PASSWORD"
keytool -certreq -keystore ljod-upload.p12 -storepass "$ANDROID_KEYSTORE_PASSWORD" \
  -alias ljod -keypass "$ANDROID_KEY_PASSWORD" -file /tmp/check.csr
```

The first must list `ljod`; the second writes a certificate request only when
the key password is right.

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
curl -sS https://git.gay/api/v1/repos/Veridian-Zenith/ljod/releases/tags/v0.3.1 \
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
git tag -d v0.3.1
git tag v0.3.1 <commit>
git push origin v0.3.1
```

## Known history

`v0.3.0` was tagged at `cc698cc`, which predates the release-publishing step, so
that tag push produced only a tag. Its release was published manually from the
signed artifact. Tags created after commit `9e6a965` publish automatically.
