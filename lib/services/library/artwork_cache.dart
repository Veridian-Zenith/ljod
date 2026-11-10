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
/// * the whole directory is held under [defaultBudgetBytes] by evicting least
///   recently used files, but only ones no longer referenced by the library —
///   deleting a referenced cover is how working artwork disappeared.
class ArtworkCache {
  ArtworkCache(this.directory, {this.budgetBytes = defaultBudgetBytes});

  /// Budget for artwork nothing references any more.
  ///
  /// Referenced covers are exempt: the scan extracts them from files that were
  /// already read once, and deleting one means the library shows no art for it
  /// until another full scan.
  static const int defaultBudgetBytes = 192 * 1024 * 1024;

  /// Largest single cover kept on disk.
  ///
  /// This used to be 2 MiB, which silently dropped a large share of real
  /// album art: a 3000×3000 JPEG is routinely 2–6 MiB, so an entire library
  /// could report "no cover" for tracks that have a perfect one embedded. The
  /// Android extractor downscales anything bigger than this before it reaches
  /// the cache.
  static const int maxFileBytes = 4 * 1024 * 1024;

  static const String extension = '.img';

  final Directory directory;

  /// Ceiling for this cache. Pluggable so a test can exercise eviction without
  /// writing hundreds of megabytes.
  final int budgetBytes;

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
  ///
  /// [maxBytes] exists for the Android pipeline, which accepts a cover at its
  /// original size and downscales it in a follow-up pass. The default applies
  /// to anything cached without that pass.
  static String? storeBytes(
    String directoryPath,
    Uint8List bytes, {
    int maxBytes = maxFileBytes,
  }) {
    if (bytes.isEmpty || bytes.length > maxBytes) return null;
    try {
      // The cache directory can be deleted underneath us ("Clear artwork
      // cache", "Clear library cache"), and a missing directory made every
      // write fail silently — the cover was dropped and nothing ever brought
      // it back. Create it on demand instead.
      final directory = Directory(directoryPath);
      if (!directory.existsSync()) directory.createSync(recursive: true);
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
    // An empty keep set means the scan could not name a single referenced
    // cover — an extraction failure, not an empty library. Deleting everything
    // in that case threw away covers the database still points at, and the
    // notification lost its art too. The budget trim still bounds the
    // directory.
    if (keepPaths.isEmpty) return 0;
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

  /// Evicts least recently used *unreferenced* files until the directory fits
  /// [budgetBytes].
  ///
  /// Files in [keepPaths] are never deleted. Evicting them used to make a
  /// working library look broken: a scan extracted hundreds of covers, this
  /// method trimmed the directory to its budget, and the database had to forget
  /// every path it deleted — so most tracks ended up without artwork, and the
  /// next scan evicted a different subset. With multi-megabyte album art the
  /// budget held only a few dozen covers.
  ///
  /// Returns the paths that were deleted, so the database can forget any row
  /// that still referenced them.
  Future<Set<String>> trim({Set<String> keepPaths = const {}}) async {
    if (!await directory.exists()) return const <String>{};

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
      return const <String>{};
    }

    var total = entries.fold<int>(0, (sum, entry) => sum + entry.length);
    if (total <= budgetBytes) return const <String>{};

    // Oldest unreferenced file first; anything the library references is kept.
    entries.sort((a, b) {
      if (a.keep != b.keep) return a.keep ? 1 : -1;
      return a.modified.compareTo(b.modified);
    });

    final removed = <String>{};
    for (final entry in entries) {
      if (total <= budgetBytes) break;
      // Sorted unreferenced-first, but never trade a live cover for the budget:
      // the file cannot be recreated without re-reading its audio file.
      if (entry.keep) continue;
      try {
        await entry.file.delete();
        total -= entry.length;
        removed.add(entry.file.path);
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
