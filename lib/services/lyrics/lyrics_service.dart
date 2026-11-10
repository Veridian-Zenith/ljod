import 'dart:collection';
import 'dart:convert';
import 'dart:io';

import 'package:audio_metadata_reader/audio_metadata_reader.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import '../../core/app_info.dart';
import '../../core/models/song_model.dart';
import '../library/library_providers.dart';
import '../settings/settings_provider.dart';

// Romanization lives in its own file; re-exported so every existing import of
// the lyrics service keeps seeing `romanizeLyrics`.
export 'romanization.dart';

class LyricLine {
  const LyricLine({this.time, required this.text});

  final Duration? time;
  final String text;
}

class Lyrics {
  const Lyrics({required this.lines, required this.synced, this.source = ''});

  final List<LyricLine> lines;
  final bool synced;
  final String source;

  bool get isEmpty => lines.every((line) => line.text.trim().isEmpty);

  /// Index of the line that should be highlighted for [position].
  int activeLine(Duration position) {
    if (!synced) return -1;
    var index = -1;
    for (var i = 0; i < lines.length; i++) {
      final time = lines[i].time;
      if (time == null) continue;
      if (time <= position) {
        index = i;
      } else {
        break;
      }
    }
    return index;
  }

  static Lyrics? parse(String raw, {String source = ''}) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty) return null;

    final timestamp = RegExp(r'\[(\d{1,3}):(\d{1,2}(?:[.:]\d{1,3})?)\]');
    final result = <LyricLine>[];
    var synced = false;

    for (final rawLine in trimmed.split(RegExp(r'\r?\n'))) {
      final matches = timestamp.allMatches(rawLine).toList();
      if (matches.isEmpty) {
        if (rawLine.startsWith(RegExp(r'\[(ar|ti|al|by|offset|re|ve):'))) {
          continue;
        }
        result.add(LyricLine(text: rawLine.trim()));
        continue;
      }

      final text = rawLine.replaceAll(timestamp, '').trim();
      if (text.isEmpty) continue;
      for (final match in matches) {
        final minutes = int.parse(match.group(1)!);
        final seconds = double.parse(match.group(2)!.replaceAll(':', '.'));
        result.add(
          LyricLine(
            time: Duration(
              milliseconds: (minutes * 60 * 1000 + seconds * 1000).round(),
            ),
            text: text,
          ),
        );
        synced = true;
      }
    }

    if (result.isEmpty) return null;
    if (synced) {
      result.sort((a, b) {
        final at = a.time ?? Duration.zero;
        final bt = b.time ?? Duration.zero;
        return at.compareTo(bt);
      });
    }
    return Lyrics(lines: result, synced: synced, source: source);
  }
}

/// Why a lyrics request ended the way it did, for the UI to explain.
enum LyricsStatus {
  /// Lyrics are available (local, cached or freshly looked up).
  found,

  /// LRCLIB knows the track but lists it as instrumental.
  instrumental,

  /// A definitive "this track has no lyrics" answer, cached permanently.
  notFound,

  /// Online lookup is switched off and nothing local exists.
  disabled,

  /// The lookup could not complete (offline, rate limited, bad metadata).
  failed,
}

/// Result of a lyrics request, including why there is no text when there is
/// none — so the sheet can say "rate limited" instead of "not found".
class LyricsResult {
  const LyricsResult({
    required this.status,
    this.lyrics,
    this.cached = false,
    this.message,
    this.retryAfter,
  });

  const LyricsResult.found(Lyrics this.lyrics, {this.cached = false})
    : status = LyricsStatus.found,
      message = null,
      retryAfter = null;

  final LyricsStatus status;
  final Lyrics? lyrics;
  final bool cached;
  final String? message;
  final Duration? retryAfter;

  bool get hasLyrics =>
      status == LyricsStatus.found && lyrics != null && !lyrics!.isEmpty;
}

/// The exact metadata sent to LRCLIB.
///
/// LRCLIB documents `track_name` and `artist_name` as required, `album_name` as
/// recommended, and `duration` as seconds in the range 1..3600. Sending an
/// out-of-range duration is a 400, and omitting the profile identifier makes
/// the request look like an anonymous client, so both are normalised here.
@immutable
class LyricsQuery {
  const LyricsQuery({
    required this.trackName,
    required this.artistName,
    this.albumName = '',
    this.durationSeconds,
  });

  factory LyricsQuery.fromSong(SongModel song) {
    final seconds = song.duration.inSeconds;
    return LyricsQuery(
      trackName: _normalize(song.title),
      artistName: _normalize(song.displayArtist),
      albumName: _normalize(song.album),
      durationSeconds: seconds >= 1 && seconds <= 3600 ? seconds : null,
    );
  }

  final String trackName;
  final String artistName;
  final String albumName;
  final int? durationSeconds;

  /// `/api/get` cannot answer without both required fields.
  bool get isCallable => trackName.isNotEmpty && artistName.isNotEmpty;

  Map<String, String> get getParams => {
    'track_name': trackName,
    'artist_name': artistName,
    if (albumName.isNotEmpty) 'album_name': albumName,
    if (durationSeconds != null) 'duration': '$durationSeconds',
  };

  Map<String, String> get searchParams => {
    'track_name': trackName,
    if (artistName.isNotEmpty) 'artist_name': artistName,
  };

  /// Changes only when the questions we would ask change: retitling a file or
  /// re-tagging it invalidates the cache, opening the same track does not.
  String get fingerprint {
    final raw =
        'v1|$trackName|$artistName|$albumName|${durationSeconds ?? 0}|'
        '${trackName.length}';
    var hash = 0xcbf29ce484222325;
    for (final unit in raw.codeUnits) {
      hash ^= unit;
      hash = (hash * 0x100000001b3) & 0xFFFFFFFFFFFFFFFF;
    }
    return hash.toRadixString(16).padLeft(16, '0');
  }

  static String _normalize(String value) =>
      value.trim().replaceAll(RegExp(r'\s+'), ' ');
}

/// The song fields that decide *which* lyrics are asked for.
///
/// Play counters, favourite state and artwork are deliberately absent: they
/// change while a track plays, so folding them into the lyrics provider's
/// identity rebuilt it on every play-count update. That dropped the sheet to a
/// loading state, and for a result that was never cached (a network failure) it
/// asked LRCLIB again.
@immutable
class LyricsSubject {
  const LyricsSubject({
    required this.id,
    required this.title,
    required this.artist,
    required this.album,
    required this.path,
    required this.duration,
  });

  factory LyricsSubject.of(SongModel song) => LyricsSubject(
    id: song.id,
    title: song.title,
    artist: song.displayArtist,
    album: song.album,
    path: song.path,
    duration: song.duration,
  );

  final String id;
  final String title;
  final String artist;
  final String album;
  final String path;
  final Duration duration;

  @override
  bool operator ==(Object other) =>
      other is LyricsSubject &&
      other.id == id &&
      other.title == title &&
      other.artist == artist &&
      other.album == album &&
      other.path == path &&
      other.duration == duration;

  @override
  int get hashCode => Object.hash(id, title, artist, album, path, duration);
}

/// One remote lookup outcome.
sealed class RemoteLyricsResult {
  const RemoteLyricsResult();
}

class RemoteLyricsHit extends RemoteLyricsResult {
  const RemoteLyricsHit(this.lyrics, {this.instrumental = false});

  final Lyrics? lyrics;
  final bool instrumental;
}

class RemoteLyricsMiss extends RemoteLyricsResult {
  const RemoteLyricsMiss();
}

class RemoteLyricsFailure extends RemoteLyricsResult {
  const RemoteLyricsFailure(this.message, {this.retryAfter});

  final String message;
  final Duration? retryAfter;
}

/// Swappable remote so the caching logic can be tested without a network.
abstract class LyricsRemote {
  Future<RemoteLyricsResult> lookup(LyricsQuery query);
}

/// Identity required by LRCLIB's usage policy. Add the project homepage once
/// this app is published; the package id keeps it unique until then.
const String lrclibUserAgent =
    'Ljod/${LjodAppInfo.versionName} (${LjodAppInfo.applicationId})';

/// LRCLIB client. One request per track, one search fallback only when the
/// metadata lookup misses, and `Retry-After` is honoured.
class LrclibRemote implements LyricsRemote {
  LrclibRemote({Dio? dio})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              baseUrl: 'https://lrclib.net',
              connectTimeout: const Duration(seconds: 6),
              receiveTimeout: const Duration(seconds: 8),
              headers: const {
                'User-Agent': lrclibUserAgent,
                'Accept': 'application/json',
              },
            ),
          );

  final Dio _dio;

  /// LRCLIB is a community service, and it answers request bursts with 502/503
  /// rather than a polite 429. Keeping our own calls apart is cheaper than
  /// retrying through that noise.
  DateTime? _lastRequest;
  static const Duration _minSpacing = Duration(milliseconds: 400);

  Future<void> _pace() async {
    final last = _lastRequest;
    if (last != null) {
      final wait = last.add(_minSpacing).difference(DateTime.now());
      if (wait > Duration.zero) await Future<void>.delayed(wait);
    }
    _lastRequest = DateTime.now();
  }

  @override
  Future<RemoteLyricsResult> lookup(LyricsQuery query) async {
    if (!query.isCallable) {
      return const RemoteLyricsFailure(
        'This track is missing a title or artist name, so there is nothing '
        'safe to look up.',
      );
    }

    for (var attempt = 0; attempt < 2; attempt++) {
      try {
        await _pace();
        final response = await _dio.get<Object>(
          '/api/get',
          queryParameters: query.getParams,
        );
        final hit = _hitFrom(response.data);
        return hit ?? const RemoteLyricsMiss();
      } on DioException catch (error) {
        final status = error.response?.statusCode;
        if (status == 404) return _search(query);
        if (status == 429) {
          return RemoteLyricsFailure(
            'LRCLIB is rate limiting requests right now.',
            retryAfter: _retryAfter(error.response),
          );
        }
        // A 5xx means LRCLIB is busy, not that we are asking too often. One
        // short retry covers it, and it must never park a cooldown: that is
        // what left the sheet saying "rate limited" indefinitely.
        if ((status == 502 || status == 503 || status == 504) && attempt == 0) {
          await Future<void>.delayed(const Duration(milliseconds: 700));
          continue;
        }
        if (status == 400) {
          return const RemoteLyricsFailure(
            'LRCLIB rejected this track\'s metadata. Check the title, artist '
            'and duration tags.',
          );
        }
        if (status != null && status >= 500) {
          return const RemoteLyricsFailure(
            'LRCLIB is busy right now. Try again in a moment.',
          );
        }
        return const RemoteLyricsFailure(
          'Could not reach LRCLIB. Check the connection and try again.',
        );
      }
    }

    return const RemoteLyricsFailure(
      'LRCLIB is busy right now. Try again in a moment.',
    );
  }

  /// One bounded fallback: search by title/artist and accept a close match.
  Future<RemoteLyricsResult> _search(LyricsQuery query) async {
    try {
      await _pace();
      final response = await _dio.get<Object>(
        '/api/search',
        queryParameters: query.searchParams,
      );
      final data = response.data;
      if (data is! List || data.isEmpty) return const RemoteLyricsMiss();

      final candidates = data.whereType<Map>().toList(growable: false);
      Map? best;
      var bestScore = -1.0;
      for (final candidate in candidates) {
        final score = _score(candidate, query);
        if (score > bestScore) {
          bestScore = score;
          best = candidate;
        }
      }
      if (best == null || bestScore < 0) return const RemoteLyricsMiss();
      return _hitFrom(best) ?? const RemoteLyricsMiss();
    } on DioException {
      // The metadata lookup already missed; a failed fallback is a miss, not
      // an error worth showing the listener.
      return const RemoteLyricsMiss();
    }
  }

  /// Prefers exact title/artist matches, close durations, and synced lyrics.
  double _score(Map candidate, LyricsQuery query) {
    final title = _string(candidate['trackName'] ?? candidate['name']);
    final artist = _string(candidate['artistName']);
    final duration = candidate['duration'];
    if (title.isEmpty) return -1;

    var score = 0.0;
    if (title.toLowerCase() == query.trackName.toLowerCase()) {
      score += 3;
    } else if (title.toLowerCase().contains(query.trackName.toLowerCase())) {
      score += 1;
    } else {
      return -1;
    }

    if (artist.toLowerCase() == query.artistName.toLowerCase()) {
      score += 2;
    } else if (artist.isNotEmpty &&
        (artist.toLowerCase().contains(query.artistName.toLowerCase()) ||
            query.artistName.toLowerCase().contains(artist.toLowerCase()))) {
      score += 1;
    }

    if (duration is num && query.durationSeconds != null) {
      final delta = (duration - query.durationSeconds!).abs();
      if (delta > 6) return -1;
      score += (6 - delta) / 6;
    }

    final synced = candidate['syncedLyrics'];
    if (synced is String && synced.trim().isNotEmpty) score += 1;
    return score;
  }

  RemoteLyricsHit? _hitFrom(Object? data) {
    if (data is! Map) return null;
    if (data['instrumental'] == true) {
      return const RemoteLyricsHit(null, instrumental: true);
    }

    final synced = data['syncedLyrics'];
    if (synced is String && synced.trim().isNotEmpty) {
      final parsed = Lyrics.parse(synced, source: 'LRCLIB');
      if (parsed != null && !parsed.isEmpty) return RemoteLyricsHit(parsed);
    }
    final plain = data['plainLyrics'];
    if (plain is String && plain.trim().isNotEmpty) {
      final parsed = Lyrics.parse(plain, source: 'LRCLIB');
      if (parsed != null && !parsed.isEmpty) return RemoteLyricsHit(parsed);
    }
    return null;
  }

  Duration _retryAfter(Response<Object?>? response) {
    final header = response?.headers.value('retry-after');
    final seconds = int.tryParse(header?.trim() ?? '');
    if (seconds != null && seconds > 0) {
      return Duration(seconds: seconds.clamp(1, 60));
    }
    return const Duration(seconds: 30);
  }

  static String _string(Object? value) => value is String ? value.trim() : '';
}

/// Cache-first lyrics loader.
///
/// Rules, in order:
/// * local sources (sidecar, embedded tag) win — no network;
/// * a previous **definitive** answer is reused forever: found lyrics, an
///   instrumental listing, or "no such track" — opening the sheet again must
///   not talk to the network;
/// * transient failures are never cached, so an explicit retry can succeed;
/// * concurrent requests for one track share a single request;
/// * `force` (the sheet's manual refresh) skips the cache but still respects a
///   rate-limit cooldown.
class LyricsService {
  LyricsService({
    LyricsRemote? remote,
    Future<Directory> Function()? cacheRoot,
    this.onCacheWrite,
  }) : _remote = remote ?? LrclibRemote(),
       _cacheRoot = cacheRoot ?? getApplicationSupportDirectory;

  static const int _memoryEntries = 32;
  static const int _cacheBudgetBytes = 6 * 1024 * 1024;
  static const int _trimEveryWrites = 25;
  static const int _embeddedMemoEntries = 256;

  final LyricsRemote _remote;
  final Future<Directory> Function() _cacheRoot;

  /// Called after a lookup is written, so storage figures stay current.
  final void Function()? onCacheWrite;

  final LinkedHashMap<String, LyricsResult> _memory = LinkedHashMap();
  final Map<String, Future<LyricsResult>> _inFlight = {};

  /// Tracks whose embedded tags held no lyrics. The probe spawns an isolate and
  /// parses tags, so a track that had none must not pay for it again on every
  /// open; an explicit refresh re-reads in case the tags were edited.
  final LinkedHashSet<String> _noEmbeddedLyrics = LinkedHashSet();

  /// Highest refresh token already served per track, so a manual refresh forces
  /// exactly one lookup instead of every later rebuild of the provider.
  final Map<String, int> _forceTokens = {};
  DateTime? _cooldownUntil;
  int _writesSinceTrim = 0;
  Directory? _cacheDirectory;

  Future<LyricsResult> load(
    SongModel song, {
    required bool allowOnline,
    bool force = false,
    int forceToken = 0,
  }) async {
    final query = LyricsQuery.fromSong(song);
    final fingerprint = query.fingerprint;

    // A refresh token forces one lookup. Treating any non-zero token as "force"
    // meant every rebuild of the provider skipped the cache and asked LRCLIB
    // again: the lines being followed were swapped mid-track, and the bursts
    // came back as 502/503.
    final tokenForced = forceToken > (_forceTokens[fingerprint] ?? 0);
    if (tokenForced) _forceTokens[fingerprint] = forceToken;
    final forced = force || tokenForced;

    if (!forced) {
      final remembered = _memory.remove(fingerprint);
      if (remembered != null) {
        // Refresh insertion order for the tiny LRU.
        _memory[fingerprint] = remembered;
        return remembered;
      }
    }

    final local = await _local(song, recheckEmbedded: forced);
    if (local != null) {
      return _remember(fingerprint, LyricsResult.found(local));
    }

    if (!allowOnline) return const LyricsResult(status: LyricsStatus.disabled);

    if (!forced) {
      final stored = await _readCache(fingerprint);
      if (stored != null) return _remember(fingerprint, stored);
    }

    final existing = _inFlight[fingerprint];
    if (existing != null) return existing;

    final future = _fetch(query, fingerprint, force: forced);
    _inFlight[fingerprint] = future;
    try {
      return await future;
    } finally {
      _inFlight.remove(fingerprint);
    }
  }

  Future<LyricsResult> _fetch(
    LyricsQuery query,
    String fingerprint, {
    required bool force,
  }) async {
    final cooldown = _cooldownUntil;
    if (cooldown != null && DateTime.now().isBefore(cooldown)) {
      final remaining = cooldown.difference(DateTime.now());
      return LyricsResult(
        status: LyricsStatus.failed,
        message: 'LRCLIB asked for a pause before the next request.',
        retryAfter: remaining,
      );
    }
    if (!force && _cooldownUntil != null) {
      _cooldownUntil = null;
    }

    final outcome = await _remote.lookup(query);

    switch (outcome) {
      case RemoteLyricsHit(instrumental: true):
        const result = LyricsResult(status: LyricsStatus.instrumental);
        await _writeCache(fingerprint, result);
        return _remember(fingerprint, result);
      case RemoteLyricsHit(:final lyrics):
        if (lyrics == null || lyrics.isEmpty) {
          const result = LyricsResult(status: LyricsStatus.notFound);
          await _writeCache(fingerprint, result);
          return _remember(fingerprint, result);
        }
        final result = LyricsResult.found(lyrics);
        await _writeCache(fingerprint, result);
        return _remember(fingerprint, result);
      case RemoteLyricsMiss():
        const result = LyricsResult(status: LyricsStatus.notFound);
        await _writeCache(fingerprint, result);
        return _remember(fingerprint, result);
      case RemoteLyricsFailure(:final message, :final retryAfter):
        if (retryAfter != null) {
          _cooldownUntil = DateTime.now().add(retryAfter);
        }
        return LyricsResult(
          status: LyricsStatus.failed,
          message: message,
          retryAfter: retryAfter,
        );
    }
  }

  LyricsResult _remember(String fingerprint, LyricsResult result) {
    _memory.remove(fingerprint);
    _memory[fingerprint] = result;
    while (_memory.length > _memoryEntries) {
      _memory.remove(_memory.keys.first);
    }
    return result;
  }

  /// Local sources, cheapest first.
  ///
  /// The sidecar check is three `exists()` calls and always runs, so a `.lrc`
  /// dropped beside a track is picked up mid-session. The embedded-tag probe is
  /// not repeated once a file is known to carry none.
  Future<Lyrics?> _local(
    SongModel song, {
    required bool recheckEmbedded,
  }) async {
    final sidecar = await _sidecar(song.path);
    if (sidecar != null) return sidecar;
    if (song.path.isEmpty) return null;
    return _embedded(song, recheck: recheckEmbedded);
  }

  Future<Lyrics?> _embedded(SongModel song, {required bool recheck}) async {
    final key = '${song.id}|${song.path}';
    if (!recheck && _noEmbeddedLyrics.contains(key)) return null;

    try {
      final embedded = await compute(_readEmbeddedLyrics, song.path);
      final parsed = embedded == null
          ? null
          : Lyrics.parse(embedded, source: 'tag');
      if (parsed != null && !parsed.isEmpty) return parsed;
    } catch (_) {
      // Embedded tag reading is best-effort.
    }

    // A definite "no embedded lyrics" answer, kept for the next open.
    _noEmbeddedLyrics.remove(key);
    _noEmbeddedLyrics.add(key);
    while (_noEmbeddedLyrics.length > _embeddedMemoEntries) {
      _noEmbeddedLyrics.remove(_noEmbeddedLyrics.first);
    }
    return null;
  }

  Future<Lyrics?> _sidecar(String path) async {
    if (path.isEmpty) return null;
    final withoutExtension = p.withoutExtension(path);
    for (final extension in ['.lrc', '.LRC', '.txt']) {
      final file = File('$withoutExtension$extension');
      if (!await file.exists()) continue;
      try {
        final parsed = Lyrics.parse(
          await file.readAsString(),
          source: 'sidecar',
        );
        if (parsed != null && !parsed.isEmpty) return parsed;
      } catch (_) {
        // Keep looking.
      }
    }
    return null;
  }

  Future<Directory?> _directory() async {
    try {
      // The directory can disappear underneath a cached handle: "Clear library
      // cache" removes it wholesale. Returning the stale path made every later
      // write fail silently and left the cache dead until the next launch.
      final cached = _cacheDirectory;
      if (cached != null) {
        if (await cached.exists()) return cached;
        _cacheDirectory = null;
      }

      final base = await _cacheRoot();
      final directory = Directory(p.join(base.path, 'lyrics'));
      if (!await directory.exists()) {
        await directory.create(recursive: true);
      }
      _cacheDirectory = directory;
      return directory;
    } catch (_) {
      return null;
    }
  }

  Future<File?> _cacheFile(String fingerprint) async {
    final directory = await _directory();
    if (directory == null) return null;
    return File(p.join(directory.path, '$fingerprint.json'));
  }

  Future<LyricsResult?> _readCache(String fingerprint) async {
    final file = await _cacheFile(fingerprint);
    if (file == null || !await file.exists()) return null;
    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map) return null;
      if (decoded['fingerprint'] != fingerprint) return null;

      final status = switch (decoded['status']) {
        'found' => LyricsStatus.found,
        'instrumental' => LyricsStatus.instrumental,
        'notFound' => LyricsStatus.notFound,
        _ => null,
      };
      if (status == null) return null;
      if (status != LyricsStatus.found) return LyricsResult(status: status);

      final rawLines = decoded['lines'];
      if (rawLines is! List) return null;
      final lines = <LyricLine>[];
      for (final raw in rawLines) {
        if (raw is! List || raw.length != 2) continue;
        final ms = raw[0];
        final text = raw[1];
        if (text is! String) continue;
        lines.add(
          LyricLine(
            time: ms is num ? Duration(milliseconds: ms.toInt()) : null,
            text: text,
          ),
        );
      }
      if (lines.isEmpty) return null;
      final lyrics = Lyrics(
        lines: lines,
        synced: decoded['synced'] == true,
        source: decoded['source'] is String
            ? decoded['source'] as String
            : 'LRCLIB',
      );
      if (lyrics.isEmpty) return null;
      return LyricsResult.found(lyrics, cached: true);
    } catch (_) {
      // Unreadable cache entry: treat as absent.
      return null;
    }
  }

  Future<void> _writeCache(String fingerprint, LyricsResult result) async {
    final file = await _cacheFile(fingerprint);
    if (file == null) return;

    final lyrics = result.lyrics;
    final payload = <String, Object?>{
      'version': 1,
      'fingerprint': fingerprint,
      'status': switch (result.status) {
        LyricsStatus.found => 'found',
        LyricsStatus.instrumental => 'instrumental',
        LyricsStatus.notFound => 'notFound',
        _ => 'failed',
      },
      'source': lyrics?.source ?? 'LRCLIB',
      'synced': lyrics?.synced ?? false,
      'fetchedAt': DateTime.now().toIso8601String(),
      'lines': [
        for (final line in lyrics?.lines ?? const <LyricLine>[])
          [line.time?.inMilliseconds, line.text],
      ],
    };

    try {
      await file.writeAsString(jsonEncode(payload), flush: true);
    } catch (_) {
      return;
    }

    onCacheWrite?.call();
    _writesSinceTrim++;
    if (_writesSinceTrim >= _trimEveryWrites) {
      _writesSinceTrim = 0;
      await _trim();
    }
  }

  /// Keeps the lyrics directory small and removes `.lrc` files written by older
  /// builds, which are no longer read.
  Future<void> _trim() async {
    final directory = await _directory();
    if (directory == null) return;

    final entries = <({File file, int length, DateTime modified})>[];
    try {
      await for (final entity in directory.list(followLinks: false)) {
        if (entity is! File) continue;
        if (p.extension(entity.path) != '.json') {
          try {
            await entity.delete();
          } catch (_) {
            // Best effort.
          }
          continue;
        }
        try {
          final stat = await entity.stat();
          entries.add((
            file: entity,
            length: stat.size,
            modified: stat.modified,
          ));
        } catch (_) {
          // Skip unreadable entries.
        }
      }
    } catch (_) {
      return;
    }

    var total = entries.fold<int>(0, (sum, entry) => sum + entry.length);
    if (total <= _cacheBudgetBytes) return;
    entries.sort((a, b) => a.modified.compareTo(b.modified));
    for (final entry in entries) {
      if (total <= _cacheBudgetBytes) break;
      try {
        await entry.file.delete();
        total -= entry.length;
      } catch (_) {
        // Best effort.
      }
    }
  }

  /// Bytes currently used by the lyrics cache.
  Future<int> usageBytes() async {
    final directory = await _directory();
    if (directory == null) return 0;
    var total = 0;
    try {
      await for (final entity in directory.list(followLinks: false)) {
        if (entity is File) {
          try {
            total += await entity.length();
          } catch (_) {
            // Skip.
          }
        }
      }
    } catch (_) {
      // Unreadable directory.
    }
    return total;
  }

  /// Deletes every cached online lookup. Local sidecars and tags are untouched.
  Future<void> clearCache() async {
    _memory.clear();
    final directory = await _directory();
    if (directory == null) return;
    try {
      await for (final entity in directory.list(followLinks: false)) {
        if (entity is File) await entity.delete();
      }
    } catch (_) {
      // Best effort.
    }
  }
}

String? _readEmbeddedLyrics(String path) {
  try {
    final file = File(path);
    if (!file.existsSync()) return null;
    final metadata = readMetadata(file, getImage: false);
    return metadata.lyrics;
  } catch (_) {
    return null;
  }
}

/// Increments whenever a lookup is written to or removed from the cache, so the
/// storage row reports the directory as it actually is.
final lyricsCacheRevisionProvider = NotifierProvider<LyricsCacheRevision, int>(
  LyricsCacheRevision.new,
);

class LyricsCacheRevision extends Notifier<int> {
  @override
  int build() => 0;

  void bump() => state = state + 1;
}

final lyricsServiceProvider = Provider<LyricsService>((ref) {
  return LyricsService(
    onCacheWrite: () => ref.read(lyricsCacheRevisionProvider.notifier).bump(),
  );
});

/// Bytes used by cached online lookups, for the storage row in Settings.
final lyricsCacheBytesProvider = FutureProvider<int>((ref) async {
  ref.watch(lyricsCacheRevisionProvider);
  return ref.watch(lyricsServiceProvider).usageBytes();
});

/// Bumped when the listener asks for a fresh lookup, so the provider re-runs
/// with `force: true` instead of serving the cached answer.
final lyricsRefreshProvider =
    NotifierProvider<LyricsRefreshNotifier, Map<String, int>>(
      LyricsRefreshNotifier.new,
    );

class LyricsRefreshNotifier extends Notifier<Map<String, int>> {
  @override
  Map<String, int> build() => const {};

  void request(String songId) {
    state = {...state, songId: (state[songId] ?? 0) + 1};
  }
}

/// The lyrics identity of a track, stable across play-count and favourite
/// changes. `null` once the track is no longer in the library.
final lyricsSubjectProvider = Provider.family<LyricsSubject?, String>((
  ref,
  songId,
) {
  return ref.watch(
    songByIdProvider(songId)
        .select((song) => song == null ? null : LyricsSubject.of(song)),
  );
});

final lyricsProvider = FutureProvider.family<LyricsResult, String>((
  ref,
  songId,
) async {
  // Watching the subject rather than the song keeps play counters, favourite
  // toggles and artwork out of this provider's identity.
  final subject = ref.watch(lyricsSubjectProvider(songId));
  if (subject == null) return const LyricsResult(status: LyricsStatus.notFound);

  // Only the toggle matters here: changing the theme must not refetch lyrics.
  final allowOnline = ref.watch(
    settingsProvider.select((settings) => settings.lyricsLookup),
  );
  final refreshToken = ref.watch(
    lyricsRefreshProvider.select((tokens) => tokens[songId] ?? 0),
  );

  // The subject above already covers every field `load` reads, so this cannot
  // observe a song the provider has not seen.
  final song = ref.read(songByIdProvider(songId));
  if (song == null) return const LyricsResult(status: LyricsStatus.notFound);

  return ref
      .read(lyricsServiceProvider)
      .load(song, allowOnline: allowOnline, forceToken: refreshToken);
});
