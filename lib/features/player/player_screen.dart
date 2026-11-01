import 'dart:math' as math;

import 'package:audio_service/audio_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/models/song_model.dart';
import '../../core/theme/ljod_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/vz_components.dart';
import 'lyrics_sheet.dart';
import '../../services/audio/audio_providers.dart';
import '../../services/library/library_providers.dart';

class PlayerScreen extends ConsumerWidget {
  const PlayerScreen({super.key});

  static Route<void> route() {
    return PageRouteBuilder<void>(
      transitionDuration: const Duration(milliseconds: 420),
      reverseTransitionDuration: const Duration(milliseconds: 300),
      pageBuilder: (_, _, _) => const PlayerScreen(),
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        final curve = CurvedAnimation(
          parent: animation,
          curve: Curves.easeOutCubic,
          reverseCurve: Curves.easeInCubic,
        );
        return FadeTransition(
          opacity: curve,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: const Offset(0, 0.08),
              end: Offset.zero,
            ).animate(curve),
            child: child,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final song = ref.watch(nowPlayingProvider);
    final playing = ref.watch(playingProvider).value ?? false;
    final position = ref.watch(positionProvider).value ?? Duration.zero;
    final duration = ref.watch(effectiveDurationProvider);
    final buffered = ref.watch(bufferedPositionProvider).value ?? Duration.zero;
    final shuffle = ref.watch(shuffleProvider);
    final repeat = ref.watch(repeatModeProvider);
    final queue = ref.watch(queueProvider).value ?? const [];
    final controller = ref.read(playbackControllerProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: LjodBackground(
        child: SafeArea(
          child: Column(
            children: [
              _TopBar(
                queueLength: queue.length,
                onQueue: song == null ? null : () => _showQueueSheet(context),
              ),
              Expanded(
                child: song == null
                    ? const EmptyState(
                        icon: Icons.graphic_eq_rounded,
                        title: 'Silence',
                        message:
                            'Pick a track from the library and the forge will '
                            'come alive.',
                      )
                    : SingleChildScrollView(
                        padding: const EdgeInsets.only(bottom: 24),
                        child: Column(
                          children: [
                            const SizedBox(height: 6),
                            _ArtStage(song: song, playing: playing),
                            const SizedBox(height: 26),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 26,
                              ),
                              child: _TrackMeta(
                                song: song,
                                onFavorite: () => ref
                                    .read(libraryProvider.notifier)
                                    .toggleFavorite(song),
                                onLyrics: () =>
                                    _showLyricsSheet(context, ref, song),
                              ),
                            ),
                            const SizedBox(height: 20),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 24,
                              ),
                              child: _SeekBar(
                                position: position,
                                duration: duration,
                                buffered: buffered,
                                onSeek: controller.seek,
                                onSeekBy: controller.seekBy,
                              ),
                            ),
                            const SizedBox(height: 16),
                            _Transport(
                              playing: playing,
                              shuffle: shuffle,
                              repeat: repeat,
                              onShuffle: controller.toggleShuffle,
                              onRepeat: controller.cycleRepeat,
                              onPrevious: controller.previous,
                              onNext: controller.next,
                              onPlayPause: controller.togglePlayPause,
                            ),
                            const SizedBox(height: 16),
                            _UpNextStrip(
                              onQueue: () => _showQueueSheet(context),
                            ),
                            const SizedBox(height: 16),
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 26,
                              ),
                              child: _StatusStrip(
                                song: song,
                                queueLength: queue.length,
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showQueueSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const _QueueSheet(),
    );
  }

  void _showLyricsSheet(BuildContext context, WidgetRef ref, SongModel song) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => LyricsSheet(song: song),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.queueLength, this.onQueue});

  final int queueLength;
  final VoidCallback? onQueue;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 8, 4),
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).maybePop(),
            icon: const Icon(Icons.keyboard_arrow_down_rounded),
            iconSize: 28,
            tooltip: 'Close player',
          ),
          Expanded(
            child: Column(
              children: [
                Text(
                  'NOW PLAYING',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: LjodTheme.amber,
                    letterSpacing: 2.4,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  queueLength == 0 ? 'Queue empty' : 'From your library',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: LjodTheme.textMuted,
                    fontSize: 10,
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onQueue,
            icon: const Icon(Icons.queue_music_rounded),
            tooltip: 'Queue',
          ),
        ],
      ),
    );
  }
}

class _ArtStage extends StatelessWidget {
  const _ArtStage({required this.song, required this.playing});

  final SongModel song;
  final bool playing;

  @override
  Widget build(BuildContext context) {
    final size = math.min(MediaQuery.sizeOf(context).width - 88, 340.0);
    return SizedBox(
      height: size + 24,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Transform.rotate(
            angle: -0.09,
            child: Container(
              width: size * 0.9,
              height: size * 0.9,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(LjodTheme.radiusXl),
                border: Border.all(
                  color: LjodTheme.amber.withValues(alpha: 0.18),
                ),
              ),
            ),
          ),
          Transform.rotate(
            angle: 0.06,
            child: Container(
              width: size * 0.95,
              height: size * 0.95,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(LjodTheme.radiusXl),
                border: Border.all(
                  color: LjodTheme.crimson.withValues(alpha: 0.12),
                ),
              ),
            ),
          ),
          Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(LjodTheme.radiusXl),
              boxShadow: [
                BoxShadow(
                  color: LjodTheme.amber.withValues(
                    alpha: playing ? 0.24 : 0.12,
                  ),
                  blurRadius: 48,
                  spreadRadius: 4,
                ),
              ],
            ),
            child: SongCover(
              song: song,
              size: size,
              radius: LjodTheme.radiusXl,
            ),
          ),
          Positioned(
            right: 26,
            top: 18,
            child: AnimatedOpacity(
              opacity: playing ? 1 : 0,
              duration: const Duration(milliseconds: 260),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: LjodTheme.bgPitch.withValues(alpha: 0.7),
                  borderRadius: BorderRadius.circular(999),
                  border: Border.all(
                    color: LjodTheme.amber.withValues(alpha: 0.4),
                  ),
                ),
                child: const EqualizerBars(height: 12, bars: 4),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TrackMeta extends StatelessWidget {
  const _TrackMeta({
    required this.song,
    required this.onFavorite,
    required this.onLyrics,
  });

  final SongModel song;
  final VoidCallback onFavorite;
  final VoidCallback onLyrics;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                song.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.w800,
                  letterSpacing: -0.8,
                ),
              ),
              const SizedBox(height: 5),
              // One flexible line: two Flexibles split the row and truncate the
              // artist long before the space is actually gone.
              Text(
                song.album.isEmpty
                    ? song.displayArtist
                    : '${song.displayArtist}  ·  ${song.album}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: LjodTheme.textSoft,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: onLyrics,
          tooltip: 'Lyrics',
          icon: const Icon(Icons.lyrics_rounded),
        ),
        IconButton(
          onPressed: onFavorite,
          tooltip: song.isFavorite
              ? 'Remove from favourites'
              : 'Add to favourites',
          icon: Icon(
            song.isFavorite
                ? Icons.favorite_rounded
                : Icons.favorite_border_rounded,
            color: song.isFavorite ? LjodTheme.crimson : LjodTheme.textSoft,
          ),
        ),
      ],
    );
  }
}

class _SeekBar extends StatefulWidget {
  const _SeekBar({
    required this.position,
    required this.duration,
    required this.buffered,
    required this.onSeek,
    required this.onSeekBy,
  });

  final Duration position;
  final Duration duration;
  final Duration buffered;
  final ValueChanged<Duration> onSeek;
  final ValueChanged<Duration> onSeekBy;

  @override
  State<_SeekBar> createState() => _SeekBarState();
}

class _SeekBarState extends State<_SeekBar> {
  double? _dragValue;

  @override
  Widget build(BuildContext context) {
    final max = widget.duration.inMilliseconds > 0
        ? widget.duration.inMilliseconds.toDouble()
        : 1.0;
    final live = widget.position.inMilliseconds.toDouble().clamp(0.0, max);
    final value = (_dragValue ?? live).clamp(0.0, max);
    final shown = Duration(milliseconds: value.round());

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
      decoration: ShapeDecoration(
        color: LjodTheme.panelBlack.withValues(alpha: 0.9),
        shape: MaterialShapeBorder(
          shape: MaterialShapes.pill,
          squash: 1,
          side: BorderSide(
            color: LjodTheme.borderStrong.withValues(alpha: 0.35),
          ),
        ),
      ),
      child: Column(
        children: [
          LjodSlider(
            value: value,
            max: max,
            buffered: widget.buffered.inMilliseconds.toDouble(),
            onChanged: (next) => setState(() => _dragValue = next),
            onChangeEnd: (next) {
              setState(() => _dragValue = null);
              widget.onSeek(Duration(milliseconds: next.round()));
            },
          ),
          const SizedBox(height: 6),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 6),
            child: Row(
              children: [
                Text(formatDuration(shown, empty: '00:00'), style: _timeStyle),
                const Spacer(),
                ShapeIconButton(
                  icon: Icons.replay_10_rounded,
                  onTap: () => widget.onSeekBy(const Duration(seconds: -10)),
                  tooltip: 'Back 10 seconds',
                  shape: MaterialShapes.circle,
                  size: 19,
                  padding: 7,
                ),
                const SizedBox(width: 10),
                ShapeIconButton(
                  icon: Icons.forward_10_rounded,
                  onTap: () => widget.onSeekBy(const Duration(seconds: 10)),
                  tooltip: 'Forward 10 seconds',
                  shape: MaterialShapes.circle,
                  size: 19,
                  padding: 7,
                ),
                const Spacer(),
                Text(
                  formatDuration(widget.duration, empty: '--:--'),
                  style: _timeStyle,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static const _timeStyle = TextStyle(
    fontSize: 10,
    color: LjodTheme.textMuted,
    letterSpacing: 0.6,
    fontWeight: FontWeight.w600,
  );

  @override
  void didUpdateWidget(covariant _SeekBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (_dragValue != null) {
      final currentMs = widget.position.inMilliseconds.toDouble();
      final dragMs = _dragValue!;
      final max = widget.duration.inMilliseconds.toDouble();
      // Commit the drag once playback catches up with the requested position.
      if (max > 0 && (currentMs - dragMs).abs() < 650) {
        _dragValue = null;
      }
    }
  }
}

class _Transport extends StatelessWidget {
  const _Transport({
    required this.playing,
    required this.shuffle,
    required this.repeat,
    required this.onShuffle,
    required this.onRepeat,
    required this.onPrevious,
    required this.onNext,
    required this.onPlayPause,
  });

  final bool playing;
  final bool shuffle;
  final AudioServiceRepeatMode repeat;
  final VoidCallback onShuffle;
  final VoidCallback onRepeat;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final VoidCallback onPlayPause;

  @override
  Widget build(BuildContext context) {
    final repeatActive = repeat != AudioServiceRepeatMode.none;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 14),
      decoration: ShapeDecoration(
        // The bar itself is a Material 3 pill so the controls read as a unit.
        // On a true-black surface the fill needs to be lifted to stay visible.
        color: LjodTheme.panelHighest.withValues(alpha: 0.85),
        shape: MaterialShapeBorder(
          shape: MaterialShapes.pill,
          squash: 1,
          side: BorderSide(color: LjodTheme.amber.withValues(alpha: 0.22)),
        ),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          ShapeIconButton(
            icon: Icons.shuffle_rounded,
            onTap: onShuffle,
            isActive: shuffle,
            tooltip: 'Shuffle',
            shape: MaterialShapes.clover4Leaf,
            size: 20,
            padding: 8,
          ),
          ShapeIconButton(
            icon: Icons.skip_previous_rounded,
            onTap: onPrevious,
            tooltip: 'Previous',
            shape: MaterialShapes.diamond,
            size: 26,
            padding: 10,
          ),
          PlayPauseButton(
            playing: playing,
            onTap: onPlayPause,
            size: 70,
            iconSize: 32,
          ),
          ShapeIconButton(
            icon: Icons.skip_next_rounded,
            onTap: onNext,
            tooltip: 'Next',
            shape: MaterialShapes.diamond,
            size: 26,
            padding: 10,
          ),
          ShapeIconButton(
            icon: repeat == AudioServiceRepeatMode.one
                ? Icons.repeat_one_rounded
                : Icons.repeat_rounded,
            onTap: onRepeat,
            isActive: repeatActive,
            tooltip: switch (repeat) {
              AudioServiceRepeatMode.one => 'Repeat one',
              AudioServiceRepeatMode.all => 'Repeat all',
              _ => 'Repeat off',
            },
            shape: MaterialShapes.cookie6Sided,
            size: 20,
            padding: 8,
          ),
        ],
      ),
    );
  }
}

/// The next track in queue order, so the player is not a dead end.
class _UpNextStrip extends ConsumerWidget {
  const _UpNextStrip({required this.onQueue});

  final VoidCallback onQueue;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queue = ref.watch(queueProvider).value ?? const [];
    final index = ref.watch(playbackStateProvider).value?.queueIndex;
    if (index == null || index + 1 >= queue.length) {
      return const SizedBox.shrink();
    }

    final item = queue[index + 1];
    final song = ref.watch(songByIdProvider(item.id));
    final controller = ref.read(playbackControllerProvider);
    final theme = Theme.of(context);
    final outfit = MaterialShapeBorder(
      shape: MaterialShapes.pill,
      squash: 1,
      side: BorderSide(color: LjodTheme.borderLight.withValues(alpha: 0.7)),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Material(
        color: Colors.transparent,
        child: Ink(
          decoration: ShapeDecoration(
            color: LjodTheme.panelBlack.withValues(alpha: 0.55),
            shape: outfit,
          ),
          child: InkWell(
            customBorder: outfit,
            onTap: () => controller.playFromQueue(index + 1),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(14, 8, 6, 8),
              child: Row(
                children: [
                  Text(
                    'UP NEXT',
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: LjodTheme.amber,
                      letterSpacing: 1.6,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(width: 12),
                  CoverArt(
                    path: song?.artworkPath,
                    size: 30,
                    radius: 9,
                    label: item.title,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: LjodTheme.textStrong,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        if (item.artist != null && item.artist!.isNotEmpty)
                          Text(
                            item.artist!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: LjodTheme.textMuted,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton(
                    onPressed: onQueue,
                    tooltip: 'Queue',
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(
                      Icons.queue_music_rounded,
                      size: 18,
                      color: LjodTheme.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusStrip extends StatelessWidget {
  const _StatusStrip({required this.song, required this.queueLength});

  final SongModel song;
  final int queueLength;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: LjodTheme.panelBlack.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: LjodTheme.borderLight),
      ),
      child: Row(
        children: [
          const Icon(Icons.album_rounded, size: 15, color: LjodTheme.amber),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              song.displayAlbum,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.bodySmall?.copyWith(
                color: LjodTheme.textSoft,
              ),
            ),
          ),
          Text(
            '$queueLength in queue',
            style: theme.textTheme.labelSmall?.copyWith(
              color: LjodTheme.textMuted,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }
}

class _QueueSheet extends ConsumerWidget {
  const _QueueSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final queue = ref.watch(queueProvider).value ?? const [];
    final state = ref.watch(playbackStateProvider).value;
    final now = ref.watch(nowPlayingProvider);
    final controller = ref.read(playbackControllerProvider);
    final theme = Theme.of(context);

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.62,
      minChildSize: 0.35,
      maxChildSize: 0.92,
      builder: (context, scrollController) {
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              child: Row(
                children: [
                  Text(
                    'QUEUE',
                    style: LjodTheme.display(theme.textTheme, size: 24),
                  ),
                  const Spacer(),
                  LjodBadge(label: '${queue.length} tracks'),
                ],
              ),
            ),
            const Divider(height: 1),
            Expanded(
              child: queue.isEmpty
                  ? const EmptyState(
                      icon: Icons.queue_music_rounded,
                      title: 'Queue is empty',
                      message: 'Play something and it will appear here.',
                      compact: true,
                    )
                  : ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(6, 6, 6, 20),
                      itemCount: queue.length,
                      itemBuilder: (context, index) {
                        final item = queue[index];
                        final artUri = item.artUri;
                        final song =
                            ref.watch(songByIdProvider(item.id)) ??
                            SongModel(
                              id: item.id,
                              path: item.extras?['path'] as String? ?? '',
                              title: item.title,
                              artist: item.artist ?? '',
                              album: item.album ?? '',
                              duration: item.duration ?? Duration.zero,
                              artworkPath:
                                  artUri != null && artUri.isScheme('file')
                                  ? artUri.toFilePath()
                                  : null,
                            );
                        final isCurrent =
                            state?.queueIndex == index || now?.id == item.id;
                        return SongTile(
                          song: song,
                          isCurrent: isCurrent,
                          playing: state?.playing ?? false,
                          showAlbum: false,
                          onTap: () => controller.playFromQueue(index),
                          trailing: isCurrent
                              ? const Icon(
                                  Icons.graphic_eq_rounded,
                                  color: LjodTheme.amber,
                                  size: 18,
                                )
                              : Text(
                                  '${index + 1}'.padLeft(2, '0'),
                                  style: theme.textTheme.labelSmall,
                                ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}
