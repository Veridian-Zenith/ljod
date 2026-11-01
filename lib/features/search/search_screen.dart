import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/models/song_model.dart';
import '../../core/theme/ljod_theme.dart';
import '../../core/widgets/vz_components.dart';
import '../../services/audio/audio_providers.dart';
import '../../services/library/library_providers.dart';

class SearchScreen extends ConsumerStatefulWidget {
  const SearchScreen({super.key});

  @override
  ConsumerState<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends ConsumerState<SearchScreen> {
  final _controller = TextEditingController();
  int _filter = 0;
  String _query = '';

  static const _filters = ['All', 'Title', 'Artist', 'Album'];

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  List<SongModel> _results(List<SongModel> songs) {
    final query = _query.trim().toLowerCase();
    if (query.isEmpty) return const [];
    return songs
        .where((song) {
          final title = song.title.toLowerCase();
          final artist = song.displayArtist.toLowerCase();
          final album = song.displayAlbum.toLowerCase();
          return switch (_filter) {
            1 => title.contains(query),
            2 => artist.contains(query),
            3 => album.contains(query),
            _ =>
              title.contains(query) ||
                  artist.contains(query) ||
                  album.contains(query),
          };
        })
        .toList(growable: false);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final songs = ref.watch(songsProvider);
    final nowPlaying = ref.watch(nowPlayingProvider);
    final playing = ref.watch(playingProvider).value ?? false;
    final controller = ref.read(playbackControllerProvider);
    final results = _results(songs);
    final suggestions = nowPlaying == null
        ? songs.take(6).toList()
        : [
            nowPlaying,
            ...songs.where((song) => song.id != nowPlaying.id).take(5),
          ];

    return SafeArea(
      bottom: false,
      child: CustomScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        slivers: [
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'SEARCH',
                    style: LjodTheme.display(theme.textTheme, size: 30),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Find a track, artist or album in the vault.',
                    style: theme.textTheme.bodySmall,
                  ),
                  const SizedBox(height: 16),
                  LjodSearchBar(
                    controller: _controller,
                    onChanged: (value) => setState(() => _query = value),
                  ),
                ],
              ),
            ),
          ),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20),
              child: FilterChipRow(
                labels: _filters,
                selectedIndex: _filter,
                onSelected: (index) => setState(() => _filter = index),
                padding: EdgeInsets.zero,
              ),
            ),
          ),
          const SliverToBoxAdapter(child: SizedBox(height: 14)),
          if (_query.trim().isEmpty) ...[
            SliverToBoxAdapter(
              child: SectionHeader(
                title: 'Start here',
                eyebrow: 'Suggestions',
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              ),
            ),
            SliverList.builder(
              itemCount: suggestions.length,
              itemBuilder: (context, index) {
                final song = suggestions[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: SongTile(
                    song: song,
                    isCurrent: nowPlaying?.id == song.id,
                    playing: playing,
                    onTap: () => controller.playSong(song, queue: suggestions),
                  ),
                );
              },
            ),
          ] else if (results.isEmpty)
            SliverFillRemaining(
              hasScrollBody: false,
              child: EmptyState(
                icon: Icons.travel_explore_rounded,
                title: 'No matches',
                message:
                    'Nothing in the vault matches “$_query”. '
                    'Try another spelling or a different field.',
                compact: true,
              ),
            )
          else ...[
            SliverToBoxAdapter(
              child: SectionHeader(
                title: '${results.length} results',
                eyebrow: 'Matches',
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 6),
              ),
            ),
            SliverList.builder(
              itemCount: results.length,
              itemBuilder: (context, index) {
                final song = results[index];
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: SongTile(
                    song: song,
                    isCurrent: nowPlaying?.id == song.id,
                    playing: playing,
                    onTap: () => controller.playSong(song, queue: results),
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
