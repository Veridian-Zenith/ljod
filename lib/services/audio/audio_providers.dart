import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:audio_service/audio_service.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/diagnostics/diagnostics_log.dart';
import '../../core/models/song_model.dart';
import '../library/library_providers.dart';
import '../settings/settings_provider.dart';
import 'ljod_audio_handler.dart';
import 'media_permissions.dart';
import 'playback_session.dart';

export 'ljod_audio_handler.dart'
    show LjodAudioHandler, LjodPlaybackHandler, PlaybackException;
export 'playback_session.dart' show PlaybackRepeat, PlaybackSession;

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

/// The queue in play order. When shuffle is on this is the shuffled order, so
/// the notification, the up-next strip and the queue sheet all agree.
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

/// Where the last session is read from and written to.
final playbackSessionProvider = Provider<PlaybackSessionStore>((ref) {
  return PlaybackSessionStore(ref.watch(sharedPreferencesProvider));
});

final playbackControllerProvider = Provider<PlaybackController>(
  PlaybackController.new,
);

class PlaybackController {
  PlaybackController(this.ref) {
    final handler = ref.read(audioHandlerProvider);

    _songSub = handler.currentSongStream
        .distinct((previous, next) => previous?.id == next?.id)
        .listen((song) {
          if (song == null) return;
          _currentId = song.id;
          // Restoring the saved session emits the restored track; that is not
          // a new play and must not inflate its play count.
          if (!_suppressPlayCount) {
            ref.read(libraryProvider.notifier).markPlayed(song);
          }
          _logMemory();
          _scheduleSave(immediate: true);
        });

    _positionSub = handler.positionStream.listen((position) {
      _lastPosition = position;
      _scheduleSave();
    });

    _stateSub = handler.playbackState.listen((state) {
      final signature =
          '${state.queueIndex}|${state.playing}|${state.shuffleMode}|'
          '${state.repeatMode}|${state.processingState}';
      if (signature == _stateSignature) return;
      _stateSignature = signature;
      _scheduleSave(immediate: true);
    });

    ref.onDispose(() {
      _saveTimer?.cancel();
      _songSub.cancel();
      _positionSub.cancel();
      _stateSub.cancel();
    });

    unawaited(_restoreSession());
  }

  final Ref ref;
  late final StreamSubscription<SongModel?> _songSub;
  late final StreamSubscription<Duration> _positionSub;
  late final StreamSubscription<PlaybackState> _stateSub;
  final Random _random = Random();

  Timer? _saveTimer;
  Duration _lastPosition = Duration.zero;
  String? _currentId;
  String? _stateSignature;

  /// The queue's ids, rebuilt only when the queue itself changes: encoding
  /// fourteen hundred ids every few seconds was steady garbage on a long drive.
  List<String>? _queueIds;
  List<SongModel>? _queueSource;

  /// Last session written, so an unchanged one is not rewritten.
  String? _lastSessionSignature;
  Duration _lastSavedPosition = Duration.zero;

  /// False until the saved session has been applied; saving before that would
  /// overwrite it with the empty startup state.
  bool _restored = false;

  /// True while the restore is in flight, so its track is not counted as a play.
  bool _suppressPlayCount = true;

  LjodPlaybackHandler get _handler => ref.read(audioHandlerProvider);

  /// Reopens the last queue at the position it was left at, paused.
  ///
  /// Playback itself stays silent: an app that starts blasting audio on launch
  /// is a worse surprise than losing the position.
  Future<void> _restoreSession() async {
    final store = ref.read(playbackSessionProvider);
    try {
      final saved = store.read();
      if (saved == null) return;

      final library = await ref.read(libraryProvider.future);
      // A tap before the library resolved wins; never replace live playback.
      if (_handler.songs.isNotEmpty) return;

      final byId = {for (final song in library.songs) song.id: song};
      final queue = [
        for (final id in saved.queue)
          if (byId[id] != null) byId[id]!,
      ];
      if (queue.isEmpty) {
        await store.clear();
        return;
      }

      final wantedId = saved.queue[saved.index];
      var index = queue.indexWhere((song) => song.id == wantedId);
      if (index < 0) index = 0;

      await _handler.loadQueue(
        queue,
        initialIndex: index,
        initialPosition: saved.position,
        autoPlay: false,
        shuffle: saved.shuffle,
      );
      await _handler.setRepeatMode(_repeatMode(saved.repeat));
      _lastPosition = saved.position;
      _currentId = queue[index].id;
    } on PlaybackException catch (error) {
      ref.read(playbackErrorProvider.notifier).report(error.message);
    } catch (_) {
      // A stale session must never prevent startup.
    } finally {
      _suppressPlayCount = false;
      _restored = true;
      _scheduleSave(immediate: true);
    }
  }

  static AudioServiceRepeatMode _repeatMode(PlaybackRepeat repeat) =>
      switch (repeat) {
        PlaybackRepeat.off => AudioServiceRepeatMode.none,
        PlaybackRepeat.all => AudioServiceRepeatMode.all,
        PlaybackRepeat.one => AudioServiceRepeatMode.one,
      };

  static PlaybackRepeat _savedRepeat(AudioServiceRepeatMode mode) =>
      switch (mode) {
        AudioServiceRepeatMode.all => PlaybackRepeat.all,
        AudioServiceRepeatMode.one => PlaybackRepeat.one,
        _ => PlaybackRepeat.off,
      };

  void _scheduleSave({bool immediate = false}) {
    if (!_restored) return;
    if (immediate) {
      _saveTimer?.cancel();
      _saveTimer = null;
      unawaited(_persistSession(force: true));
      return;
    }
    // Position ticks arrive several times a second. A pending timer already
    // covers them; cancelling and re-creating one per tick was pure churn, and
    // every firing rewrote the entire queue.
    if (_saveTimer?.isActive ?? false) return;
    _saveTimer = Timer(const Duration(seconds: 8), () {
      _saveTimer = null;
      unawaited(_persistSession());
    });
  }

  /// Records the resident set and the decoded-cover footprint once per track.
  ///
  /// "RAM climbs until the phone lags" cannot be judged from a bug report; one
  /// line per track shows whether it is steady or growing.
  void _logMemory() {
    try {
      final rss = (ProcessInfo.currentRss / (1024 * 1024)).round();
      final covers =
          PaintingBinding.instance.imageCache.currentSizeBytes / (1024 * 1024);
      DiagnosticsLog.instance.log(
        'memory: $rss MB rss, ${covers.toStringAsFixed(1)} MB decoded covers',
        level: DiagnosticsLevel.info,
      );
    } catch (_) {
      // Diagnostics must never affect playback.
    }
  }

  Future<void> _persistSession({bool force = false}) async {
    if (!_restored) return;
    final handler = _handler;
    final base = handler.baseSongs;
    if (base.isEmpty) return;

    final currentId = handler.mediaItem.value?.id ?? _currentId;
    var index = currentId == null
        ? 0
        : base.indexWhere((song) => song.id == currentId);
    if (index < 0) index = 0;

    final ids = identical(base, _queueSource)
        ? _queueIds!
        : (_queueIds = [for (final song in base) song.id]);
    _queueSource = base;

    final shuffle = handler.shuffleEnabled;
    final repeat = _savedRepeat(handler.playbackState.value.repeatMode);
    final signature =
        '$index|${ids.length}|${ids.isEmpty ? '' : ids.first}|'
        '${ids.isEmpty ? '' : ids.last}|$shuffle|${repeat.name}';
    final moved =
        (_lastPosition - _lastSavedPosition).abs() >=
        const Duration(seconds: 1);
    // Nothing that affects a restore changed and the position barely moved: a
    // write here would re-encode every queued id for nothing.
    if (!force && signature == _lastSessionSignature && !moved) return;

    _lastSessionSignature = signature;
    _lastSavedPosition = _lastPosition;

    await ref
        .read(playbackSessionProvider)
        .write(
          PlaybackSession(
            queue: ids,
            index: index,
            position: _lastPosition,
            shuffle: shuffle,
            repeat: repeat,
          ),
        );
  }

  Future<void> playSong(SongModel song, {List<SongModel>? queue}) async {
    List<SongModel> songs = queue ?? ref.read(songsProvider);
    if (songs.isEmpty) songs = [song];
    if (!songs.any((item) => item.id == song.id)) {
      songs = [song, ...songs];
    }
    final index = songs.indexWhere((item) => item.id == song.id);

    await _loadQueue(songs, index < 0 ? 0 : index);
  }

  /// Plays [songs] in library order from the top.
  Future<void> playAll(List<SongModel> songs) async {
    if (songs.isEmpty) return;
    await _loadQueue(songs, 0, shuffle: false);
  }

  /// Plays [songs] shuffled, starting from a random track.
  Future<void> shuffleAll(List<SongModel> songs) async {
    if (songs.isEmpty) return;
    await _loadQueue(songs, _random.nextInt(songs.length), shuffle: true);
  }

  /// Deals the current queue again, keeping the playing track first.
  Future<void> reshuffle() => _guard(_handler.reshuffle);

  /// Loads a queue and reports failures instead of letting them escape as
  /// unhandled future errors from fire-and-forget tap handlers.
  Future<void> _loadQueue(
    List<SongModel> songs,
    int index, {
    bool? shuffle,
  }) async {
    try {
      // The media notification is a runtime permission from Android 13; ask
      // before the first sound so the controls exist when playback starts.
      await ensureNotificationPermission();
      await _handler.loadQueue(songs, initialIndex: index, shuffle: shuffle);
    } on PlaybackException catch (error) {
      ref.read(playbackErrorProvider.notifier).report(error.message);
    } catch (error) {
      ref
          .read(playbackErrorProvider.notifier)
          .report('Playback failed: $error');
    }
  }

  /// Runs a transport action and reports a failure instead of letting it
  /// escape as an unhandled future error from a fire-and-forget tap handler.
  /// Without this, a rejected seek or a plugin fault looked like a dead button.
  Future<void> _guard(Future<void> Function() action) async {
    try {
      await action();
    } on PlaybackException catch (error) {
      ref.read(playbackErrorProvider.notifier).report(error.message);
    } catch (error) {
      ref
          .read(playbackErrorProvider.notifier)
          .report('Playback failed: $error');
    }
  }

  Future<void> togglePlayPause() => _guard(() async {
    if (_handler.playbackState.value.playing) {
      await _handler.pause();
    } else {
      await ensureNotificationPermission();
      await _handler.play();
    }
  });

  Future<void> play() => _guard(_handler.play);

  Future<void> pause() => _guard(_handler.pause);

  Future<void> next() => _guard(_handler.skipToNext);

  Future<void> previous() => _guard(_handler.skipToPrevious);

  Future<void> seek(Duration position) => _guard(() => _handler.seek(position));

  Future<void> seekBy(Duration delta) => _guard(() async {
    // The player's own position rather than the last broadcast one: broadcasts
    // are throttled, and a skip button must not drift by a second.
    final current = _lastPosition + delta;
    final duration = _handler.mediaItem.value?.duration ?? Duration.zero;
    var target = current;
    if (target < Duration.zero) target = Duration.zero;
    if (duration > Duration.zero && target > duration) target = duration;
    await _handler.seek(target);
  });

  Future<void> toggleShuffle() =>
      _guard(() => _handler.setShuffleEnabled(!_handler.shuffleEnabled));

  Future<void> setShuffleEnabled(bool enabled) =>
      _guard(() => _handler.setShuffleEnabled(enabled));

  Future<void> setRepeatMode(AudioServiceRepeatMode mode) =>
      _guard(() => _handler.setRepeatMode(mode));

  Future<void> cycleRepeat() => _guard(() async {
    final next = switch (_handler.playbackState.value.repeatMode) {
      AudioServiceRepeatMode.none => AudioServiceRepeatMode.all,
      AudioServiceRepeatMode.all => AudioServiceRepeatMode.one,
      AudioServiceRepeatMode.one => AudioServiceRepeatMode.none,
      _ => AudioServiceRepeatMode.all,
    };
    await _handler.setRepeatMode(next);
  });

  /// Jumps to a queue entry without re-dealing the queue.
  Future<void> playFromQueue(int index) =>
      _guard(() => _handler.skipToQueueItem(index));

  Future<void> toggleFavorite(SongModel song) async {
    await ref.read(libraryProvider.notifier).toggleFavorite(song);
  }
}
