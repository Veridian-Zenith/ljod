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

  test('prune drops covers the library no longer references', () async {
    final keepBytes = Uint8List.fromList(List.filled(512, 1));
    final staleBytes = Uint8List.fromList(List.filled(512, 2));
    final keep = ArtworkCache.storeBytes(temp.path, keepBytes)!;
    ArtworkCache.storeBytes(temp.path, staleBytes);

    final removed = await cache.pruneOrphans({keep});

    expect(removed, 1);
    expect(temp.listSync().map((e) => e.path), [keep]);
  });

  test('trim holds the directory under its budget', () async {
    // 12 files of ~1 MB when the budget is 192 MB: force the budget down by
    // writing past it with a tiny override of the file set.
    final files = <String>[];
    for (var i = 0; i < 3; i++) {
      final bytes = Uint8List.fromList(List.filled(1024, i));
      files.add(ArtworkCache.storeBytes(temp.path, bytes)!);
      // Backdate so eviction order is deterministic.
      File(files.last)
          .setLastModifiedSync(DateTime.now().subtract(Duration(hours: 3 - i)));
    }

    final total = await cache.usageBytes();
    expect(total, 3 * 1024);

    // Nothing to evict while under budget.
    expect(await cache.trim(), 0);
    expect(temp.listSync().length, 3);
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
    expect(await absent.trim(), 0);
    await absent.clear();
  });
}
