import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/app_info.dart';
import '../../core/database/app_database.dart';
import '../../core/diagnostics/diagnostics_log.dart';
import 'artwork_match.dart';

/// One album's artwork identity.
///
/// Value equality on [memoKey] is what lets a `FutureProvider.family` share one
/// lookup between every row of the same album.
@immutable
class ArtworkRequest {
  const ArtworkRequest({
    required this.artist,
    required this.album,
    required this.title,
  });

  final String artist;
  final String album;
  final String title;

  String get memoKey =>
      artworkMemoKey(artist: artist, album: album, title: title);

  @override
  bool operator ==(Object other) =>
      other is ArtworkRequest && other.memoKey == memoKey;

  @override
  int get hashCode => memoKey.hashCode;
}

/// One catalogue answer. [failed] separates "could not reach the catalogue"
/// from "the catalogue has no cover", because only the latter is worth
/// remembering.
typedef _Lookup = ({String? url, bool failed});

/// Finds album covers online and remembers the URLs.
///
/// Ljod used to extract every embedded picture into `<app support>/artwork`,
/// which cost 1.46 GB for a thousand covers and still left tracks without art.
/// A cover is now a URL: nothing is written to the device, any number of tracks
/// share one lookup, and the only thing cached is a row of text per album.
///
/// Deezer is asked first because its public API needs no key and serves
/// 1000 px covers; iTunes is the fallback, upscaled from its thumbnail.
class OnlineArtworkService {
  OnlineArtworkService({Dio? dio, AppDatabase? database})
    : _dio =
          dio ??
          Dio(
            BaseOptions(
              connectTimeout: const Duration(seconds: 5),
              receiveTimeout: const Duration(seconds: 7),
              headers: const {
                'User-Agent':
                    'Ljod/${LjodAppInfo.versionName} '
                    '(${LjodAppInfo.applicationId})',
              },
            ),
          ),
      _db = database ?? AppDatabase.instance;

  /// A remembered "no cover" is retried eventually: a track's album may be
  /// added to a catalogue months after the file was ripped.
  static const Duration _missTtl = Duration(days: 14);
  static const int _maxConcurrent = 3;

  final Dio _dio;
  final AppDatabase _db;

  /// Lookups in progress, so twenty rows of one album make one request.
  final Map<String, Future<String?>> _inFlight = {};

  int _active = 0;
  final List<Completer<void>> _waiting = [];

  /// Cover URL for [request], or null when no catalogue has one.
  Future<String?> lookup(ArtworkRequest request) {
    final key = request.memoKey;
    if (key.isEmpty) return Future.value(null);
    final running = _inFlight[key];
    if (running != null) return running;
    final future = _resolve(key, request);
    _inFlight[key] = future;
    return future.whenComplete(() => _inFlight.remove(key));
  }

  /// Forgets every remembered lookup, including the misses.
  ///
  /// The dropped count is logged so a manual refresh leaves proof that it ran,
  /// instead of only having repainted tiles.
  Future<void> clear() async {
    final dropped = await _db.artworkUrlCount();
    await _db.clearArtworkUrls();
    DiagnosticsLog.instance.log(
      'artwork: cleared $dropped remembered lookup(s)',
      level: DiagnosticsLevel.info,
    );
  }

  Future<String?> _resolve(String key, ArtworkRequest request) async {
    try {
      final cached = await _db.artworkUrl(key);
      if (cached != null) {
        final isMiss = cached.url.isEmpty;
        final expired =
            DateTime.now().millisecondsSinceEpoch - cached.fetchedAtMs >
            _missTtl.inMilliseconds;
        if (!isMiss || !expired) return isMiss ? null : cached.url;
      }
    } catch (_) {
      // A missing memo table only costs a request.
    }

    _Lookup result;
    try {
      result = await _fetch(request);
    } catch (_) {
      // Unexpected payloads must look like "no cover", never like an error the
      // UI has to render.
      result = (url: null, failed: true);
    }

    // Never remember a network failure as "this album has no cover": one
    // offline session would otherwise hide the cover for two weeks.
    if (result.failed) return null;

    try {
      await _db.setArtworkUrl(key, result.url);
    } catch (_) {
      // Remembering is an optimisation, never a requirement.
    }
    return result.url;
  }

  Future<_Lookup> _fetch(ArtworkRequest request) async {
    final deezer = await _deezer(request);
    if (deezer.url != null) return deezer;
    final itunes = await _itunes(request);
    if (itunes.url != null) return itunes;
    // Only a total failure keeps the result out of the memo; one catalogue
    // answering "nothing" is a real answer.
    return (url: null, failed: deezer.failed && itunes.failed);
  }

  /// Removes characters that would change the meaning of a catalogue query.
  ///
  /// Deezer's syntax is `field:"value"`, so a tag containing a quote could
  /// otherwise truncate the query and match something unrelated.
  static String _term(String value) =>
      value.replaceAll(RegExp(r'["\\]'), ' ').trim();

  Future<_Lookup> _deezer(ArtworkRequest request) async {
    final artist = _term(request.artist);
    final album = _term(request.album);
    final title = _term(request.title);

    final queries = <String>[
      if (artist.isNotEmpty && album.isNotEmpty)
        'artist:"$artist" album:"$album"',
      if (album.isNotEmpty) 'album:"$album"',
      if (artist.isNotEmpty && title.isNotEmpty)
        'artist:"$artist" track:"$title"',
      if (title.isNotEmpty) 'track:"$title"',
    ];
    if (queries.isEmpty) return (url: null, failed: false);

    final endpoint = album.isEmpty ? '/search' : '/search/album';
    for (final query in queries) {
      final response = await _get('https://api.deezer.com$endpoint', {
        'q': query,
        'limit': '8',
      });
      if (response.failed) return (url: null, failed: true);
      final payload = response.payload;
      if (payload == null) return (url: null, failed: false);
      final cover = pickDeezerCover(payload, album: album);
      if (cover != null) return (url: cover, failed: false);
    }
    return (url: null, failed: false);
  }

  Future<_Lookup> _itunes(ArtworkRequest request) async {
    final album = _term(request.album);
    final term = [
      _term(request.artist),
      album.isEmpty ? _term(request.title) : album,
    ].where((part) => part.isNotEmpty).join(' ');
    if (term.isEmpty) return (url: null, failed: false);

    final response = await _get('https://itunes.apple.com/search', {
      'term': term,
      'entity': 'album',
      'limit': '6',
    });
    if (response.failed) return (url: null, failed: true);
    final payload = response.payload;
    if (payload == null) return (url: null, failed: false);
    return (url: pickItunesCover(payload, album: album), failed: false);
  }

  /// One request. A non-object body counts as "no result", not as a failure.
  Future<({Map<String, Object?>? payload, bool failed})> _get(
    String url,
    Map<String, String> query,
  ) async {
    await _acquire();
    try {
      final response = await _dio.get<Object?>(url, queryParameters: query);
      final data = response.data;
      if (data is! Map) return (payload: null, failed: false);
      return (
        payload: data.map((key, value) => MapEntry(key.toString(), value)),
        failed: false,
      );
    } on DioException catch (error) {
      DiagnosticsLog.instance.log(
        'artwork: lookup failed (${error.type.name})',
        level: DiagnosticsLevel.warning,
      );
      return (payload: null, failed: true);
    } catch (_) {
      return (payload: null, failed: true);
    } finally {
      _release();
    }
  }

  /// Caps concurrent requests: an album grid asks for a cover per tile, and a
  /// hundred parallel requests would be throttled or refused.
  Future<void> _acquire() async {
    if (_active < _maxConcurrent) {
      _active++;
      return;
    }
    final slot = Completer<void>();
    _waiting.add(slot);
    await slot.future;
  }

  void _release() {
    if (_waiting.isEmpty) {
      if (_active > 0) _active--;
      return;
    }
    // Hand the slot straight to the next waiter without dropping the count.
    _waiting.removeAt(0).complete();
  }
}

final onlineArtworkServiceProvider = Provider<OnlineArtworkService>((ref) {
  return OnlineArtworkService();
});

/// Cover URL for one album, or null while it is being found or absent.
final artworkUrlProvider = FutureProvider.family<String?, ArtworkRequest>(
  (ref, request) => ref.watch(onlineArtworkServiceProvider).lookup(request),
);

/// Remembered lookups, for the storage row in Settings.
final artworkLookupCountProvider = FutureProvider<int>((ref) async {
  try {
    return await AppDatabase.instance.artworkUrlCount();
  } catch (_) {
    return 0;
  }
});
