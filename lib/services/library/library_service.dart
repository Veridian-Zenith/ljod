import 'dart:io';
import 'dart:math';

import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/models/folder_scope.dart';
import '../../core/models/song_model.dart';
import '../../core/utils/formatters.dart';
import 'artwork_cache.dart';

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

/// Reads the device music library.
///
/// Android uses a thin MediaStore bridge so the scan respects scoped storage.
/// Desktop falls back to walking the usual music folders.
class LibraryService {
  const LibraryService();

  static const MethodChannel _channel = MethodChannel('dev.vz.ljod/media');
  static const int _enrichBatchSize = 48;

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
  /// metadata batch so the UI can show real progress instead of a spinner.
  Future<List<SongModel>> scan({
    FolderScope scope = const FolderScope(),
    void Function(int processed, int total)? onProgress,
    Map<String, String> knownArtwork = const {},
  }) async {
    if (isAndroid && !await hasPermission()) {
      throw const LibraryPermissionException();
    }

    final raw = (await _rawTracks())
        .where((track) {
          final path = track['path'];
          return path is String && scope.allowsPath(path);
        })
        .toList(growable: false);

    if (raw.isEmpty) {
      onProgress?.call(0, 0);
      return const [];
    }

    final support = await getApplicationSupportDirectory();
    final artworkDirectory = Directory(p.join(support.path, 'artwork'));
    if (!await artworkDirectory.exists()) {
      await artworkDirectory.create(recursive: true);
    }

    final enriched = <Map<String, Object?>>[];
    for (var start = 0; start < raw.length; start += _enrichBatchSize) {
      final end = min(start + _enrichBatchSize, raw.length);
      final batch = raw.sublist(start, end);
      // Only ship the artwork mapping for this batch: a whole-library map would
      // be copied across the isolate boundary on every chunk.
      final batchArtwork = <String, String>{
        for (final track in batch)
          if (knownArtwork[track['id']] != null)
            track['id'] as String: knownArtwork[track['id']]!,
      };
      final result = await compute(_enrichTracks, {
        'tracks': batch,
        'artworkDirectory': artworkDirectory.path,
        'knownArtwork': batchArtwork,
      });
      enriched.addAll(result);
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
          artworkPath: _clean(item['artworkPath']),
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

    // Keep the cache honest: drop covers for tracks that are gone, then hold
    // the directory under its byte budget. Both are best-effort.
    final keepArtwork = {
      for (final song in songs)
        if (song.artworkPath != null) song.artworkPath!,
    };
    final cache = ArtworkCache(artworkDirectory);
    await cache.pruneOrphans(keepArtwork);
    await cache.trim(keepPaths: keepArtwork);

    return songs;
  }

  /// Bytes currently used by cached cover art.
  Future<int> artworkCacheBytes() async {
    try {
      final support = await getApplicationSupportDirectory();
      return await ArtworkCache(Directory(p.join(support.path, 'artwork')))
          .usageBytes();
    } catch (_) {
      return 0;
    }
  }

  /// Deletes cached cover art only, leaving the indexed library intact.
  Future<void> clearArtworkCache() async {
    try {
      final support = await getApplicationSupportDirectory();
      await ArtworkCache(Directory(p.join(support.path, 'artwork'))).clear();
    } catch (_) {
      // Best effort; artwork is rebuilt on the next scan.
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
  /// or artwork are read, so folder rules open quickly.
  Future<List<AudioFolder>> listFolders() async {
    if (isAndroid && !await hasPermission()) {
      throw const LibraryPermissionException();
    }

    final counts = <String, int>{};
    for (final track in await _rawTracks()) {
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

  Future<List<Map<String, Object?>>> _rawTracks() async {
    if (isAndroid) return _queryAndroid();
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

  Future<List<Map<String, Object?>>> _scanDesktop() async {
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

    for (final root in roots) {
      try {
        await for (final entity in root.list(
          recursive: true,
          followLinks: false,
        )) {
          if (tracks.length >= 5000) break;
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
        // Unreadable folder — skip it and keep scanning the rest.
      }
    }

    return tracks;
  }

  static String? _clean(Object? value) {
    if (value is! String) return null;
    final trimmed = value.trim();
    if (trimmed.isEmpty || trimmed == '<unknown>') return null;
    return trimmed;
  }
}

/// Runs off the UI isolate. Reads tags and caches embedded cover art.
List<Map<String, Object?>> _enrichTracks(Map<String, Object?> request) {
  final tracks = (request['tracks'] as List?) ?? const [];
  final artworkDirectory = request['artworkDirectory'] as String?;
  final output = <Map<String, Object?>>[];

  for (final entry in tracks) {
    if (entry is! Map) continue;
    final track = entry.map(
      (key, value) => MapEntry(key.toString(), value as Object?),
    );
    final path = track['path'] as String?;
    if (path == null || path.isEmpty) continue;

    final result = Map<String, Object?>.from(track);

    final id = (track['id'] as String?) ?? path;
    final knownArtwork = (request['knownArtwork'] as Map?) ?? const {};
    final known = knownArtwork[id];
    // Reuse previously extracted art when the file still exists, so rescans do
    // not re-read every cover from every file.
    final hasArtwork = known is String && File(known).existsSync();
    if (hasArtwork) result['artworkPath'] = known;

    // Scoped storage may hand back a content:// URI with no file path. Keep the
    // MediaStore metadata so the track is still playable; just skip tag reads.
    final file = File(path);
    if (!file.existsSync()) {
      output.add(result);
      continue;
    }

    try {
      final metadata = readMetadata(file, getImage: !hasArtwork);
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

      if (!hasArtwork &&
          artworkDirectory != null &&
          metadata.pictures.isNotEmpty) {
        final picture = _bestPicture(metadata.pictures);
        if (picture != null) {
          final written = ArtworkCache.storeBytes(
            artworkDirectory,
            picture.bytes,
          );
          if (written != null) result['artworkPath'] = written;
        }
      }
    } catch (_) {
      // Tag reading is best-effort; MediaStore metadata still stands.
    }

    output.add(result);
  }

  return output;
}

String? _preferred(String? value, Object? fallback) {
  final trimmed = value?.trim();
  if (trimmed != null && trimmed.isNotEmpty) return trimmed;
  if (fallback is String && fallback.trim().isNotEmpty) return fallback;
  return null;
}

Picture? _bestPicture(List<Picture> pictures) {
  if (pictures.isEmpty) return null;
  for (final picture in pictures) {
    if (picture.pictureType == PictureType.coverFront) return picture;
  }
  return pictures.first;
}
