import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/models/folder_scope.dart';

/// Injected in `main()` after `SharedPreferences.getInstance()` resolves.
final sharedPreferencesProvider = Provider<SharedPreferences>((ref) {
  throw UnimplementedError(
    'sharedPreferencesProvider must be overridden at app startup.',
  );
});

class AppSettings {
  const AppSettings({
    this.expressiveMotion = true,
    this.lyricsLookup = false,
    this.sortFavoritesFirst = false,
    this.folderFilterMode = FolderFilterMode.all,
    this.folderFilters = const [],
  });

  final bool expressiveMotion;
  final bool lyricsLookup;
  final bool sortFavoritesFirst;
  final FolderFilterMode folderFilterMode;
  final List<String> folderFilters;

  FolderScope get folderScope =>
      FolderScope(mode: folderFilterMode, folders: folderFilters);

  String get folderSummary => switch (folderFilterMode) {
    FolderFilterMode.all => 'Scanning every folder',
    FolderFilterMode.only =>
      folderFilters.isEmpty
          ? 'No folders selected yet'
          : 'Only ${_folderCount(folderFilters.length)}',
    FolderFilterMode.exclude =>
      folderFilters.isEmpty
          ? 'Nothing excluded'
          : 'Excluding ${_folderCount(folderFilters.length)}',
  };

  AppSettings copyWith({
    bool? expressiveMotion,
    bool? lyricsLookup,
    bool? sortFavoritesFirst,
    FolderFilterMode? folderFilterMode,
    List<String>? folderFilters,
  }) {
    return AppSettings(
      expressiveMotion: expressiveMotion ?? this.expressiveMotion,
      lyricsLookup: lyricsLookup ?? this.lyricsLookup,
      sortFavoritesFirst: sortFavoritesFirst ?? this.sortFavoritesFirst,
      folderFilterMode: folderFilterMode ?? this.folderFilterMode,
      folderFilters: folderFilters ?? this.folderFilters,
    );
  }
}

String _folderCount(int count) => count == 1 ? '1 folder' : '$count folders';

final settingsProvider = NotifierProvider<SettingsNotifier, AppSettings>(
  SettingsNotifier.new,
);

class SettingsNotifier extends Notifier<AppSettings> {
  static const _motion = 'settings.expressiveMotion';
  static const _lyrics = 'settings.lyricsLookup';
  static const _favoriteFirst = 'settings.sortFavoritesFirst';
  static const _folderMode = 'settings.folderMode';
  static const _folderFilters = 'settings.folderFilters';

  SharedPreferences get _prefs => ref.read(sharedPreferencesProvider);

  @override
  AppSettings build() {
    final prefs = ref.watch(sharedPreferencesProvider);
    final storedMode = prefs.getString(_folderMode);
    final mode = FolderFilterMode.values.firstWhere(
      (value) => value.name == storedMode,
      orElse: () => FolderFilterMode.all,
    );

    return AppSettings(
      expressiveMotion: prefs.getBool(_motion) ?? true,
      // Off by default: a local-first player should not reach the network
      // until the listener opts in.
      lyricsLookup: prefs.getBool(_lyrics) ?? false,
      sortFavoritesFirst: prefs.getBool(_favoriteFirst) ?? false,
      folderFilterMode: mode,
      folderFilters: prefs.getStringList(_folderFilters) ?? const [],
    );
  }

  Future<void> setExpressiveMotion(bool value) async {
    state = state.copyWith(expressiveMotion: value);
    await _prefs.setBool(_motion, value);
  }

  Future<void> setLyricsLookup(bool value) async {
    state = state.copyWith(lyricsLookup: value);
    await _prefs.setBool(_lyrics, value);
  }

  Future<void> setSortFavoritesFirst(bool value) async {
    state = state.copyWith(sortFavoritesFirst: value);
    await _prefs.setBool(_favoriteFirst, value);
  }

  Future<void> setFolderScope(
    FolderFilterMode mode,
    List<String> folders,
  ) async {
    final unique = folders.toSet().toList()..sort();
    state = state.copyWith(folderFilterMode: mode, folderFilters: unique);
    await _prefs.setString(_folderMode, mode.name);
    await _prefs.setStringList(_folderFilters, unique);
  }
}
