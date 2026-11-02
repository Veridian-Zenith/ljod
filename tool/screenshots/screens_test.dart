import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ljod/core/diagnostics/diagnostics_log.dart';
import 'package:ljod/core/models/song_model.dart';
import 'package:ljod/core/theme/ljod_theme.dart';
import 'package:ljod/core/widgets/vz_components.dart';
import 'package:ljod/features/settings/diagnostics_screen.dart';
import 'package:ljod/main.dart';
import 'package:ljod/services/audio/audio_providers.dart';
import 'package:ljod/services/library/library_providers.dart';
import 'package:ljod/services/settings/settings_provider.dart';
import 'package:material_ui/material_ui.dart';

/// Renders the real screens with real fonts into PNGs.
///
/// Run with:
///   flutter test tool/screenshots/screens_test.dart --update-goldens
///
/// The output lands in `tool/screenshots/goldens/` and is meant to be looked at,
/// not asserted: this is Flutter's screenshot tooling, kept out of `test/` so a
/// routine `flutter test` never depends on rendering.
///
/// To view them, run `python3 tool/screenshots/serve.py` and register
/// `http://127.0.0.1:8765/` as the preview. Regenerate, then reload: the server
/// reads the PNGs from disk, so the pixels refresh without touching any HTML.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(_loadFonts);

  testWidgets('home with a now-playing track', (tester) async {
    await _configureView(tester);
    await _pumpApp(tester);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/1-home.png'),
    );
  });

  testWidgets('player screen', (tester) async {
    await _configureView(tester);
    await _pumpApp(tester);
    // The mini player is the first bar in the tree; tapping its body opens the
    // full player.
    await tester.tapAt(tester.getCenter(find.byType(LjodBar).first));
    await _settle(tester);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/2-player.png'),
    );
  });

  testWidgets('diagnostics with warnings and errors only', (tester) async {
    await _configureView(tester);
    await DiagnosticsLog.instance.clear();
    await DiagnosticsLog.instance.record(
      'session start',
      level: DiagnosticsLevel.info,
    );
    await DiagnosticsLog.instance.record(
      'queue: 12 tracks, starting at “Amber”',
      level: DiagnosticsLevel.info,
    );
    await DiagnosticsLog.instance.record(
      'notification permission denied (denied); playback notification cannot '
      'be shown',
      level: DiagnosticsLevel.warning,
    );
    await DiagnosticsLog.instance.record(
      'flutter error: Undefined name\n#0 main (package:ljod/main.dart:12)',
      level: DiagnosticsLevel.error,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: LjodTheme.build(),
        darkTheme: LjodTheme.build(),
        home: const DiagnosticsScreen(),
      ),
    );
    // The log resolves through path_provider, which has no plugin here. Wait
    // past its timeout so the populated list is what gets captured.
    await _settle(tester, frames: 45);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/3-diagnostics.png'),
    );
  });
}

Future<void> _configureView(WidgetTester tester) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(390, 844);
  tester.view.padding = const FakeViewPadding(top: 24, bottom: 34);
  addTearDown(tester.view.reset);
}

Future<void> _settle(WidgetTester tester, {int frames = 12}) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// The app draws with bundled mono weights and Material icons; without them a
/// golden renders text as boxes and the layout is meaningless.
Future<void> _loadFonts() async {
  final mono = FontLoader('JetBrainsMono');
  for (final weight in const [
    'Regular',
    'Medium',
    'SemiBold',
    'Bold',
    'ExtraBold',
  ]) {
    mono.addFont(rootBundle.load('assets/fonts/JetBrainsMono-$weight.ttf'));
  }
  await mono.load();

  final flutterRoot =
      Platform.environment['FLUTTER_ROOT'] ?? '/home/dae/flutter';
  final icons = File(
    '$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
  );
  if (icons.existsSync()) {
    final loader = FontLoader('MaterialIcons')
      ..addFont(
        icons.readAsBytes().then((bytes) => ByteData.sublistView(bytes)),
      );
    await loader.load();
  } else {
    // ignore: avoid_print
    print('MaterialIcons not found at ${icons.path}; icons render as boxes.');
  }
}

Future<void> _pumpApp(WidgetTester tester) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        // Defaults instead of SharedPreferences: the harness only needs the
        // settled UI, and a test-only prefs mock outside `test/` is exactly the
        // kind of scaffolding this is meant to avoid.
        settingsProvider.overrideWith(_DefaultSettings.new),
        audioHandlerProvider.overrideWithValue(_NowPlayingHandler()),
        libraryProvider.overrideWith(_SampleLibraryNotifier.new),
      ],
      child: const LjodApp(),
    ),
  );
  await _settle(tester);
}

class _DefaultSettings extends SettingsNotifier {
  @override
  AppSettings build() => const AppSettings();
}

class _SampleLibraryNotifier extends LibraryNotifier {
  // The real notifier writes through sqflite, which has no host plugin in a
  // widget test; the screenshot only needs the state.
  @override
  Future<void> markPlayed(SongModel song) async {}

  @override
  Future<LibraryState> build() async => LibraryState(
    songs: [
      SongModel(
        id: '1',
        path: '/music/a.mp3',
        title: 'Amber',
        artist: 'Veridian Zenith',
        album: 'Forge',
        duration: const Duration(minutes: 3, seconds: 24),
        isFavorite: true,
        playCount: 12,
        addedAt: DateTime(2026, 10, 2),
      ),
      SongModel(
        id: '2',
        path: '/music/b.mp3',
        title: 'Ember',
        artist: 'Veridian Zenith',
        album: 'Forge',
        duration: const Duration(minutes: 4, seconds: 2),
        addedAt: DateTime(2026, 10, 12),
      ),
    ],
    lastScan: DateTime(2026, 11, 1, 12, 30),
  );
}

class _NowPlayingHandler extends BaseAudioHandler
    implements LjodPlaybackHandler {
  final SongModel _song = SongModel(
    id: '1',
    path: '/music/a.mp3',
    title: 'Amber',
    artist: 'Veridian Zenith',
    album: 'Forge',
    duration: const Duration(minutes: 3, seconds: 24),
    addedAt: DateTime(2026, 10, 2),
  );

  @override
  Stream<Duration> get positionStream =>
      Stream<Duration>.value(const Duration(minutes: 1, seconds: 12));

  @override
  Stream<Duration> get bufferedPositionStream =>
      Stream<Duration>.value(const Duration(minutes: 2));

  @override
  Stream<Duration?> get durationStream =>
      Stream<Duration?>.value(const Duration(minutes: 3, seconds: 24));

  @override
  Stream<bool> get playingStream => Stream<bool>.value(true);

  @override
  Stream<int?> get currentIndexStream => Stream<int?>.value(0);

  @override
  Stream<SongModel?> get currentSongStream => Stream<SongModel?>.value(_song);

  @override
  List<SongModel> get songs => [_song];

  @override
  Future<void> loadQueue(
    List<SongModel> songs, {
    int initialIndex = 0,
    Duration initialPosition = Duration.zero,
    bool autoPlay = true,
  }) async {}

  @override
  Future<void> setShuffleEnabled(bool enabled) async {}

  @override
  Future<void> setVolume(double volume) async {}

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) async {}

  @override
  Future<void> disposePlayer() async {}
}
