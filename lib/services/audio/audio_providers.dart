import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/song_model.dart';
import '../library/library_providers.dart';
import 'ljod_audio_handler.dart';

export 'ljod_audio_handler.dart'
    show LjodAudioHandler, LjodPlaybackHandler, PlaybackException;

/// Overridden in `main()` with the instance created by `AudioService.init`.
/// Widget tests override it with a silent handler.
final audioHandlerProvider = Provider<LjodPlaybackHandler>((ref) {
  throw UnimplementedError(
    'audioHandlerProvider must be overridden with an initialised handler.',
  );
});

final playbackStateProvider = StreamProvider<PlaybackState>((ref) {
  return ref.watch(audioHandlerProvider).playbackState;
});

final currentSongProvider = StreamProvider<SongModel?>((ref) {
  return ref.watch(audioHandlerProvider).currentSongStream;
});

final queueProvider = StreamProvider<List<MediaItem>>((ref) {
  return ref.watch(audioHandlerProvider).queue;
});

final positionProvider = StreamProvider<Duration>((ref) {
  return ref.watch(audioHandlerProvider).positionStream;
});

final bufferedPositionProvider = StreamProvider<Duration>((ref) {
  return ref.watch(audioHandlerProvider).bufferedPositionStream;
});

final durationProvider = StreamProvider<Duration?>((ref) {
  return ref.watch(audioHandlerProvider).durationStream;
});

final playingProvider = StreamProvider<bool>((ref) {
  return ref.watch(audioHandlerProvider).playingStream;
});

final nowPlayingProvider = Provider<SongModel?>((ref) {
  final playing = ref.watch(currentSongProvider).value;
  if (playing == null) return null;
  final songs = ref.watch(songsProvider);
  for (final song in songs) {
    if (song.id == playing.id) return song;
  }
  return playing;
});

final effectiveDurationProvider = Provider<Duration>((ref) {
  final streamed = ref.watch(durationProvider).value;
  final song = ref.watch(nowPlayingProvider);
  if (streamed != null && streamed > Duration.zero) return streamed;
  return song?.duration ?? Duration.zero;
});

final shuffleProvider = Provider<bool>((ref) {
  final state = ref.watch(playbackStateProvider).value;
  return state?.shuffleMode == AudioServiceShuffleMode.all;
});

final repeatModeProvider = Provider<AudioServiceRepeatMode>((ref) {
  return ref.watch(playbackStateProvider).value?.repeatMode ??
      AudioServiceRepeatMode.none;
});

/// Last playback failure, cleared once the shell has shown it.
///
/// `loadQueue` failures would otherwise only exist as an unawaited future from
/// a tap handler, so nothing would tell the listener why a track did not start.
final playbackErrorProvider = NotifierProvider<PlaybackErrorNotifier, String?>(
  PlaybackErrorNotifier.new,
);

class PlaybackErrorNotifier extends Notifier<String?> {
  @override
  String? build() => null;

  void report(String message) => state = message;

  void clear() => state = null;
}

final playbackControllerProvider = Provider<PlaybackController>(
  PlaybackController.new,
);

class PlaybackController {
  PlaybackController(this.ref) {
    _subscription = ref.read(audioHandlerProvider).currentSongStream.listen((
      song,
    ) {
      if (song == null) return;
      ref.read(libraryProvider.notifier).markPlayed(song);
    });
    ref.onDispose(() => _subscription.cancel());
  }

  final Ref ref;
  late final StreamSubscription<SongModel?> _subscription;

  LjodPlaybackHandler get _handler => ref.read(audioHandlerProvider);

  Future<void> playSong(SongModel song, {List<SongModel>? queue}) async {
    List<SongModel> songs = queue ?? ref.read(songsProvider);
    if (songs.isEmpty) songs = [song];
    if (!songs.any((item) => item.id == song.id)) {
      songs = [song, ...songs];
    }
    final index = songs.indexWhere((item) => item.id == song.id);

    await _loadQueue(songs, index < 0 ? 0 : index);
  }

  /// Loads a queue and reports failures instead of letting them escape as
  /// unhandled future errors from fire-and-forget tap handlers.
  Future<void> _loadQueue(List<SongModel> songs, int index) async {
    try {
      await _handler.loadQueue(songs, initialIndex: index);
    } on PlaybackException catch (error) {
      ref.read(playbackErrorProvider.notifier).report(error.message);
    } catch (error) {
      ref
          .read(playbackErrorProvider.notifier)
          .report('Playback failed: $error');
    }
  }

  Future<void> togglePlayPause() async {
    if (_handler.playbackState.value.playing) {
      await _handler.pause();
    } else {
      await _handler.play();
    }
  }

  Future<void> play() => _handler.play();

  Future<void> pause() => _handler.pause();

  Future<void> next() => _handler.skipToNext();

  Future<void> previous() => _handler.skipToPrevious();

  Future<void> seek(Duration position) => _handler.seek(position);

  Future<void> seekBy(Duration delta) async {
    final current = _handler.playbackState.value.updatePosition + delta;
    final duration = _handler.mediaItem.value?.duration ?? Duration.zero;
    var target = current;
    if (target < Duration.zero) target = Duration.zero;
    if (duration > Duration.zero && target > duration) target = duration;
    await _handler.seek(target);
  }

  Future<void> toggleShuffle() async {
    final enabled =
        _handler.playbackState.value.shuffleMode == AudioServiceShuffleMode.all;
    await _handler.setShuffleEnabled(!enabled);
  }

  Future<void> setShuffleEnabled(bool enabled) =>
      _handler.setShuffleEnabled(enabled);

  Future<void> setRepeatMode(AudioServiceRepeatMode mode) =>
      _handler.setRepeatMode(mode);

  Future<void> cycleRepeat() async {
    final next = switch (_handler.playbackState.value.repeatMode) {
      AudioServiceRepeatMode.none => AudioServiceRepeatMode.all,
      AudioServiceRepeatMode.all => AudioServiceRepeatMode.one,
      AudioServiceRepeatMode.one => AudioServiceRepeatMode.none,
      _ => AudioServiceRepeatMode.all,
    };
    await _handler.setRepeatMode(next);
  }

  Future<void> playFromQueue(int index) async {
    final songs = _handler.songs;
    if (index < 0 || index >= songs.length) return;
    await _loadQueue(songs, index);
  }

  Future<void> toggleFavorite(SongModel song) async {
    await ref.read(libraryProvider.notifier).toggleFavorite(song);
  }
}
