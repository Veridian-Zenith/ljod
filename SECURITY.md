# Security policy

## Supported versions

Only the latest released version receives fixes. Ljod is distributed as a signed
APK from the [releases page](https://git.gay/Veridian-Zenith/ljod/releases).

| Version | Supported |
| --- | --- |
| 0.3.x | yes |
| < 0.3 | no |

## Reporting a vulnerability

Please **do not** open a public issue for anything security-sensitive. Forgejo
has no private advisory system, so report to the maintainer privately instead —
the contact details are on <https://git.gay/Veridian-Zenith>.

Include the affected version, the platform, reproduction steps, and what an
attacker gains.

You can expect an acknowledgement within a few days. Once a fix is released the
advisory is published with credit, unless you ask to remain anonymous.

## Scope

In scope:

* the Android app (`lib/`, `android/app/src/main/kotlin/`) — library scanning,
  MediaStore access, playback service and notification handling
* data handling: what Ljod stores, and the single outbound LRCLIB request
  (see [docs/PRIVACY.md](docs/PRIVACY.md))
* the release pipeline: signing, secret handling and the published APK

Out of scope:

* vulnerabilities in Android itself or in third-party packages (report those
  upstream; if Ljod needs a workaround, tell us anyway)
* attacks that require a rooted device or physical access to unlocked storage
* the absence of certificate pinning for `lrclib.net` — it is an optional,
  user-enabled feature that sends no sensitive data

## Secrets

Signing material is never stored in this repository. If you find a keystore,
password or token committed anywhere in the history, report it privately
immediately rather than opening an issue.

## Verifying a download

Releases are signed with the project's upload keystore. To check an APK:

```sh
apksigner verify --print-certs --verbose ljod-0.4.0-arm64-v8a.apk
```

If the certificate does not belong to Veridian Zenith, do not install it.
