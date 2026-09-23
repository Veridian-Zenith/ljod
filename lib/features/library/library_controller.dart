import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/models/song.dart';
import 'library_repository.dart';

/// StateNotifier managing library songs.
/// Supports best-friend synergy with Repository and Player controllers.
class LibraryController extends StateNotifier<AsyncValue<List<Song>>> {
  final LibraryRepository _repository;

  LibraryController(this._repository) : super(const AsyncValue.loading()) {
    loadSongs();
  }

  Future<void> loadSongs() async {
    state = const AsyncValue.loading();
    try {
      final songs = await _repository.getSongs();
      state = AsyncValue.data(songs);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  Future<void> toggleFavorite(String songId) async {
    final currentState = state.value;
    if (currentState == null) return;

    final updated = currentState.map((song) {
      if (song.id == songId) {
        final newFav = !song.isFavorite;
        _repository.toggleFavorite(songId, newFav);
        return song.copyWith(isFavorite: newFav);
      }
      return song;
    }).toList();

    state = AsyncValue.data(updated);
  }
}

final libraryControllerProvider =
    StateNotifierProvider<LibraryController, AsyncValue<List<Song>>>((ref) {
  final repo = ref.watch(libraryRepositoryProvider);
  return LibraryController(repo);
});
