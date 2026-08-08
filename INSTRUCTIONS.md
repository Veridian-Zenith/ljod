# Ljod — Veridian Zenith Music Player

## Project Identity
- **Package:** `dev.vz.ljod`
- **App ID:** `dev.vz.ljod`
- **License:** OSL-3.0
- **Repository:** Veridian-Zenith/ljod

## Quick Reference
```bash
# Build
./gradlew :app:assembleDebug

# Lint
./gradlew :app:lintDebug

# Detekt (static analysis)
./gradlew :app:detekt

# Both lint + detekt
./gradlew :app:detekt :app:lintDebug
```

## Architecture

```
dev.vz.ljod/
├── core/                    # Reusable foundation (no app-specific code)
│   ├── data/scanner/        #   MediaScanner — generic MediaStore queries
│   └── ui/
│       ├── navigation/      #   ScreenHost — generic bottom nav
│       └── theme/           #   LjodTheme, Palette, Dimens, Type
├── playback/                # Media3 wrappers (reusable)
│   ├── PlaybackController   #   State flows for play/pause/title/etc
│   └── PlaybackService      #   MediaSessionService impl
├── data/                    # App persistence
│   ├── model/Song           #   Room entity
│   └── database/            #   Room DB + DAO
├── di/                      # Hilt modules (thin wiring)
├── app/                     # App shell (LjodShell.kt)
├── ui/                      # Screen composables
│   ├── home/
│   ├── library/
│   └── settings/
├── LjodApp.kt               # Application class
└── MainActivity.kt          # Entry point
```

## Design System — Nordic Void

4 switchable palettes extracted from `vzdev.indevs.in`:

| Palette | Accent | Background | Glow |
|---------|--------|------------|------|
| Nordic (default) | `#FFB347` amber | `#050200` near-black | `#CCFFB347` |
| Midnight | `#818CF8` indigo | `#020008` void | `#CC8B5CF6` |
| Blood Moon | `#EF4444` red | `#080000` dark red | `#CCDC2626` |
| Golden | `#FFD700` gold | `#0A0800` dark amber | `#CCFFD700` |

Access in Compose: `LjodTheme.palette.accent`

### Design Tokens
- **Spacing:** 4dp base unit (2, 4, 8, 12, 16, 24, 32, 48, 64dp)
- **Radii:** 4, 8, 12, 16, 24dp, pill (9999dp)
- **Typography:** System default (swap to Iosevka Charon for terminal feel)
- **Glow:** `0 0 20px` accent at 80% alpha — signature VZ effect

## Code Conventions

### Kotlin
- Use `@Immutable` / `@Stable` for Compose data classes
- Use `kotlinx.serialization` for JSON (not Gson/Moshi)
- Use `sealed class` for UI state, not nullable wrappers
- Use `flow {}` + `StateFlow` for reactive data
- No `runBlocking` on main thread
- No `GlobalScope` — use structured concurrency
- Prefer `?.let {}` over null checks
- Use `by` delegate for `mutableStateOf` and `collectAsState`

### Compose
- `@Composable` functions: PascalCase, no `Composable` suffix
- One primary composable per file
- Extract repeated patterns into reusable composables in `core/ui/`
- Use `MaterialTheme.colorScheme.*` not hardcoded colors (use `LjodTheme.palette` for VZ-specific)
- Edge-to-edge: `enableEdgeToEdge()` in Activity, handle insets via `Modifier.padding()`
- No `@Preview` in core modules (only in `ui/` screens)

### DI (Hilt)
- `@HiltAndroidApp` on Application
- `@AndroidEntryPoint` on Activity and Service
- `@Singleton` for app-scoped dependencies
- `@Provides` in `di/` modules, not in classes
- Keep DI modules thin — just wiring, no logic

### Architecture Rules
- `core/` must never import from `dev.vz.ljod.ui`, `dev.vz.ljod.data`, or `dev.vz.ljod.app`
- `playback/` must never import from `ui/` or `app/`
- `ui/` screens import from `core/` and `playback/` only
- `app/` (LjodShell) is the only place that imports everything
- Data flows: `MediaScanner` → `PlaybackController` → UI StateFlows
- Room entities use `@Entity` + `@Dao` pattern (no raw SQL in business logic)

### Security
- No hardcoded API keys, tokens, or secrets
- `lint.xml` blocks: `TrustAllX509TrustManager`, `HardcodedDebugMode`, `Disclosure`
- ProGuard/R8 enabled for release builds
- `exported=false` on all components except MainActivity and PlaybackService
- `enableOnBackInvokedCallback` for predictive back gesture

### Git
- Commit messages: `<type>: <description>` (conventional commits)
- Types: `feat`, `fix`, `refactor`, `chore`, `docs`, `style`, `test`
- No commits to master without review (for public repos)
- Branches: `feat/<name>`, `fix/<name>`, `refactor/<name>`

## Dependencies

| Library | Version | Purpose |
|---------|---------|---------|
| Compose BOM | 2024.12.01 | UI toolkit |
| Material3 | (BOM) | Design system |
| Media3 | 1.5.1 | ExoPlayer + MediaSession |
| Hilt | 2.53.1 | DI |
| Room | 2.6.1 | SQLite persistence |
| Timber | 5.0.1 | Logging |
| Kotlinx Serialization | 1.7.3 | JSON |
| Detekt | 1.23.7 | Static analysis |

**Not included (intentionally):**
- Coil/Glide — add when needed for album art
- Navigation Compose — custom `ScreenHost` handles nav
- Retrofit/OkHttp — add when network features needed
- DataStore — add for preferences (Room used for music data)

## Extending

### Add a new screen
1. Create `ui/<name>/<Name>Screen.kt`
2. Add `Screen(key, icon, label, content)` to `LjodShell.kt` screens list
3. Add vector icon to `res/drawable/`

### Add a new palette
1. Add `LjodPalette(...)` to `LjodPalettes` in `core/ui/theme/Palette.kt`
2. Reference via `LjodPalettes.YourName`

### Add a new dependency
1. Add to `gradle/libs.versions.toml`
2. Add `implementation`/`ksp` to `app/build.gradle.kts`
3. Run `./gradlew :app:dependencies` to verify resolution

## Known Issues / TODO
- [ ] Album art loading (needs image library)
- [ ] Preferences/DataStore for settings
- [ ] Notification controls
- [ ] Widget support
- [ ] Search functionality
- [ ] Equalizer integration
