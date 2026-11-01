import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/models/song_model.dart';
import '../../core/theme/ljod_theme.dart';
import '../../core/widgets/vz_components.dart';
import '../../services/audio/audio_providers.dart';
import '../../services/library/library_providers.dart';
import '../../services/settings/settings_provider.dart';
import '../../services/stats/stats_provider.dart';
import '../stats/stats_screen.dart';

enum _LibrarySort { title, artist, recent, duration }

class LibraryScreen extends ConsumerStatefulWidget {
  const LibraryScreen({super.key});

  @override
  ConsumerState<LibraryScreen> createState() => _LibraryScreenState();
}

class _LibraryScreenState extends ConsumerState<LibraryScreen> {
  int _filter = 0;
  bool _grid = false;
  _LibrarySort _sort = _LibrarySort.title;
  String? _albumFilter;

  @override
  Widget build(BuildContext context) {
    final library = ref.watch(libraryProvider);
    final state = library.value ?? const LibraryState();
    final nowPlaying = ref.watch(nowPlayingProvider);
    final playing = ref.watch(playingProvider).value ?? false;
    final controller = ref.read(playbackControllerProvider);
    final favoritesFirst = ref.watch(settingsProvider).sortFavoritesFirst;
    final stats = ref.watch(statsProvider);

    final byAlbum = <String, List<SongModel>>{};
    for (final song in state.songs) {
      (byAlbum[song.displayAlbum] ??= <SongModel>[]).add(song);
    }

    var songs = _filter == 1 ? state.favorites : [...state.songs];
    final album = _albumFilter;
    if (album != null) {
      songs = songs
          .where((song) => song.displayAlbum == album)
          .toList(growable: false);
    }
    songs.sort((a, b) {
      if (favoritesFirst && a.isFavorite != b.isFavorite) {
        return a.isFavorite ? -1 : 1;
      }
      return switch (_sort) {
        _LibrarySort.title => a.title.toLowerCase().compareTo(
          b.title.toLowerCase(),
        ),
        _LibrarySort.artist => a.displayArtist.toLowerCase().compareTo(
          b.displayArtist.toLowerCase(),
        ),
        _LibrarySort.recent => (b.addedAt ?? DateTime(0)).compareTo(
          a.addedAt ?? DateTime(0),
        ),
        _LibrarySort.duration => b.duration.compareTo(a.duration),
      };
    });

    return SafeArea(
      bottom: false,
      child: CustomScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        slivers: [
          SliverToBoxAdapter(
            child: _Header(
              tracks: stats.totalTracks,
              albums: stats.totalAlbums,
              favorites: stats.totalFavorites,
              scanning: state.isScanning,
              onRescan: () => ref.read(libraryProvider.notifier).rescan(),
              onStats: () => Navigator.of(context).push(StatsScreen.route()),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 2, 12, 10),
              child: Row(
                children: [
                  Expanded(
                    child: FilterChipRow(
                      labels: const ['All tracks', 'Favourites'],
                      selectedIndex: _filter,
                      onSelected: (index) => setState(() => _filter = index),
                      padding: EdgeInsets.zero,
                    ),
                  ),
                  const SizedBox(width: 4),
                  PopupMenuButton<_LibrarySort>(
                    tooltip: 'Sort',
                    initialValue: _sort,
                    onSelected: (value) => setState(() => _sort = value),
                    itemBuilder: (context) => const [
                      PopupMenuItem(
                        value: _LibrarySort.title,
                        child: Text('Title'),
                      ),
                      PopupMenuItem(
                        value: _LibrarySort.artist,
                        child: Text('Artist'),
                      ),
                      PopupMenuItem(
                        value: _LibrarySort.recent,
                        child: Text('Recently added'),
                      ),
                      PopupMenuItem(
                        value: _LibrarySort.duration,
                        child: Text('Duration'),
                      ),
                    ],
                    icon: const Icon(Icons.sort_rounded, size: 20),
                  ),
                  IconButton(
                    tooltip: _grid ? 'List view' : 'Grid view',
                    onPressed: () => setState(() => _grid = !_grid),
                    icon: Icon(
                      _grid
                          ? Icons.view_agenda_rounded
                          : Icons.grid_view_rounded,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (byAlbum.length > 1)
            SliverToBoxAdapter(
              child: SizedBox(
                height: 146,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  itemCount: byAlbum.length + 1,
                  separatorBuilder: (_, _) => const SizedBox(width: 10),
                  itemBuilder: (context, index) {
                    if (index == 0) {
                      return _AlbumChip(
                        name: 'All albums',
                        count: state.songs.length,
                        selected: _albumFilter == null,
                        artworkPath: null,
                        allTile: true,
                        onTap: () => setState(() => _albumFilter = null),
                      );
                    }
                    final entry = byAlbum.entries.elementAt(index - 1);
                    return _AlbumChip(
                      name: entry.key,
                      count: entry.value.length,
                      artworkPath: entry.value.first.artworkPath,
                      selected: _albumFilter == entry.key,
                      onTap: () => setState(
                        () => _albumFilter = _albumFilter == entry.key
                            ? null
                            : entry.key,
                      ),
                    );
                  },
                ),
              ),
            ),
          if (state.permissionDenied)
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: _PermissionCard(
                  onGrant: () => ref.read(libraryProvider.notifier).rescan(),
                  onOpenSettings: () =>
                      ref.read(libraryServiceProvider).openSettings(),
                ),
              ),
            )
          else if (state.songs.isEmpty && library.isLoading)
            const SliverFillRemaining(
              hasScrollBody: false,
              child: LoadingView(label: 'Indexing the vault…'),
            )
          else if (songs.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: EmptyState(
                icon: album != null
                    ? Icons.album_rounded
                    : _filter == 1
                    ? Icons.favorite_border_rounded
                    : Icons.library_music_rounded,
                title: album != null
                    ? 'Nothing in this album'
                    : _filter == 1
                    ? 'No pinned tracks'
                    : 'Library empty',
                message: album != null
                    ? 'No tracks in “$album” match the current filter.'
                    : _filter == 1
                    ? 'Tap the heart on any track to keep it close.'
                    : 'Grant music access and Ljod will index every supported '
                          'audio file on the device.',
                action: album != null
                    ? TextButton(
                        onPressed: () => setState(() => _albumFilter = null),
                        child: const Text('Show all albums'),
                      )
                    : _filter == 1
                    ? TextButton(
                        onPressed: () => setState(() => _filter = 0),
                        child: const Text('Browse all tracks'),
                      )
                    : FilledButton.icon(
                        onPressed: () =>
                            ref.read(libraryProvider.notifier).rescan(),
                        icon: const Icon(Icons.radar_rounded, size: 18),
                        label: const Text('Scan device'),
                      ),
              ),
            )
          else if (_grid)
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 210),
              sliver: SliverGrid.builder(
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: 16,
                  crossAxisSpacing: 16,
                  childAspectRatio: 0.72,
                ),
                itemCount: songs.length,
                itemBuilder: (context, index) {
                  final song = songs[index];
                  return AlbumTile(
                    title: song.title,
                    subtitle: song.displayArtist,
                    artworkPath: song.artworkPath,
                    badge: song.isFavorite ? 'Pinned' : null,
                    onTap: () => controller.playSong(song, queue: songs),
                  );
                },
              ),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 210),
              sliver: SliverList.builder(
                itemCount: songs.length,
                itemBuilder: (context, index) {
                  final song = songs[index];
                  return SongTile(
                    song: song,
                    isCurrent: nowPlaying?.id == song.id,
                    playing: playing,
                    onTap: () => controller.playSong(song, queue: songs),
                    onFavorite: () =>
                        ref.read(libraryProvider.notifier).toggleFavorite(song),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}

/// Compact album browser so the library is not a bare list of rows.
class _AlbumChip extends StatelessWidget {
  const _AlbumChip({
    required this.name,
    required this.count,
    required this.selected,
    required this.onTap,
    this.artworkPath,
    this.allTile = false,
  });

  final String name;
  final int count;
  final bool selected;
  final VoidCallback onTap;
  final String? artworkPath;
  final bool allTile;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 104,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(LjodTheme.radiusMd),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 90,
              height: 90,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(LjodTheme.radiusMd),
                border: Border.all(
                  color: selected ? LjodTheme.amber : LjodTheme.borderLight,
                  width: selected ? 1.6 : 1,
                ),
              ),
              clipBehavior: Clip.antiAlias,
              child: allTile
                  ? Container(
                      color: LjodTheme.panelBlack,
                      child: Icon(
                        Icons.grid_view_rounded,
                        size: 26,
                        color: selected ? LjodTheme.amber : LjodTheme.textMuted,
                      ),
                    )
                  : CoverArt(
                      path: artworkPath,
                      size: 90,
                      radius: 0,
                      label: name,
                    ),
            ),
            const SizedBox(height: 6),
            Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: theme.textTheme.labelMedium?.copyWith(
                color: selected ? LjodTheme.amber : LjodTheme.textStrong,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.2,
              ),
            ),
            Text(
              '$count ${count == 1 ? 'track' : 'tracks'}',
              style: theme.textTheme.labelSmall?.copyWith(
                color: LjodTheme.textMuted,
                fontSize: 9,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.tracks,
    required this.albums,
    required this.favorites,
    required this.scanning,
    required this.onRescan,
    required this.onStats,
  });

  final int tracks;
  final int albums;
  final int favorites;
  final bool scanning;
  final VoidCallback onRescan;
  final VoidCallback onStats;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 12, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'LIBRARY',
                  style: LjodTheme.display(theme.textTheme, size: 30),
                ),
              ),
              if (scanning)
                const Padding(
                  padding: EdgeInsets.only(right: 10),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else
                IconButton(
                  onPressed: onRescan,
                  tooltip: 'Rescan device',
                  icon: const Icon(Icons.radar_rounded),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: StatCard(
                  value: '$tracks',
                  label: 'Tracks',
                  dense: true,
                  onTap: onStats,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: StatCard(
                  value: '$albums',
                  label: 'Albums',
                  dense: true,
                  onTap: onStats,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: StatCard(
                  value: '$favorites',
                  label: 'Pinned',
                  dense: true,
                  onTap: onStats,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _PermissionCard extends StatelessWidget {
  const _PermissionCard({required this.onGrant, required this.onOpenSettings});

  final VoidCallback onGrant;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    return Panel(
      borderColor: LjodTheme.amber.withValues(alpha: 0.4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(
                Icons.lock_outline_rounded,
                color: LjodTheme.amber,
                size: 18,
              ),
              SizedBox(width: 8),
              Text(
                'MUSIC ACCESS REQUIRED',
                style: TextStyle(
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.4,
                  color: LjodTheme.amber,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Ljod only reads audio files. Nothing leaves the device.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              FilledButton.icon(
                onPressed: onGrant,
                icon: const Icon(Icons.lock_open_rounded, size: 18),
                label: const Text('Allow access'),
              ),
              TextButton.icon(
                onPressed: onOpenSettings,
                icon: const Icon(Icons.settings_rounded, size: 16),
                label: const Text('App settings'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
