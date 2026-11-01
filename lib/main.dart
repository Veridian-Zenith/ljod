import 'package:audio_service/audio_service.dart';
import 'package:audio_session/audio_session.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'core/diagnostics/diagnostics_log.dart';
import 'core/theme/ljod_theme.dart';
import 'features/setup/setup_screen.dart';
import 'features/setup/setup_state.dart';
import 'features/shell/app_shell.dart';
import 'services/audio/audio_providers.dart';
import 'services/settings/settings_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Decoded covers are the largest single memory consumer here, and an
  // unbounded image cache on a phone with big embedded art is a plausible
  // source of "the UI vanished" process deaths. Keep it small and predictable.
  PaintingBinding.instance.imageCache
    ..maximumSize = 120
    ..maximumSizeBytes = 96 << 20;

  // Everything that goes wrong is written to a short local trail before the
  // process can die, so a crash is readable on the next launch even without
  // developer options.
  await DiagnosticsLog.instance.initialize();
  installDiagnosticsHandlers();

  final preferences = await SharedPreferences.getInstance();
  // Configure Android/iOS media session so notifications, media buttons
  // and the system now-playing panel work properly.
  //
  // The session is deliberately not activated here: `just_audio` activates it
  // (and takes audio focus) when playback starts, so doing it at launch would
  // interrupt whatever the user is already listening to.
  try {
    final session = await AudioSession.instance;
    await session.configure(AudioSessionConfiguration.music());
  } catch (e) {
    debugPrint('AudioSession unavailable: $e');
  }

  final audioHandler = await _initializeAudio();

  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
      systemNavigationBarColor: LjodTheme.bgBlack,
      systemNavigationBarIconBrightness: Brightness.light,
      systemNavigationBarDividerColor: Colors.transparent,
    ),
  );

  runApp(
    ProviderScope(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(preferences),
        audioHandlerProvider.overrideWithValue(audioHandler),
      ],
      child: LjodApp(showSetup: !await hasCompletedSetup(preferences)),
    ),
  );
}

/// Creates the media-session handler.
///
/// `AudioService.init` needs the native plugin; when it is unavailable (desktop
/// dev runs, unit tests) we still get a usable in-process handler instead of a
/// hard crash.
Future<LjodAudioHandler> _initializeAudio() async {
  try {
    return await AudioService.init<LjodAudioHandler>(
      builder: LjodAudioHandler.new,
      config: const AudioServiceConfig(
        androidNotificationChannelId: 'dev.vz.ljod.playback',
        androidNotificationChannelName: 'Ljod playback',
        androidNotificationChannelDescription:
            'Controls for the currently playing track.',
        androidNotificationIcon: 'drawable/ic_stat_music_note',
        // Keep the service foreground while paused so media-button resumes do
        // not hit Android's background-start restrictions. The notification is
        // therefore dismissible rather than "ongoing".
        androidNotificationOngoing: false,
        androidStopForegroundOnPause: false,
        androidNotificationClickStartsActivity: true,
        preloadArtwork: true,
        artDownscaleWidth: 512,
        artDownscaleHeight: 512,
      ),
    );
  } catch (error, stackTrace) {
    debugPrint('AudioService unavailable, using in-process playback: $error');
    debugPrintStack(stackTrace: stackTrace);
    return LjodAudioHandler();
  }
}

class LjodApp extends ConsumerStatefulWidget {
  const LjodApp({super.key, this.showSetup = false});

  /// When true, the first-run setup flow is shown before the main shell.
  final bool showSetup;

  @override
  ConsumerState<LjodApp> createState() => _LjodAppState();
}

class _LjodAppState extends ConsumerState<LjodApp> {
  late bool _showSetup = widget.showSetup;

  Future<void> _finishSetup() async {
    final preferences = ref.read(sharedPreferencesProvider);
    await markSetupComplete(preferences);
    if (!mounted) return;
    setState(() => _showSetup = false);
  }

  @override
  Widget build(BuildContext context) {
    final settings = ref.watch(settingsProvider);
    // Surfaces are true black on purpose; only motion is user-tunable.
    final theme = LjodTheme.build(expressiveMotion: settings.expressiveMotion);

    return MaterialApp(
      title: 'Ljod',
      debugShowCheckedModeBanner: false,
      theme: theme,
      darkTheme: theme,
      themeMode: ThemeMode.dark,
      home: _showSetup
          ? SetupScreen(onFinished: _finishSetup)
          : const LjodShell(),
    );
  }
}
