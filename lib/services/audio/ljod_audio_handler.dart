import 'dart:async';
import 'dart:math';

import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';

import '../../core/diagnostics/diagnostics_log.dart';
import '../../core/models/song_model.dart';
import 'shuffle_order.dart';

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

  /// The songs currently loaded into the player, in the order they will play.
  List<SongModel> get songs;

  /// The queue before shuffling, so the unshuffled order can be restored and
  /// persisted across launches.
  List<SongModel> get baseSongs;

  bool get shuffleEnabled;

  Future<void> loadQueue(
    List<SongModel> songs, {
    int initialIndex = 0,
    Duration initialPosition = Duration.zero,
    bool autoPlay = true,
    bool? shuffle,
  });

  Future<void> setShuffleEnabled(bool enabled);

  /// Deals the current queue again, keeping the playing track first.
  Future<void> reshuffle();
  Future<void> setVolume(double volume);
  Future<void> disposePlayer();
}

/// Bridges `just_audio` into the Android media session / notification stack.
///
/// Shuffle is handled here rather than by `just_audio`: the plugin's shuffle
/// order is private, so the notification and the app's up-next strip could not
/// agree with it. Ljod materialises the shuffled order as the queue itself, and
/// keeps `just_audio`'s own shuffle disabled. That makes "what plays next" a
/// property of the queue, which everything else already reads.
class LjodAudioHandler extends BaseAudioHandler
    with QueueHandler, SeekHandler
    implements LjodPlaybackHandler {
  LjodAudioHandler() : _player = AudioPlayer() {
    _subscriptions.add(
      _player.playbackEventStream.listen(
        (_) => _broadcastState(),
        onError: (Object error, StackTrace stack) {
          DiagnosticsLog.instance.log(
            'player error: $error',
            level: DiagnosticsLevel.error,
          );
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
  }

  final AudioPlayer _player;
  final List<StreamSubscription<Object?>> _subscriptions = [];
  final Random _random = Random();

  /// The queue as the caller handed it over, unshuffled.
  List<SongModel> _baseOrder = const [];

  /// The order that actually plays; equals [_baseOrder] when shuffle is off.
  List<SongModel> _songs = const [];

  bool _shuffle = false;
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
      level: DiagnosticsLevel.info,
    );
  }

  AudioPlayer get player => _player;

  @override
  List<SongModel> get songs => _songs;

  @override
  List<SongModel> get baseSongs => _baseOrder;

  @override
  bool get shuffleEnabled => _shuffle;

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
  ///
  /// Distinct by id: reordering the queue (shuffle on/off) changes the current
  /// index without changing the track, and that must not look like a new play.
  @override
  Stream<SongModel?> get currentSongStream {
    return _player.currentIndexStream
        .map((index) {
          if (index == null || index < 0 || index >= _songs.length) return null;
          return _songs[index];
        })
        .distinct((previous, next) => previous?.id == next?.id);
  }

  @override
  Future<void> loadQueue(
    List<SongModel> songs, {
    int initialIndex = 0,
    Duration initialPosition = Duration.zero,
    bool autoPlay = true,
    bool? shuffle,
  }) async {
    if (songs.isEmpty) {
      throw const PlaybackException('There is nothing in the queue to play.');
    }
    if (shuffle != null) _shuffle = shuffle;
    _baseOrder = List.unmodifiable(songs);

    final start = initialIndex.clamp(0, songs.length - 1);
    final order = _shuffle
        ? _applyShuffle(_baseOrder, first: start)
        : _baseOrder;
    DiagnosticsLog.instance.log(
      'queue: ${order.length} tracks'
      '${_shuffle ? ' (shuffled)' : ''}, starting at '
      '“${order[_shuffle ? 0 : start].title}”',
      level: DiagnosticsLevel.info,
    );

    await _applyQueue(
      order,
      _shuffle ? 0 : start,
      initialPosition: initialPosition,
      autoPlay: autoPlay,
    );
  }

  /// Swaps in a new playing order without losing the track position.
  Future<void> _applyQueue(
    List<SongModel> order,
    int index, {
    required Duration initialPosition,
    required bool autoPlay,
  }) async {
    _songs = List.unmodifiable(order);
    final start = index.clamp(0, _songs.length - 1);

    // One MediaItem per track, shared by the queue, the current item and the
    // audio-source tag. Building three copies of every entry for a
    // library-sized queue was the largest allocation on every queue load.
    final items = [for (final song in _songs) song.toMediaItem()];
    queue.add(List<MediaItem>.unmodifiable(items));
    mediaItem.add(items[start]);

    final sources = [
      for (var i = 0; i < _songs.length; i++)
        AudioSource.uri(_uriFor(_songs[i]), tag: items[i]),
    ];

    try {
      await _player.setAudioSources(
        sources,
        initialIndex: start,
        initialPosition: initialPosition,
      );
    } on PlayerException catch (error) {
      throw PlaybackException(
        'Could not open “${_songs[start].title}”: ${error.message}',
      );
    } on PlayerInterruptedException {
      // A newer load superseded this one; nothing to report.
      return;
    }

    _broadcastState();
    if (autoPlay) await play();
  }

  /// Scoped storage can hand back a `content://` URI instead of a path.
  static Uri _uriFor(SongModel song) =>
      song.path.contains('://') ? Uri.parse(song.path) : Uri.file(song.path);

  List<SongModel> _applyShuffle(List<SongModel> songs, {int first = 0}) {
    final order = shuffledOrder(songs.length, first: first, random: _random);
    return [for (final index in order) songs[index]];
  }

  SongModel? _currentSong() {
    final index = _player.currentIndex;
    if (index == null || index < 0 || index >= _songs.length) return null;
    return _songs[index];
  }

  @override
  Future<void> setShuffleEnabled(bool enabled) async {
    if (_shuffle == enabled) return;
    _shuffle = enabled;
    if (_songs.isEmpty) {
      _broadcastState();
      return;
    }

    final current = _currentSong();
    final position = _player.position;
    final wasPlaying = _player.playing;
    final baseIndex = current == null
        ? 0
        : _baseOrder.indexWhere((song) => song.id == current.id);
    final start = baseIndex < 0 ? 0 : baseIndex;

    // Reloading the same track would be pointless churn for a queue of one.
    if (_baseOrder.length <= 1) {
      _broadcastState();
      return;
    }

    await _applyQueue(
      _shuffle ? _applyShuffle(_baseOrder, first: start) : _baseOrder,
      _shuffle ? 0 : start,
      initialPosition: position,
      autoPlay: wasPlaying,
    );
  }

  @override
  Future<void> reshuffle() async {
    if (_songs.isEmpty) return;
    if (!_shuffle) {
      await setShuffleEnabled(true);
      return;
    }

    final current = _currentSong();
    final position = _player.position;
    final wasPlaying = _player.playing;
    final baseIndex = current == null
        ? 0
        : _baseOrder.indexWhere((song) => song.id == current.id);

    await _applyQueue(
      _applyShuffle(_baseOrder, first: baseIndex < 0 ? 0 : baseIndex),
      0,
      initialPosition: position,
      autoPlay: wasPlaying,
    );
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

  /// Jumps to a queue entry without rebuilding the queue, so the shuffled order
  /// the listener is looking at stays intact.
  @override
  Future<void> skipToQueueItem(int index) async {
    if (index < 0 || index >= _songs.length) return;
    await _player.seek(Duration.zero, index: index);
    if (!_player.playing) await play();
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
  Future<void> setVolume(double volume) => _player.setVolume(volume);

  /// Last state broadcast, so pure position ticks are not republished five
  /// times a second.
  DateTime _lastBroadcast = DateTime.fromMillisecondsSinceEpoch(0);
  String? _broadcastKey;

  void _broadcastState() {
    _logPlayback();

    // `playbackEventStream` emits on every position tick. The media session
    // extrapolates the position from `updatePosition` and the speed, so a real
    // state change goes out immediately and a bare position tick at most once
    // a second — the rest was an allocation and a platform-channel message per
    // 200 ms for the whole session.
    final key =
        '${_player.processingState}|${_player.playing}|'
        '${_player.currentIndex}|${_player.loopMode}|${_player.speed}|$_shuffle';
    final now = DateTime.now();
    if (key == _broadcastKey &&
        now.difference(_lastBroadcast) < const Duration(seconds: 1)) {
      return;
    }
    _broadcastKey = key;
    _lastBroadcast = now;

    final processing = switch (_player.processingState) {
      ProcessingState.idle => AudioProcessingState.idle,
      ProcessingState.loading => AudioProcessingState.loading,
      ProcessingState.buffering => AudioProcessingState.buffering,
      ProcessingState.ready => AudioProcessingState.ready,
      ProcessingState.completed => AudioProcessingState.completed,
    };

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
        shuffleMode: _shuffle
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
