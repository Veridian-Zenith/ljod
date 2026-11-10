import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:ljod/services/library/sidecar_artwork.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory root;

  setUp(() {
    root = Directory.systemTemp.createTempSync('ljod-sidecar-');
  });

  tearDown(() {
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  File file(Directory directory, String name) {
    return File(p.join(directory.path, name))..writeAsBytesSync(const [0]);
  }

  test('every supported raster cover format is found', () {
    for (final extension in const [
      'jpg',
      'jpeg',
      'jfif',
      'png',
      'webp',
      'gif',
      'bmp',
    ]) {
      final folder = Directory(p.join(root.path, extension))..createSync();
      final track = file(folder, 'song.mp3');
      final cover = file(folder, 'cover.$extension');

      final picked = pickSidecarArtwork(track, folderImages(folder));

      expect(
        picked?.path,
        cover.path,
        reason: '$extension covers must not be invisible to the scan',
      );
    }
  });

  test('matching ignores the case of the cover file name', () {
    final track = file(root, 'Track One.mp3');
    final cover = file(root, 'Folder.JPG');

    expect(pickSidecarArtwork(track, folderImages(root))?.path, cover.path);
  });

  test('a picture named after the track is used', () {
    final track = file(root, 'Track One.mp3');
    final cover = file(root, 'track one.png');

    expect(pickSidecarArtwork(track, folderImages(root))?.path, cover.path);
  });

  test('cover files win over the track-named picture', () {
    final track = file(root, 'Track One.mp3');
    file(root, 'Track One.png');
    final cover = file(root, 'cover.png');

    expect(pickSidecarArtwork(track, folderImages(root))?.path, cover.path);
  });

  test('unrelated images and unreadable folders yield no cover', () {
    final track = file(root, 'Track One.mp3');
    file(root, 'back.png');
    file(root, 'scan.txt');

    expect(pickSidecarArtwork(track, folderImages(root)), isNull);
    expect(
      pickSidecarArtwork(
        track,
        folderImages(Directory(p.join(root.path, 'no'))),
      ),
      isNull,
    );
  });

  test('folder listings skip subdirectories and non-images', () {
    final inner = Directory(p.join(root.path, 'inner'))..createSync();
    file(inner, 'cover.jpg');
    file(root, 'folder.jpg');
    file(root, 'notes.txt');

    expect(folderImages(root).keys, ['folder.jpg']);
  });
}
