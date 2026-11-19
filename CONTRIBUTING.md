# Contributing

Thanks for helping with Ljod. This is a small, opinionated codebase — the notes
below are what keep it that way.

## Setup

```sh
flutter --version   # 3.50.0 stable
flutter pub get
flutter run
```

Full requirements and Android specifics are in [docs/BUILDING.md](docs/BUILDING.md).

## Before you open a pull request

```sh
dart format lib test
flutter analyze
flutter test
```

All three must be clean, and CI runs exactly these plus a debug APK build on
every PR. `dart format` is enforced with `--set-exit-if-changed`, so an
unformatted file fails the build.

## Code conventions

* **Layering.** `features` → `services` → `core`. A screen never talks to
  `sqflite`, `dio` or `MediaStore` directly; a service never imports a screen.
  See [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md).
* **State.** Riverpod providers only. Platform singletons that tests cannot
  construct (`SharedPreferences`, the audio handler) are injected as providers
  overridden in `main()`.
* **Style.** Material 3 Expressive via `material_ui`, true-black surfaces, the
  bundled JetBrains Mono. Reuse `core/widgets/vz_components.dart` rather than
  hand-rolling a card, chip or section header.
* **Comments.** Explain *why* a non-obvious decision exists (notification
  behaviour, isolate boundaries, cache limits), not what the line does.
* **Privacy.** Nothing may phone home. The only permitted outbound request is
  the opt-in LRCLIB lookup, and it must stay off by default.

## Tests

| File | Covers |
| --- | --- |
| `test/app_info_test.dart` | version constant matches `pubspec.yaml`, tag derives correctly |
| `test/core_test.dart` | models, folder scope rules, formatters |
| `test/cache_test.dart` | artwork and lyrics cache behaviour |
| `test/lyrics_test.dart` | sidecar/embedded/remote resolution, caching, romanisation |
| `test/widget_test.dart` | shell, settings, setup flow, phone viewport |

Add a test with the fix, not after it. Prefer a narrow unit test over a widget
test unless the behaviour is genuinely visual or navigational.

## Commits

* One logical change per commit; present tense subject (`fix: …`, `feat: …`,
  `docs: …`, `ci: …`).
* Explain the reason in the body when it is not obvious from the diff.
* Do not commit generated output: `build/`, `.dart_tool/`, `.gradle/`,
  `local.properties`, `*.p12`, `*.jks`, `*.keystore`.

## Version bumping

Only maintainers bump versions. If your change needs one, update **both**
`pubspec.yaml` and `lib/core/app_info.dart` — `test/app_info_test.dart` fails
otherwise. Release steps are in [docs/RELEASING.md](docs/RELEASING.md).

## Secrets

Never paste keystore contents, passwords or tokens into an issue, a commit or a
chat. Signing material is passed to CI as repository secrets and to local builds
as environment variables or the git-ignored `local.properties`.

## Licence

Ljod is licensed under the [Open Software License 3.0](LICENSE). By submitting a
contribution you agree it may be distributed under those terms.
