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

/// Best-effort romanization for lyrics containing non-Latin characters.
String romanizeLyrics(String text) {
  final patterns = {
    '爱': 'ai',
    '你': 'ni',
    '我': 'wo',
    '心': 'xin',
    '梦': 'meng',
    '歌': 'ge',
    '音': 'yin',
    '乐': 'yue',
    '时': 'shi',
    '光': 'guang',
    '风': 'feng',
    '花': 'hua',
    '月': 'yue',
    '夜': 'ye',
    '想': 'xiang',
    '望': 'wang',
    '情': 'qing',
    '青春': 'qing chun',
    '回忆': 'hui yi',
  };
  var result = text;
  for (final k in patterns.keys) {
    result = result.replaceAll(k, '[${patterns[k]}]');
  }
  result = result.replaceAllMapped(
    RegExp(r'\[([a-z ]+)\]|[^\x00-\x7F\[\]]+'),
    (m) => m.group(1) != null ? ' ${m.group(1)!} ' : ' ',
  );
  // Collapse the gaps left by removed characters so the sub-line reads evenly.
  return result.replaceAll(RegExp(r'\s+'), ' ').trim();
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

  @override
  Future<RemoteLyricsResult> lookup(LyricsQuery query) async {
    if (!query.isCallable) {
      return const RemoteLyricsFailure(
        'This track is missing a title or artist name, so there is nothing '
        'safe to look up.',
      );
    }

    try {
      final response = await _dio.get<Object>(
        '/api/get',
        queryParameters: query.getParams,
      );
      final hit = _hitFrom(response.data);
      if (hit != null) return hit;
      return const RemoteLyricsMiss();
    } on DioException catch (error) {
      final status = error.response?.statusCode;
      if (status == 404) return _search(query);
      if (status == 429 || status == 503) {
        return RemoteLyricsFailure(
          'LRCLIB is rate limiting requests right now.',
          retryAfter: _retryAfter(error.response),
        );
      }
      if (status == 400) {
        return const RemoteLyricsFailure(
          'LRCLIB rejected this track\'s metadata. Check the title, artist '
          'and duration tags.',
        );
      }
      return const RemoteLyricsFailure(
        'Could not reach LRCLIB. Check the connection and try again.',
      );
    }
  }

  /// One bounded fallback: search by title/artist and accept a close match.
  Future<RemoteLyricsResult> _search(LyricsQuery query) async {
    try {
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

  final LyricsRemote _remote;
  final Future<Directory> Function() _cacheRoot;

  /// Called after a lookup is written, so storage figures stay current.
  final void Function()? onCacheWrite;

  final LinkedHashMap<String, LyricsResult> _memory = LinkedHashMap();
  final Map<String, Future<LyricsResult>> _inFlight = {};
  DateTime? _cooldownUntil;
  int _writesSinceTrim = 0;
  Directory? _cacheDirectory;

  Future<LyricsResult> load(
    SongModel song, {
    required bool allowOnline,
    bool force = false,
  }) async {
    final query = LyricsQuery.fromSong(song);
    final fingerprint = query.fingerprint;

    if (!force) {
      final remembered = _memory.remove(fingerprint);
      if (remembered != null) {
        // Refresh insertion order for the tiny LRU.
        _memory[fingerprint] = remembered;
        return remembered;
      }
    }

    final local = await _local(song);
    if (local != null) {
      return _remember(fingerprint, LyricsResult.found(local));
    }

    if (!allowOnline) return const LyricsResult(status: LyricsStatus.disabled);

    if (!force) {
      final stored = await _readCache(fingerprint);
      if (stored != null) return _remember(fingerprint, stored);
    }

    final existing = _inFlight[fingerprint];
    if (existing != null) return existing;

    final future = _fetch(query, fingerprint, force: force);
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

  Future<Lyrics?> _local(SongModel song) async {
    final sidecar = await _sidecar(song.path);
    if (sidecar != null) return sidecar;
    if (song.path.isEmpty) return null;

    try {
      final embedded = await compute(_readEmbeddedLyrics, song.path);
      final parsed = embedded == null
          ? null
          : Lyrics.parse(embedded, source: 'tag');
      if (parsed != null && !parsed.isEmpty) return parsed;
    } catch (_) {
      // Embedded tag reading is best-effort.
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
    if (_cacheDirectory != null) return _cacheDirectory;
    try {
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

final lyricsProvider = FutureProvider.family<LyricsResult, String>((
  ref,
  songId,
) async {
  final song = ref.watch(songByIdProvider(songId));
  if (song == null) return const LyricsResult(status: LyricsStatus.notFound);

  // Only the toggle matters here: changing the theme must not refetch lyrics.
  final allowOnline = ref.watch(
    settingsProvider.select((settings) => settings.lyricsLookup),
  );
  final refreshToken = ref.watch(
    lyricsRefreshProvider.select((tokens) => tokens[songId] ?? 0),
  );

  return ref
      .read(lyricsServiceProvider)
      .load(song, allowOnline: allowOnline, force: refreshToken > 0);
});
