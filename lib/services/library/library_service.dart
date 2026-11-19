import 'dart:io';
import 'dart:math';

import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/diagnostics/diagnostics_log.dart';
import '../../core/models/folder_scope.dart';
import '../../core/models/song_model.dart';
import '../../core/utils/formatters.dart';

class LibraryPermissionException implements Exception {
  const LibraryPermissionException();

  @override
  String toString() => 'Music library permission was not granted.';
}

class LibraryScanException implements Exception {
  const LibraryScanException(this.message);

  final String message;

  @override
  String toString() => message;
}

const supportedFileExtensions = {
  '.mp3',
  '.flac',
  '.aac',
  '.ogg',
  '.m4a',
  '.wav',
  '.wma',
  '.opus',
  '.mp4',
  '.aiff',
  '.ape',
  '.mpc',
  '.wv',
};

/// A folder that currently contains audio reported by the platform.
class AudioFolder {
  const AudioFolder({required this.path, required this.trackCount});

  final String path;
  final int trackCount;

  String get name {
    final base = p.basename(path);
    return base.isEmpty ? path : base;
  }

  String get parent => p.dirname(path);
}

/// Outcome of a library scan.
///
/// One pass returns everything the app needs from the platform: the tracks, the
/// folders they live in, and how much could not be read. Nothing needs a second
/// query over the same files afterwards.
class LibraryScan {
  const LibraryScan({
    required this.songs,
    this.folders = const [],
    this.missingFiles = 0,
    this.tagReadFailures = 0,
    this.unreadableFolders = 0,
    this.truncated = false,
  });

  final List<SongModel> songs;

  /// Folders that contained audio, counted from the same rows the scan read.
  final List<AudioFolder> folders;

  /// Tracks whose file was gone when tags were read. Platform metadata is kept
  /// so the row still behaves like the library reported it.
  final int missingFiles;

  /// Tracks whose tags could not be parsed; platform metadata was used.
  final int tagReadFailures;

  /// Folders the desktop walk could not open.
  final int unreadableFolders;

  /// Whether the desktop walk stopped at [LibraryService.maxDesktopTracks].
  final bool truncated;
}

/// Raw platform rows plus what the query could not read.
class _RawScan {
  const _RawScan(
    this.tracks, {
    this.unreadableFolders = 0,
    this.truncated = false,
  });

  final List<Map<String, Object?>> tracks;
  final int unreadableFolders;
  final bool truncated;
}

/// Reads the device music library.
///
/// Android uses a thin MediaStore bridge so the scan respects scoped storage.
/// Desktop falls back to walking the usual music folders.
class LibraryService {
  const LibraryService();

  static const MethodChannel _channel = MethodChannel('dev.vz.ljod/media');
  static const int _enrichBatchSize = 48;

  /// Ceiling for the desktop walk, so a music folder that resolves to a huge
  /// tree cannot keep a scan running forever.
  static const int maxDesktopTracks = 5000;

  bool get isAndroid => !kIsWeb && Platform.isAndroid;

  Future<bool> hasPermission() async {
    if (!isAndroid) return true;
    final audio = await Permission.audio.status;
    return audio.isGranted || audio.isLimited;
  }

  Future<bool> requestPermission() async {
    if (!isAndroid) return true;
    final audio = await Permission.audio.request();
    return audio.isGranted || audio.isLimited;
  }

  Future<void> openSettings() async {
    await openAppSettings();
  }

  /// Scan the device and return playable tracks.
  ///
  /// [scope] decides which folders are read. [onProgress] is called after each
  /// metadata batch so the UI can show real progress instead of a spinner. The
  /// result also names any cached covers eviction had to remove.
  Future<LibraryScan> scan({
    FolderScope scope = const FolderScope(),
    void Function(int processed, int total)? onProgress,
  }) async {
    if (isAndroid && !await hasPermission()) {
      throw const LibraryPermissionException();
    }

    final stopwatch = Stopwatch()..start();
    final log = DiagnosticsLog.instance;
    log.log('scan: started', level: DiagnosticsLevel.info);

    // Covers are resolved online, so the directory that used to hold extracted
    // images is deleted rather than grown. Doing it before the query returns
    // the space even on a scan that finds no tracks.
    await clearArtworkCache();

    final source = await _scanSource();
    // A row the platform cannot give a path for is a fault worth reporting; a
    // row the folder rules excluded is expected and is not counted.
    final raw = <Map<String, Object?>>[];
    var pathless = 0;
    for (final track in source.tracks) {
      final path = track['path'];
      if (path is! String || path.isEmpty) {
        pathless++;
        continue;
      }
      if (!scope.allowsPath(path)) continue;
      raw.add(track);
    }
    if (pathless > 0) {
      log.log(
        'scan: $pathless platform row(s) had no file path and were skipped',
        level: DiagnosticsLevel.warning,
      );
    }

    // Counted from every row the platform returned, not the filtered ones:
    // folder rules must list a folder that is currently excluded, or it could
    // never be turned back on. Still the same query, so no second pass.
    final folders = _foldersFrom(source.tracks);

    if (raw.isEmpty) {
      onProgress?.call(0, 0);
      // An empty result with tracks on the device means the rules excluded
      // them; that is worth a warning, not a silent "0 tracks".
      log.log(
        'scan: no audio matched the folder rules '
        '(${source.tracks.length} track(s) on the device)',
        level: source.tracks.isEmpty
            ? DiagnosticsLevel.info
            : DiagnosticsLevel.warning,
      );
      return LibraryScan(songs: const [], folders: folders);
    }

    final enriched = <Map<String, Object?>>[];
    var missingFiles = 0;
    var tagReadFailures = 0;
    for (var start = 0; start < raw.length; start += _enrichBatchSize) {
      final end = min(start + _enrichBatchSize, raw.length);
      final batch = raw.sublist(start, end);
      final result = await compute(_enrichTracks, {'tracks': batch});
      final batchTracks = result['tracks'];
      if (batchTracks is List) {
        enriched.addAll(batchTracks.whereType<Map<String, Object?>>());
      }
      missingFiles += (result['missing'] as num?)?.toInt() ?? 0;
      tagReadFailures += (result['readFailed'] as num?)?.toInt() ?? 0;
      onProgress?.call(enriched.length, raw.length);
    }

    final seen = <String>{};
    final songs = <SongModel>[];
    for (final item in enriched) {
      final id = item['id'] as String?;
      final path = item['path'] as String?;
      if (id == null || path == null || path.isEmpty) continue;
      if (!seen.add(id)) continue;

      final parsed = parseFileStem(path);
      final title = _clean(item['title']) ?? parsed.title;
      final artist = _clean(item['artist']) ?? parsed.artist;
      final album = _clean(item['album']) ?? '';

      songs.add(
        SongModel(
          id: id,
          path: path,
          title: title,
          artist: artist,
          album: album,
          albumArtist: _clean(item['albumArtist']) ?? artist,
          duration: Duration(
            milliseconds: (item['durationMs'] as num?)?.toInt() ?? 0,
          ),
          trackNumber: (item['trackNumber'] as num?)?.toInt() ?? 0,
          addedAt: item['addedAtMs'] == null
              ? null
              : DateTime.fromMillisecondsSinceEpoch(
                  (item['addedAtMs'] as num).toInt(),
                ),
        ),
      );
    }

    songs.sort((a, b) {
      final byAlbum = a.album.toLowerCase().compareTo(b.album.toLowerCase());
      if (byAlbum != 0) return byAlbum;
      final byTrack = a.trackNumber.compareTo(b.trackNumber);
      if (byTrack != 0) return byTrack;
      return a.title.toLowerCase().compareTo(b.title.toLowerCase());
    });

    // One summary line holds what took a separate query before: tracks, the
    // shape of the library, and how long the pass took.
    final albums = songs.map((song) => song.displayAlbum).toSet().length;
    final artists = songs.map((song) => song.displayArtist).toSet().length;
    final totalMinutes =
        songs.fold<int>(0, (sum, song) => sum + song.duration.inMilliseconds) ~/
        60000;
    log.log(
      'scan: ${songs.length} tracks · $albums albums · $artists artists · '
      '${folders.length} folders · $totalMinutes min · '
      '${stopwatch.elapsedMilliseconds} ms',
      level: DiagnosticsLevel.info,
    );
    if (source.truncated) {
      log.log(
        'scan: stopped at $maxDesktopTracks files; narrow the folder rules to '
        'index the rest',
        level: DiagnosticsLevel.warning,
      );
    }
    if (source.unreadableFolders > 0) {
      log.log(
        'scan: ${source.unreadableFolders} folder(s) could not be read and '
        'were skipped',
        level: DiagnosticsLevel.warning,
      );
    }
    if (missingFiles > 0) {
      log.log(
        'scan: $missingFiles file(s) were missing while reading tags; platform '
        'metadata was kept',
        level: DiagnosticsLevel.warning,
      );
    }
    if (tagReadFailures > 0) {
      log.log(
        'scan: tags could not be read for $tagReadFailures file(s); platform '
        'metadata was used instead',
        level: DiagnosticsLevel.warning,
      );
    }
    log.log(
      'artwork: covers resolve online per album; nothing is extracted to disk',
      level: DiagnosticsLevel.info,
    );

    return LibraryScan(
      songs: songs,
      folders: folders,
      missingFiles: missingFiles,
      tagReadFailures: tagReadFailures,
      unreadableFolders: source.unreadableFolders,
      truncated: source.truncated,
    );
  }

  /// Deletes cover files that older builds extracted.
  ///
  /// Nothing writes to that directory any more, so it exists only on a device
  /// that ran a build with the on-disk artwork cache.
  Future<void> clearArtworkCache() async {
    try {
      final support = await getApplicationSupportDirectory();
      final directory = Directory(p.join(support.path, 'artwork'));
      if (await directory.exists()) {
        await directory.delete(recursive: true);
        DiagnosticsLog.instance.log(
          'artwork: deleted the legacy extracted-cover directory',
          level: DiagnosticsLevel.info,
        );
      }
    } catch (_) {
      // A missing or locked directory is not an error.
    }
  }

  /// Deletes derived files (cached artwork and lyrics) that live outside the
  /// database, so clearing the library cache does not leave them orphaned.
  ///
  /// Both directories are recreated lazily by the next scan or lyrics lookup.
  Future<void> clearCaches() async {
    try {
      final support = await getApplicationSupportDirectory();
      for (final name in ['artwork', 'lyrics']) {
        final directory = Directory(p.join(support.path, name));
        if (await directory.exists()) {
          await directory.delete(recursive: true);
        }
      }
    } catch (_) {
      // Cache cleanup is best-effort; never fail the caller.
    }
  }

  /// Lists folders that currently contain audio, with track counts.
  ///
  /// This is deliberately a lightweight MediaStore/filesystem query: no tags
  /// or artwork are read. After a scan the published folder list is used
  /// instead, so this only runs before the first scan or after a refresh.
  Future<List<AudioFolder>> listFolders() async {
    if (isAndroid && !await hasPermission()) {
      throw const LibraryPermissionException();
    }
    return _foldersFrom((await _scanSource()).tracks);
  }

  static List<AudioFolder> _foldersFrom(List<Map<String, Object?>> tracks) {
    final counts = <String, int>{};
    for (final track in tracks) {
      final path = track['path'];
      if (path is! String) continue;
      final folder = FolderScope.folderOf(path);
      if (folder == null) continue;
      counts[folder] = (counts[folder] ?? 0) + 1;
    }

    final folders = counts.entries
        .map((entry) => AudioFolder(path: entry.key, trackCount: entry.value))
        .toList(growable: false);
    folders.sort(
      (a, b) => a.path.toLowerCase().compareTo(b.path.toLowerCase()),
    );
    return folders;
  }

  Future<_RawScan> _scanSource() async {
    if (isAndroid) return _RawScan(await _queryAndroid());
    return _scanDesktop();
  }

  Future<List<Map<String, Object?>>> _queryAndroid() async {
    try {
      final result = await _channel.invokeListMethod<Object?>('queryAudio');
      if (result == null) return const [];
      return result
          .whereType<Map<Object?, Object?>>()
          .map(
            (row) => row.map((key, value) => MapEntry(key.toString(), value)),
          )
          .toList(growable: false);
    } on PlatformException catch (error) {
      throw LibraryScanException(
        error.message ?? 'The device music library could not be read.',
      );
    } on MissingPluginException {
      throw const LibraryScanException(
        'The device music bridge is unavailable on this build.',
      );
    }
  }

  Future<_RawScan> _scanDesktop() async {
    final roots = <Directory>{};
    final home =
        Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'];
    if (home != null) {
      for (final name in ['Music', 'Downloads', 'Downloads/Music']) {
        final directory = Directory(p.join(home, name));
        if (directory.existsSync()) roots.add(directory);
      }
    }
    final local = Directory(p.join(Directory.current.path, 'music'));
    if (local.existsSync()) roots.add(local);

    final tracks = <Map<String, Object?>>[];
    final seen = <String>{};
    var unreadableFolders = 0;
    var truncated = false;

    for (final root in roots) {
      if (truncated) break;
      try {
        await for (final entity in root.list(
          recursive: true,
          followLinks: false,
        )) {
          if (tracks.length >= maxDesktopTracks) {
            truncated = true;
            break;
          }
          if (entity is! File) continue;
          final extension = p.extension(entity.path).toLowerCase();
          if (!supportedFileExtensions.contains(extension)) continue;
          if (!seen.add(entity.path)) continue;

          final stat = await entity.stat();
          tracks.add({
            'id': entity.path,
            'path': entity.path,
            'title': null,
            'artist': null,
            'album': null,
            'albumArtist': null,
            'durationMs': 0,
            'trackNumber': 0,
            'addedAtMs': stat.modified.millisecondsSinceEpoch,
          });
        }
      } catch (_) {
        // Unreadable folder — skip it, keep scanning the rest, and report it.
        unreadableFolders++;
      }
    }

    return _RawScan(
      tracks,
      unreadableFolders: unreadableFolders,
      truncated: truncated,
    );
  }

  static String? _clean(Object? value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    if (trimmed.isEmpty || trimmed == '<unknown>') return null;
    return trimmed;
  }
}

/// Runs off the UI isolate. Reads tags only; cover art is resolved online, so
/// nothing here decodes or writes image bytes.
///
/// Returns the enriched tracks with counts of what could not be read, so the
/// scan can log one honest summary instead of losing failures in the isolate.
///
/// This runs in a spawned isolate, so it must stay free of plugin calls:
/// JNI-backed plugins (path_provider, shared_preferences) are bound to the
/// main isolate and fail here.
Map<String, Object?> _enrichTracks(Map<String, Object?> request) {
  final tracks = (request['tracks'] as List?) ?? const [];
  final output = <Map<String, Object?>>[];
  var missing = 0;
  var readFailed = 0;

  for (final entry in tracks) {
    if (entry is! Map) continue;
    final track = entry.map(
      (key, value) => MapEntry(key.toString(), value as Object?),
    );
    final path = track['path'] as String?;
    if (path == null || path.isEmpty) continue;

    final result = Map<String, Object?>.from(track);

    // Scoped storage may hand back a content:// URI with no file path. Keep the
    // MediaStore metadata so the track is still playable; just skip tag reads.
    final file = File(path);
    if (!file.existsSync()) {
      missing++;
      output.add(result);
      continue;
    }

    try {
      final metadata = readMetadata(file, getImage: false);
      result['title'] = _preferred(metadata.title, track['title']);
      result['artist'] = _preferred(metadata.artist, track['artist']);
      result['album'] = _preferred(metadata.album, track['album']);
      result['albumArtist'] = _preferred(
        metadata.albumArtist,
        track['albumArtist'],
      );
      result['trackNumber'] = metadata.trackNumber ?? track['trackNumber'];
      final duration = metadata.duration?.inMilliseconds ?? 0;
      if (duration > 0) result['durationMs'] = duration;
    } catch (_) {
      // Tag reading is best-effort; MediaStore metadata still stands.
      readFailed++;
    }

    output.add(result);
  }

  return {'tracks': output, 'missing': missing, 'readFailed': readFailed};
}

String? _preferred(String? value, Object? fallback) {
  final trimmed = value?.trim();
  if (trimmed != null && trimmed.isNotEmpty) return trimmed;
  if (fallback is String && fallback.trim().isNotEmpty) return fallback;
  return null;
}
