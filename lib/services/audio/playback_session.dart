import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// How playback should behave when it resumes.
enum PlaybackRepeat { off, all, one }

/// Everything needed to make the player look the same after the app is closed
/// and reopened: what was queued, which track was playing, how far in, and the
/// repeat/shuffle state.
///
/// The library order is stored rather than the shuffled order, so toggling
/// shuffle off after a restart still shows tracks in the order the library
/// lists them.
class PlaybackSession {
  const PlaybackSession({
    required this.queue,
    required this.index,
    required this.position,
    required this.repeat,
    this.shuffle = false,
  });

  final List<String> queue;
  final int index;
  final Duration position;
  final PlaybackRepeat repeat;
  final bool shuffle;
}

/// Stores the last playback session beside the other settings.
///
/// Everything here is best-effort: a listener losing their place is a small
/// annoyance, and playback must never fail because a preference write did.
class PlaybackSessionStore {
  PlaybackSessionStore(this._preferences);

  static const String key = 'playback.session';

  final SharedPreferences _preferences;

  PlaybackSession? read() {
    final raw = _preferences.getString(key);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map) return null;
      final queue = <String>[
        for (final id in decoded['queue'] as List? ?? const [])
          if (id is String && id.isNotEmpty) id,
      ];
      if (queue.isEmpty) return null;
      final index = ((decoded['index'] as num?)?.toInt() ?? 0).clamp(
        0,
        queue.length - 1,
      );
      final positionMs = (decoded['positionMs'] as num?)?.toInt() ?? 0;
      return PlaybackSession(
        queue: List.unmodifiable(queue),
        index: index,
        position: Duration(milliseconds: positionMs < 0 ? 0 : positionMs),
        repeat: switch (decoded['repeat']) {
          'all' => PlaybackRepeat.all,
          'one' => PlaybackRepeat.one,
          _ => PlaybackRepeat.off,
        },
        shuffle: decoded['shuffle'] == true,
      );
    } catch (_) {
      // A corrupt or older payload simply means "nothing to restore".
      return null;
    }
  }

  Future<void> write(PlaybackSession session) async {
    try {
      await _preferences.setString(
        key,
        jsonEncode({
          'version': 1,
          'queue': session.queue,
          'index': session.index,
          'positionMs': session.position.inMilliseconds,
          'shuffle': session.shuffle,
          'repeat': session.repeat.name,
          'savedAt': DateTime.now().toIso8601String(),
        }),
      );
    } catch (_) {
      // Convenience only.
    }
  }

  Future<void> clear() async {
    try {
      await _preferences.remove(key);
    } catch (_) {
      // Convenience only.
    }
  }
}
