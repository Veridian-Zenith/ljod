import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/models/song_model.dart';
import '../../core/theme/ljod_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/ljod_logo.dart';
import '../../core/widgets/vz_components.dart';
import '../../services/audio/audio_providers.dart';
import '../../services/library/library_providers.dart';
import '../../services/stats/stats_provider.dart';
import '../player/player_screen.dart';
import '../stats/stats_screen.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key, this.onOpenLibrary});

  final VoidCallback? onOpenLibrary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final library = ref.watch(libraryProvider);
    final state = library.value ?? const LibraryState();
    final nowPlaying = ref.watch(nowPlayingProvider);
    final playing = ref.watch(playingProvider).value ?? false;
    final controller = ref.read(playbackControllerProvider);
    final stats = ref.watch(statsProvider);

    final favorites = state.favorites.take(8).toList(growable: false);
    final recent = state.recentlyPlayed;
    final newest = [...state.songs]
      ..sort((a, b) {
        final at = a.addedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        final bt = b.addedAt ?? DateTime.fromMillisecondsSinceEpoch(0);
        return bt.compareTo(at);
      });

    return SafeArea(
      bottom: false,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: _Header(
              state: state,
              onRescan: () => ref.read(libraryProvider.notifier).rescan(),
              onInsights: () => Navigator.of(context).push(StatsScreen.route()),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 4, 20, 18),
              child: _Hero(
                song: nowPlaying,
                playing: playing,
                isScanning: state.isScanning,
                permissionDenied: state.permissionDenied,
                onPlayPause: controller.togglePlayPause,
                onOpenPlayer: () =>
                    Navigator.of(context).push(PlayerScreen.route()),
                onGrantAccess: () =>
                    ref.read(libraryProvider.notifier).rescan(),
              ),
            ),
          ),
          if (library.isLoading && state.songs.isEmpty)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: LoadingView(label: 'Summoning your library…'),
            )
          else if (state.error != null)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _InlineError(
                  message: state.error!,
                  onRetry: () => ref.read(libraryProvider.notifier).rescan(),
                ),
              ),
            )
          else if (state.songs.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: EmptyState(
                icon: Icons.folder_open_rounded,
                title: 'The forge is quiet',
                message:
                    'Ljod reads audio stored on this device. Grant access and '
                    'we will index MP3, FLAC, AAC, OGG and more.',
                action: FilledButton.icon(
                  onPressed: () => ref.read(libraryProvider.notifier).rescan(),
                  icon: const Icon(Icons.radar_rounded, size: 18),
                  label: const Text('Scan device'),
                ),
              ),
            )
          else ...[
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 18),
                child: _InsightsStrip(
                  stats: stats,
                  onTap: () => Navigator.of(context).push(StatsScreen.route()),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: SectionHeader(
                title: favorites.isEmpty
                    ? 'Pick up where you left off'
                    : 'Favourites',
                eyebrow: favorites.isEmpty ? 'Recent' : 'Pinned',
                trailing: TextButton(
                  onPressed: onOpenLibrary,
                  child: const Text('Library'),
                ),
              ),
            ),
            SliverToBoxAdapter(
              child: _SongRail(
                songs: favorites.isNotEmpty
                    ? favorites
                    : (recent.isNotEmpty ? recent : newest.take(8).toList()),
                onPlay: (song, queue) =>
                    controller.playSong(song, queue: queue),
              ),
            ),
            const SliverToBoxAdapter(child: SizedBox(height: 26)),
            SliverToBoxAdapter(
              child: SectionHeader(
                title: 'New in the vault',
                eyebrow: 'Recently added',
                subtitle: stats.recentlyAddedCount == 0
                    ? null
                    : '${stats.recentlyAddedCount} added in the last 30 days',
                trailing: TextButton(
                  onPressed: onOpenLibrary,
                  child: const Text('See all'),
                ),
              ),
            ),
            SliverList.builder(
              itemCount: newest.length < 6 ? newest.length : 6,
              itemBuilder: (context, index) {
                final song = newest[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: SongTile(
                    song: song,
                    isCurrent: nowPlaying?.id == song.id,
                    playing: playing,
                    onTap: () => controller.playSong(song, queue: newest),
                    onFavorite: () =>
                        ref.read(libraryProvider.notifier).toggleFavorite(song),
                  ),
                );
              },
            ),
          ],
          const SliverToBoxAdapter(child: SizedBox(height: 210)),
        ],
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.state,
    required this.onRescan,
    required this.onInsights,
  });

  final LibraryState state;
  final VoidCallback onRescan;
  final VoidCallback onInsights;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 12, 18),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Wrap(
                  spacing: 10,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const LjodLockup(markSize: 36, textSize: 38),
                    const LjodBadge(
                      label: 'Audio Forge',
                      isActive: true,
                      icon: Icons.bolt_rounded,
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  state.isScanning
                      ? 'Reading the device library…'
                      : '${state.songs.length} tracks · '
                            '${state.favorites.length} pinned',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: LjodTheme.textMuted,
                    letterSpacing: 0.3,
                  ),
                ),
              ],
            ),
          ),
          if (state.isScanning)
            const Padding(
              padding: EdgeInsets.only(top: 12, right: 10),
              child: SizedBox(
                width: 22,
                height: 22,
                child: CircularProgressIndicator(strokeWidth: 2.2),
              ),
            )
          else ...[
            IconButton(
              onPressed: onInsights,
              tooltip: 'Insights',
              icon: const Icon(Icons.insights_rounded),
            ),
            IconButton(
              onPressed: onRescan,
              tooltip: 'Rescan device',
              icon: const Icon(Icons.radar_rounded),
            ),
          ],
        ],
      ),
    );
  }
}

/// Compact summary that links to the full Insights screen and keeps the home
/// feed from reading as a stack of rails.
class _InsightsStrip extends StatelessWidget {
  const _InsightsStrip({required this.stats, required this.onTap});

  final LibraryStats stats;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(LjodTheme.radiusMd),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
          decoration: BoxDecoration(
            color: LjodTheme.panelBlack.withValues(alpha: 0.82),
            borderRadius: BorderRadius.circular(LjodTheme.radiusMd),
            border: Border.all(color: LjodTheme.borderLight),
          ),
          child: Row(
            children: [
              Container(
                width: 34,
                height: 34,
                alignment: Alignment.center,
                decoration: ShapeDecoration(
                  color: LjodTheme.amber.withValues(alpha: 0.12),
                  shape: MaterialShapeBorder(
                    shape: MaterialShapes.cookie4Sided,
                    side: BorderSide(
                      color: LjodTheme.amber.withValues(alpha: 0.34),
                    ),
                  ),
                ),
                child: const Icon(
                  Icons.insights_rounded,
                  size: 17,
                  color: LjodTheme.amber,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'INSIGHTS',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: LjodTheme.amber,
                        letterSpacing: 2.0,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '${formatCount(stats.totalPlayCount)} plays · '
                      '${stats.totalFavorites} pinned · '
                      '${stats.recentlyAddedCount} new',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: LjodTheme.textSoft,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.chevron_right_rounded,
                size: 20,
                color: LjodTheme.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Hero extends StatelessWidget {
  const _Hero({
    required this.song,
    required this.playing,
    required this.isScanning,
    required this.permissionDenied,
    required this.onPlayPause,
    required this.onOpenPlayer,
    required this.onGrantAccess,
  });

  final SongModel? song;
  final bool playing;
  final bool isScanning;
  final bool permissionDenied;
  final VoidCallback onPlayPause;
  final VoidCallback onOpenPlayer;
  final VoidCallback onGrantAccess;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final track = song;
    if (track == null) {
      return Panel(
        radius: LjodTheme.radiusLg,
        padding: const EdgeInsets.all(22),
        color: LjodTheme.panelBlack,
        borderColor: LjodTheme.amber.withValues(alpha: 0.28),
        glow: true,
        child: Stack(
          children: [
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const LjodBadge(
                  label: 'Standing by',
                  isActive: false,
                  icon: Icons.radio_button_checked_rounded,
                ),
                const SizedBox(height: 22),
                Text(
                  'Nothing spinning.',
                  style: theme.textTheme.headlineMedium?.copyWith(
                    fontWeight: FontWeight.w800,
                    letterSpacing: -1,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  permissionDenied
                      ? 'Ljod needs access to audio files to build your library.'
                      : isScanning
                      ? 'Indexing tags and cover art right now.'
                      : 'Choose a track and the forge will light up.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: LjodTheme.textMuted,
                  ),
                ),
                const SizedBox(height: 20),
                if (permissionDenied)
                  FilledButton.icon(
                    onPressed: onGrantAccess,
                    icon: const Icon(Icons.lock_open_rounded, size: 18),
                    label: const Text('Grant music access'),
                  )
                else
                  OutlinedButton.icon(
                    onPressed: isScanning ? null : onGrantAccess,
                    icon: const Icon(Icons.radar_rounded, size: 18),
                    label: const Text('Scan device'),
                  ),
              ],
            ),
          ],
        ),
      );
    }

    return Panel(
      radius: LjodTheme.radiusLg,
      padding: const EdgeInsets.all(20),
      color: LjodTheme.panelBlack,
      borderColor: LjodTheme.amber.withValues(alpha: 0.35),
      glow: true,
      onTap: onOpenPlayer,
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  LjodBadge(
                    label: playing ? 'Now playing' : 'Paused',
                    isActive: true,
                    icon: playing
                        ? Icons.graphic_eq_rounded
                        : Icons.pause_rounded,
                  ),
                  const Spacer(),
                  if (playing) const EqualizerBars(),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  HeroArtwork(song: track),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          track.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.6,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Text(
                          track.displayArtist,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: LjodTheme.textSoft,
                          ),
                        ),
                        if (track.album.isNotEmpty) ...[
                          const SizedBox(height: 2),
                          Text(
                            track.album,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: LjodTheme.textMuted,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              Row(
                children: [
                  FilledButton.tonalIcon(
                    onPressed: () =>
                        Navigator.of(context).push(PlayerScreen.route()),
                    icon: const Icon(Icons.open_in_full_rounded, size: 17),
                    label: const Text('Open player'),
                  ),
                  const Spacer(),
                  PlayPauseButton(
                    playing: playing,
                    onTap: onPlayPause,
                    size: 56,
                    iconSize: 28,
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class HeroArtwork extends StatelessWidget {
  const HeroArtwork({super.key, required this.song});

  final SongModel song;

  @override
  Widget build(BuildContext context) {
    return Stack(
      clipBehavior: Clip.none,
      children: [
        SongCover(song: song, size: 108, radius: 26),
        Positioned(
          right: -6,
          bottom: -6,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            curve: Curves.easeOutBack,
            width: 32,
            height: 32,
            decoration: BoxDecoration(
              color: LjodTheme.amber,
              shape: BoxShape.circle,
              border: Border.all(color: LjodTheme.bgPitch, width: 2.5),
              boxShadow: [
                BoxShadow(
                  color: LjodTheme.amber.withValues(alpha: 0.35),
                  blurRadius: 12,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: const Icon(
              Icons.play_arrow_rounded,
              size: 16,
              color: LjodTheme.panelBlack,
            ),
          ),
        ),
      ],
    );
  }
}

class _SongRail extends StatelessWidget {
  const _SongRail({required this.songs, required this.onPlay});

  final List<SongModel> songs;
  final void Function(SongModel song, List<SongModel> queue) onPlay;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 186,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 20),
        itemCount: songs.length,
        separatorBuilder: (_, _) => const SizedBox(width: 12),
        itemBuilder: (context, index) {
          final song = songs[index];
          return SizedBox(
            width: 138,
            child: AlbumTile(
              title: song.title,
              subtitle: song.displayArtist,
              artworkPath: song.artworkPath,
              onTap: () => onPlay(song, songs),
              badge: song.isFavorite ? 'Pinned' : null,
            ),
          );
        },
      ),
    );
  }
}

class _InlineError extends StatelessWidget {
  const _InlineError({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Panel(
      color: LjodTheme.panelBlack,
      borderColor: LjodTheme.error.withValues(alpha: 0.45),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: LjodTheme.error),
          const SizedBox(width: 12),
          Expanded(
            child: Text(message, style: Theme.of(context).textTheme.bodySmall),
          ),
          TextButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
