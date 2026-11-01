import 'package:audio_service/audio_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ljod/core/models/song_model.dart';
import 'package:ljod/core/utils/formatters.dart';
import 'package:ljod/features/settings/settings_screen.dart';
import 'package:ljod/main.dart';
import 'package:ljod/services/audio/audio_providers.dart';
import 'package:ljod/services/library/library_providers.dart';
import 'package:ljod/services/settings/settings_provider.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('duration formatting handles minutes, hours and emptiness', () {
    expect(formatDuration(const Duration(minutes: 2, seconds: 3)), '02:03');
    expect(
      formatDuration(const Duration(hours: 1, minutes: 2, seconds: 3)),
      '1:02:03',
    );
    expect(formatDuration(Duration.zero), '--:--');
  });

  test('online lyrics lookup is opt-in by default', () async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final container = ProviderContainer(
      overrides: [sharedPreferencesProvider.overrideWithValue(preferences)],
    );
    addTearDown(container.dispose);

    expect(container.read(settingsProvider).lyricsLookup, isFalse);
  });

  testWidgets('LjodApp renders the shell and navigation', (tester) async {
    await _pumpApp(tester);

    expect(find.text('LJOD'), findsOneWidget);
    expect(find.byIcon(Icons.home_rounded), findsOneWidget);
    expect(find.byIcon(Icons.search_rounded), findsOneWidget);
    expect(find.byIcon(Icons.library_music_rounded), findsOneWidget);
    expect(find.byIcon(Icons.settings_rounded), findsOneWidget);
  });

  testWidgets('shell and settings fit a phone viewport', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);

    await _pumpApp(tester);

    await tester.tap(find.bySemanticsLabel('Search'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('SEARCH'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Library'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('LIBRARY'), findsOneWidget);

    await tester.tap(find.bySemanticsLabel('Settings'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('SETTINGS'), findsOneWidget);
    expect(find.text('Scan'.toUpperCase()), findsOneWidget);
    expect(find.text('Listening'), findsOneWidget);

    // The About card sits below the fold; scroll to it and confirm the
    // setup-tour entry is reachable, not just declared.
    await tester.scrollUntilVisible(
      find.text('Replay setup tour'),
      240,
      scrollable: find
          .descendant(
            of: find.byType(SettingsScreen),
            matching: find.byType(Scrollable),
          )
          .first,
    );
    await tester.ensureVisible(find.text('Replay setup tour'));
    await tester.pumpAndSettle();
    expect(find.text('Replay setup tour'), findsOneWidget);

    // Tapping it must open the tour in replay mode (close, not skip).
    await tester.tap(find.text('Replay setup tour'));
    await tester.pumpAndSettle();
    expect(find.text('Close'), findsOneWidget);
    expect(find.text('Your music.\nYour device.'), findsOneWidget);
  });

  testWidgets('home insights strip opens the insights screen', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(390, 844);
    addTearDown(tester.view.reset);

    await _pumpApp(tester, library: _SampleLibraryNotifier.new);

    expect(find.text('INSIGHTS'), findsOneWidget);

    await tester.tap(find.text('INSIGHTS'));
    await tester.pumpAndSettle();

    // The dedicated screen renders real aggregates from the library.
    expect(find.text('TOTAL SPIN'), findsOneWidget);
    expect(find.text('RANKINGS'), findsOneWidget);
    expect(find.text('Amber'), findsWidgets);
  });

  testWidgets('playback failures surface and are cleared', (tester) async {
    await _pumpApp(tester);

    final container = ProviderScope.containerOf(
      tester.element(find.text('LJOD')),
    );
    container
        .read(playbackErrorProvider.notifier)
        .report('Could not open a track: unsupported format');

    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.textContaining('Could not open a track'), findsOneWidget);
    expect(container.read(playbackErrorProvider), isNull);
  });

  testWidgets('setup flow can finish', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    await preferences.setBool('ljod.setup.completed', false);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          audioHandlerProvider.overrideWithValue(_SilentAudioHandler()),
          libraryProvider.overrideWith(_EmptyLibraryNotifier.new),
        ],
        child: const LjodApp(showSetup: true),
      ),
    );
    await tester.pump();
    expect(find.byType(FilledButton), findsWidgets);
    expect(find.text('LJOD'), findsOneWidget);
  });
}

Future<void> _pumpApp(
  WidgetTester tester, {
  LibraryNotifier Function()? library,
}) async {
  SharedPreferences.setMockInitialValues({});
  final preferences = await SharedPreferences.getInstance();
  await preferences.setBool('ljod.setup.completed', true);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
        audioHandlerProvider.overrideWithValue(_SilentAudioHandler()),
        libraryProvider.overrideWith(library ?? _EmptyLibraryNotifier.new),
      ],
      child: const LjodApp(),
    ),
  );
  await tester.pump();
}

class _EmptyLibraryNotifier extends LibraryNotifier {
  @override
  Future<LibraryState> build() async => const LibraryState();
}

class _SampleLibraryNotifier extends LibraryNotifier {
  @override
  Future<LibraryState> build() async => LibraryState(
    songs: [
      SongModel(
        id: '1',
        path: '/music/a.mp3',
        title: 'Amber',
        artist: 'VZ',
        album: 'Forge',
        duration: const Duration(minutes: 3),
        isFavorite: true,
        playCount: 4,
        addedAt: DateTime.now(),
      ),
      SongModel(
        id: '2',
        path: '/music/b.mp3',
        title: 'Ember',
        artist: 'VZ',
        album: 'Forge',
        duration: const Duration(minutes: 4),
        addedAt: DateTime.now(),
      ),
    ],
    lastScan: DateTime.now(),
  );
}

/// A media handler that never touches native audio plugins.
class _SilentAudioHandler extends BaseAudioHandler
    implements LjodPlaybackHandler {
  @override
  Stream<Duration> get positionStream => Stream<Duration>.empty();

  @override
  Stream<Duration> get bufferedPositionStream => Stream<Duration>.empty();

  @override
  Stream<Duration?> get durationStream => Stream<Duration?>.empty();

  @override
  Stream<bool> get playingStream => Stream<bool>.empty();

  @override
  Stream<int?> get currentIndexStream => Stream<int?>.empty();

  @override
  Stream<SongModel?> get currentSongStream => Stream<SongModel?>.empty();

  @override
  List<SongModel> get songs => const [];

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
