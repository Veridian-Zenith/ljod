import 'dart:io';

import 'package:path/path.dart' as p;

/// Cover file names music libraries keep beside the audio, in preference order.
const List<String> _coverStems = [
  'cover',
  'folder',
  'front',
  'album',
  'albumart',
  'albumartsmall',
  'artwork',
  'thumb',
];

/// Every raster format Flutter decodes, not just JPEG: libraries ship PNG,
/// WebP, GIF and BMP covers too.
const List<String> _coverExtensions = [
  '.jpg',
  '.jpeg',
  '.jfif',
  '.png',
  '.webp',
  '.gif',
  '.bmp',
];

/// Lists the image files in one folder, keyed by lower-case file name.
///
/// Reading a folder once and resolving many tracks against it keeps a scan of
/// an album folder linear instead of one directory walk per track. Matching is
/// case-insensitive because `Folder.JPG` and `folder.jpg` are equally common.
Map<String, File> folderImages(Directory directory) {
  final images = <String, File>{};
  try {
    if (!directory.existsSync()) return images;
    for (final entity in directory.listSync(followLinks: false)) {
      if (entity is! File) continue;
      final name = p.basename(entity.path).toLowerCase();
      if (!_coverExtensions.any(name.endsWith)) continue;
      images[name] = entity;
    }
  } catch (_) {
    // Unreadable folder: no sidecar art.
  }
  return images;
}

/// The cover stored next to [track], if any.
///
/// Tried after an embedded picture: plenty of libraries ship `cover.jpg` or
/// `folder.jpg` instead of tagging every file, and `<track>.jpg` is the other
/// common shape. Without this, such a library showed no artwork at all.
File? pickSidecarArtwork(File track, Map<String, File> folderImages) {
  if (folderImages.isEmpty) return null;
  final stem = p.basenameWithoutExtension(track.path).toLowerCase();
  for (final name in [..._coverStems, stem]) {
    for (final extension in _coverExtensions) {
      final match = folderImages['$name$extension'];
      if (match != null) return match;
    }
  }
  return null;
}
