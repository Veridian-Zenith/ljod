import 'dart:io';

import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart';

import '../diagnostics/diagnostics_log.dart';
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
    final path = await _databasePath();

    return openDatabase(
      path,
      version: 4,
      onCreate: (db, version) => _createSchema(db),
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 3) {
          // The library is a rebuildable cache; schema changes are cheap. Every
          // table this schema creates has to be dropped: a leftover
          // `playlist_songs` makes the CREATE below fail and leaves the database
          // unopenable.
          await db.execute('DROP TABLE IF EXISTS playlist_songs');
          await db.execute('DROP TABLE IF EXISTS playlists');
          await db.execute('DROP TABLE IF EXISTS songs');
          await _createSchema(db);
          return;
        }
        if (oldVersion < 4) {
          // Artwork moved online: the database now remembers cover URLs instead
          // of file paths. The songs table is untouched, so a library already
          // indexed keeps its favourites and play counts.
          await _createArtworkUrlsTable(db);
        }
      },
    );
  }

  /// Absolute path of the database file.
  ///
  /// A folder that already holds the database wins, so a directory that starts
  /// resolving again cannot strand the library in another one. Only when no
  /// folder has one yet does the preference order decide: documents (where the
  /// library canonically lives), then sqflite's own databases folder, which
  /// sqflite answers through its platform channel and therefore survives a
  /// fault in the directory bridge, then the support folder. Nothing here
  /// assumes which plugin answers, so replacing one cannot empty the app.
  Future<String> _databasePath() async {
    const fileName = 'ljod_library.db';
    final candidates = <String, Future<String> Function()>{
      'documents': () async => (await getApplicationDocumentsDirectory()).path,
      'sqflite': getDatabasesPath,
      'support': () async => (await getApplicationSupportDirectory()).path,
    };

    final resolved = <String, String>{};
    Object? firstFailure;
    for (final candidate in candidates.entries) {
      try {
        final directory = await candidate.value();
        if (directory.isEmpty) continue;
        resolved[candidate.key] = directory;
      } catch (error) {
        firstFailure ??= error;
      }
    }

    if (resolved.isEmpty) {
      throw StateError(
        'No writable directory could be resolved for the library database: '
        '$firstFailure',
      );
    }

    final preferred = candidates.keys.first;
    for (final entry in resolved.entries) {
      if (!await File(join(entry.value, fileName)).exists()) continue;
      if (entry.key != preferred) {
        DiagnosticsLog.instance.log(
          'library: the existing database is in the ${entry.key} folder, so it '
          'is used instead of the $preferred folder',
          level: DiagnosticsLevel.info,
        );
      }
      return join(entry.value, fileName);
    }

    final chosen = resolved.entries.first;
    if (chosen.key != preferred) {
      DiagnosticsLog.instance.log(
        'library: the $preferred folder could not be resolved, so the database '
        'is in the ${chosen.key} folder. First failure: $firstFailure',
        level: DiagnosticsLevel.warning,
      );
    }
    return join(chosen.value, fileName);
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
    await _createArtworkUrlsTable(db);
  }

  /// One row per album: the cover URL found online, or an empty string when no
  /// catalogue had one. Text only — no images are stored on the device.
  Future<void> _createArtworkUrlsTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS artwork_urls (
        albumKey TEXT PRIMARY KEY,
        url TEXT NOT NULL,
        fetchedAtMs INTEGER NOT NULL
      )
    ''');
  }

  Future<List<SongModel>> allSongs() async {
    final db = await database;
    final rows = await db.query('songs', orderBy: 'title COLLATE NOCASE ASC');
    return rows.map(SongModel.fromDbMap).toList(growable: false);
  }

  /// Forgets cover paths written by builds that extracted artwork to disk.
  ///
  /// The column stays in the schema so older databases still open, but nothing
  /// reads it: covers are URLs resolved per album.
  Future<void> clearArtworkPaths() async {
    final db = await database;
    await db.update('songs', {'artworkPath': null});
  }

  /// Remembered cover URL for [albumKey], with the time it was fetched.
  Future<({String url, int fetchedAtMs})?> artworkUrl(String albumKey) async {
    final db = await database;
    final rows = await db.query(
      'artwork_urls',
      columns: ['url', 'fetchedAtMs'],
      where: 'albumKey = ?',
      whereArgs: [albumKey],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    final row = rows.first;
    return (
      url: row['url'] as String? ?? '',
      fetchedAtMs: (row['fetchedAtMs'] as int?) ?? 0,
    );
  }

  /// Stores a cover URL, or an empty string to remember that there is none.
  Future<void> setArtworkUrl(String albumKey, String? url) async {
    final db = await database;
    await db.insert('artwork_urls', {
      'albumKey': albumKey,
      'url': url ?? '',
      'fetchedAtMs': DateTime.now().millisecondsSinceEpoch,
    }, conflictAlgorithm: ConflictAlgorithm.replace);
  }

  Future<int> artworkUrlCount() async {
    final db = await database;
    final rows = await db.rawQuery(
      "SELECT COUNT(*) AS n FROM artwork_urls WHERE url <> ''",
    );
    return (rows.first['n'] as int?) ?? 0;
  }

  Future<void> clearArtworkUrls() async {
    final db = await database;
    await db.delete('artwork_urls');
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
          artworkPath = excluded.artworkPath
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
