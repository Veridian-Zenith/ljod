import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/database/app_database.dart';
import '../../core/models/song.dart';

/// Repository responsible for querying local songs.
/// Works harmoniously with AppDatabase and exposes reactive streams/states
/// while remaining fully capable of operating solo for unit testing or direct queries.
class LibraryRepository {
  final AppDatabase _db;

  LibraryRepository({AppDatabase? db}) : _db = db ?? AppDatabase.instance;

  Future<List<Song>> getSongs() async {
    final db = await _db.database;
    final result = await db.query('songs');
    if (result.isEmpty) {
      // Return stub data for preview/standalone mode if database is empty
      return _getStubSongs();
    }
    return result.map((map) => Song(
      id: map['id'] as String,
      title: map['title'] as String,
      artist: map['artist'] as String,
      album: map['album'] as String,
      durationMs: map['duration'] as int,
      path: map['path'] as String,
      isFavorite: (map['isFavorite'] as int) == 1,
      playCount: map['playCount'] as int,
    )).toList();
  }

  Future<void> toggleFavorite(String songId, bool isFavorite) async {
    final db = await _db.database;
    await db.update(
      'songs',
      {'isFavorite': isFavorite ? 1 : 0},
      where: 'id = ?',
      whereArgs: [songId],
    );
  }

  List<Song> _getStubSongs() {
    return const [
      Song(
        id: '1',
        title: 'Aurora Echoes',
        artist: 'Veridian Zenith',
        album: 'Ljod Genesis',
        durationMs: 215000,
        path: '/storage/emulated/0/Music/aurora.flac',
        isFavorite: true,
      ),
      Song(
        id: '2',
        title: 'C2 Silicon Pulse',
        artist: 'Audio Architect',
        album: 'Hardware Decode',
        durationMs: 180000,
        path: '/storage/emulated/0/Music/pulse.mp3',
      ),
    ];
  }
}

final libraryRepositoryProvider = Provider<LibraryRepository>((ref) {
  return LibraryRepository();
});
