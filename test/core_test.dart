import 'package:audio_service/audio_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ljod/core/models/song_model.dart';
import 'package:ljod/core/utils/formatters.dart';
import 'package:ljod/services/audio/audio_providers.dart';
import 'package:ljod/services/library/library_providers.dart';
import 'package:ljod/services/lyrics/lyrics_service.dart';
import 'package:ljod/services/stats/stats_provider.dart';

/// Records seeks so the controller's clamping can be asserted without a
/// native player.
class _RecordingHandler extends BaseAudioHandler
    implements LjodPlaybackHandler {
  _RecordingHandler({required Duration position, Duration? duration}) {
    playbackState.add(PlaybackState(updatePosition: position));
    mediaItem.add(MediaItem(id: 'test', title: 'Test', duration: duration));
  }

  final List<Duration> seeks = [];

  @override
  Future<void> seek(Duration position) async => seeks.add(position);

  @override
  Stream<Duration> get positionStream => const Stream<Duration>.empty();

  @override
  Stream<Duration> get bufferedPositionStream => const Stream<Duration>.empty();

  @override
  Stream<Duration?> get durationStream => const Stream<Duration?>.empty();

  @override
  Stream<bool> get playingStream => const Stream<bool>.empty();

  @override
  Stream<int?> get currentIndexStream => const Stream<int?>.empty();

  @override
  Stream<SongModel?> get currentSongStream => const Stream<SongModel?>.empty();

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
  Future<void> disposePlayer() async {}
}

void main() {
  group('lyrics parsing', () {
    test('synced LRC lines are sorted and resolved by position', () {
      final lyrics = Lyrics.parse(
        '[00:02.00]Second\n[00:01.50]First\n[00:03.25]Third\n',
      );

      expect(lyrics, isNotNull);
      expect(lyrics!.synced, isTrue);
      expect(lyrics.lines.map((line) => line.text), [
        'First',
        'Second',
        'Third',
      ]);
      expect(lyrics.activeLine(Duration.zero), -1);
      expect(lyrics.activeLine(const Duration(milliseconds: 1600)), 0);
      expect(lyrics.activeLine(const Duration(seconds: 2)), 1);
      expect(lyrics.activeLine(const Duration(seconds: 4)), 2);
    });

    test('plain lyrics stay unsynced and metadata tags are ignored', () {
      final lyrics = Lyrics.parse(
        '[ar:Someone]\n[ti:A song]\nFirst line\nSecond line\n',
      );

      expect(lyrics, isNotNull);
      expect(lyrics!.synced, isFalse);
      expect(lyrics.lines.map((line) => line.text), [
        'First line',
        'Second line',
      ]);
      expect(lyrics.activeLine(const Duration(seconds: 2)), -1);
    });

    test('empty and whitespace-only payloads are rejected', () {
      expect(Lyrics.parse('   \n\n '), isNull);
    });
  });

  group('playback controller', () {
    test('seekBy clamps inside the track bounds', () async {
      final handler = _RecordingHandler(
        position: const Duration(seconds: 30),
        duration: const Duration(seconds: 60),
      );
      final container = ProviderContainer(
        overrides: [audioHandlerProvider.overrideWithValue(handler)],
      );
      addTearDown(container.dispose);
      final controller = container.read(playbackControllerProvider);

      await controller.seekBy(const Duration(seconds: -10));
      await controller.seekBy(const Duration(seconds: -60));
      await controller.seekBy(const Duration(seconds: 90));

      expect(handler.seeks, [
        const Duration(seconds: 20),
        Duration.zero,
        const Duration(seconds: 60),
      ]);
    });

    test('seekBy still works when the duration is unknown', () async {
      final handler = _RecordingHandler(position: const Duration(seconds: 5));
      final container = ProviderContainer(
        overrides: [audioHandlerProvider.overrideWithValue(handler)],
      );
      addTearDown(container.dispose);

      await container
          .read(playbackControllerProvider)
          .seekBy(const Duration(seconds: 10));

      expect(handler.seeks, [const Duration(seconds: 15)]);
    });
  });

  group('romanization', () {
    test('maps common Chinese characters and leaves Latin text alone', () {
      final romanized = romanizeLyrics('爱你');
      expect(romanized, contains('ai'));
      expect(romanized, contains('ni'));
      expect(romanizeLyrics('hello world'), 'hello world');
    });

    test('unmapped scripts collapse so the lyrics sheet can fall back', () {
      expect(romanizeLyrics('ありがとう').trim(), isEmpty);
    });
  });

  group('library stats', () {
    test('aggregates favourites, albums and play counts', () {
      final now = DateTime.now();
      final container = ProviderContainer(
        overrides: [
          songsProvider.overrideWithValue([
            SongModel(
              id: '1',
              path: '/music/a.mp3',
              title: 'A',
              artist: 'X',
              album: 'One',
              duration: const Duration(minutes: 3),
              isFavorite: true,
              playCount: 5,
              addedAt: now,
            ),
            SongModel(
              id: '2',
              path: '/music/b.mp3',
              title: 'B',
              artist: 'X',
              album: 'One',
              duration: const Duration(minutes: 4),
              playCount: 2,
              addedAt: now.subtract(const Duration(days: 3)),
            ),
            SongModel(
              id: '3',
              path: '/music/c.mp3',
              title: 'C',
              artist: 'Y',
              album: 'Two',
              duration: const Duration(minutes: 2),
              addedAt: now.subtract(const Duration(days: 90)),
            ),
          ]),
        ],
      );
      addTearDown(container.dispose);

      final stats = container.read(statsProvider);
      expect(stats.totalTracks, 3);
      expect(stats.totalAlbums, 2);
      expect(stats.totalFavorites, 1);
      expect(stats.totalPlayCount, 7);
      expect(stats.mostPlayedSong?.id, '1');
      expect(stats.recentlyAddedCount, 2);

      // Plays × track length, only counting tracks that were played.
      expect(stats.listeningTime, const Duration(minutes: 23));
      expect(stats.mostPlayed.map((song) => song.id), ['1', '2']);
      expect(stats.topArtists.map((artist) => artist.name), ['X']);
      expect(stats.topArtists.first.plays, 7);
      expect(stats.topArtists.first.tracks, 2);
      expect(stats.topArtists.first.shareOf(7), 1.0);
    });

    test('an empty library reports zeroes and no most-played track', () {
      final container = ProviderContainer(
        overrides: [songsProvider.overrideWithValue(const [])],
      );
      addTearDown(container.dispose);

      final stats = container.read(statsProvider);
      expect(stats.totalTracks, 0);
      expect(stats.totalPlayCount, 0);
      expect(stats.mostPlayedSong, isNull);
    });
  });

  group('song model', () {
    test('database mapping round-trips metadata and user state', () {
      final song = SongModel(
        id: '42',
        path: '/music/Artist - Track.mp3',
        title: 'Track',
        artist: 'Artist',
        album: 'Album',
        albumArtist: 'Album Artist',
        duration: const Duration(minutes: 3, seconds: 12),
        trackNumber: 4,
        artworkPath: '/cache/art.jpg',
        isFavorite: true,
        playCount: 9,
        lastPlayed: DateTime.fromMillisecondsSinceEpoch(1700000000000),
        addedAt: DateTime.fromMillisecondsSinceEpoch(1600000000000),
      );

      final restored = SongModel.fromDbMap(song.toDbMap());

      expect(restored.id, song.id);
      expect(restored.path, song.path);
      expect(restored.title, song.title);
      expect(restored.artist, song.artist);
      expect(restored.album, song.album);
      expect(restored.albumArtist, song.albumArtist);
      expect(restored.duration, song.duration);
      expect(restored.trackNumber, song.trackNumber);
      expect(restored.artworkPath, song.artworkPath);
      expect(restored.isFavorite, isTrue);
      expect(restored.playCount, 9);
      expect(restored.lastPlayed, song.lastPlayed);
      expect(restored.addedAt, song.addedAt);
    });

    test('filename fallback parses artist and title', () {
      final parsed = parseFileStem('/music/Some Artist - A Title.flac');
      expect(parsed.artist, 'Some Artist');
      expect(parsed.title, 'A Title');

      final untagged = parseFileStem('/music/Just A Title.mp3');
      expect(untagged.artist, 'Unknown artist');
      expect(untagged.title, 'Just A Title');
    });
  });
}
