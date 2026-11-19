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
import 'package:ljod/features/stats/stats_screen.dart';
import 'package:ljod/main.dart';
import 'package:ljod/services/audio/audio_providers.dart';
import 'package:ljod/services/library/library_providers.dart';
import 'package:ljod/services/library/online_artwork.dart';
import 'package:ljod/services/lyrics/lyrics_service.dart';
import 'package:ljod/services/settings/settings_provider.dart';
import 'package:material_ui/material_ui.dart';

/// Renders the real screens with real fonts straight into `screenshots/`.
///
/// Run with:
///   flutter test tool/screenshots/screens_test.dart --update-goldens
///
/// The output is not a test fixture: these are the images README.md embeds, so
/// they are written to `screenshots/` rather than to a private goldens folder
/// that a copy step could leave behind. Every image is 780x1688 (a 390x844
/// phone at 2x) because six screenshots at four different sizes is how the
/// documentation ended up showing the wrong build.
///
/// To view them, run `python3 tool/screenshots/serve.py` and register
/// `http://127.0.0.1:8765/` as the preview. Regenerate, then reload: the server
/// reads the PNGs from disk, so the pixels refresh without touching any HTML.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(_loadFonts);

  testWidgets('home', (tester) async {
    await _configureView(tester);
    await _pumpApp(tester);
    await _capture(tester, 'home');
  });

  testWidgets('library', (tester) async {
    await _configureView(tester);
    await _pumpApp(tester);
    await _tapNav(tester, 2);
    await _capture(tester, 'library');
  });

  testWidgets('player', (tester) async {
    await _configureView(tester);
    await _pumpApp(tester);
    // The mini player is the first bar in the tree; tapping its body opens the
    // full player.
    await tester.tapAt(tester.getCenter(find.byType(LjodBar).first));
    await _settle(tester);
    await _capture(tester, 'player');
  });

  testWidgets('lyrics', (tester) async {
    await _configureView(tester);
    await _pumpApp(tester);
    await tester.tapAt(tester.getCenter(find.byType(LjodBar).first));
    await _settle(tester);
    // The lyrics button sits on the player next to the track title.
    await tester.tap(find.byIcon(Icons.lyrics_rounded).first);
    await _settle(tester, frames: 20);
    await _capture(tester, 'lyrics');
  });

  testWidgets('settings', (tester) async {
    await _configureView(tester);
    await _pumpApp(tester);
    await _tapNav(tester, 3);
    await _capture(tester, 'settings');
  });

  testWidgets('insights', (tester) async {
    await _configureView(tester);
    // Insights is a pushed route, so it is rendered on its own rather than
    // reached through the shell: same screen, same providers, one less tap
    // that a layout change could break.
    await tester.pumpWidget(
      ProviderScope(
        overrides: _overrides,
        child: MaterialApp(
          // The real app hides this; without it the ribbon lands in the docs.
          debugShowCheckedModeBanner: false,
          theme: LjodTheme.build(),
          darkTheme: LjodTheme.build(),
          themeMode: ThemeMode.dark,
          home: const StatsScreen(),
        ),
      ),
    );
    await _settle(tester);
    await _capture(tester, 'insights');
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
        debugShowCheckedModeBanner: false,
        theme: LjodTheme.build(),
        darkTheme: LjodTheme.build(),
        home: const DiagnosticsScreen(),
      ),
    );
    // The log resolves through path_provider, which has no plugin here. Wait
    // past its timeout so the populated list is what gets captured.
    await _settle(tester, frames: 45);
    await _capture(tester, 'diagnostics');
  });
}

/// One phone, one scale, for every image the docs embed.
const _dpr = 2.0;
const _logicalSize = Size(390, 844);

Future<void> _configureView(WidgetTester tester) async {
  tester.view.devicePixelRatio = _dpr;
  tester.view.physicalSize = Size(
    _logicalSize.width * _dpr,
    _logicalSize.height * _dpr,
  );
  tester.view.padding = const FakeViewPadding(
    top: 24 * _dpr,
    bottom: 34 * _dpr,
  );
  addTearDown(tester.view.reset);
}

Future<void> _capture(WidgetTester tester, String name) {
  return expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('../../screenshots/$name.png'),
  );
}

/// Taps a bottom-nav destination by position. The private `_NavItem` has no key
/// or stable label finder, but the items divide the bar evenly, so the centre of
/// each quarter is unambiguous.
Future<void> _tapNav(WidgetTester tester, int index) async {
  // The nav bar is the last bar in the tree; the mini player, when present, is
  // an earlier one.
  final rect = tester.getRect(find.byType(LjodBar).last);
  final slot = rect.width / 4;
  await tester.tapAt(Offset(rect.left + slot * (index + 0.5), rect.center.dy));
  await _settle(tester);
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

/// The provider set every screen is rendered against: a settled library, one
/// playing track and lyrics that came back from a lookup.
final _overrides = [
  // Defaults instead of SharedPreferences: the harness only needs the settled
  // UI, and a test-only prefs mock outside `test/` is exactly the kind of
  // scaffolding this is meant to avoid.
  settingsProvider.overrideWith(_DefaultSettings.new),
  audioHandlerProvider.overrideWithValue(_NowPlayingHandler()),
  libraryProvider.overrideWith(_SampleLibraryNotifier.new),
  lyricsProvider.overrideWith((ref, songId) async => _foundLyrics),
  // Settings shows a cache size and a lookup count; path_provider and SQLite
  // have no plugin here, so the rows would capture as "Measuring…" and "Tap to
  // look up covers again" instead of the real thing.
  lyricsCacheBytesProvider.overrideWith((ref) async => 182 * 1024),
  artworkLookupCountProvider.overrideWith((ref) async => 64),
];

Future<void> _pumpApp(WidgetTester tester) async {
  await tester.pumpWidget(
    ProviderScope(overrides: _overrides, child: const LjodApp()),
  );
  await _settle(tester);
}

const _foundLyrics = LyricsResult.found(
  Lyrics(
    synced: true,
    source: 'LRCLIB',
    lines: [
      LyricLine(
        time: Duration(seconds: 0),
        text: 'The forge is cold, the hammer resting',
      ),
      LyricLine(
        time: Duration(seconds: 14),
        text: 'Amber light across the floor',
      ),
      LyricLine(
        time: Duration(seconds: 29),
        text: 'Every ember keeps its story',
      ),
      LyricLine(time: Duration(seconds: 45), text: 'Every scar a little more'),
      LyricLine(
        time: Duration(minutes: 1, seconds: 2),
        text: 'I am counting what the fire gave',
      ),
      LyricLine(
        time: Duration(minutes: 1, seconds: 12),
        text: 'Nothing here was given twice',
      ),
      LyricLine(
        time: Duration(minutes: 1, seconds: 26),
        text: 'Hold the heat and let it hold you',
      ),
      LyricLine(
        time: Duration(minutes: 1, seconds: 41),
        text: 'Shape the silence, shape it warm',
      ),
      LyricLine(
        time: Duration(minutes: 1, seconds: 58),
        text: 'Amber on the anvil, burning',
      ),
      LyricLine(
        time: Duration(minutes: 2, seconds: 15),
        text: 'Amber, amber, keep me here',
      ),
      LyricLine(
        time: Duration(minutes: 2, seconds: 40),
        text: 'Ash is only what the flame leaves',
      ),
      LyricLine(
        time: Duration(minutes: 3, seconds: 5),
        text: 'And the flame has taken care',
      ),
    ],
  ),
);

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
  List<SongModel> get baseSongs => songs;

  @override
  bool get shuffleEnabled => false;

  @override
  Future<void> loadQueue(
    List<SongModel> songs, {
    int initialIndex = 0,
    Duration initialPosition = Duration.zero,
    bool autoPlay = true,
    bool? shuffle,
  }) async {}

  @override
  Future<void> setShuffleEnabled(bool enabled) async {}

  @override
  Future<void> reshuffle() async {}

  @override
  Future<void> setVolume(double volume) async {}

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) async {}

  @override
  Future<void> disposePlayer() async {}
}
