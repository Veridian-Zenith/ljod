class Song {
  final String id;
  final String title;
  final String artist;
  final String album;
  final int durationMs;
  final String path;
  final bool isFavorite;
  final int playCount;

  const Song({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    required this.durationMs,
    required this.path,
    this.isFavorite = false,
    this.playCount = 0,
  });

  factory Song.fromJson(Map<String, dynamic> json) {
    return Song(
      id: json['id'] as String,
      title: json['title'] as String,
      artist: json['artist'] as String,
      album: json['album'] as String,
      durationMs: json['durationMs'] as int,
      path: json['path'] as String,
      isFavorite: json['isFavorite'] as bool? ?? false,
      playCount: json['playCount'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'artist': artist,
        'album': album,
        'durationMs': durationMs,
        'path': path,
        'isFavorite': isFavorite,
        'playCount': playCount,
      };

  Song copyWith({
    bool? isFavorite,
    int? playCount,
  }) {
    return Song(
      id: id,
      title: title,
      artist: artist,
      album: album,
      durationMs: durationMs,
      path: path,
      isFavorite: isFavorite ?? this.isFavorite,
      playCount: playCount ?? this.playCount,
    );
  }
}
