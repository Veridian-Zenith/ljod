import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/database/app_database.dart';
import '../../core/models/song_model.dart';
import '../settings/settings_provider.dart';
import 'library_service.dart';

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
          ? 'Reading tags and artwork'
          : 'Reading tags and artwork · $scanProcessed/$scanTotal',
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

/// Folders that currently contain audio. Invalidated after every completed
/// scan, and on demand by the folder-rules screen.
final libraryFoldersProvider = FutureProvider<List<AudioFolder>>((ref) {
  // Re-read when a scan completes, but not on every progress tick.
  ref.watch(libraryProvider.select((value) => value.value?.lastScan));
  return ref.read(libraryServiceProvider).listFolders();
});

class LibraryNotifier extends AsyncNotifier<LibraryState> {
  AppDatabase get _db => AppDatabase.instance;
  LibraryService get _service => ref.read(libraryServiceProvider);

  @override
  Future<LibraryState> build() async {
    // Startup must never block on permission prompts or background scanning.
    // The setup flow (or an explicit Rescan) owns the first scan.
    return LibraryState(songs: await _db.allSongs());
  }

  LibraryState get _current => state.value ?? const LibraryState();

  void _publish(LibraryState next) {
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
      final knownArtwork = await _db.artworkPaths();
      final scanned = await _service.scan(
        scope: scope,
        knownArtwork: knownArtwork,
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
      await _db.upsertSongs(scanned);
      if (scanned.isNotEmpty) {
        await _db.removeMissing(scanned.map((song) => song.id).toSet());
      }
      final songs = await _db.allSongs();
      _publish(
        LibraryState(
          songs: songs,
          isScanning: false,
          lastScan: DateTime.now(),
          scanPhase: ScanPhase.done,
          scanProcessed: scanned.length,
          scanTotal: scanned.length,
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
      _publish(
        _current.copyWith(
          isScanning: false,
          error: error.message,
          scanPhase: ScanPhase.idle,
        ),
      );
    } catch (error) {
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
    await _db.clear();
    await _service.clearCaches();
    if (!ref.mounted) return;
    state = const AsyncData(LibraryState());
  }

  /// Deletes cached cover art only; the indexed library stays usable (covers
  /// fall back to initials until the next scan extracts them again).
  Future<void> clearArtworkCache() async {
    await _service.clearArtworkCache();
    await _db.clearArtworkPaths();
    if (!ref.mounted) return;
    state = AsyncData(
      _current.copyWith(
        songs: _current.songs
            .map((song) => song.copyWith(artworkPath: ''))
            .toList(growable: false),
      ),
    );
  }
}

/// Bytes used by cached cover art, for the storage row in Settings.
///
/// Recomputed after every scan so the figure matches what the cache actually
/// holds, and left alone during a scan to avoid walking the directory on every
/// progress tick.
final artworkCacheBytesProvider = FutureProvider<int>((ref) async {
  ref.watch(libraryProvider.select((value) => value.value?.lastScan));
  return ref.read(libraryServiceProvider).artworkCacheBytes();
});

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
