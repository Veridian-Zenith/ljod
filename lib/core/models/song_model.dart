import 'dart:io';

import 'package:audio_service/audio_service.dart';

/// A single track in the local Ljod library.
///
/// [id] is stable across rescans: the Android MediaStore row id when available,
/// otherwise the absolute file path.
class SongModel {
  const SongModel({
    required this.id,
    required this.path,
    required this.title,
    required this.artist,
    this.album = '',
    this.albumArtist = '',
    this.duration = Duration.zero,
    this.trackNumber = 0,
    this.artworkPath,
    this.isFavorite = false,
    this.playCount = 0,
    this.lastPlayed,
    this.addedAt,
  });

  final String id;
  final String path;
  final String title;
  final String artist;
  final String album;
  final String albumArtist;
  final Duration duration;
  final int trackNumber;

  /// Cached cover art on disk. Embedded art is extracted during a library scan.
  final String? artworkPath;

  final bool isFavorite;
  final int playCount;
  final DateTime? lastPlayed;
  final DateTime? addedAt;

  File get file => File(path);

  String get displayArtist => artist.trim().isEmpty ? 'Unknown artist' : artist;
  String get displayAlbum => album.trim().isEmpty ? 'Unknown album' : album;

  MediaItem toMediaItem() {
    return MediaItem(
      id: id,
      title: title,
      artist: displayArtist,
      album: displayAlbum,
      duration: duration > Duration.zero ? duration : null,
      artUri: artworkPath == null ? null : Uri.file(artworkPath!),
      extras: {'path': path},
    );
  }

  SongModel copyWith({
    String? id,
    String? path,
    String? title,
    String? artist,
    String? album,
    String? albumArtist,
    Duration? duration,
    int? trackNumber,
    String? artworkPath,
    bool? isFavorite,
    int? playCount,
    DateTime? lastPlayed,
    DateTime? addedAt,
  }) {
    return SongModel(
      id: id ?? this.id,
      path: path ?? this.path,
      title: title ?? this.title,
      artist: artist ?? this.artist,
      album: album ?? this.album,
      albumArtist: albumArtist ?? this.albumArtist,
      duration: duration ?? this.duration,
      trackNumber: trackNumber ?? this.trackNumber,
      artworkPath: artworkPath ?? this.artworkPath,
      isFavorite: isFavorite ?? this.isFavorite,
      playCount: playCount ?? this.playCount,
      lastPlayed: lastPlayed ?? this.lastPlayed,
      addedAt: addedAt ?? this.addedAt,
    );
  }

  Map<String, Object?> toDbMap() {
    return {
      'id': id,
      'path': path,
      'title': title,
      'artist': artist,
      'album': album,
      'albumArtist': albumArtist,
      'durationMs': duration.inMilliseconds,
      'trackNumber': trackNumber,
      'artworkPath': artworkPath,
      'isFavorite': isFavorite ? 1 : 0,
      'playCount': playCount,
      'lastPlayedMs': lastPlayed?.millisecondsSinceEpoch,
      'addedAtMs': (addedAt ?? DateTime.now()).millisecondsSinceEpoch,
    };
  }

  factory SongModel.fromDbMap(Map<String, Object?> map) {
    return SongModel(
      id: map['id'] as String,
      path: map['path'] as String? ?? '',
      title: map['title'] as String? ?? 'Unknown track',
      artist: map['artist'] as String? ?? '',
      album: map['album'] as String? ?? '',
      albumArtist: map['albumArtist'] as String? ?? '',
      duration: Duration(milliseconds: (map['durationMs'] as int?) ?? 0),
      trackNumber: (map['trackNumber'] as int?) ?? 0,
      artworkPath: map['artworkPath'] as String?,
      isFavorite: ((map['isFavorite'] as int?) ?? 0) == 1,
      playCount: (map['playCount'] as int?) ?? 0,
      lastPlayed: map['lastPlayedMs'] == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(map['lastPlayedMs'] as int),
      addedAt: map['addedAtMs'] == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(map['addedAtMs'] as int),
    );
  }
}
