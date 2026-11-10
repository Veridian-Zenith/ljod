import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

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
import 'artwork_cache.dart';
import 'sidecar_artwork.dart';

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
class LibraryScan {
  const LibraryScan({
    required this.songs,
    this.evictedArtwork = const <String>{},
  });

  final List<SongModel> songs;

  /// Cover files the cache had to evict to stay inside its budget. [songs] may
  /// still reference them, so the database has to forget those paths before the
  /// library is reloaded.
  final Set<String> evictedArtwork;
}

/// Reads the device music library.
///
/// Android uses a thin MediaStore bridge so the scan respects scoped storage.
/// Desktop falls back to walking the usual music folders.
class LibraryService {
  const LibraryService();

  static const MethodChannel _channel = MethodChannel('dev.vz.ljod/media');
  static const int _enrichBatchSize = 48;
  static const int _artworkBatchSize = 24;

  /// Raw covers accepted before the downscaling pass on Android.
  ///
  /// A 3000×3000 PNG cover is routinely 6–12 MiB. The cache ceiling used to
  /// apply to the raw bytes, so such a cover was refused outright and the track
  /// looked untagged — 680 of 1744 tracks in one library. The platform decoder
  /// re-encodes whatever arrives here, so only the pathological case is capped.
  static const int _maxRawArtworkBytes = 24 * 1024 * 1024;

  /// Size above which reused art is downscaled during a scan.
  ///
  /// Covers written before downscaling existed are still full size; they are
  /// converted on the next scan, while covers already at display size are left
  /// alone so a scan does not decode the whole cache.
  static const int _reshrinkAboveBytes = 700 * 1024;

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
      return const LibraryScan(songs: []);
    }

    final support = await getApplicationSupportDirectory();
    final artworkDirectory = Directory(p.join(support.path, 'artwork'));
    if (!await artworkDirectory.exists()) {
      await artworkDirectory.create(recursive: true);
    }

    final enriched = <Map<String, Object?>>[];
    // Pre-downscale cover path -> cached path, shared by every batch so a
    // reused album cover is decoded once and later batches reuse the mapping.
    final replacements = <String, String>{};
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
        'maxRawBytes': isAndroid
            ? _maxRawArtworkBytes
            : ArtworkCache.maxFileBytes,
      });
      enriched.addAll(result);
      if (isAndroid) {
        await _shrinkArtwork(result, artworkDirectory, replacements);
      }
      onProgress?.call(enriched.length, raw.length);
    }

    // Tag reading needs a readable file path. Scoped storage can hand back a
    // `content://` URI instead, and then the cover is lost even though the
    // picture is right there in the file. Ask the platform for whatever the
    // isolate could not produce before giving up on it.
    if (isAndroid) {
      await _recoverAndroidArtwork(enriched, artworkDirectory);
      // Recovered pictures arrive at full size too, so they take the same
      // downscaling path as tag and sidecar art.
      await _shrinkArtwork(enriched, artworkDirectory, replacements);
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
    //
    // Covers the database still references are kept even when this scan could
    // not reproduce a path for them: a scan that fails to read tags must not
    // delete art the library continues to point at.
    final keepArtwork = <String>{
      for (final song in songs)
        if (_clean(song.artworkPath) != null) song.artworkPath!,
      // Superseded originals are deliberately left out: they are the full-size
      // covers the downscaling pass replaced, and keeping them here would hold
      // a gigabyte of files nothing points at.
      for (final path in knownArtwork.values)
        if (path.isNotEmpty && !replacements.containsKey(path)) path,
    };
    final cache = ArtworkCache(artworkDirectory);
    await cache.pruneOrphans(keepArtwork);
    final evicted = <String>{...await cache.trim(keepPaths: keepArtwork)};

    // One line that answers "why is there no artwork?" precisely, and only
    // counts covers whose file is still on disk. Counting paths alone made this
    // line report numbers the library never showed: a path whose file had been
    // trimmed, cleared or deleted outside the app still counted as "covered".
    final sources = <String, String>{
      for (final item in enriched)
        if (item['artworkSource'] is String)
          (item['id'] as String? ?? ''): item['artworkSource'] as String,
    };
    final bySource = <String, int>{};
    for (final song in songs) {
      final path = _clean(song.artworkPath);
      if (path == null) {
        bySource.update('none', (count) => count + 1, ifAbsent: () => 1);
        continue;
      }
      if (!File(path).existsSync()) {
        // Forget the dead path instead of claiming a cover the app cannot paint.
        evicted.add(path);
        bySource.update('missing', (count) => count + 1, ifAbsent: () => 1);
        continue;
      }
      bySource.update(
        sources[song.id] ?? 'cached',
        (count) => count + 1,
        ifAbsent: () => 1,
      );
    }
    final covered =
        songs.length - (bySource['none'] ?? 0) - (bySource['missing'] ?? 0);
    final missing = bySource['missing'] ?? 0;
    DiagnosticsLog.instance.log(
      'artwork: $covered of ${songs.length} tracks have a cover '
      '(embedded ${bySource['embedded'] ?? 0}, sidecar ${bySource['sidecar'] ?? 0}, '
      'platform ${bySource['platform'] ?? 0}, reused ${bySource['reused'] ?? 0})'
      '${missing == 0 ? '' : ', $missing cached file(s) missing'}'
      '${replacements.isEmpty ? '' : ', ${replacements.length} downscaled'}',
      level: songs.isNotEmpty && covered == 0
          ? DiagnosticsLevel.warning
          : DiagnosticsLevel.info,
    );

    return LibraryScan(songs: songs, evictedArtwork: evicted);
  }

  /// Fills in covers that the in-isolate tag reader could not produce.
  ///
  /// `MediaMetadataRetriever` decodes the embedded picture straight from the
  /// content URI, so a track whose path is not a readable file still gets its
  /// artwork. Pictures arrive as files in a staging directory and go through
  /// [ArtworkCache] like every other cover, so hashing, de-duplication and the
  /// size ceiling stay in one place.
  Future<void> _recoverAndroidArtwork(
    List<Map<String, Object?>> enriched,
    Directory artworkDirectory,
  ) async {
    final missing = [
      for (final item in enriched)
        if (_clean(item['artworkPath']) == null) item,
    ];
    if (missing.isEmpty) return;

    final staging = Directory(
      p.join(artworkDirectory.parent.path, 'artwork-staging'),
    );
    var recovered = 0;
    try {
      if (!await staging.exists()) await staging.create(recursive: true);
      for (var start = 0; start < missing.length; start += _artworkBatchSize) {
        final end = min(start + _artworkBatchSize, missing.length);
        final batch = missing.sublist(start, end);
        final Map<String, String>? produced;
        try {
          produced = await _channel.invokeMapMethod<String, String>(
            'extractArtwork',
            {
              'dir': staging.path,
              'tracks': [
                for (final item in batch)
                  {'id': item['id'], 'uri': item['contentUri'] ?? item['path']},
              ],
            },
          );
        } on MissingPluginException {
          // A build without the method: nothing to recover, and the scan goes on.
          return;
        } on PlatformException catch (error) {
          // Silence here is why "no artwork at all" was undiagnosable: the
          // platform bridge failed and nothing in the trail said so.
          DiagnosticsLog.instance.log(
            'artwork: platform extraction failed: ${error.message}',
            level: DiagnosticsLevel.warning,
          );
          return;
        }
        if (produced == null || produced.isEmpty) continue;

        for (final item in batch) {
          final staged = produced[item['id']];
          if (staged == null) continue;
          final file = File(staged);
          try {
            final written = ArtworkCache.storeBytes(
              artworkDirectory.path,
              await file.readAsBytes(),
              maxBytes: _maxRawArtworkBytes,
            );
            if (written != null) {
              item['artworkPath'] = written;
              item['artworkSource'] = 'platform';
              recovered++;
            }
          } catch (_) {
            // Unreadable staged image; leave this track without a cover.
          } finally {
            try {
              if (await file.exists()) await file.delete();
            } catch (_) {
              // Staging is disposable.
            }
          }
        }
      }
    } catch (_) {
      // Recovery is best-effort: a missing cover must never fail the scan.
    } finally {
      try {
        if (await staging.exists()) await staging.delete(recursive: true);
      } catch (_) {
        // Best effort.
      }
    }

    // Zero successes for tracks that need a cover is the signal that the
    // platform bridge (not the files) is the problem. Silence here is why a
    // scan could report a thousand missing covers with no explanation.
    if (recovered == 0) {
      DiagnosticsLog.instance.log(
        'artwork: platform extraction produced nothing for '
        '${missing.length} track(s)',
        level: DiagnosticsLevel.warning,
      );
    }
  }

  /// Downscales cached covers to a phone-friendly size.
  ///
  /// Tag and sidecar art used to be stored byte-for-byte: 1064 covers came to
  /// 1.46 GB, and anything above [ArtworkCache.maxFileBytes] was refused before
  /// it was cached. Sending the bytes through the platform decoder fixes both —
  /// the result is a 1024 px JPEG that is a fraction of the size and well
  /// inside the cache ceiling.
  ///
  /// [replacements] maps a pre-shrink path to its cached replacement and is
  /// shared across the scan, so an artwork shared by an album is decoded once.
  Future<void> _shrinkArtwork(
    List<Map<String, Object?>> items,
    Directory artworkDirectory,
    Map<String, String> replacements,
  ) async {
    // A later batch can hold the pre-shrink path of art an earlier batch
    // already converted; remap those instead of decoding them again.
    for (final item in items) {
      final path = _clean(item['artworkPath']);
      if (path == null) continue;
      final replaced = replacements[path];
      if (replaced != null) item['artworkPath'] = replaced;
    }

    final candidates = <String>{};
    for (final item in items) {
      final path = _clean(item['artworkPath']);
      if (path == null) continue;
      if (replacements.containsValue(path)) continue;
      // Reused covers are only worth re-encoding while they are still large;
      // otherwise every scan would decode the entire cache again.
      if (item['artworkSource'] == 'reused') {
        try {
          if (await File(path).length() <= _reshrinkAboveBytes) continue;
        } catch (_) {
          continue;
        }
      }
      candidates.add(path);
    }
    if (candidates.isEmpty) return;

    final staging = Directory(
      p.join(artworkDirectory.parent.path, 'artwork-shrink'),
    );
    try {
      if (!await staging.exists()) await staging.create(recursive: true);
      final Map<String, String>? produced;
      try {
        produced = await _channel.invokeMapMethod<String, String>(
          'shrinkArtwork',
          {'dir': staging.path, 'files': candidates.toList()},
        );
      } on MissingPluginException {
        // A build without the method keeps the covers it already has.
        return;
      } on PlatformException catch (error) {
        DiagnosticsLog.instance.log(
          'artwork: downscaling failed: ${error.message}',
          level: DiagnosticsLevel.warning,
        );
        return;
      }
      if (produced == null || produced.isEmpty) return;

      for (final entry in produced.entries) {
        final file = File(entry.value);
        try {
          final written = ArtworkCache.storeBytes(
            artworkDirectory.path,
            await file.readAsBytes(),
          );
          if (written != null) replacements[entry.key] = written;
        } catch (_) {
          // Unreadable output; the original cover stays in place.
        } finally {
          try {
            if (await file.exists()) await file.delete();
          } catch (_) {
            // Staging is disposable.
          }
        }
      }

      for (final item in items) {
        final path = _clean(item['artworkPath']);
        final replacement = path == null ? null : replacements[path];
        if (replacement != null) item['artworkPath'] = replacement;
      }
    } finally {
      try {
        if (await staging.exists()) await staging.delete(recursive: true);
      } catch (_) {
        // Best effort.
      }
    }
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
  final maxRawBytes =
      (request['maxRawBytes'] as num?)?.toInt() ?? ArtworkCache.maxFileBytes;
  final output = <Map<String, Object?>>[];
  // Per-folder image listings and per-cover bytes: an album of 20 tracks must
  // read its `folder.jpg` once, not twenty times.
  final imagesCache = <String, Map<String, File>>{};
  final sidecarBytes = <String, Uint8List?>{};

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
    if (hasArtwork) {
      result['artworkPath'] = known;
      result['artworkSource'] = 'reused';
    }

    // Scoped storage may hand back a content:// URI with no file path. Keep the
    // MediaStore metadata so the track is still playable; just skip tag reads.
    final file = File(path);
    if (!file.existsSync()) {
      output.add(result);
      continue;
    }

    // Pictures the tag reader decoded, kept outside the try so a malformed tag
    // block does not also cost the track its sidecar cover.
    var pictures = const <Picture>[];
    try {
      final metadata = readMetadata(file, getImage: !hasArtwork);
      pictures = metadata.pictures;
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
    }

    if (!hasArtwork && artworkDirectory != null) {
      // Embedded art is not the only layout: many libraries keep one
      // `cover.jpg` / `folder.jpg` beside the tracks, or name a picture after
      // the track, in JPEG, PNG, WebP, GIF or BMP. Without this fallback such a
      // library showed no covers at all.
      var source = 'embedded';
      Uint8List? bytes = pictures.isEmpty
          ? null
          : _bestPicture(pictures)?.bytes;
      if (bytes == null || bytes.isEmpty) {
        source = 'sidecar';
        bytes = null;
        final images = imagesCache.putIfAbsent(
          file.parent.path,
          () => folderImages(file.parent),
        );
        final sidecar = pickSidecarArtwork(file, images);
        if (sidecar != null) {
          bytes = sidecarBytes.putIfAbsent(sidecar.path, () {
            try {
              return sidecar.readAsBytesSync();
            } catch (_) {
              // Unreadable image; treat as no cover.
              return null;
            }
          });
        }
      }

      if (bytes != null && bytes.isNotEmpty) {
        final written = ArtworkCache.storeBytes(
          artworkDirectory,
          bytes,
          maxBytes: maxRawBytes,
        );
        if (written != null) {
          result['artworkPath'] = written;
          result['artworkSource'] = source;
        }
      }
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
