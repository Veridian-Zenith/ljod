import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

import '../../core/diagnostics/diagnostics_log.dart';

/// Asks for the Android 13+ notification permission.
///
/// The manifest declares `POST_NOTIFICATIONS`, but from API 33 it is a runtime
/// permission: without it the playback notification is silently dropped, so the
/// lock screen and shade show nothing and media controls look broken. The
/// foreground service still runs, which makes the failure easy to miss.
///
/// Returns whether the notification may be posted. Repeated calls are cheap:
/// a granted permission short-circuits before any dialog.
Future<bool> ensureNotificationPermission() async {
  if (kIsWeb || !Platform.isAndroid) return true;

  try {
    final current = await Permission.notification.status;
    if (current.isGranted || current.isLimited) return true;

    // Android stops showing the dialog after two denials; asking again does
    // nothing, so report the state instead of pretending a prompt appeared.
    if (current.isPermanentlyDenied) {
      DiagnosticsLog.instance.log(
        'notification permission blocked by the user; playback notification '
        'cannot be shown',
        level: DiagnosticsLevel.warning,
      );
      return false;
    }

    final result = await Permission.notification.request();
    if (result.isGranted || result.isLimited) return true;

    DiagnosticsLog.instance.log(
      'notification permission denied ($result); playback notification cannot '
      'be shown',
      level: DiagnosticsLevel.warning,
    );
    return false;
  } catch (error) {
    DiagnosticsLog.instance.log(
      'notification permission request failed: $error',
      level: DiagnosticsLevel.warning,
    );
    return false;
  }
}
