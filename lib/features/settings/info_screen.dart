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
                    'What your device decodes, what Ljod decodes itself, and '
                    'what it can only list',
                padding: EdgeInsets.zero,
              ),
              const SizedBox(height: 10),
              const Panel(
                child: Column(
                  children: [
                    _FormatGroup(
                      icon: Icons.memory_rounded,
                      title: 'Your device — hardware or system codec',
                      text:
                          'Android decodes these, usually on the audio DSP, so '
                          'they cost the least battery. Which exact formats a '
                          'phone exposes is up to its codec set.',
                      formats: [
                        'MP3',
                        'AAC',
                        'M4A / MP4',
                        'FLAC',
                        'OGG VORBIS',
                        'OPUS',
                      ],
                    ),
                    SizedBox(height: 16),
                    _FormatGroup(
                      icon: Icons.developer_board_rounded,
                      title: 'Ljod — bundled software decoders',
                      text:
                          'Shipped with the player and used when the device has '
                          'no matching codec or refuses the file layout. Works '
                          'on any phone, at the cost of CPU.',
                      formats: ['WAV', 'FLAC', 'ALAC', 'OPUS', 'VORBIS'],
                    ),
                    SizedBox(height: 16),
                    _FormatGroup(
                      icon: Icons.block_rounded,
                      title: 'Indexed, but no decoder',
                      text:
                          'Android can list these files, so they may be indexed, '
                          'but neither the device nor Ljod can decode them. '
                          'Playing one fails — convert it to FLAC or MP3 to hear '
                          'it here.',
                      formats: ['AIFF', 'WMA', 'APE', 'MPC', 'WAVPACK'],
                    ),
                    SizedBox(height: 16),
                    _InfoRow(
                      icon: Icons.text_snippet_rounded,
                      title: 'Tags and metadata',
                      text:
                          'ID3v2 in MP3, Vorbis comments in FLAC, OGG and Opus, '
                          'and MP4 atoms in M4A are read locally, so titles, '
                          'artists, albums and track numbers come from the file '
                          'itself.',
                    ),
                  ],
                ),
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
                          'Covers are looked up per album by artist and album '
                          'name, remembered as a link and painted at the size of '
                          'the tile. Nothing is extracted to disk, and an album '
                          'the catalogues do not know shows initials.',
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
                    const SizedBox(height: 10),
                    Text(
                      'Album artwork is looked up by artist and album name '
                      '(Deezer, then Apple’s iTunes catalogue) and the link is '
                      'stored on this device.',
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
                        'Built with Flutter. Your library, audio and settings '
                        'stay on this device.',
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

class _FormatGroup extends StatelessWidget {
  const _FormatGroup({
    required this.icon,
    required this.title,
    required this.text,
    required this.formats,
  });

  final IconData icon;
  final String title;
  final String text;
  final List<String> formats;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _InfoRow(icon: icon, title: title, text: text),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.only(left: 28),
          child: Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [for (final format in formats) _Pill(format)],
          ),
        ),
      ],
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
