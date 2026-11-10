import 'package:material_ui/material_ui.dart';

import '../../core/theme/ljod_theme.dart';
import '../../core/widgets/vz_components.dart';

/// Info page showing supported formats, artwork and lyrics handling, folder
/// rules and privacy notes.
///
/// Reached from Settings → About. Everything is short, labelled and grouped:
/// this is the screen someone opens when they want one answer, not a manual.
class InfoScreen extends StatelessWidget {
  const InfoScreen({super.key});

  static const List<String> _formats = [
    'MP3',
    'FLAC',
    'AAC / M4A',
    'MP4',
    'OGG',
    'OPUS',
    'WAV',
    'AIFF',
    'WMA',
    'APE',
    'MPC',
    'WavPack',
  ];

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      backgroundColor: theme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: Text(
          'INFO',
          style: LjodTheme.display(theme.textTheme, size: 22),
        ),
        leading: IconButton(
          onPressed: () => Navigator.of(context).pop(),
          icon: const Icon(Icons.arrow_back_rounded),
        ),
      ),
      body: LjodBackground(
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 32),
            children: [
              const SectionHeader(
                title: 'Supported formats',
                eyebrow: 'Formats',
                subtitle:
                    'Indexed by extension and read through the platform '
                    'decoder',
                padding: EdgeInsets.zero,
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [for (final format in _formats) _Pill(format)],
              ),
              const SizedBox(height: 24),
              const SectionHeader(
                title: 'Artwork & lyrics',
                eyebrow: 'Media',
                padding: EdgeInsets.zero,
              ),
              const SizedBox(height: 8),
              const Panel(
                child: Column(
                  children: [
                    _InfoRow(
                      icon: Icons.image_rounded,
                      title: 'Cover art',
                      text:
                          'Embedded pictures are copied into a local cache, one '
                          'file per unique picture, at most 4 MiB each. A folder '
                          'image beside the track (cover, folder, front) is used '
                          'when the tags have none. Only the full-screen player '
                          'decodes them, so long lists stay smooth.',
                    ),
                    SizedBox(height: 14),
                    _InfoRow(
                      icon: Icons.notes_rounded,
                      title: 'Lyrics',
                      text:
                          'A sidecar .lrc or .txt beside the track wins, then '
                          'lyrics embedded in the file. The online lookup is '
                          'only used when you enable it.',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const SectionHeader(
                title: 'Folder rules',
                eyebrow: 'Scanning',
                padding: EdgeInsets.zero,
              ),
              const SizedBox(height: 8),
              Panel(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Choose which folders are indexed. Rules apply to the '
                      'next library scan and never change your files.',
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 12),
                    const _InfoRow(
                      icon: Icons.check_circle_rounded,
                      title: 'Only',
                      text: 'Index the selected folders and nothing else.',
                    ),
                    const SizedBox(height: 10),
                    const _InfoRow(
                      icon: Icons.block_rounded,
                      title: 'Exclude',
                      text: 'Index everything except the selected folders.',
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              const SectionHeader(
                title: 'Privacy',
                eyebrow: 'Your data',
                padding: EdgeInsets.zero,
              ),
              const SizedBox(height: 8),
              Panel(
                borderColor: LjodTheme.amber,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.shield_rounded,
                          size: 20,
                          color: LjodTheme.stable,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'LOCAL ONLY',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: LjodTheme.stable,
                            letterSpacing: 1.6,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Ljod never uploads audio, creates accounts, shows ads or '
                      'collects analytics.',
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 10),
                    Text(
                      'Online lyrics lookup is off by default. When you switch '
                      'it on, only the track title, artist, album (if set) and '
                      'duration are sent to LRCLIB — one request per track, and '
                      'the answer is cached on this device.',
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        const Icon(
                          Icons.toggle_on_rounded,
                          size: 18,
                          color: LjodTheme.amber,
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'Settings → Lyrics & order → Online lyrics lookup',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: LjodTheme.amber,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Panel(
                child: Row(
                  children: [
                    const Icon(
                      Icons.flutter_dash_rounded,
                      size: 22,
                      color: LjodTheme.textMuted,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        'Built with Flutter. All data stays on this device.',
                        style: theme.textTheme.bodySmall,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  const _Pill(this.label);

  final String label;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
      decoration: BoxDecoration(
        color: LjodTheme.panelBlack,
        borderRadius: BorderRadius.circular(LjodTheme.radiusXs),
        border: Border.all(color: LjodTheme.borderLight),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontFamily: LjodTheme.monoFamily,
          fontSize: 11,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.3,
          color: LjodTheme.textSoft,
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.title, required this.text});

  final IconData icon;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 18, color: LjodTheme.amber),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                title,
                style: theme.textTheme.labelMedium?.copyWith(
                  color: LjodTheme.textStrong,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 2),
              Text(text, style: theme.textTheme.bodySmall),
            ],
          ),
        ),
      ],
    );
  }
}
