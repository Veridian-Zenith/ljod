import 'package:audio_service/audio_service.dart';
import 'package:just_audio/just_audio.dart';

/// A robust audio handler built on top of `just_audio` and `audio_service`.
/// This interfaces directly with Android MediaSession and supports standard
/// decoders as well as vendor-specific private hardware codecs (such as Samsung's
/// c2/sec.* decoders managed transparently by ExoPlayer underlying `just_audio`).
class LjodAudioHandler extends BaseAudioHandler with SeekHandler {
  final AudioPlayer _player = AudioPlayer();

  LjodAudioHandler() {
    // Broadcast playback state changes to the system MediaSession / Android Media3 hooks
    _player.playbackEventStream.map(_transformEvent).pipe(playbackState);

    // Listen to current position updates for scrubbing/progress
    _player.positionStream.listen((position) {
      final oldState = playbackState.value;
      playbackState.add(oldState.copyWith(updatePosition: position));
    });
  }

  AudioPlayer get player => _player;

  @override
  Future<void> play() => _player.play();

  @override
  Future<void> pause() => _player.pause();

  @override
  Future<void> seek(Duration position) => _player.seek(position);

  @override
  Future<void> stop() async {
    await _player.stop();
    return super.stop();
  }

  /// Load and play a media item from URI or local file path.
  /// ExoPlayer under the hood automatically resolves platform decoders,
  /// including vendor-specific OMX/C2 hardware codecs.
  Future<void> loadAndPlay(MediaItem item, String audioPath) async {
    mediaItem.add(item);
    await _player.setAudioSource(AudioSource.uri(Uri.parse(audioPath)));
    await play();
  }

  PlaybackState _transformEvent(PlaybackEvent event) {
    return PlaybackState(
      controls: [
        MediaControl.rewind,
        if (_player.playing) MediaControl.pause else MediaControl.play,
        MediaControl.stop,
        MediaControl.fastForward,
      ],
      systemActions: const {
        MediaAction.seek,
        MediaAction.seekForward,
        MediaAction.seekBackward,
      },
      androidCompactActionIndices: const [1],
      processingState: const {
        ProcessingState.idle: AudioProcessingState.idle,
        ProcessingState.loading: AudioProcessingState.loading,
        ProcessingState.buffering: AudioProcessingState.buffering,
        ProcessingState.ready: AudioProcessingState.ready,
        ProcessingState.completed: AudioProcessingState.completed,
      }[_player.processingState]!,
      playing: _player.playing,
      updatePosition: _player.position,
      bufferedPosition: _player.bufferedPosition,
      speed: _player.speed,
      queueIndex: event.currentIndex,
    );
  }
}
