import 'dart:async';

import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';

import '../../core/diagnostics/diagnostics_log.dart';
import '../../core/models/song_model.dart';

class PlaybackException implements Exception {
  const PlaybackException(this.message);

  final String message;

  @override
  String toString() => message;
}

/// The slice of the playback handler the UI and controller depend on.
///
/// Keeping this separate from [LjodAudioHandler] lets widget tests supply a
/// silent handler without booting the native audio plugins.
abstract class LjodPlaybackHandler implements AudioHandler {
  Stream<Duration> get positionStream;
  Stream<Duration> get bufferedPositionStream;
  Stream<Duration?> get durationStream;
  Stream<bool> get playingStream;
  Stream<int?> get currentIndexStream;
  Stream<SongModel?> get currentSongStream;

  /// The songs currently loaded into the player, in queue order.
  List<SongModel> get songs;

  Future<void> loadQueue(
    List<SongModel> songs, {
    int initialIndex = 0,
    Duration initialPosition = Duration.zero,
    bool autoPlay = true,
  });

  Future<void> setShuffleEnabled(bool enabled);
  Future<void> setVolume(double volume);
  Future<void> disposePlayer();
}

/// Bridges `just_audio` into the Android media session / notification stack.
class LjodAudioHandler extends BaseAudioHandler
    with QueueHandler, SeekHandler
    implements LjodPlaybackHandler {
  LjodAudioHandler() : _player = AudioPlayer() {
    _subscriptions.add(
      _player.playbackEventStream.listen(
        (_) => _broadcastState(),
        onError: (Object error, StackTrace stack) {
          DiagnosticsLog.instance.log('player error: $error');
          playbackState.add(
            playbackState.value.copyWith(
              errorMessage: error.toString(),
              processingState: AudioProcessingState.error,
            ),
          );
        },
      ),
    );
    _subscriptions.add(
      _player.currentIndexStream.listen((index) {
        if (index == null || index < 0 || index >= _songs.length) return;
        mediaItem.add(_songs[index].toMediaItem());
        _broadcastState();
      }),
    );
    _subscriptions.add(_player.loopModeStream.listen((_) => _broadcastState()));
    _subscriptions.add(
      _player.shuffleModeEnabledStream.listen((_) => _broadcastState()),
    );
  }

  final AudioPlayer _player;
  final List<StreamSubscription<Object?>> _subscriptions = [];
  List<SongModel> _songs = const [];
  String? _loggedItemId;
  bool? _loggedPlaying;

  /// Breadcrumbs for the diagnostics trail: a crash while playing should leave
  /// the track and the last transport change behind it.
  void _logPlayback() {
    final item = mediaItem.value;
    if (item == null) return;
    final playing = _player.playing;
    if (item.id == _loggedItemId && playing == _loggedPlaying) return;
    _loggedItemId = item.id;
    _loggedPlaying = playing;
    DiagnosticsLog.instance.log(
      '${playing ? 'play' : 'pause'} “${item.title}”'
      '${item.artist == null ? '' : ' — ${item.artist}'}',
    );
  }

  AudioPlayer get player => _player;

  @override
  List<SongModel> get songs => _songs;

  @override
  Stream<Duration> get positionStream => _player.positionStream;
  @override
  Stream<Duration> get bufferedPositionStream => _player.bufferedPositionStream;
  @override
  Stream<Duration?> get durationStream => _player.durationStream;
  @override
  Stream<bool> get playingStream => _player.playingStream;
  @override
  Stream<int?> get currentIndexStream => _player.currentIndexStream;

  /// Emits the current [SongModel] as the queue advances, including auto-play.
  @override
  Stream<SongModel?> get currentSongStream {
    return _player.currentIndexStream.map((index) {
      if (index == null || index < 0 || index >= _songs.length) return null;
      return _songs[index];
    });
  }

  @override
  Future<void> loadQueue(
    List<SongModel> songs, {
    int initialIndex = 0,
    Duration initialPosition = Duration.zero,
    bool autoPlay = true,
  }) async {
    if (songs.isEmpty) {
      throw const PlaybackException('There is nothing in the queue to play.');
    }
    _songs = List.unmodifiable(songs);
    final index = initialIndex.clamp(0, songs.length - 1);
    DiagnosticsLog.instance.log(
      'queue: ${songs.length} tracks, starting at “${songs[index].title}”',
    );

    queue.add(_songs.map((song) => song.toMediaItem()).toList(growable: false));
    mediaItem.add(_songs[index].toMediaItem());

    final sources = _songs
        .map((song) {
          final uri = song.path.contains('://')
              ? Uri.parse(song.path)
              : Uri.file(song.path);
          return AudioSource.uri(uri, tag: song.toMediaItem());
        })
        .toList(growable: false);

    try {
      await _player.setAudioSources(
        sources,
        initialIndex: index,
        initialPosition: initialPosition,
      );
    } on PlayerException catch (error) {
      throw PlaybackException(
        'Could not open “${_songs[index].title}”: ${error.message}',
      );
    } on PlayerInterruptedException {
      // A newer load superseded this one; nothing to report.
      return;
    }

    if (autoPlay) await play();
  }

  @override
  Future<void> play() async {
    if (_player.audioSource == null) return;
    await _player.play();
  }

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> skipToNext() => _player.seekToNext();

  @override
  Future<void> skipToPrevious() async {
    if (_player.position > const Duration(seconds: 3)) {
      await _player.seek(Duration.zero);
    } else {
      await _player.seekToPrevious();
    }
  }

  @override
  Future<void> stop() async {
    await _player.stop();
    playbackState.add(
      playbackState.value.copyWith(
        processingState: AudioProcessingState.idle,
        playing: false,
      ),
    );
    await super.stop();
  }

  @override
  Future<void> setRepeatMode(AudioServiceRepeatMode repeatMode) async {
    await _player.setLoopMode(switch (repeatMode) {
      AudioServiceRepeatMode.one => LoopMode.one,
      AudioServiceRepeatMode.all => LoopMode.all,
      _ => LoopMode.off,
    });
    _broadcastState();
  }

  @override
  Future<void> setShuffleEnabled(bool enabled) async {
    await _player.setShuffleModeEnabled(enabled);
    _broadcastState();
  }

  @override
  Future<void> setVolume(double volume) => _player.setVolume(volume);

  void _broadcastState() {
    final processing = switch (_player.processingState) {
      ProcessingState.idle => AudioProcessingState.idle,
      ProcessingState.loading => AudioProcessingState.loading,
      ProcessingState.buffering => AudioProcessingState.buffering,
      ProcessingState.ready => AudioProcessingState.ready,
      ProcessingState.completed => AudioProcessingState.completed,
    };

    _logPlayback();

    playbackState.add(
      playbackState.value.copyWith(
        controls: [
          MediaControl.skipToPrevious,
          if (_player.playing) MediaControl.pause else MediaControl.play,
          MediaControl.skipToNext,
        ],
        androidCompactActionIndices: const [0, 1, 2],
        systemActions: const {MediaAction.seek},
        processingState: processing,
        playing: _player.playing,
        updatePosition: _player.position,
        bufferedPosition: _player.bufferedPosition,
        speed: _player.speed,
        queueIndex: _player.currentIndex,
        repeatMode: switch (_player.loopMode) {
          LoopMode.one => AudioServiceRepeatMode.one,
          LoopMode.all => AudioServiceRepeatMode.all,
          LoopMode.off => AudioServiceRepeatMode.none,
        },
        shuffleMode: _player.shuffleModeEnabled
            ? AudioServiceShuffleMode.all
            : AudioServiceShuffleMode.none,
      ),
    );
  }

  @override
  Future<void> disposePlayer() async {
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    await _player.dispose();
  }
}
