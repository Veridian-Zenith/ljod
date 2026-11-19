import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/app_info.dart';
import '../../core/theme/ljod_theme.dart';
import '../../core/utils/formatters.dart';
import '../../core/widgets/vz_components.dart';
import '../../services/library/online_artwork.dart';
import '../../services/lyrics/lyrics_service.dart';
import '../../services/library/library_providers.dart';
import '../../services/settings/settings_provider.dart';
import '../../services/stats/stats_provider.dart';
import '../setup/setup_screen.dart';
import '../stats/stats_screen.dart';
import 'diagnostics_screen.dart';
import 'folder_rules_screen.dart';
import 'info_screen.dart';
import 'licenses_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(settingsProvider);
    final settingsNotifier = ref.read(settingsProvider.notifier);
    final library = ref.watch(libraryProvider).value ?? const LibraryState();
    final stats = ref.watch(statsProvider);
    final theme = Theme.of(context);

    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 210),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SETTINGS',
                      style: LjodTheme.display(theme.textTheme, size: 30),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Tune the forge to your taste.',
                      style: theme.textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              if (library.isScanning)
                const Padding(
                  padding: EdgeInsets.only(top: 8),
                  child: SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              else
                const LjodBadge(label: 'Local only', isActive: true),
            ],
          ),
          const SizedBox(height: 22),
          const _SectionLabel('Appearance'),
          _Card(
            children: [
              _SettingRow(
                icon: Icons.animation_rounded,
                title: 'Expressive motion',
                subtitle: 'Morphing shapes, springs and page fades',
                trailing: Switch(
                  value: settings.expressiveMotion,
                  onChanged: settingsNotifier.setExpressiveMotion,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const _SectionLabel('Scan'),
          _Card(
            children: [
              _SettingRow(
                icon: Icons.library_music_rounded,
                title: 'Indexed tracks',
                subtitle:
                    '${library.songs.length} tracks · ${library.favorites.length} pinned',
                trailing: LjodBadge(
                  label: library.permissionDenied ? 'No access' : 'Ready',
                  isActive: !library.permissionDenied,
                  color: library.permissionDenied ? LjodTheme.error : null,
                ),
              ),
              const _RowDivider(),
              _SettingRow(
                icon: Icons.history_rounded,
                title: 'Listening',
                subtitle: stats.totalPlayCount == 0
                    ? 'Play counts appear after your first track'
                    : '${formatCount(stats.totalPlayCount)} plays logged · '
                          '${stats.topArtists.isEmpty ? 'no artists yet' : 'led by ${stats.topArtists.first.name}'}',
                trailing: stats.mostPlayedSong?.lastPlayed == null
                    ? null
                    : Text(
                        formatRelativeDate(stats.mostPlayedSong!.lastPlayed),
                        style: const TextStyle(
                          fontSize: 10,
                          color: LjodTheme.textMuted,
                        ),
                      ),
                onTap: () => Navigator.of(context).push(StatsScreen.route()),
              ),
              const _RowDivider(),
              _SettingRow(
                icon: Icons.radar_rounded,
                title: 'Rescan device',
                subtitle: library.isScanning
                    ? 'Reading tags…'
                    : 'Re-index every supported audio file in one pass',
                enabled: !library.isScanning,
                onTap: () async {
                  await ref.read(libraryProvider.notifier).rescan();
                  if (!context.mounted) return;
                  final state = ref.read(libraryProvider).value;
                  _toast(
                    context,
                    state?.permissionDenied == true
                        ? 'Music access is still required.'
                        : state?.error != null
                        ? 'Scan failed. Diagnostics has the details.'
                        : '${state?.songs.length ?? 0} tracks indexed.',
                  );
                },
              ),
              const _RowDivider(),
              // Only while a scan is running: `scanPhase` stays `done` after
              // it finishes, which left a row titled "Scanning" on Settings
              // forever, showing "Library up to date".
              if (library.isScanning) ...[
                _SettingRow(
                  icon:
                      library.scanPhase == ScanPhase.reading ||
                          library.scanPhase == ScanPhase.saving
                      ? Icons.sync_rounded
                      : Icons.radar_rounded,
                  title: 'Scanning',
                  subtitle: library.scanLabel,
                  trailing: library.scanProgress != null
                      ? Text('${(library.scanProgress! * 100).round()}%')
                      : const SizedBox.shrink(),
                ),
                const _RowDivider(),
              ],
            ],
          ),
          const SizedBox(height: 18),
          // Each cache has its own re-run, so a fault in one never forces a
          // full library rescan to fix it.
          const _SectionLabel('Caches'),
          _Card(
            children: [
              _SettingRow(
                icon: Icons.image_rounded,
                title: 'Artwork lookups',
                subtitle: ref
                    .watch(artworkLookupCountProvider)
                    .when(
                      data: (count) =>
                          '$count ${count == 1 ? 'album' : 'albums'} remembered · '
                          'tap to look up covers again',
                      error: (_, _) => 'Tap to look up covers again',
                      loading: () => 'Tap to look up covers again',
                    ),
                onTap: () => _refreshArtwork(context, ref),
              ),
              const _RowDivider(),
              _SettingRow(
                icon: Icons.lyrics_rounded,
                title: 'Cached lyrics',
                subtitle: ref
                    .watch(lyricsCacheBytesProvider)
                    .when(
                      data: (bytes) =>
                          '${formatBytes(bytes)} used · tap to look up lyrics again',
                      error: (_, _) => 'Size unavailable on this platform',
                      loading: () => 'Measuring…',
                    ),
                onTap: () => _refreshLyrics(context, ref),
              ),
              const _RowDivider(),
              _SettingRow(
                icon: Icons.cleaning_services_rounded,
                title: 'Clear library cache',
                subtitle: 'Forget indexed tracks, favourites and play counts',
                destructive: true,
                onTap: () => _confirmClear(context, ref),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const _SectionLabel('Scan rules'),
          _Card(
            children: [
              _SettingRow(
                icon: Icons.folder_rounded,
                title: 'Folder rules',
                subtitle: settings.folderSummary,
                trailing: const Icon(
                  Icons.chevron_right_rounded,
                  color: LjodTheme.textMuted,
                ),
                onTap: () => Navigator.of(context).push<bool>(
                  MaterialPageRoute(builder: (_) => const FolderRulesScreen()),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const _SectionLabel('Lyrics & order'),
          _Card(
            children: [
              _SettingRow(
                icon: Icons.lyrics_rounded,
                title: 'Online lyrics lookup',
                subtitle:
                    'Off by default. One request per track when no embedded or '
                    'sidecar lyrics exist, then cached until you refresh it',
                trailing: Switch(
                  value: settings.lyricsLookup,
                  onChanged: settingsNotifier.setLyricsLookup,
                ),
              ),
              const _RowDivider(),
              _SettingRow(
                icon: Icons.star_rounded,
                title: 'Pin favourites first',
                subtitle: 'Keep favourited tracks at the top of the library',
                trailing: Switch(
                  value: settings.sortFavoritesFirst,
                  onChanged: settingsNotifier.setSortFavoritesFirst,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          const _SectionLabel('About'),
          _Card(
            children: [
              _SettingRow(
                icon: Icons.info_rounded,
                title: 'Ljod',
                subtitle: 'Version ${LjodAppInfo.version} · Veridian Zenith',
                trailing: const LjodBadge(label: 'OSL-3.0'),
              ),
              const _RowDivider(),
              _SettingRow(
                icon: Icons.info_rounded,
                title: 'Info & formats',
                subtitle: 'Supported formats, privacy and folder rules',
                onTap: () => Navigator.of(
                  context,
                ).push(MaterialPageRoute(builder: (_) => const InfoScreen())),
              ),
              const _RowDivider(),
              _SettingRow(
                icon: Icons.rocket_launch_rounded,
                title: 'Replay setup tour',
                subtitle:
                    'Walk through access, folder rules and scanning again',
                onTap: () => Navigator.of(context).push<void>(
                  MaterialPageRoute(
                    builder: (routeContext) => SetupScreen(
                      replaying: true,
                      onFinished: () => Navigator.of(routeContext).pop(),
                    ),
                  ),
                ),
              ),
              const _RowDivider(),
              _SettingRow(
                icon: Icons.report_rounded,
                title: 'Diagnostics',
                subtitle: 'Local error and playback trail, kept on this device',
                trailing: const Icon(
                  Icons.chevron_right_rounded,
                  color: LjodTheme.textMuted,
                ),
                onTap: () => Navigator.of(context).push<void>(
                  MaterialPageRoute(builder: (_) => const DiagnosticsScreen()),
                ),
              ),
              const _RowDivider(),
              _SettingRow(
                icon: Icons.code_rounded,
                title: 'Open-source licences',
                subtitle: 'Every bundled package and its full licence text',
                trailing: const Icon(
                  Icons.chevron_right_rounded,
                  color: LjodTheme.textMuted,
                ),
                onTap: () => Navigator.of(context).push<void>(
                  MaterialPageRoute(builder: (_) => const LicensesScreen()),
                ),
              ),
            ],
          ),
          const SizedBox(height: 26),
          Text(
            'LJOD AUDIO FORGE\n'
            'Built by Veridian Zenith. Your audio never leaves this device.\n'
            'Covers and lyrics send names, never files.',
            textAlign: TextAlign.center,
            style: theme.textTheme.labelSmall?.copyWith(
              color: LjodTheme.textMuted,
              height: 1.7,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            '\u00a9 2026 Veridian Zenith',
            textAlign: TextAlign.center,
            style: theme.textTheme.labelSmall?.copyWith(
              color: LjodTheme.textMuted.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmClear(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Clear the library cache?'),
        content: const Text(
          'Indexed metadata, favourites and play counts will be forgotten. '
          'Your audio files stay untouched — rescan any time.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Clear cache'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(libraryProvider.notifier).clearCache();
    if (!context.mounted) return;
    _toast(context, 'Library cache cleared.');
  }

  Future<void> _refreshLyrics(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Refresh cached lyrics?'),
        content: const Text(
          'Cached lyric answers are deleted. Sidecar and embedded lyrics are read '
          'again, and the online lookup runs once more if it is enabled. Play '
          'counts and your library are untouched.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Refresh'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(lyricsServiceProvider).clearCache();
    ref.read(lyricsCacheRevisionProvider.notifier).bump();
    ref.invalidate(lyricsCacheBytesProvider);
    if (!context.mounted) return;
    _toast(context, 'Lyrics cache refreshed.');
  }

  Future<void> _refreshArtwork(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Refresh artwork lookups?'),
        content: const Text(
          'Remembered cover links are dropped and looked up again as tiles are '
          'shown. Cover files left by older versions are deleted. Your library '
          'and audio files are untouched.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Refresh'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await ref.read(libraryProvider.notifier).clearArtworkLookups();
    ref.invalidate(artworkLookupCountProvider);
    if (!context.mounted) return;
    _toast(context, 'Artwork lookups refreshed.');
  }

  void _toast(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }
}

class _SectionLabel extends StatelessWidget {
  const _SectionLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 6, bottom: 8),
      child: Text(
        text.toUpperCase(),
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
          color: LjodTheme.amber,
          letterSpacing: 2.2,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  const _Card({required this.children});

  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: LjodTheme.panelBlack.withValues(alpha: 0.9),
        borderRadius: BorderRadius.circular(LjodTheme.radiusMd),
        border: Border.all(color: LjodTheme.borderLight),
      ),
      child: Column(children: children),
    );
  }
}

class _RowDivider extends StatelessWidget {
  const _RowDivider();

  @override
  Widget build(BuildContext context) {
    return const Divider(height: 1, indent: 64, endIndent: 16);
  }
}

class _SettingRow extends StatelessWidget {
  const _SettingRow({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.trailing,
    this.onTap,
    this.enabled = true,
    this.destructive = false,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;
  final bool enabled;
  final bool destructive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final accent = destructive ? LjodTheme.error : LjodTheme.amber;
    final opacity = enabled ? 1.0 : 0.45;

    final content = Padding(
      padding: const EdgeInsets.fromLTRB(14, 13, 12, 13),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: accent.withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: accent.withValues(alpha: 0.24)),
            ),
            child: Icon(
              icon,
              size: 18,
              color: accent.withValues(alpha: opacity),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: destructive
                        ? LjodTheme.error
                        : LjodTheme.textStrong.withValues(alpha: opacity),
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: LjodTheme.textMuted.withValues(alpha: opacity),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 10),
          if (trailing != null)
            Opacity(opacity: opacity, child: trailing!)
          else if (onTap != null)
            Icon(
              Icons.chevron_right_rounded,
              size: 20,
              color: LjodTheme.textMuted.withValues(alpha: opacity),
            ),
        ],
      ),
    );

    if (onTap == null) return content;
    return Material(
      color: Colors.transparent,
      child: InkWell(onTap: enabled ? onTap : null, child: content),
    );
  }
}
