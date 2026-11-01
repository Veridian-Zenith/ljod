import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/models/song_model.dart';
import '../library/library_providers.dart';

/// One artist's share of listening, used by the Insights screen.
class ArtistStat {
  const ArtistStat({
    required this.name,
    required this.plays,
    required this.tracks,
  });

  final String name;
  final int plays;
  final int tracks;

  /// Share of the top artist's plays, in the 0..1 range.
  double shareOf(int maxPlays) => maxPlays <= 0 ? 0 : plays / maxPlays;
}

class LibraryStats {
  const LibraryStats({
    required this.totalTracks,
    required this.totalFavorites,
    required this.totalAlbums,
    required this.totalPlayCount,
    required this.mostPlayedSong,
    required this.recentlyAddedCount,
    this.listeningTime = Duration.zero,
    this.mostPlayed = const [],
    this.topArtists = const [],
  });

  final int totalTracks;
  final int totalFavorites;
  final int totalAlbums;
  final int totalPlayCount;
  final SongModel? mostPlayedSong;
  final int recentlyAddedCount;

  /// Approximate listening time: counted plays of each track × its length.
  final Duration listeningTime;

  /// Up to five tracks with at least one play, most played first.
  final List<SongModel> mostPlayed;

  /// Up to five artists with at least one play, most played first.
  final List<ArtistStat> topArtists;

  static const empty = LibraryStats(
    totalTracks: 0,
    totalFavorites: 0,
    totalAlbums: 0,
    totalPlayCount: 0,
    mostPlayedSong: null,
    recentlyAddedCount: 0,
  );

  bool get hasPlayHistory => totalPlayCount > 0;
}

final statsProvider = Provider<LibraryStats>((ref) {
  final songs = ref.watch(songsProvider);
  if (songs.isEmpty) return LibraryStats.empty;

  final favorites = songs.where((s) => s.isFavorite).length;
  final albums = songs.map((s) => s.displayAlbum).toSet().length;
  final totalPlayCount = songs.fold(0, (sum, s) => sum + s.playCount);

  final sortedByPlay = [...songs]
    ..sort((a, b) => b.playCount.compareTo(a.playCount));
  final played = sortedByPlay
      .where((song) => song.playCount > 0)
      .take(5)
      .toList(growable: false);

  final microsPlayed = songs.fold<int>(
    0,
    (sum, song) => sum + song.duration.inMicroseconds * song.playCount,
  );

  final byArtist = <String, ({int plays, int tracks})>{};
  for (final song in songs) {
    final name = song.displayArtist;
    final entry = byArtist[name] ?? (plays: 0, tracks: 0);
    byArtist[name] = (
      plays: entry.plays + song.playCount,
      tracks: entry.tracks + 1,
    );
  }
  final artists =
      byArtist.entries
          .map(
            (entry) => ArtistStat(
              name: entry.key,
              plays: entry.value.plays,
              tracks: entry.value.tracks,
            ),
          )
          .where((artist) => artist.plays > 0)
          .toList(growable: false)
        ..sort((a, b) => b.plays.compareTo(a.plays));

  final now = DateTime.now();
  final recentlyAdded = songs
      .where(
        (s) => s.addedAt != null && now.difference(s.addedAt!).inDays <= 30,
      )
      .length;

  return LibraryStats(
    totalTracks: songs.length,
    totalFavorites: favorites,
    totalAlbums: albums,
    totalPlayCount: totalPlayCount,
    mostPlayedSong: played.isEmpty ? null : played.first,
    recentlyAddedCount: recentlyAdded,
    listeningTime: Duration(microseconds: microsPlayed),
    mostPlayed: played,
    topArtists: artists.take(5).toList(growable: false),
  );
});
