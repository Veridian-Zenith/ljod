import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:ljod/core/diagnostics/diagnostics_log.dart';
import 'package:ljod/core/utils/formatters.dart';
import 'package:ljod/services/library/artwork_cache.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory temp;
  late ArtworkCache cache;

  setUp(() {
    temp = Directory.systemTemp.createTempSync('ljod-artwork-');
    cache = ArtworkCache(temp);
  });

  tearDown(() {
    if (temp.existsSync()) temp.deleteSync(recursive: true);
  });

  test('identical covers are stored once', () {
    final bytes = Uint8List.fromList(List.filled(2048, 7));
    final first = ArtworkCache.storeBytes(temp.path, bytes);
    final second = ArtworkCache.storeBytes(temp.path, bytes);

    expect(first, isNotNull);
    expect(second, first);
    expect(
      temp.listSync().whereType<File>().length,
      1,
      reason: 'an album of 20 tracks must not store 20 copies of one cover',
    );
  });

  test('oversized covers are skipped instead of written', () {
    final huge = Uint8List(ArtworkCache.maxFileBytes + 1);
    expect(ArtworkCache.storeBytes(temp.path, huge), isNull);
    expect(temp.listSync(), isEmpty);
  });

  test('a raised raw limit accepts art that is downscaled afterwards', () {
    // Android caches the original and shrinks it in a follow-up pass; the
    // default ceiling refused such a cover before the shrink could run, which
    // is how a tagged track ended up with no artwork at all.
    final bytes = Uint8List(ArtworkCache.maxFileBytes + 1024);
    expect(ArtworkCache.storeBytes(temp.path, bytes), isNull);

    final stored = ArtworkCache.storeBytes(
      temp.path,
      bytes,
      maxBytes: ArtworkCache.maxFileBytes * 2,
    );

    expect(stored, isNotNull);
    expect(File(stored!).lengthSync(), bytes.length);
  });

  test('prune drops covers the library no longer references', () async {
    final keepBytes = Uint8List.fromList(List.filled(512, 1));
    final staleBytes = Uint8List.fromList(List.filled(512, 2));
    final keep = ArtworkCache.storeBytes(temp.path, keepBytes)!;
    ArtworkCache.storeBytes(temp.path, staleBytes);

    final removed = await cache.pruneOrphans({keep});

    expect(removed, 1);
    expect(temp.listSync().map((e) => e.path), [keep]);
  });

  test('prune does nothing when a scan names no referenced cover', () async {
    final path = ArtworkCache.storeBytes(
      temp.path,
      Uint8List.fromList(List.filled(256, 3)),
    )!;

    // An extraction failure hands back an empty set. Deleting on that signal
    // wiped a working cache once, and the notification lost its art with it.
    expect(await cache.pruneOrphans(const {}), 0);
    expect(File(path).existsSync(), isTrue);
  });

  test('storeBytes recreates a deleted cache directory', () {
    final directory = Directory(p.join(temp.path, 'artwork'));
    // "Clear artwork cache" deletes the directory, not just its files.
    expect(directory.existsSync(), isFalse);

    final path = ArtworkCache.storeBytes(
      directory.path,
      Uint8List.fromList(List.filled(128, 5)),
    );

    expect(path, isNotNull);
    expect(File(path!).existsSync(), isTrue);
  });

  test('trim leaves the directory alone while it is under budget', () async {
    final files = <String>[];
    for (var i = 0; i < 3; i++) {
      final bytes = Uint8List.fromList(List.filled(1024, i + 1));
      files.add(ArtworkCache.storeBytes(temp.path, bytes)!);
      // Backdate so eviction order is deterministic.
      File(files.last)
          .setLastModifiedSync(DateTime.now().subtract(Duration(hours: 3 - i)));
    }

    expect(await cache.usageBytes(), 3 * 1024);

    // Nothing to evict while under budget.
    expect(await cache.trim(), isEmpty);
    expect(temp.listSync().length, 3);
  });

  test('trim evicts the oldest covers and reports what it deleted', () async {
    // The budget is configurable so eviction is reachable without writing the
    // real 192 MiB ceiling into a test.
    final limited = ArtworkCache(temp, budgetBytes: 2048);
    final written = <String>[];
    for (var i = 0; i < 3; i++) {
      final bytes = Uint8List.fromList(List.filled(1024, i + 1));
      written.add(ArtworkCache.storeBytes(temp.path, bytes)!);
      File(written.last)
          .setLastModifiedSync(DateTime.now().subtract(Duration(hours: 3 - i)));
    }

    final removed = await limited.trim();

    // 3 KiB over a 2 KiB budget: exactly the oldest file goes.
    expect(removed, {written.first});
    expect(await limited.usageBytes(), lessThanOrEqualTo(2048));
    expect(File(written.first).existsSync(), isFalse);
  });

  test('trim never deletes a cover the library still references', () async {
    // A large library of multi-megabyte covers used to be trimmed back to the
    // budget right after extraction, and every deleted path was cleared in the
    // database — so most tracks showed no art no matter how good the scan was.
    final limited = ArtworkCache(temp, budgetBytes: 1024);
    final written = <String>[];
    for (var i = 0; i < 3; i++) {
      written.add(
        ArtworkCache.storeBytes(
          temp.path,
          Uint8List.fromList(List.filled(1024, 20 + i)),
        )!,
      );
    }

    final removed = await limited.trim(keepPaths: written.toSet());

    expect(removed, isEmpty, reason: 'live covers outrank the byte budget');
    for (final path in written) {
      expect(File(path).existsSync(), isTrue);
    }
  });

  test('trim drops unreferenced covers before referenced ones', () async {
    final limited = ArtworkCache(temp, budgetBytes: 1536);
    final keep = ArtworkCache.storeBytes(
      temp.path,
      Uint8List.fromList(List.filled(1024, 11)),
    )!;
    final stale = ArtworkCache.storeBytes(
      temp.path,
      Uint8List.fromList(List.filled(1024, 12)),
    )!;
    File(keep)
        .setLastModifiedSync(DateTime.now().subtract(const Duration(hours: 2)));
    File(stale)
        .setLastModifiedSync(DateTime.now().subtract(const Duration(hours: 1)));

    final removed = await limited.trim(keepPaths: {keep});

    expect(removed, {stale});
    expect(File(keep).existsSync(), isTrue);
  });

  test('clear empties the cache', () async {
    ArtworkCache.storeBytes(temp.path, Uint8List.fromList(List.filled(256, 9)));
    await cache.clear();
    expect(await cache.usageBytes(), 0);
  });

  test('byte sizes read naturally', () {
    expect(formatBytes(512), '512 B');
    expect(formatBytes(2048), '2.0 KB');
    expect(formatBytes(5 * 1024 * 1024), '5.0 MB');
    expect(formatBytes(3 * 1024 * 1024 * 1024), '3.00 GB');
  });

  test('diagnostics log stays bounded', () async {
    final log = DiagnosticsLog.instance;
    await log.clear();
    for (var i = 0; i < 4000; i++) {
      await log.record('entry $i ${'x' * 60}');
    }
    final size = log.entries.fold<int>(0, (sum, line) => sum + line.length);
    expect(size, lessThanOrEqualTo(DiagnosticsLog.maxBytes));
    expect(log.entries, isNotEmpty);
    await log.clear();
  });

  test('missing directories do not throw', () async {
    final missing = Directory(p.join(temp.path, 'nope'));
    final absent = ArtworkCache(missing);
    expect(await absent.usageBytes(), 0);
    expect(await absent.pruneOrphans({}), 0);
    expect(await absent.trim(), isEmpty);
    await absent.clear();
  });
}
