/// Text handling shared by the online artwork lookup.
///
/// Kept free of Flutter and database imports so the matching rules can be
/// reasoned about (and tested) without a device, a network or a widget tree.
library;

/// Collapses a title, artist or album to the form used for comparisons and for
/// the cache key.
///
/// Case, punctuation and repeated spaces differ constantly between tags and
/// catalogue entries (`Хулиганка (Phonk Remix)` vs `Хулиганка - Phonk Remix`),
/// so everything except letters and digits is folded to a single space. Scripts
/// above Latin-1 are preserved, which keeps Cyrillic and CJK titles intact.
String normalizeArtworkText(String value) {
  final folded = value
      .toLowerCase()
      // Typographic punctuation lives above Latin-1, so the class below would
      // keep it and two spellings of one album would get different keys.
      .replaceAll(RegExp(r'[«»„“”‘’…—–−•·™©®]+'), ' ')
      .replaceAll(RegExp(r'[^0-9a-z\u00c0-\uffff]+'), ' ')
      .trim();
  return folded.replaceAll(RegExp(r'\s+'), ' ');
}

/// Stable key for one album's artwork.
///
/// Albums without a tag fall back to the track title, because a compilation
/// with no album metadata still deserves its own cover rather than sharing one
/// with the whole library.
String artworkMemoKey({
  required String artist,
  required String album,
  required String title,
}) {
  final identity = album.trim().isEmpty ? title : album;
  final artistPart = normalizeArtworkText(artist);
  final identityPart = normalizeArtworkText(identity);
  if (artistPart.isEmpty && identityPart.isEmpty) return '';
  return '$artistPart|$identityPart';
}

/// Largest cover Deezer's album search result offers.
String? pickDeezerCover(Map<String, Object?> payload, {required String album}) {
  final data = payload['data'];
  if (data is! List || data.isEmpty) return null;

  final wanted = normalizeArtworkText(album);
  String? first;
  String? partial;

  for (final entry in data) {
    if (entry is! Map) continue;
    // `/search/album` returns the album itself; `/search` nests it under
    // `album`, so both shapes are read here.
    final albumMap = entry['album'] is Map ? entry['album'] as Map : entry;
    final cover = albumMap['cover_xl'] ?? albumMap['cover_big'];
    if (cover is! String || cover.isEmpty) continue;
    first ??= cover;
    if (wanted.isEmpty) return cover;

    final name = normalizeArtworkText('${albumMap['title'] ?? ''}');
    if (name.isEmpty) continue;
    if (name == wanted) return cover;
    if (name.contains(wanted) || wanted.contains(name)) partial ??= cover;
  }

  // The query already scoped the search to this artist and album, so a
  // near-match beats showing nothing.
  return partial ?? first;
}

/// Largest cover from an iTunes Search API album result.
String? pickItunesCover(Map<String, Object?> payload, {required String album}) {
  final results = payload['results'];
  if (results is! List || results.isEmpty) return null;

  final wanted = normalizeArtworkText(album);
  String? first;
  String? partial;

  for (final entry in results) {
    if (entry is! Map) continue;
    final raw = entry['artworkUrl100'] ?? entry['artworkUrl60'];
    if (raw is! String || raw.isEmpty) continue;
    final url = itunesArtworkUrl(raw);
    if (url == null) continue;
    first ??= url;
    if (wanted.isEmpty) return url;

    final name = normalizeArtworkText('${entry['collectionName'] ?? ''}');
    if (name.isEmpty) continue;
    if (name == wanted) return url;
    if (name.contains(wanted) || wanted.contains(name)) partial ??= url;
  }

  return partial ?? first;
}

/// Asks Apple for a larger rendition than the 100 px thumbnail it returns.
///
/// The size is encoded in the path (`.../100x100bb.jpg`), so the same image is
/// served at 600 px by editing it. Unrecognised URLs are returned unchanged
/// rather than guessed at.
String? itunesArtworkUrl(String raw, {int size = 600}) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return null;
  if (!trimmed.startsWith('http')) return null;
  return trimmed.replaceFirstMapped(
    RegExp(r'\d+x\d+[a-z]*\.(jpe?g|png)$', caseSensitive: false),
    (match) => '${size}x${size}bb.${match[1]!.toLowerCase()}',
  );
}
