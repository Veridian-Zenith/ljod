import 'package:path/path.dart' as p;

/// How folder rules are interpreted when building the library.
enum FolderFilterMode {
  /// Index audio from every folder reported by the platform.
  all,

  /// Index audio only from the folders listed in [FolderScope.folders].
  only,

  /// Index audio from every folder except those listed in
  /// [FolderScope.folders].
  exclude,
}

/// A persisted set of folder rules applied during a library scan.
///
/// Folders are matched recursively: selecting `/Music/Rock` also includes
/// `/Music/Rock/Live`. Paths reported as `content://` URIs do not expose
/// their folder, so those files are always kept.
class FolderScope {
  const FolderScope({
    this.mode = FolderFilterMode.all,
    this.folders = const [],
  });

  final FolderFilterMode mode;
  final List<String> folders;

  bool get isFiltered => mode != FolderFilterMode.all;

  bool allowsPath(String path) {
    if (!isFiltered || folders.isEmpty) {
      return mode != FolderFilterMode.only;
    }

    final folder = folderOf(path);
    if (folder == null) return true;

    final matches = folders.any((rule) {
      final normalized = normalizeFolder(rule);
      return normalized.isNotEmpty &&
          (folder == normalized || folder.startsWith('$normalized/'));
    });

    return mode == FolderFilterMode.only ? matches : !matches;
  }

  /// The containing folder for a real filesystem path, or `null` when the path
  /// is a content URI / has no parent.
  static String? folderOf(String path) {
    if (path.isEmpty || path.contains('://')) return null;
    final folder = p.dirname(path);
    if (folder.isEmpty || folder == '.' || folder == p.separator) {
      return null;
    }
    return normalizeFolder(folder);
  }

  static String normalizeFolder(String folder) {
    var normalized = folder.replaceAll('\\', '/');
    while (normalized.length > 1 && normalized.endsWith('/')) {
      normalized = normalized.substring(0, normalized.length - 1);
    }
    return normalized;
  }
}
