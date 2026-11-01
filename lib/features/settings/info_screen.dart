import 'package:material_ui/material_ui.dart';

import '../../core/theme/ljod_theme.dart';
import '../../core/widgets/vz_components.dart';

/// Info page showing supported formats, folder rules, and privacy notes.
///
/// Reached from Settings → About.
class InfoScreen extends StatelessWidget {
  const InfoScreen({super.key});

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
          child: CustomScrollView(
            slivers: [
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 14, 20, 26),
                sliver: SliverList.list(
                  children: [
                    const SectionHeader(
                      title: 'Supported formats',
                      eyebrow: 'Formats',
                      padding: EdgeInsets.zero,
                    ),
                    const SizedBox(height: 6),
                    const _InfoRow(
                      icon: Icons.music_note_rounded,
                      text: 'MP3 (ID3), FLAC (Vorbis), AAC/MP4 (iTunes), OGG (Vorbis), WAV',
                    ),
                    const _InfoRow(
                      icon: Icons.image_rounded,
                      text: 'Embedded artwork is cached as JPEG',
                    ),
                    const SizedBox(height: 20),
                    const SectionHeader(
                      title: 'Folder rules',
                      eyebrow: 'Scanning',
                      padding: EdgeInsets.zero,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Select which folders are indexed. Rules apply to the '
                      'next library scan and never change your files.',
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 12),
                    const _InfoRow(
                      icon: Icons.check_circle_rounded,
                      text: 'Only: index selected folders only',
                    ),
                    const _InfoRow(
                      icon: Icons.block_rounded,
                      text: 'Exclude: ignore selected folders',
                    ),
                    const SizedBox(height: 20),
                    const SectionHeader(
                      title: 'Privacy',
                      eyebrow: 'Your data',
                      padding: EdgeInsets.zero,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Ljod is fully offline. It never uploads audio, creates '
                      'accounts, uses ads or collects analytics. Online lyrics '
                      'lookup is off by default; if you switch it on, only the '
                      'track title, artist name, album (if set) and duration are '
                      'sent to LRCLIB. Each track is asked about once; the answer '
                      'is cached locally. No audio files leave this device.',
                      style: theme.textTheme.bodySmall,
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Toggle: Settings → Lyrics & order → Online lyrics lookup.',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: LjodTheme.amber,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(20, 18, 20, 32),
                  child: Panel(
                    borderColor: LjodTheme.amber,
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 14,
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.shield_rounded,
                            size: 24,
                            color: LjodTheme.stable,
                          ),
                          SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Built with Flutter. All data stays on this device.',
                              style: TextStyle(
                                fontSize: 11,
                                color: LjodTheme.textMuted,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: LjodTheme.amber),
          const SizedBox(width: 10),
          Expanded(child: Text(text)),
        ],
      ),
    );
  }
}
