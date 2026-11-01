import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

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
  static const String fileName = 'diagnostics.log';

  /// File the Android side writes an uncaught exception to before the process
  /// dies. Consumed once and folded into the log on the next launch.
  static const String nativeCrashFileName = 'ljod-crash.log';

  final List<String> _memory = [];
  File? _file;
  bool _ready = false;

  /// Recent entries in memory, oldest first.
  List<String> get entries => List.unmodifiable(_memory);

  Future<void> _ensureReady() async {
    if (_ready) return;
    try {
      final support = await getApplicationSupportDirectory();
      _file = File(p.join(support.path, fileName));
      if (await _file!.exists()) {
        final existing = await _file!.readAsString();
        _memory
          ..clear()
          ..addAll(
            existing
                .split('\n')
                .where((line) => line.trim().isNotEmpty)
                .toList(growable: true),
          );
      }
    } catch (_) {
      _file = null;
    }
    _ready = true;
  }

  /// Appends [message] with a timestamp. Never throws.
  Future<void> record(String message) async {
    final stamp = DateTime.now().toIso8601String().substring(11, 19);
    final entry = '[$stamp] $message';
    _memory.add(entry);
    await _trim();
    final file = _file;
    if (file == null) return;
    try {
      await file.writeAsString('${_memory.join('\n')}\n', flush: true);
    } catch (_) {
      // Diagnostics must never break the app.
    }
  }

  /// Fire-and-forget variant for hot paths.
  void log(String message) {
    unawaited(record(message));
  }

  /// Loads the log and folds in any native crash the Android layer captured.
  Future<void> initialize() async {
    await _ensureReady();
    await _ingestNativeCrash();
    await record('session start');
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
    var total = _memory.fold<int>(0, (sum, line) => sum + line.length + 1);
    while (total > maxBytes && _memory.length > 1) {
      final removed = _memory.removeAt(0);
      total -= removed.length + 1;
    }
  }

  /// The full log as text, newest entry first.
  Future<String> read() async {
    await _ensureReady();
    return _memory.reversed.join('\n');
  }

  Future<void> clear() async {
    _memory.clear();
    final file = _file;
    try {
      if (file != null && await file.exists()) await file.delete();
    } catch (_) {
      // Best effort.
    }
  }
}

/// Installs handlers that funnel Dart-side failures into [DiagnosticsLog].
///
/// Existing behaviour is preserved: errors are still reported to the console
/// (`presentError`) rather than being swallowed, so this only adds a trail.
void installDiagnosticsHandlers() {
  final log = DiagnosticsLog.instance;

  final previousFlutterOnError = FlutterError.onError;
  FlutterError.onError = (details) {
    log.log(
      'flutter error: ${details.exceptionAsString()}'
      '${details.stack == null ? '' : '\n${details.stack}'}',
    );
    if (previousFlutterOnError != null) {
      previousFlutterOnError(details);
    } else {
      FlutterError.presentError(details);
    }
  };

  PlatformDispatcher.instance.onError = (error, stack) {
    log.log('uncaught: $error\n$stack');
    // Returning false keeps Flutter's default handling for this zone.
    return false;
  };
}
