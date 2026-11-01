/// Small, dependency-free formatting helpers shared across Ljod's UI.
library;

String formatDuration(Duration duration, {String empty = '--:--'}) {
  if (duration <= Duration.zero) return empty;
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  final seconds = duration.inSeconds.remainder(60);
  final mm = minutes.toString().padLeft(2, '0');
  final ss = seconds.toString().padLeft(2, '0');
  return hours > 0 ? '$hours:$mm:$ss' : '$mm:$ss';
}

String formatCount(int count) {
  if (count >= 1000000) {
    final value = count / 1000000;
    return '${value.toStringAsFixed(value >= 10 ? 0 : 1)}m';
  }
  if (count >= 1000) {
    final value = count / 1000;
    return '${value.toStringAsFixed(value >= 10 ? 0 : 1)}k';
  }
  return '$count';
}

/// Human-readable byte size for cache and storage rows.
String formatBytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  final kb = bytes / 1024;
  if (kb < 1024) return '${kb.toStringAsFixed(kb >= 100 ? 0 : 1)} KB';
  final mb = kb / 1024;
  if (mb < 1024) return '${mb.toStringAsFixed(mb >= 100 ? 0 : 1)} MB';
  return '${(mb / 1024).toStringAsFixed(2)} GB';
}

String formatRelativeDate(DateTime? date) {
  if (date == null) return '';
  final now = DateTime.now();
  final difference = now.difference(date);
  if (difference.inMinutes < 1) return 'just now';
  if (difference.inHours < 1) return '${difference.inMinutes}m ago';
  if (difference.inDays < 1) return '${difference.inHours}h ago';
  if (difference.inDays < 7) return '${difference.inDays}d ago';
  if (difference.inDays < 365) {
    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}';
  }
  return '${date.year}';
}

/// Best-effort `Artist - Title` parsing for filenames without tags.
({String artist, String title}) parseFileStem(String path) {
  final name = path.split(RegExp(r'[/\\]')).last;
  final dot = name.lastIndexOf('.');
  final stem = dot > 0 ? name.substring(0, dot) : name;
  final cleaned = stem.replaceAll(RegExp(r'[_]+'), ' ').trim();

  final separators = [' - ', ' – ', ' — '];
  for (final separator in separators) {
    final index = cleaned.indexOf(separator);
    if (index > 0 && index < cleaned.length - separator.length) {
      final artist = cleaned.substring(0, index).trim();
      final title = cleaned.substring(index + separator.length).trim();
      if (artist.isNotEmpty && title.isNotEmpty) {
        return (artist: artist, title: title);
      }
    }
  }
  return (artist: 'Unknown artist', title: cleaned);
}

String albumInitials(String value) {
  final words = value
      .trim()
      .split(RegExp(r'\s+'))
      .where((word) => word.isNotEmpty)
      .take(2);
  if (words.isEmpty) return 'LJ';
  return words.map((word) => word[0].toUpperCase()).join();
}
