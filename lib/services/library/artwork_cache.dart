import 'dart:io';
import 'dart:typed_data';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Bounded, de-duplicated on-disk cache for cover art extracted from tags.
///
/// Three rules keep this from turning into a multi-gigabyte directory:
///
/// * files are named by a hash of their *content*, so every track on an album
///   shares one cover instead of storing the same image thousands of times;
/// * a single cover larger than [maxFileBytes] is skipped rather than written
///   (huge scans are almost always uncompressed art nobody needs at full size);
/// * the whole directory is held under [budgetBytes] by evicting least
///   recently used files, preferring ones no longer referenced by the library.
class ArtworkCache {
  ArtworkCache(this.directory);

  /// Hard ceiling for cached artwork.
  static const int budgetBytes = 192 * 1024 * 1024;

  /// Largest single cover kept on disk.
  static const int maxFileBytes = 2 * 1024 * 1024;

  static const String extension = '.img';

  final Directory directory;

  /// Opens (and creates) the artwork cache under app support storage.
  static Future<ArtworkCache> open() async {
    final support = await getApplicationSupportDirectory();
    final directory = Directory(p.join(support.path, 'artwork'));
    if (!directory.existsSync()) {
      await directory.create(recursive: true);
    }
    return ArtworkCache(directory);
  }

  /// Writes [bytes] into [directoryPath], returning the file path.
  ///
  /// Static and synchronous so the scan isolate can call it without a channel
  /// round-trip. Returns `null` when the image is too large or cannot be
  /// written; artwork is decoration, so failures are silent.
  static String? storeBytes(String directoryPath, Uint8List bytes) {
    if (bytes.isEmpty || bytes.length > maxFileBytes) return null;
    try {
      final file = File(
        p.join(directoryPath, '${_contentKey(bytes)}$extension'),
      );
      if (!file.existsSync()) {
        file.writeAsBytesSync(bytes, flush: true);
      }
      return file.path;
    } catch (_) {
      return null;
    }
  }

  /// Stable key from the image bytes (FNV-1a 64-bit plus the byte length, so a
  /// hash collision would also have to collide in size).
  static String _contentKey(Uint8List bytes) {
    var hash = 0xcbf29ce484222325;
    for (final byte in bytes) {
      hash ^= byte;
      hash = (hash * 0x100000001b3) & 0xFFFFFFFFFFFFFFFF;
    }
    return '${bytes.length.toRadixString(16)}_'
        '${hash.toRadixString(16).padLeft(16, '0')}';
  }

  /// Total bytes currently on disk.
  Future<int> usageBytes() => _usage(directory);

  static Future<int> _usage(Directory directory) async {
    var total = 0;
    try {
      if (!await directory.exists()) return 0;
      await for (final entity in directory.list(followLinks: false)) {
        if (entity is! File) continue;
        try {
          total += await entity.length();
        } catch (_) {
          // File vanished mid-walk; ignore.
        }
      }
    } catch (_) {
      // Unreadable cache directory: report what we have.
    }
    return total;
  }

  /// Deletes files whose paths are not in [keepPaths] — covers for tracks that
  /// were removed, rescanned with different art, or cached by an older naming
  /// scheme.
  Future<int> pruneOrphans(Set<String> keepPaths) async {
    var removed = 0;
    try {
      if (!await directory.exists()) return 0;
      await for (final entity in directory.list(followLinks: false)) {
        if (entity is! File) continue;
        if (keepPaths.contains(entity.path)) continue;
        try {
          await entity.delete();
          removed++;
        } catch (_) {
          // Best effort.
        }
      }
    } catch (_) {
      // Best effort.
    }
    return removed;
  }

  /// Evicts least recently used files until the directory fits [budgetBytes].
  ///
  /// Files not in [keepPaths] go first; referenced covers are only evicted when
  /// the directory still exceeds the budget afterwards.
  Future<int> trim({Set<String> keepPaths = const {}}) async {
    if (!await directory.exists()) return 0;

    final entries = <({File file, int length, DateTime modified, bool keep})>[];
    try {
      await for (final entity in directory.list(followLinks: false)) {
        if (entity is! File) continue;
        try {
          final stat = await entity.stat();
          entries.add((
            file: entity,
            length: stat.size,
            modified: stat.modified,
            keep: keepPaths.contains(entity.path),
          ));
        } catch (_) {
          // Skip unreadable entries.
        }
      }
    } catch (_) {
      return 0;
    }

    var total = entries.fold<int>(0, (sum, entry) => sum + entry.length);
    if (total <= budgetBytes) return 0;

    // Unreferenced first (oldest of those), then referenced if still over.
    entries.sort((a, b) {
      if (a.keep != b.keep) return a.keep ? 1 : -1;
      return a.modified.compareTo(b.modified);
    });

    var removed = 0;
    for (final entry in entries) {
      if (total <= budgetBytes) break;
      try {
        await entry.file.delete();
        total -= entry.length;
        removed++;
      } catch (_) {
        // Best effort.
      }
    }
    return removed;
  }

  /// Removes every cached cover.
  Future<void> clear() async {
    try {
      if (await directory.exists()) {
        await directory.delete(recursive: true);
      }
    } catch (_) {
      // Best effort: the next scan re-extracts what it needs.
    }
  }
}
