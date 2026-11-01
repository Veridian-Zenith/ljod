import 'dart:async';
import 'dart:io';

import 'package:audio_service/audio_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ljod/core/models/song_model.dart';
import 'package:ljod/features/player/lyrics_sheet.dart';
import 'package:ljod/services/audio/audio_providers.dart';
import 'package:ljod/services/lyrics/lyrics_service.dart';
import 'package:ljod/services/settings/settings_provider.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

SongModel _song({
  String id = 'song-1',
  String title = 'Ember',
  String artist = 'VZ',
  String album = 'Forge',
  Duration duration = const Duration(minutes: 3, seconds: 20),
  String path = '/music/ember.flac',
}) {
  return SongModel(
    id: id,
    path: path,
    title: title,
    artist: artist,
    album: album,
    duration: duration,
    addedAt: DateTime(2026, 1, 1),
  );
}

const _lrc = '[00:01.00]First line\n[00:04.50]Second line';

Lyrics _lyrics({String text = _lrc}) => Lyrics.parse(text, source: 'LRCLIB')!;

class _FakeRemote implements LyricsRemote {
  _FakeRemote(this.respond);

  FutureOr<RemoteLyricsResult> Function(LyricsQuery query) respond;
  int calls = 0;
  final List<LyricsQuery> queries = [];

  @override
  Future<RemoteLyricsResult> lookup(LyricsQuery query) async {
    calls++;
    queries.add(query);
    return respond(query);
  }
}

void main() {
  late Directory temp;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('ljod-lyrics-');
  });

  tearDown(() {
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  LyricsService service(LyricsRemote remote) =>
      LyricsService(remote: remote, cacheRoot: () async => temp);

  test('one request, then the cache answers', () async {
    final remote = _FakeRemote((_) => RemoteLyricsHit(_lyrics()));

    final first = await service(remote).load(_song(), allowOnline: true);
    expect(first.hasLyrics, isTrue);
    expect(first.cached, isFalse);

    // A fresh service proves the answer came from disk, not memory.
    final second = await service(remote).load(_song(), allowOnline: true);

    expect(remote.calls, 1);
    expect(second.hasLyrics, isTrue);
    expect(second.cached, isTrue);
    expect(second.lyrics!.lines.length, 2);
  });

  test('a definitive miss is cached so it is never asked again', () async {
    final remote = _FakeRemote((_) => const RemoteLyricsMiss());

    expect(
      (await service(remote).load(_song(), allowOnline: true)).status,
      LyricsStatus.notFound,
    );
    expect(
      (await service(remote).load(_song(), allowOnline: true)).status,
      LyricsStatus.notFound,
    );

    expect(remote.calls, 1, reason: 'notFound must not refetch on reopen');
  });

  test('instrumental listings are cached too', () async {
    final remote = _FakeRemote(
      (_) => const RemoteLyricsHit(null, instrumental: true),
    );

    expect(
      (await service(remote).load(_song(), allowOnline: true)).status,
      LyricsStatus.instrumental,
    );
    expect(
      (await service(remote).load(_song(), allowOnline: true)).status,
      LyricsStatus.instrumental,
    );
    expect(remote.calls, 1);
  });

  test('manual refresh bypasses the cache', () async {
    final remote = _FakeRemote((_) => const RemoteLyricsMiss());

    await service(remote).load(_song(), allowOnline: true);
    await service(remote).load(_song(), allowOnline: true);
    expect(remote.calls, 1);

    await service(remote).load(_song(), allowOnline: true, force: true);
    expect(remote.calls, 2);
  });

  test('transient failures are not cached', () async {
    var attempt = 0;
    final remote = _FakeRemote((_) {
      attempt++;
      return attempt == 1
          ? const RemoteLyricsFailure('offline')
          : RemoteLyricsHit(_lyrics());
    });

    final loader = service(remote);
    expect(
      (await loader.load(_song(), allowOnline: true)).status,
      LyricsStatus.failed,
    );
    final retry = await loader.load(_song(), allowOnline: true);
    expect(retry.hasLyrics, isTrue);
    expect(remote.calls, 2);
  });

  test('LRCLIB query carries normalised metadata and a valid duration', () {
    final query = LyricsQuery.fromSong(
      _song(title: '  Ember   Rising ', artist: ' VZ ', album: ' Forge '),
    );

    expect(query.getParams['track_name'], 'Ember Rising');
    expect(query.getParams['artist_name'], 'VZ');
    expect(query.getParams['album_name'], 'Forge');
    expect(query.getParams['duration'], '200');
  });

  test('duration outside LRCLIB bounds is omitted instead of rejected', () {
    final long = LyricsQuery.fromSong(
      _song(duration: const Duration(hours: 1, minutes: 20)),
    );
    final unknown = LyricsQuery.fromSong(_song(duration: Duration.zero));

    expect(long.durationSeconds, isNull);
    expect(long.getParams.containsKey('duration'), isFalse);
    expect(unknown.getParams.containsKey('duration'), isFalse);
  });

  test('re-tagging a track invalidates its cached lyrics', () async {
    final remote = _FakeRemote((_) => RemoteLyricsHit(_lyrics()));
    final loader = service(remote);

    await loader.load(_song(), allowOnline: true);
    await loader.load(_song(title: 'Ember (Live)'), allowOnline: true);

    expect(remote.calls, 2);
  });

  test('a rate-limit cooldown prevents an immediate retry', () async {
    final remote = _FakeRemote(
      (_) => const RemoteLyricsFailure(
        'slow down',
        retryAfter: Duration(seconds: 30),
      ),
    );
    final loader = service(remote);

    final first = await loader.load(_song(), allowOnline: true);
    expect(first.status, LyricsStatus.failed);
    expect(first.retryAfter, isNotNull);

    final second = await loader.load(_song(), allowOnline: true);
    expect(second.status, LyricsStatus.failed);
    expect(remote.calls, 1, reason: 'Retry-After must be honoured');
  });

  test('concurrent opens share a single request', () async {
    final gate = Completer<RemoteLyricsResult>();
    final remote = _FakeRemote((_) => gate.future);
    final loader = service(remote);

    final a = loader.load(_song(), allowOnline: true);
    final b = loader.load(_song(), allowOnline: true);
    gate.complete(RemoteLyricsHit(_lyrics()));

    final results = await Future.wait([a, b]);
    expect(remote.calls, 1);
    expect(results.every((result) => result.hasLyrics), isTrue);
  });

  test('a sidecar file wins without any network call', () async {
    final remote = _FakeRemote((_) => RemoteLyricsHit(_lyrics()));
    final track = File('${temp.path}/track.flac')..writeAsStringSync('');
    File('${temp.path}/track.lrc').writeAsStringSync(_lrc);

    final result = await service(remote)
        .load(_song(path: track.path), allowOnline: true);

    expect(result.hasLyrics, isTrue);
    expect(result.lyrics!.source, 'sidecar');
    expect(remote.calls, 0);
  });

  test('online lookup switched off never reaches the network', () async {
    final remote = _FakeRemote((_) => RemoteLyricsHit(_lyrics()));
    final result = await service(remote).load(_song(), allowOnline: false);

    expect(result.status, LyricsStatus.disabled);
    expect(remote.calls, 0);
  });

  testWidgets('romanization renders under the original lyric', (tester) async {
    SharedPreferences.setMockInitialValues({});
    final preferences = await SharedPreferences.getInstance();
    final song = _song(title: 'Amber', path: '/music/amber.flac');
    final lyrics = Lyrics.parse(
      '[00:00.00]爱你\n[00:03.00]hello world',
      source: 'LRCLIB',
    )!;

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(preferences),
          audioHandlerProvider.overrideWithValue(_SilentAudioHandler()),
          positionProvider.overrideWith((ref) => Stream.value(Duration.zero)),
          lyricsProvider(song.id)
              .overrideWith((ref) async => LyricsResult.found(lyrics)),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: SizedBox(height: 720, child: LyricsSheet(song: song)),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    // The original line stays, and a romanization appears beneath it.
    expect(find.text('爱你'), findsOneWidget);
    expect(find.textContaining('ai'), findsWidgets);
    expect(find.text('hello world'), findsOneWidget);
  });
}

/// Media handler that never touches native audio plugins.
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
