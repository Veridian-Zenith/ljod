import 'dart:ui' as ui;

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/models/folder_scope.dart';
import '../../core/theme/ljod_theme.dart';
import '../../core/widgets/ljod_logo.dart';
import '../../core/widgets/vz_components.dart';
import '../../services/library/library_providers.dart';
import '../../services/settings/settings_provider.dart';
import '../settings/folder_rules_screen.dart';

/// First-run setup: privacy, access, folder rules and a real library scan.
///
/// There is intentionally no artificial loading sequence. Every progress value
/// shown here comes from the active scan.
class SetupScreen extends ConsumerStatefulWidget {
  const SetupScreen({
    super.key,
    required this.onFinished,
    this.replaying = false,
  });

  final VoidCallback onFinished;

  /// Replays setup from Settings. The wording stays the same, but the flow is
  /// shown as a route instead of the app's home.
  final bool replaying;

  @override
  ConsumerState<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends ConsumerState<SetupScreen> {
  static const _stepCount = 4;

  int _step = 0;
  bool? _accessGranted;
  bool _scanStarted = false;
  bool _requesting = false;

  @override
  void initState() {
    super.initState();
    _readExistingPermission();
  }

  Future<void> _readExistingPermission() async {
    final service = ref.read(libraryServiceProvider);
    if (!service.isAndroid) {
      if (mounted) setState(() => _accessGranted = true);
      return;
    }
    final granted = await service.hasPermission();
    if (mounted) setState(() => _accessGranted = granted);
  }

  @override
  Widget build(BuildContext context) {
    final library = ref.watch(libraryProvider).value ?? const LibraryState();

    if (_step == _stepCount - 1 && !_scanStarted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _step == _stepCount - 1) _startScan();
      });
    }

    return Scaffold(
      // Replayed as a pushed route, so it must paint its own surface.
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: LjodBackground(
        child: SafeArea(
          child: Column(
            children: [
              _SetupTopBar(
                step: _step,
                steps: _stepCount,
                replaying: widget.replaying,
                onSkip: widget.onFinished,
              ),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 260),
                  switchInCurve: Curves.easeOutCubic,
                  switchOutCurve: Curves.easeInCubic,
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: SlideTransition(
                      position: Tween<Offset>(
                        begin: const Offset(0.04, 0),
                        end: Offset.zero,
                      ).animate(animation),
                      child: child,
                    ),
                  ),
                  child: SingleChildScrollView(
                    key: ValueKey(_step),
                    padding: const EdgeInsets.fromLTRB(24, 12, 24, 20),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 520),
                        child: switch (_step) {
                          0 => const _WelcomeStep(),
                          1 => _AccessStep(
                            accessGranted: _accessGranted,
                            requesting: _requesting,
                            onOpenSettings: () =>
                                ref.read(libraryServiceProvider).openSettings(),
                          ),
                          2 => const _FoldersStep(),
                          _ => _ScanStep(
                            state: library,
                            onRetry: _retryScan,
                            onRequestAccess: _requestScanAccess,
                          ),
                        },
                      ),
                    ),
                  ),
                ),
              ),
              _SetupActions(
                step: _step,
                steps: _stepCount,
                replaying: widget.replaying,
                requesting: _requesting,
                accessGranted: _accessGranted,
                onBack: () => setState(() => _step -= 1),
                onPrimary: _primaryAction,
                onSkipAccess: () => setState(() => _step = 2),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _primaryAction() async {
    switch (_step) {
      case 0:
        setState(() => _step = 1);
      case 1:
        if (_accessGranted == true) {
          setState(() => _step = 2);
          return;
        }
        await _requestAccess();
      case 2:
        setState(() => _step = 3);
      default:
        widget.onFinished();
    }
  }

  Future<void> _requestAccess() async {
    if (_requesting) return;
    setState(() => _requesting = true);
    final granted = await ref.read(libraryServiceProvider).requestPermission();
    if (!mounted) return;
    setState(() {
      _requesting = false;
      _accessGranted = granted;
    });
    if (granted) {
      // Access granted: let the person review folder rules next.
      setState(() => _step = 2);
    } else {
      _toast(
        'Access was not granted. You can allow it later in Android settings.',
      );
    }
  }

  void _startScan() {
    if (_scanStarted) return;
    _scanStarted = true;
    ref
        .read(libraryProvider.notifier)
        .rescan(requestPermission: _accessGranted == true);
  }

  Future<void> _requestScanAccess() async {
    final granted = await ref.read(libraryServiceProvider).requestPermission();
    if (!mounted) return;
    if (!granted) {
      _toast('Access was not granted. You can allow it in Android settings.');
      return;
    }
    setState(() => _accessGranted = true);
    _retryScan();
  }

  void _retryScan() {
    _scanStarted = false;
    _startScan();
  }

  void _toast(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _SetupTopBar extends StatelessWidget {
  const _SetupTopBar({
    required this.step,
    required this.steps,
    required this.replaying,
    required this.onSkip,
  });

  final int step;
  final int steps;
  final bool replaying;
  final VoidCallback onSkip;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 14, 4),
      child: Row(
        children: [
          const LjodLockup(markSize: 26, textSize: 24),
          const SizedBox(width: 14),
          for (var index = 0; index < steps; index++)
            AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              width: index == step ? 22 : 7,
              height: 7,
              margin: const EdgeInsets.only(right: 5),
              decoration: BoxDecoration(
                color: index <= step ? LjodTheme.amber : LjodTheme.borderStrong,
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          const Spacer(),
          TextButton(
            onPressed: onSkip,
            child: Text(replaying ? 'Close' : 'Skip setup'),
          ),
        ],
      ),
    );
  }
}

class _SetupActions extends StatelessWidget {
  const _SetupActions({
    required this.step,
    required this.steps,
    required this.replaying,
    required this.requesting,
    required this.accessGranted,
    required this.onBack,
    required this.onPrimary,
    required this.onSkipAccess,
  });

  final int step;
  final int steps;
  final bool replaying;
  final bool requesting;
  final bool? accessGranted;
  final VoidCallback onBack;
  final VoidCallback onPrimary;
  final VoidCallback onSkipAccess;

  @override
  Widget build(BuildContext context) {
    final isLast = step == steps - 1;
    final needsAccess = step == 1 && accessGranted != true;

    return SafeArea(
      top: false,
      minimum: const EdgeInsets.fromLTRB(24, 8, 24, 14),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              if (step > 0)
                TextButton.icon(
                  onPressed: onBack,
                  icon: const Icon(Icons.arrow_back_rounded, size: 18),
                  label: const Text('Back'),
                )
              else
                const SizedBox.shrink(),
              const Spacer(),
              FilledButton.icon(
                onPressed: requesting ? null : onPrimary,
                icon: requesting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Icon(
                        isLast
                            ? Icons.check_rounded
                            : needsAccess
                            ? Icons.lock_open_rounded
                            : Icons.arrow_forward_rounded,
                        size: 18,
                      ),
                label: Text(
                  isLast
                      ? (replaying ? 'Done' : 'Finish setup')
                      : needsAccess
                      ? 'Allow access'
                      : 'Continue',
                ),
              ),
            ],
          ),
          if (needsAccess)
            TextButton(
              onPressed: onSkipAccess,
              child: const Text('Continue without access'),
            ),
        ],
      ),
    );
  }
}

class _WelcomeStep extends StatelessWidget {
  const _WelcomeStep();

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 18),
        const _SetupEmblem(),
        const SizedBox(height: 26),
        Text(
          'Your music.\nYour device.',
          style: theme.textTheme.displaySmall?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -1.4,
            height: 1.02,
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Ljod is a local-first player. It reads audio that is already on '
          'this device and never uploads your library.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: LjodTheme.textSoft,
          ),
        ),
        const SizedBox(height: 26),
        const _FeatureRow(
          icon: Icons.offline_bolt_rounded,
          title: 'Works offline',
          message: 'Playback, artwork and lyrics stay on this device.',
        ),
        const _FeatureRow(
          icon: Icons.folder_rounded,
          title: 'You choose the folders',
          message: 'Scan everything, pick folders, or skip noisy ones.',
        ),
        const _FeatureRow(
          icon: Icons.lyrics_rounded,
          title: 'Lyrics when you want them',
          message:
              'Sidecar and embedded lyrics always work. Online lookup is off '
              'by default.',
        ),
        const SizedBox(height: 10),
        const _InfoNote(
          text:
              'When enabled: track title, artist, album (if set), and duration '
              'are sent to LRCLIB for lyrics lookup. No audio files are uploaded.',
        ),
        const SizedBox(height: 20),
        Panel(
          color: LjodTheme.panelBlack.withValues(alpha: 0.7),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.shield_outlined,
                size: 18,
                color: LjodTheme.stable,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'No account, no ads, no library upload. The only network '
                  'request is an optional lyrics lookup.',
                  style: theme.textTheme.bodySmall,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SetupEmblem extends StatelessWidget {
  const _SetupEmblem();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 150,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // One small, static blurred halo: the mark's own line art, so the
          // glow matches the logo rather than a generic rounded box.
          ImageFiltered(
            imageFilter: ui.ImageFilter.blur(sigmaX: 18, sigmaY: 18),
            child: const LjodMark(size: 116, color: Color(0x59FFB347)),
          ),
          const LjodMark(size: 112, semanticLabel: 'Ljod'),
        ],
      ),
    );
  }
}

class _FeatureRow extends StatelessWidget {
  const _FeatureRow({
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: LjodTheme.amber.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(13),
              border: Border.all(
                color: LjodTheme.amber.withValues(alpha: 0.22),
              ),
            ),
            child: Icon(icon, size: 18, color: LjodTheme.amber),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(message, style: theme.textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AccessStep extends StatelessWidget {
  const _AccessStep({
    required this.accessGranted,
    required this.requesting,
    required this.onOpenSettings,
  });

  final bool? accessGranted;
  final bool requesting;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final granted = accessGranted == true;
    final denied = accessGranted == false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 18),
        _StepIcon(
          icon: granted ? Icons.lock_open_rounded : Icons.lock_outline_rounded,
          active: granted,
        ),
        const SizedBox(height: 24),
        Text(
          granted ? 'Music access granted' : 'Allow music access',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.8,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          granted
              ? 'Ljod can now read audio from this device. It only reads '
                    'files; nothing is moved or changed.'
              : 'Ljod needs permission to read audio files so it can build '
                    'your library. Android will show a system prompt.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: LjodTheme.textSoft,
          ),
        ),
        const SizedBox(height: 22),
        const _FeatureRow(
          icon: Icons.visibility_off_rounded,
          title: 'Read-only access',
          message: 'Ljod never edits, deletes or uploads your audio files.',
        ),
        const _FeatureRow(
          icon: Icons.phonelink_lock_rounded,
          title: 'Stays on this device',
          message:
              'Indexing happens locally. There is no account or cloud library.',
        ),
        if (denied) ...[
          const SizedBox(height: 6),
          Panel(
            borderColor: LjodTheme.error.withValues(alpha: 0.4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Access was not granted. You can continue and scan later, '
                  'or allow it from Android settings.',
                  style: theme.textTheme.bodySmall,
                ),
                const SizedBox(height: 10),
                TextButton.icon(
                  onPressed: onOpenSettings,
                  icon: const Icon(Icons.settings_rounded, size: 16),
                  label: const Text('Open app settings'),
                ),
              ],
            ),
          ),
        ],
        if (requesting) ...[
          const SizedBox(height: 16),
          const LinearProgressIndicator(minHeight: 2),
        ],
      ],
    );
  }
}

class _FoldersStep extends ConsumerWidget {
  const _FoldersStep();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final settings = ref.watch(settingsProvider);
    final folders = ref.watch(libraryFoldersProvider);

    final count = settings.folderFilters.length;
    final summary = switch (settings.folderFilterMode) {
      FolderFilterMode.all => 'All folders',
      FolderFilterMode.only =>
        count == 0 ? 'No folders selected' : 'Only $count selected',
      FolderFilterMode.exclude =>
        count == 0 ? 'Nothing excluded' : '$count excluded',
    };

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 18),
        const _StepIcon(icon: Icons.folder_copy_rounded, active: true),
        const SizedBox(height: 24),
        Text(
          'Choose what to scan',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.8,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          'By default every folder with audio is indexed. You can scan only '
          'selected folders, or exclude folders you do not want in Ljod.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: LjodTheme.textSoft,
          ),
        ),
        const SizedBox(height: 22),
        Panel(
          borderColor: LjodTheme.amber.withValues(alpha: 0.26),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: LjodTheme.amber.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.folder_open_rounded,
                  color: LjodTheme.amber,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      summary,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      folders.maybeWhen(
                        data: (items) =>
                            '${items.length} folders currently contain audio',
                        orElse: () => 'Folder list loads after access',
                      ),
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          onPressed: () async {
            await Navigator.of(context).push<bool>(
              MaterialPageRoute(
                builder: (_) => const FolderRulesScreen(rescanOnSave: false),
              ),
            );
          },
          icon: const Icon(Icons.tune_rounded, size: 18),
          label: const Text('Edit folder rules'),
        ),
        const SizedBox(height: 18),
        Text(
          'Folder rules apply to the scan that runs next. Content-only '
          'libraries (some Android 11+ devices) may not expose folder paths.',
          style: theme.textTheme.bodySmall?.copyWith(
            color: LjodTheme.textMuted,
          ),
        ),
      ],
    );
  }
}

class _ScanStep extends StatelessWidget {
  const _ScanStep({
    required this.state,
    required this.onRetry,
    required this.onRequestAccess,
  });

  final LibraryState state;
  final VoidCallback onRetry;
  final VoidCallback onRequestAccess;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final progress = state.scanProgress;
    final finished = state.lastScan != null && !state.isScanning;
    final albums = state.songs.map((song) => song.displayAlbum).toSet().length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 18),
        _StepIcon(
          icon: finished ? Icons.library_music_rounded : Icons.radar_rounded,
          active: true,
        ),
        const SizedBox(height: 24),
        Text(
          finished ? 'Library ready' : 'Building your library',
          style: theme.textTheme.headlineSmall?.copyWith(
            fontWeight: FontWeight.w800,
            letterSpacing: -0.8,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          finished
              ? '${state.songs.length} tracks from $albums albums are ready to play.'
              : 'Ljod is reading tags and artwork. This happens once and is '
                    'safe to leave running in the background.',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: LjodTheme.textSoft,
          ),
        ),
        const SizedBox(height: 24),
        Panel(
          borderColor: state.error != null
              ? LjodTheme.error.withValues(alpha: 0.4)
              : LjodTheme.amber.withValues(alpha: 0.24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    state.permissionDenied
                        ? Icons.lock_outline_rounded
                        : finished
                        ? Icons.check_circle_rounded
                        : Icons.graphic_eq_rounded,
                    size: 18,
                    color: state.permissionDenied
                        ? LjodTheme.error
                        : finished
                        ? LjodTheme.stable
                        : LjodTheme.amber,
                  ),
                  const SizedBox(width: 9),
                  Expanded(
                    child: Text(
                      state.permissionDenied
                          ? 'Music access is required'
                          : state.error ?? state.scanLabel,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              LinearProgressIndicator(
                value: state.isScanning ? progress : (finished ? 1 : 0),
                minHeight: 4,
              ),
              const SizedBox(height: 10),
              Text(
                state.isScanning
                    ? progress == null
                          ? 'Looking for audio files…'
                          : '${state.scanProcessed} of ${state.scanTotal} tracks'
                    : finished
                    ? 'Indexed locally. You can rescan any time from Settings.'
                    : 'Scan has not started yet.',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
        if (state.permissionDenied || state.error != null) ...[
          const SizedBox(height: 16),
          if (state.permissionDenied)
            FilledButton.icon(
              onPressed: onRequestAccess,
              icon: const Icon(Icons.lock_open_rounded, size: 18),
              label: const Text('Allow access'),
            )
          else
            OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Try again'),
            ),
        ],
      ],
    );
  }
}

class _StepIcon extends StatelessWidget {
  const _StepIcon({required this.icon, required this.active});

  final IconData icon;
  final bool active;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 64,
      height: 64,
      decoration: BoxDecoration(
        color: active
            ? LjodTheme.amber.withValues(alpha: 0.12)
            : LjodTheme.panelHigh,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: active
              ? LjodTheme.amber.withValues(alpha: 0.40)
              : LjodTheme.borderLight,
        ),
      ),
      child: Icon(
        icon,
        size: 28,
        color: active ? LjodTheme.amber : LjodTheme.textMuted,
      ),
    );
  }
}

class _InfoNote extends StatelessWidget {
  const _InfoNote({required this.text});
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: LjodTheme.panelBlack.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: LjodTheme.amber.withValues(alpha: 0.18)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.info_outline_rounded,
            size: 14,
            color: LjodTheme.amber,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: LjodTheme.textMuted),
            ),
          ),
        ],
      ),
    );
  }
}
