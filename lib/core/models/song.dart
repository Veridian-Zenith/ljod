import 'package:json_annotation/json_annotation.dart';

part 'song.g.dart';

@JsonSerializable()
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

  factory Song.fromJson(Map<String, dynamic> json) => _$SongFromJson(json);
  Map<String, dynamic> toJson() => _$SongToJson(this);

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
