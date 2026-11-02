import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// How much a diagnostics entry matters.
///
/// Only [warning] and [error] are shown by default: a trail that records every
/// routine event is unreadable exactly when it is needed.
enum DiagnosticsLevel {
  /// Routine breadcrumbs (queue changes, transport toggles, session start).
  info,

  /// Something degraded but recoverable.
  warning,

  /// A failure: a caught exception, a native crash, a playback error.
  error,
}

/// A small, bounded, on-device log of anything that can explain a crash or a
/// playback failure.
///
/// Debug builds can die from a native fault that Dart never sees (a bad
/// foreground-service start, an OOM kill, a plugin fault), so the app records
/// what it was doing and surfaces it in Settings. Nothing here ever leaves the
/// device.
///
/// The log is capped at [maxBytes]: it is a diagnostic breadcrumb trail, not a
/// growing archive.
class DiagnosticsLog {
  DiagnosticsLog._();

  static final DiagnosticsLog instance = DiagnosticsLog._();

  static const int maxBytes = 128 * 1024;
  static const String fileName = 'diagnostics-2.log';

  /// File the Android side writes an uncaught exception to before the process
  /// dies. Consumed once and folded into the log on the next launch.
  static const String nativeCrashFileName = 'ljod-crash.log';

  /// Longest stack trace kept per failure; the head names the cause, the tail
  /// is framework noise that buries it.
  static const int maxStackLines = 8;

  static const Map<String, DiagnosticsLevel> _markers = {
    'I': DiagnosticsLevel.info,
    'W': DiagnosticsLevel.warning,
    'E': DiagnosticsLevel.error,
  };

  final List<_Entry> _memory = [];
  File? _file;
  bool _ready = false;

  /// Recent entries in memory, oldest first.
  List<String> get entries {
    final formatted = _format(_memory, includeInfo: false);
    return formatted.isEmpty ? const [] : formatted.split('\n');
  }

  /// Entries that explain a problem, newest first.
  ///
  /// [includeInfo] adds the routine breadcrumbs, which are off by default: they
  /// are only useful when reconstructing what happened before a fault.
  Future<String> read({bool includeInfo = false}) async {
    await _ensureReady();
    return _format(_memory.reversed.toList(), includeInfo: includeInfo);
  }

  /// How many failure entries are held, for the settings badge.
  int count({bool includeInfo = false}) => _memory
      .where((entry) => includeInfo || entry.level != DiagnosticsLevel.info)
      .length;

  Future<void> _ensureReady() async {
    if (_ready) return;
    try {
      // A blocked platform channel must not leave the diagnostics screen
      // spinning forever: the in-memory trail is still worth showing.
      final support = await getApplicationSupportDirectory().timeout(
        const Duration(seconds: 3),
      );
      _file = File(p.join(support.path, fileName));
      if (await _file!.exists()) {
        final existing = await _file!.readAsString();
        for (final line in existing.split('\n')) {
          final entry = _parse(line);
          if (entry != null) _memory.add(entry);
        }
      }
    } catch (_) {
      _file = null;
    }
    _ready = true;
  }

  /// Appends [message] with a timestamp. Never throws.
  Future<void> record(
    String message, {
    DiagnosticsLevel level = DiagnosticsLevel.error,
  }) async {
    final stamp = DateTime.now().toIso8601String().substring(11, 19);
    _memory.add(_Entry(level, '[$stamp] ${message.trim()}'));
    await _trim();
    final file = _file;
    if (file == null) return;
    try {
      await file.writeAsString('${_serialize()}\n', flush: true);
    } catch (_) {
      // Diagnostics must never break the app.
    }
  }

  /// Fire-and-forget variant for hot paths.
  void log(String message, {DiagnosticsLevel level = DiagnosticsLevel.error}) {
    unawaited(record(message, level: level));
  }

  /// Loads the log and folds in any native crash the Android layer captured.
  Future<void> initialize() async {
    await _ensureReady();
    await _ingestNativeCrash();
    await record('session start', level: DiagnosticsLevel.info);
  }

  Future<void> _ingestNativeCrash() async {
    // The Android layer writes beside the app's files; depending on the SDK
    // that resolves to either the support or the documents directory.
    for (final resolve in [
      getApplicationSupportDirectory,
      getApplicationDocumentsDirectory,
    ]) {
      try {
        final directory = await resolve();
        final crash = File(p.join(directory.path, nativeCrashFileName));
        if (!await crash.exists()) continue;
        final contents = await crash.readAsString();
        await crash.delete();
        if (contents.trim().isEmpty) continue;
        for (final line in contents.trim().split('\n')) {
          await record('ANDROID CRASH: $line');
        }
        return;
      } catch (_) {
        // Try the next location.
      }
    }
  }

  Future<void> _trim() async {
    if (_memory.isEmpty) return;
    // Measured as rendered: the level tag is part of what Settings shows.
    var total = _memory.fold<int>(0, (sum, entry) => sum + _cost(entry));
    while (total > maxBytes && _memory.length > 1) {
      total -= _cost(_memory.removeAt(0));
    }
  }

  static int _cost(_Entry entry) =>
      entry.body.length + _tagFor(entry.level).length + 4;

  static String _tagFor(DiagnosticsLevel level) => switch (level) {
    DiagnosticsLevel.info => 'INFO',
    DiagnosticsLevel.warning => 'WARN',
    DiagnosticsLevel.error => 'ERROR',
  };

  Future<void> clear() async {
    _memory.clear();
    final file = _file;
    try {
      if (file != null && await file.exists()) await file.delete();
    } catch (_) {
      // Best effort.
    }
  }

  String _serialize() => _memory
      .map((entry) => '${_markerFor(entry.level)} ${entry.body}')
      .join('\n');

  static String _markerFor(DiagnosticsLevel level) => switch (level) {
    DiagnosticsLevel.info => 'I',
    DiagnosticsLevel.warning => 'W',
    DiagnosticsLevel.error => 'E',
  };

  static _Entry? _parse(String line) {
    if (line.length < 3) return null;
    final level = _markers[line[0]];
    if (level == null || line[1] != ' ') return null;
    return _Entry(level, line.substring(2));
  }

  static String _format(List<_Entry> entries, {required bool includeInfo}) {
    return entries
        .where((entry) => includeInfo || entry.level != DiagnosticsLevel.info)
        .map((entry) => '[${_tagFor(entry.level)}] ${entry.body}')
        .join('\n');
  }
}

class _Entry {
  _Entry(this.level, this.body);

  final DiagnosticsLevel level;

  /// Already stamped: `[HH:MM:SS] message`.
  final String body;
}

/// Installs handlers that funnel Dart-side failures into [DiagnosticsLog].
///
/// Existing behaviour is preserved: errors are still reported to the console
/// (`presentError`) rather than being swallowed, so this only adds a trail.
void installDiagnosticsHandlers() {
  final log = DiagnosticsLog.instance;

  final previousFlutterOnError = FlutterError.onError;
  FlutterError.onError = (details) {
    // The full framework stack runs hundreds of frames and pushes the actual
    // cause off the screen; the first few name the widget and the site.
    final stack = details.stack;
    final head = stack == null
        ? ''
        : '\n${_head(stack.toString(), DiagnosticsLog.maxStackLines)}';
    log.log(
      'flutter error: ${details.exceptionAsString()}$head',
      level: DiagnosticsLevel.error,
    );
    if (previousFlutterOnError != null) {
      previousFlutterOnError(details);
    } else {
      FlutterError.presentError(details);
    }
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    log.log(
      'uncaught: $error\n${_head(stack.toString(), DiagnosticsLog.maxStackLines)}',
      level: DiagnosticsLevel.error,
    );
    // Returning false keeps Flutter's default handling for this zone.
    return false;
  };
}

String _head(String text, int lines) {
  final split = text.split('\n');
  if (split.length <= lines) return text;
  return '${split.take(lines).join('\n')}\n…';
}
