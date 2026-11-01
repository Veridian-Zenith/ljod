import 'dart:ui' as ui;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/models/song_model.dart';
import '../../core/theme/ljod_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/vz_components.dart';
import '../../services/audio/audio_providers.dart';
import '../../services/stats/stats_provider.dart';

/// Listening insights: real numbers derived from play history, no guesses.
class StatsScreen extends ConsumerWidget {
  const StatsScreen({super.key});

  static Route<void> route() {
    return MaterialPageRoute<void>(builder: (_) => const StatsScreen());
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(statsProvider);
    final controller = ref.read(playbackControllerProvider);
    final theme = Theme.of(context);

    return Scaffold(
      // Pushed routes need their own surface: a transparent Scaffold leaves the
      // app bar floating on whatever the Navigator renders behind it.
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'INSIGHTS',
          style: LjodTheme.display(theme.textTheme, size: 22),
        ),
        leading: IconButton(
          onPressed: () => Navigator.of(context).maybePop(),
          icon: const Icon(Icons.arrow_back_rounded),
          tooltip: 'Back',
        ),
      ),
      body: LjodBackground(
        child: SafeArea(
          top: false,
          child: stats.totalTracks == 0
              ? const EmptyState(
                  icon: Icons.insights_rounded,
                  title: 'Nothing measured yet',
                  message:
                      'Scan your library and play something. Ljod counts real '
                      'plays on this device and nothing leaves it.',
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
                  children: [
                    _SpinHero(stats: stats),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: StatCard(
                            label: 'Tracks',
                            value: formatCount(stats.totalTracks),
                            icon: Icons.music_note_rounded,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: StatCard(
                            label: 'Albums',
                            value: formatCount(stats.totalAlbums),
                            icon: Icons.album_rounded,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: StatCard(
                            label: 'Pinned',
                            value: formatCount(stats.totalFavorites),
                            icon: Icons.favorite_rounded,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: StatCard(
                            label: 'New · 30d',
                            value: formatCount(stats.recentlyAddedCount),
                            icon: Icons.auto_awesome_rounded,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 26),
                    if (stats.mostPlayed.isEmpty)
                      const Panel(
                        borderColor: LjodTheme.borderLight,
                        child: Row(
                          children: [
                            Icon(
                              Icons.graphic_eq_rounded,
                              size: 18,
                              color: LjodTheme.amber,
                            ),
                            SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'No plays recorded yet. Your rankings and '
                                'top artists appear as you listen.',
                                style: TextStyle(
                                  fontSize: 11,
                                  color: LjodTheme.textMuted,
                                  height: 1.5,
                                ),
                              ),
                            ),
                          ],
                        ),
                      )
                    else ...[
                      const SectionHeader(
                        title: 'Most played',
                        eyebrow: 'Rankings',
                        padding: EdgeInsets.only(bottom: 10, left: 4),
                      ),
                      for (var i = 0; i < stats.mostPlayed.length; i++)
                        _RankedTrack(
                          rank: i + 1,
                          song: stats.mostPlayed[i],
                          onTap: () => controller.playSong(
                            stats.mostPlayed[i],
                            queue: stats.mostPlayed,
                          ),
                        ),
                      const SizedBox(height: 22),
                      const SectionHeader(
                        title: 'Top artists',
                        eyebrow: 'Rotation',
                        padding: EdgeInsets.only(bottom: 10, left: 4),
                      ),
                      _ArtistBars(artists: stats.topArtists),
                    ],
                    const SizedBox(height: 26),
                    Text(
                      'Counted locally from this device. Cleared with the '
                      'library cache.',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: LjodTheme.textMuted,
                        height: 1.6,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _SpinHero extends StatelessWidget {
  const _SpinHero({required this.stats});

  final LibraryStats stats;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: ShapeDecoration(
        color: LjodTheme.panelBlack,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(LjodTheme.radiusLg),
          side: BorderSide(color: LjodTheme.amber.withValues(alpha: 0.30)),
        ),
        shadows: [
          BoxShadow(
            color: LjodTheme.amber.withValues(alpha: 0.12),
            blurRadius: 34,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Stack(
        children: [
          // Geometric accent instead of bending the whole card out of shape.
          // A small static blur keeps it soft without a full-screen filter.
          Positioned(
            right: -34,
            top: -30,
            child: ImageFiltered(
              imageFilter: ui.ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                width: 132,
                height: 132,
                decoration: ShapeDecoration(
                  color: LjodTheme.amber.withValues(alpha: 0.035),
                  shape: MaterialShapeBorder(
                    shape: MaterialShapes.cookie9Sided,
                    side: BorderSide(
                      color: LjodTheme.amber.withValues(alpha: 0.30),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const LjodBadge(
                  label: 'Total spin',
                  isActive: true,
                  icon: Icons.graphic_eq_rounded,
                ),
                const SizedBox(height: 18),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      formatCount(stats.totalPlayCount),
                      style: LjodTheme.display(
                        theme.textTheme,
                        size: 56,
                        color: LjodTheme.amber,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 10),
                      child: Text(
                        stats.totalPlayCount == 1 ? 'play' : 'plays',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: LjodTheme.textSoft,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  '≈ ${_listeningLabel(stats.listeningTime)} of music, '
                  '${stats.mostPlayedSong == null ? 'no favourite yet' : 'led by ${stats.mostPlayedSong!.title}'}.',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: LjodTheme.textMuted,
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

String _listeningLabel(Duration duration) {
  if (duration <= Duration.zero) return '0m';
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  if (hours == 0) return '${duration.inMinutes}m';
  return '${hours}h ${minutes}m';
}

class _RankedTrack extends StatelessWidget {
  const _RankedTrack({
    required this.rank,
    required this.song,
    required this.onTap,
  });

  final int rank;
  final SongModel song;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(LjodTheme.radiusMd),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: LjodTheme.panelBlack.withValues(alpha: 0.8),
              borderRadius: BorderRadius.circular(LjodTheme.radiusMd),
              border: Border.all(color: LjodTheme.borderLight),
            ),
            child: Row(
              children: [
                Container(
                  width: 30,
                  height: 30,
                  alignment: Alignment.center,
                  decoration: ShapeDecoration(
                    color: LjodTheme.amber.withValues(alpha: 0.14),
                    shape: MaterialShapeBorder(
                      shape: rank == 1
                          ? MaterialShapes.cookie4Sided
                          : MaterialShapes.diamond,
                      side: BorderSide(
                        color: LjodTheme.amber.withValues(
                          alpha: rank == 1 ? 0.5 : 0.25,
                        ),
                      ),
                    ),
                  ),
                  child: Text(
                    '$rank',
                    style: TextStyle(
                      fontSize: 11,
                      fontWeight: FontWeight.w800,
                      color: rank == 1 ? LjodTheme.amber : LjodTheme.textMuted,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                SongCover(song: song, size: 42, radius: 13),
                const SizedBox(width: 11),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        song.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        song.displayArtist,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: LjodTheme.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                LjodBadge(label: '${song.playCount}×', isActive: rank == 1),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ArtistBars extends StatelessWidget {
  const _ArtistBars({required this.artists});

  final List<ArtistStat> artists;

  @override
  Widget build(BuildContext context) {
    if (artists.isEmpty) {
      return const Panel(
        child: Text(
          'Artist rankings appear once tracks are played.',
          style: TextStyle(fontSize: 11, color: LjodTheme.textMuted),
        ),
      );
    }
    final theme = Theme.of(context);
    final max = artists.first.plays;
    return Column(
      children: [
        for (var i = 0; i < artists.length; i++)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      margin: const EdgeInsets.only(right: 8),
                      decoration: ShapeDecoration(
                        color: i == 0
                            ? LjodTheme.amber
                            : LjodTheme.borderStrong,
                        shape: MaterialShapeBorder(
                          shape: MaterialShapes.diamond,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        artists[i].name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: LjodTheme.textStrong,
                          fontWeight: i == 0
                              ? FontWeight.w700
                              : FontWeight.w500,
                        ),
                      ),
                    ),
                    Text(
                      '${artists[i].plays} plays · '
                      '${artists[i].tracks} '
                      '${artists[i].tracks == 1 ? 'track' : 'tracks'}',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: LjodTheme.textMuted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 7),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: Stack(
                    children: [
                      Container(height: 5, color: LjodTheme.panelHighest),
                      FractionallySizedBox(
                        widthFactor: artists[i].shareOf(max).clamp(0.04, 1.0),
                        child: Container(
                          height: 5,
                          decoration: const BoxDecoration(
                            gradient: LinearGradient(
                              colors: [LjodTheme.amber, LjodTheme.amberDeep],
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}
