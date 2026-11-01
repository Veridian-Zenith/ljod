import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../models/song_model.dart';

/// Local, offline-first library database.
///
/// The songs table is a cache of the device library. Favourite / play-count
/// state is preserved across rescans because a scan only upserts metadata.
class AppDatabase {
  AppDatabase._();

  static final AppDatabase instance = AppDatabase._();
  static Database? _database;

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _open();
    return _database!;
  }

  Future<Database> _open() async {
    final directory = await getApplicationDocumentsDirectory();
    final path = join(directory.path, 'ljod_library.db');

    return openDatabase(
      path,
      version: 3,
      onCreate: (db, version) => _createSchema(db),
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 3) {
          // The library is a rebuildable cache; schema changes are cheap.
          await db.execute('DROP TABLE IF EXISTS songs');
          await db.execute('DROP TABLE IF EXISTS playlists');
          await _createSchema(db);
        }
      },
    );
  }

  Future<void> _createSchema(Database db) async {
    await db.execute('''
      CREATE TABLE songs (
        id TEXT PRIMARY KEY,
        path TEXT NOT NULL,
        title TEXT NOT NULL,
        artist TEXT NOT NULL,
        album TEXT NOT NULL,
        albumArtist TEXT NOT NULL DEFAULT '',
        durationMs INTEGER NOT NULL,
        trackNumber INTEGER NOT NULL DEFAULT 0,
        artworkPath TEXT,
        isFavorite INTEGER NOT NULL DEFAULT 0,
        playCount INTEGER NOT NULL DEFAULT 0,
        lastPlayedMs INTEGER,
        addedAtMs INTEGER NOT NULL
      )
    ''');
    await db.execute('CREATE INDEX idx_songs_title ON songs(title)');
    await db.execute('CREATE INDEX idx_songs_artist ON songs(artist)');
    await db.execute('CREATE INDEX idx_songs_album ON songs(album)');

    await db.execute('''
      CREATE TABLE playlists (
        id TEXT PRIMARY KEY,
        name TEXT NOT NULL,
        createdAt INTEGER NOT NULL
      )
    ''');
    await db.execute('''
      CREATE TABLE playlist_songs (
        playlistId TEXT NOT NULL,
        songId TEXT NOT NULL,
        position INTEGER NOT NULL,
        PRIMARY KEY (playlistId, songId)
      )
    ''');
  }

  Future<List<SongModel>> allSongs() async {
    final db = await database;
    final rows = await db.query('songs', orderBy: 'title COLLATE NOCASE ASC');
    return rows.map(SongModel.fromDbMap).toList(growable: false);
  }

  /// Upserts every scanned track while preserving user state.
  /// Previously extracted artwork per song id, so a rescan can reuse cached
  /// covers instead of re-reading every file.
  Future<Map<String, String>> artworkPaths() async {
    final db = await database;
    final rows = await db.query(
      'songs',
      columns: ['id', 'artworkPath'],
      where: 'artworkPath IS NOT NULL',
    );
    return {
      for (final row in rows)
        if ((row['artworkPath'] as String?)?.isNotEmpty ?? false)
          row['id'] as String: row['artworkPath'] as String,
    };
  }

  /// Forgets cached artwork paths after the artwork directory is cleared.
  Future<void> clearArtworkPaths() async {
    final db = await database;
    await db.update('songs', {'artworkPath': null});
  }

  Future<void> upsertSongs(List<SongModel> songs) async {
    if (songs.isEmpty) return;
    final db = await database;
    final batch = db.batch();

    for (final song in songs) {
      final map = song.toDbMap()
        ..remove('isFavorite')
        ..remove('playCount')
        ..remove('lastPlayedMs');

      batch.rawInsert(
        '''
        INSERT INTO songs (
          id, path, title, artist, album, albumArtist, durationMs,
          trackNumber, artworkPath, isFavorite, playCount, lastPlayedMs, addedAtMs
        ) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, 0, 0, NULL, ?)
        ON CONFLICT(id) DO UPDATE SET
          path = excluded.path,
          title = excluded.title,
          artist = excluded.artist,
          album = excluded.album,
          albumArtist = excluded.albumArtist,
          durationMs = excluded.durationMs,
          trackNumber = excluded.trackNumber,
          artworkPath = COALESCE(excluded.artworkPath, songs.artworkPath)
        ''',
        [
          map['id'],
          map['path'],
          map['title'],
          map['artist'],
          map['album'],
          map['albumArtist'],
          map['durationMs'],
          map['trackNumber'],
          map['artworkPath'],
          map['addedAtMs'],
        ],
      );
    }

    await batch.commit(noResult: true);
  }

  /// Removes cached rows whose files disappeared from device storage.
  Future<void> removeMissing(Set<String> keepIds) async {
    final db = await database;
    final rows = await db.query('songs', columns: ['id']);
    final stale = rows
        .map((row) => row['id'] as String)
        .where((id) => !keepIds.contains(id))
        .toList();
    if (stale.isEmpty) return;

    final batch = db.batch();
    for (final id in stale) {
      batch.delete('songs', where: 'id = ?', whereArgs: [id]);
    }
    await batch.commit(noResult: true);
  }

  Future<void> setFavorite(String id, bool favorite) async {
    final db = await database;
    await db.update(
      'songs',
      {'isFavorite': favorite ? 1 : 0},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> markPlayed(String id) async {
    final db = await database;
    await db.rawUpdate(
      '''
      UPDATE songs
      SET playCount = playCount + 1, lastPlayedMs = ?
      WHERE id = ?
      ''',
      [DateTime.now().millisecondsSinceEpoch, id],
    );
  }

  Future<void> clear() async {
    final db = await database;
    await db.delete('songs');
  }

  Future<void> close() async {
    final db = _database;
    if (db != null) {
      await db.close();
      _database = null;
    }
  }
}
