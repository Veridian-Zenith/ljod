import 'package:flutter/painting.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../core/diagnostics/diagnostics_log.dart';
import '../../core/models/song_model.dart';
import '../settings/settings_provider.dart';
import 'library_service.dart';
import 'online_artwork.dart';

/// Coarse stage of a library scan, used by the global status bar.
enum ScanPhase { idle, permission, querying, reading, saving, done }

class LibraryState {
  const LibraryState({
    this.songs = const [],
    this.isScanning = false,
    this.permissionDenied = false,
    this.lastScan,
    this.error,
    this.scanPhase = ScanPhase.idle,
    this.scanProcessed = 0,
    this.scanTotal = 0,
  });

  final List<SongModel> songs;
  final bool isScanning;
  final bool permissionDenied;
  final DateTime? lastScan;
  final String? error;
  final ScanPhase scanPhase;
  final int scanProcessed;
  final int scanTotal;

  bool get isEmpty => songs.isEmpty;

  /// `null` while the total is unknown; otherwise a 0..1 fraction.
  double? get scanProgress {
    if (scanTotal <= 0) return null;
    return (scanProcessed / scanTotal).clamp(0.0, 1.0);
  }

  String get scanLabel => switch (scanPhase) {
    ScanPhase.permission => 'Waiting for music access',
    ScanPhase.querying => 'Finding audio files',
    ScanPhase.reading =>
      scanTotal <= 0
          ? 'Reading tags'
          : 'Reading tags · $scanProcessed/$scanTotal',
    ScanPhase.saving => 'Saving library',
    ScanPhase.done => 'Library up to date',
    ScanPhase.idle => isScanning ? 'Scanning library' : 'Idle',
  };

  List<SongModel> get favorites =>
      songs.where((song) => song.isFavorite).toList(growable: false);

  List<SongModel> get recentlyPlayed {
    final songs = [...this.songs.where((song) => song.lastPlayed != null)];
    songs.sort((a, b) => b.lastPlayed!.compareTo(a.lastPlayed!));
    return songs.take(12).toList(growable: false);
  }

  LibraryState copyWith({
    List<SongModel>? songs,
    bool? isScanning,
    bool? permissionDenied,
    DateTime? lastScan,
    String? error,
    bool clearError = false,
    ScanPhase? scanPhase,
    int? scanProcessed,
    int? scanTotal,
  }) {
    return LibraryState(
      songs: songs ?? this.songs,
      isScanning: isScanning ?? this.isScanning,
      permissionDenied: permissionDenied ?? this.permissionDenied,
      lastScan: lastScan ?? this.lastScan,
      error: clearError ? null : (error ?? this.error),
      scanPhase: scanPhase ?? this.scanPhase,
      scanProcessed: scanProcessed ?? this.scanProcessed,
      scanTotal: scanTotal ?? this.scanTotal,
    );
  }
}

final libraryServiceProvider = Provider<LibraryService>((ref) {
  return const LibraryService();
});

final libraryProvider = AsyncNotifierProvider<LibraryNotifier, LibraryState>(
  LibraryNotifier.new,
);

/// Folder counts published by the last scan.
///
/// The scan already walks every file, so its folder tally is reused rather than
/// asking the platform a second time. [ScannedFolders.clear] drops it when a
/// fresh query is genuinely wanted.
final scannedFoldersProvider =
    NotifierProvider<ScannedFolders, List<AudioFolder>?>(ScannedFolders.new);

class ScannedFolders extends Notifier<List<AudioFolder>?> {
  @override
  List<AudioFolder>? build() => null;

  void publish(List<AudioFolder> folders) => state = folders;

  void clear() => state = null;
}

/// Folders that currently contain audio.
///
/// Instant after a scan. The platform is queried only before the first scan of
/// a session, or after the folder-rules screen asks for a reload.
final libraryFoldersProvider = FutureProvider<List<AudioFolder>>((ref) {
  // Rebuild when a scan completes, but not on every progress tick.
  ref.watch(libraryProvider.select((value) => value.value?.lastScan));
  final scanned = ref.watch(scannedFoldersProvider);
  if (scanned != null) return scanned;
  return ref.read(libraryServiceProvider).listFolders();
});

class LibraryNotifier extends AsyncNotifier<LibraryState> {
  AppDatabase get _db => AppDatabase.instance;
  LibraryService get _service => ref.read(libraryServiceProvider);

  /// Latest state published while [build] was still reading the database.
  ///
  /// Setup starts its scan as soon as this notifier exists, so the scan can
  /// finish before the initial `allSongs()` read returns. Returning that read
  /// then overwrote the finished scan with the pre-scan (empty) rows — the
  /// library looked empty and the person had to scan a second time for no
  /// reason. The newer state wins here.
  LibraryState? _published;

  @override
  Future<LibraryState> build() async {
    // Startup must never block on permission prompts or background scanning.
    // The setup flow (or an explicit Rescan) owns the first scan.
    try {
      final songs = await _db.allSongs();
      return _published ?? LibraryState(songs: songs);
    } catch (error) {
      // Without this, an unopenable database looked exactly like an empty
      // library: the failure surfaced as a bare platform error far from
      // anything that named the database.
      DiagnosticsLog.instance.log(
        'library: could not read the database, so no tracks can be shown: '
        '$error',
      );
      rethrow;
    }
  }

  LibraryState get _current => state.value ?? const LibraryState();

  void _publish(LibraryState next) {
    _published = next;
    if (!ref.mounted) return;
    state = AsyncData(next);
  }

  Future<void> rescan({bool requestPermission = true}) async {
    if (_current.isScanning) return;
    _publish(
      _current.copyWith(
        isScanning: true,
        permissionDenied: false,
        clearError: true,
        scanPhase: ScanPhase.permission,
        scanProcessed: 0,
        scanTotal: 0,
      ),
    );

    try {
      if (_service.isAndroid) {
        final granted = requestPermission
            ? await _service.requestPermission()
            : await _service.hasPermission();
        if (!granted) {
          DiagnosticsLog.instance.log(
            'scan: not started, music access was not granted',
            level: DiagnosticsLevel.warning,
          );
          _publish(
            _current.copyWith(
              isScanning: false,
              permissionDenied: true,
              scanPhase: ScanPhase.idle,
            ),
          );
          return;
        }
      }

      _publish(_current.copyWith(scanPhase: ScanPhase.querying));
      final scope = ref.read(settingsProvider).folderScope;
      // No pre-scan path clearing: `upsertSongs` writes `artworkPath` (always
      // null now) for every row it touches, so a table-wide UPDATE first would
      // only walk the same rows twice.
      final scanned = await _service.scan(
        scope: scope,
        onProgress: (processed, total) {
          if (!ref.mounted) return;
          _publish(
            _current.copyWith(
              scanPhase: ScanPhase.reading,
              scanProcessed: processed,
              scanTotal: total,
            ),
          );
        },
      );

      _publish(_current.copyWith(scanPhase: ScanPhase.saving));
      await _db.upsertSongs(scanned.songs);
      // An empty result only means "the device has no music" when the library
      // was already empty. With tracks indexed it means the platform query came
      // back empty — permission revoked mid-scan, storage not mounted, or a
      // failed bridge call — and pruning then deleted every row, so the library
      // looked empty and had to be scanned again. Keep the rows in that case.
      if (scanned.songs.isEmpty && _current.songs.isNotEmpty) {
        DiagnosticsLog.instance.log(
          'scan: the device returned no tracks; keeping the existing library',
          level: DiagnosticsLevel.warning,
        );
      } else {
        await _db.removeMissing(scanned.songs.map((song) => song.id).toSet());
      }
      final songs = await _db.allSongs();
      if (!ref.mounted) return;
      // The scan's own folder tally is what folder rules show from now on.
      ref.read(scannedFoldersProvider.notifier).publish(scanned.folders);
      _publish(
        LibraryState(
          songs: songs,
          isScanning: false,
          lastScan: DateTime.now(),
          scanPhase: ScanPhase.done,
          scanProcessed: scanned.songs.length,
          scanTotal: scanned.songs.length,
        ),
      );
    } on LibraryPermissionException {
      _publish(
        _current.copyWith(
          isScanning: false,
          permissionDenied: true,
          scanPhase: ScanPhase.idle,
        ),
      );
    } on LibraryScanException catch (error) {
      DiagnosticsLog.instance.log('scan failed: ${error.message}');
      _publish(
        _current.copyWith(
          isScanning: false,
          error: error.message,
          scanPhase: ScanPhase.idle,
        ),
      );
    } catch (error) {
      DiagnosticsLog.instance.log('scan failed: $error');
      _publish(
        _current.copyWith(
          isScanning: false,
          error: 'Library scan failed: $error',
          scanPhase: ScanPhase.idle,
        ),
      );
    }
  }

  Future<void> toggleFavorite(SongModel song) async {
    final next = !song.isFavorite;
    await _db.setFavorite(song.id, next);
    if (!ref.mounted) return;
    state = AsyncData(
      _current.copyWith(
        songs: _current.songs
            .map(
              (item) =>
                  item.id == song.id ? item.copyWith(isFavorite: next) : item,
            )
            .toList(growable: false),
      ),
    );
  }

  Future<void> markPlayed(SongModel song) async {
    await _db.markPlayed(song.id);
    if (!ref.mounted) return;
    final now = DateTime.now();
    state = AsyncData(
      _current.copyWith(
        songs: _current.songs
            .map(
              (item) => item.id == song.id
                  ? item.copyWith(
                      playCount: item.playCount + 1,
                      lastPlayed: now,
                    )
                  : item,
            )
            .toList(growable: false),
      ),
    );
  }

  Future<void> clearCache() async {
    DiagnosticsLog.instance.log(
      'library: clearing the indexed cache and derived files',
      level: DiagnosticsLevel.info,
    );
    await _db.clear();
    await _service.clearCaches();
    if (!ref.mounted) return;
    ref.read(scannedFoldersProvider.notifier).clear();
    state = const AsyncData(LibraryState());
  }

  /// Forgets every remembered cover link and deletes the cover files older
  /// builds left behind, which also returns their space to the device.
  ///
  /// Nothing is lost: artwork is looked up again the next time it is painted.
  Future<void> clearArtworkLookups() async {
    await _service.clearArtworkCache();
    await _db.clearArtworkPaths();
    await ref.read(onlineArtworkServiceProvider).clear();
    // Visible tiles still hold the old URL in a cached provider and the old
    // bitmap in the image cache; without both, the button would look like it
    // did nothing until the app restarted.
    ref.invalidate(artworkUrlProvider);
    try {
      PaintingBinding.instance.imageCache.clear();
    } catch (_) {
      // Nothing to drop when no frame has been painted.
    }
    if (!ref.mounted) return;
    state = AsyncData(
      _current.copyWith(
        songs: _current.songs
            .map((song) => song.copyWith(clearArtwork: true))
            .toList(growable: false),
      ),
    );
  }
}

/// The full library once loaded. Empty while the first scan is running.
final songsProvider = Provider<List<SongModel>>((ref) {
  return ref.watch(libraryProvider).value?.songs ?? const [];
});

final songByIdProvider = Provider.family<SongModel?, String>((ref, id) {
  for (final song in ref.watch(songsProvider)) {
    if (song.id == id) return song;
  }
  return null;
});
