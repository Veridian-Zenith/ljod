import 'package:flutter/rendering.dart' show ScrollDirection;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/models/song_model.dart';
import '../../core/theme/ljod_theme.dart';
import '../../core/widgets/vz_components.dart';
import '../../services/audio/audio_providers.dart';
import '../../services/lyrics/lyrics_service.dart';
import '../../services/settings/settings_provider.dart';

/// The lyrics sheet.
///
/// Lyrics arrive from a local sidecar, an embedded tag, or one cached LRCLIB
/// lookup. Nothing here polls: the only network call is the one the lookup
/// provider already made, or the explicit "look up / refresh" action.
class LyricsSheet extends ConsumerStatefulWidget {
  const LyricsSheet({super.key, required this.song});

  final SongModel song;

  @override
  ConsumerState<LyricsSheet> createState() => _LyricsSheetState();
}

class _LyricsSheetState extends ConsumerState<LyricsSheet> {
  final Map<int, GlobalKey> _lineKeys = {};

  /// Romanization is shown by default when the text has any to show; the chip
  /// hides it again. Original lines always stay visible.
  bool? _showRomanization;
  bool _followPlayback = true;
  int _lastActive = -1;

  String _romanizedLine(String text) {
    final romanized = romanizeLyrics(text).trim();
    if (romanized.isEmpty) return '';
    if (romanized.toLowerCase() == text.trim().toLowerCase()) return '';
    // Unmapped scripts collapse to fragments; keep only useful output.
    if (romanized.replaceAll(RegExp(r'[^A-Za-z]'), '').length < 3) return '';
    return romanized;
  }

  bool _canRomanize(Lyrics lyrics) =>
      lyrics.lines.any((line) => _romanizedLine(line.text).isNotEmpty);

  void _refresh({bool force = true}) {
    ref.read(lyricsRefreshProvider.notifier).request(widget.song.id);
    if (force) {
      ref.invalidate(lyricsProvider(widget.song.id));
    }
  }

  Future<void> _enableLookupAndRetry() async {
    await ref.read(settingsProvider.notifier).setLyricsLookup(true);
    if (!mounted) return;
    _refresh();
  }

  @override
  Widget build(BuildContext context) {
    final song = widget.song;
    final lyricsAsync = ref.watch(lyricsProvider(song.id));
    final position = ref.watch(positionProvider).value ?? Duration.zero;
    final result = lyricsAsync.value;
    final lyrics = result?.hasLyrics == true ? result!.lyrics! : null;
    final showRomanization =
        _showRomanization ?? (lyrics != null && _canRomanize(lyrics));

    final active = lyrics?.activeLine(position) ?? -1;
    if (lyrics != null && active != _lastActive) {
      _lastActive = active;
      if (_followPlayback && active >= 0) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          final context = _lineKeys[active]?.currentContext;
          if (context != null) {
            Scrollable.ensureVisible(
              context,
              alignment: 0.34,
              duration: const Duration(milliseconds: 320),
              curve: Curves.easeOutCubic,
            );
          }
        });
      }
    }

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.78,
      minChildSize: 0.4,
      maxChildSize: 0.96,
      builder: (context, scrollController) {
        return Column(
          children: [
            _Header(
              song: song,
              result: result,
              isRefreshing: lyricsAsync.isLoading && lyricsAsync.hasValue,
              canRomanize: lyrics != null && _canRomanize(lyrics),
              romanizeEnabled: showRomanization,
              onToggleRomanize: () =>
                  setState(() => _showRomanization = !showRomanization),
              onRefresh: _refresh,
              onFollow: () {
                setState(() => _followPlayback = !_followPlayback);
                if (_followPlayback) _lastActive = -1;
              },
              followsPlayback: _followPlayback,
            ),
            const Divider(height: 1),
            Expanded(
              child: lyricsAsync.when(
                loading: () => const LoadingView(label: 'Looking for lyrics…'),
                error: (error, _) => _StateMessage(
                  icon: Icons.cloud_off_rounded,
                  title: 'Could not read lyrics',
                  message: '$error',
                  actionLabel: 'Try again',
                  onAction: _refresh,
                ),
                data: (value) {
                  if (lyrics == null) {
                    return _emptyState(
                      value,
                      settingsOn: ref.watch(
                        settingsProvider.select((s) => s.lyricsLookup),
                      ),
                    );
                  }
                  return NotificationListener<UserScrollNotification>(
                    onNotification: (notification) {
                      if (notification.direction != ScrollDirection.idle &&
                          _followPlayback) {
                        setState(() => _followPlayback = false);
                      }
                      return false;
                    },
                    child: ListView.builder(
                      controller: scrollController,
                      padding: const EdgeInsets.fromLTRB(20, 14, 20, 48),
                      itemCount: lyrics.lines.length,
                      itemBuilder: (context, index) {
                        final line = lyrics.lines[index];
                        if (line.text.trim().isEmpty) {
                          return const SizedBox(height: 14);
                        }
                        final key = _lineKeys.putIfAbsent(index, GlobalKey.new);
                        return _LyricLineView(
                          key: key,
                          line: line,
                          romanized: showRomanization
                              ? _romanizedLine(line.text)
                              : '',
                          isActive: lyrics.synced && index == active,
                          dimmed: lyrics.synced && index != active,
                          onTap: line.time == null
                              ? null
                              : () => ref
                                    .read(playbackControllerProvider)
                                    .seek(line.time!),
                        );
                      },
                    ),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _emptyState(LyricsResult? result, {required bool settingsOn}) {
    switch (result?.status) {
      case LyricsStatus.instrumental:
        return const _StateMessage(
          icon: Icons.music_off_rounded,
          title: 'Instrumental',
          message: 'LRCLIB has this track on file with no lyrics.',
        );
      case LyricsStatus.notFound:
        return _StateMessage(
          icon: Icons.lyrics_outlined,
          title: 'No lyrics for this track',
          message:
              'LRCLIB has no match, and there is no sidecar or embedded '
              'lyrics. A matching .lrc file beside the track works offline.',
          actionLabel: 'Search LRCLIB again',
          onAction: settingsOn ? _refresh : _enableLookupAndRetry,
        );
      case LyricsStatus.disabled:
        return _StateMessage(
          icon: Icons.cloud_off_rounded,
          title: 'Online lookup is off',
          message:
              'Sidecar and embedded lyrics always work. Ljod can ask LRCLIB '
              'once for this track — the title, artist, album and duration go '
              'out, nothing else.',
          actionLabel: 'Look up lyrics',
          onAction: _enableLookupAndRetry,
        );
      case LyricsStatus.failed:
        final wait = result?.retryAfter;
        return _StateMessage(
          icon: Icons.wifi_off_rounded,
          title: 'Lookup did not finish',
          message: [
            result?.message ?? 'Something went wrong asking LRCLIB.',
            if (wait != null) 'Retry in ${wait.inSeconds}s.',
          ].join(' '),
          actionLabel: wait == null ? 'Try again' : null,
          onAction: wait == null ? _refresh : null,
        );
      case LyricsStatus.found:
      case null:
        return _StateMessage(
          icon: Icons.lyrics_outlined,
          title: 'No lyrics yet',
          message: settingsOn
              ? 'Nothing cached for this track yet.'
              : 'Enable online lookup to fetch lyrics once, or drop a .lrc '
                    'file beside the track.',
          actionLabel: 'Look up lyrics',
          onAction: _refresh,
        );
    }
  }
}

class _Header extends StatelessWidget {
  const _Header({
    required this.song,
    required this.result,
    required this.isRefreshing,
    required this.canRomanize,
    required this.romanizeEnabled,
    required this.onToggleRomanize,
    required this.onRefresh,
    required this.onFollow,
    required this.followsPlayback,
  });

  final SongModel song;
  final LyricsResult? result;
  final bool isRefreshing;
  final bool canRomanize;
  final bool romanizeEnabled;
  final VoidCallback onToggleRomanize;
  final VoidCallback onRefresh;
  final VoidCallback onFollow;
  final bool followsPlayback;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final lyrics = result?.lyrics;

    final sourceLabel = switch (lyrics?.source) {
      'sidecar' => 'LRC FILE',
      'tag' => 'EMBEDDED',
      'LRCLIB' => 'LRCLIB',
      null => null,
      final other => other.toUpperCase(),
    };

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'LYRICS',
                      style: LjodTheme.display(theme.textTheme, size: 24),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      song.displayAlbum.isEmpty
                          ? '${song.title} · ${song.displayArtist}'
                          : '${song.title} · ${song.displayAlbum}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: LjodTheme.textSoft,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                tooltip: followsPlayback
                    ? 'Following playback'
                    : 'Follow playback',
                onPressed: onFollow,
                icon: Icon(
                  followsPlayback
                      ? Icons.my_location_rounded
                      : Icons.location_searching_rounded,
                  color: followsPlayback
                      ? LjodTheme.amber
                      : LjodTheme.textMuted,
                ),
              ),
              IconButton(
                tooltip: 'Look up again',
                onPressed: onRefresh,
                icon: isRefreshing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.refresh_rounded),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 6,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (sourceLabel != null)
                LjodBadge(
                  label: lyrics?.synced == true ? 'SYNCED' : sourceLabel,
                  isActive: true,
                ),
              if (lyrics != null && !lyrics.synced && sourceLabel != null)
                LjodBadge(label: sourceLabel),
              if (result?.cached == true) const LjodBadge(label: 'CACHED'),
              if (canRomanize)
                _Chip(
                  icon: Icons.translate_rounded,
                  label: romanizeEnabled ? 'ROMANIZED' : 'ROMANIZE',
                  active: romanizeEnabled,
                  onTap: onToggleRomanize,
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({
    required this.icon,
    required this.label,
    required this.active,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final accent = active ? LjodTheme.amber : LjodTheme.textMuted;
    return Material(
      color: active
          ? LjodTheme.amber.withValues(alpha: 0.16)
          : LjodTheme.panelBlack.withValues(alpha: 0.7),
      borderRadius: BorderRadius.circular(999),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 12, color: accent),
              const SizedBox(width: 5),
              Text(
                label,
                style: TextStyle(
                  fontSize: 9,
                  letterSpacing: 0.9,
                  fontWeight: FontWeight.w700,
                  color: accent,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// One lyric line: the original stays primary, the romanization sits under it
/// in a smaller, quieter size.
class _LyricLineView extends StatelessWidget {
  const _LyricLineView({
    super.key,
    required this.line,
    required this.romanized,
    required this.isActive,
    required this.dimmed,
    this.onTap,
  });

  final LyricLine line;
  final String romanized;
  final bool isActive;
  final bool dimmed;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final base = theme.textTheme.titleMedium!;
    final color = isActive
        ? LjodTheme.amber
        : dimmed
        ? LjodTheme.textMuted
        : LjodTheme.textStrong;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeOut,
        margin: const EdgeInsets.symmetric(vertical: 3),
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 9),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          color: isActive
              ? LjodTheme.amber.withValues(alpha: 0.08)
              : Colors.transparent,
          border: Border(
            left: BorderSide(
              width: 2,
              color: isActive ? LjodTheme.amber : Colors.transparent,
            ),
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            AnimatedDefaultTextStyle(
              duration: const Duration(milliseconds: 200),
              style: base.copyWith(
                height: 1.45,
                color: color,
                fontWeight: isActive ? FontWeight.w800 : FontWeight.w500,
              ),
              child: Text(line.text),
            ),
            if (romanized.isNotEmpty) ...[
              const SizedBox(height: 3),
              Text(
                romanized,
                style: theme.textTheme.bodySmall?.copyWith(
                  height: 1.35,
                  fontSize: (base.fontSize ?? 16) * 0.72,
                  letterSpacing: 0.4,
                  color: isActive
                      ? LjodTheme.amber.withValues(alpha: 0.75)
                      : LjodTheme.textMuted.withValues(alpha: 0.9),
                  fontWeight: FontWeight.w400,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _StateMessage extends StatelessWidget {
  const _StateMessage({
    required this.icon,
    required this.title,
    required this.message,
    this.actionLabel,
    this.onAction,
  });

  final IconData icon;
  final String title;
  final String message;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 46,
            height: 46,
            alignment: Alignment.center,
            decoration: ShapeDecoration(
              color: LjodTheme.amber.withValues(alpha: 0.10),
              shape: MaterialShapeBorder(
                shape: MaterialShapes.cookie4Sided,
                side: BorderSide(
                  color: LjodTheme.amber.withValues(alpha: 0.28),
                ),
              ),
            ),
            child: Icon(icon, size: 20, color: LjodTheme.amber),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            message,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: LjodTheme.textSoft,
              height: 1.55,
            ),
          ),
          if (actionLabel != null && onAction != null) ...[
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onAction,
              icon: const Icon(Icons.bolt_rounded, size: 18),
              label: Text(actionLabel!),
            ),
          ],
        ],
      ),
    );
  }
}
