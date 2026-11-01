import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/diagnostics/diagnostics_log.dart';
import '../../core/theme/ljod_theme.dart';
import '../../core/widgets/vz_components.dart';

/// Shows the on-device diagnostics trail.
///
/// There is no analytics and no upload: this screen exists so a crash can be
/// understood on a device where developer options (and therefore `adb`) are
/// unavailable.
class DiagnosticsScreen extends ConsumerStatefulWidget {
  const DiagnosticsScreen({super.key});

  @override
  ConsumerState<DiagnosticsScreen> createState() => _DiagnosticsScreenState();
}

class _DiagnosticsScreenState extends ConsumerState<DiagnosticsScreen> {
  String? _log;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final log = await DiagnosticsLog.instance.read();
    if (!mounted) return;
    setState(() {
      _log = log;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final log = _log;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          'DIAGNOSTICS',
          style: LjodTheme.display(theme.textTheme, size: 22),
        ),
        actions: [
          IconButton(
            tooltip: 'Copy log',
            onPressed: log == null || log.isEmpty
                ? null
                : () async {
                    await Clipboard.setData(ClipboardData(text: log));
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Diagnostics copied.')),
                    );
                  },
            icon: const Icon(Icons.copy_rounded),
          ),
          IconButton(
            tooltip: 'Clear log',
            onPressed: log == null || log.isEmpty
                ? null
                : () async {
                    await DiagnosticsLog.instance.clear();
                    await _load();
                  },
            icon: const Icon(Icons.delete_outline_rounded),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
          children: [
            Text(
              'Ljod keeps a short, local trail of errors and playback events so '
              'a crash can be read on the next launch. It never leaves this '
              'device.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: LjodTheme.textSoft,
              ),
            ),
            const SizedBox(height: 16),
            if (_loading)
              const Padding(
                padding: EdgeInsets.only(top: 24),
                child: Center(child: CircularProgressIndicator(strokeWidth: 2)),
              )
            else if (log == null || log.isEmpty)
              Panel(
                child: Text(
                  'Nothing logged yet. That is the good outcome.',
                  style: theme.textTheme.bodyMedium,
                ),
              )
            else
              Panel(
                child: SelectableText(
                  log,
                  style: theme.textTheme.bodySmall?.copyWith(
                    height: 1.6,
                    color: LjodTheme.textSoft,
                    fontFamily: LjodTheme.monoFamily,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
