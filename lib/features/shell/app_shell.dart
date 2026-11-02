import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

import '../../core/models/song_model.dart';
import '../../core/theme/ljod_theme.dart';
import '../../core/widgets/vz_components.dart';
import '../../services/audio/audio_providers.dart';
import '../home/home_screen.dart';
import '../library/library_screen.dart';
import '../player/player_screen.dart';
import '../search/search_screen.dart';
import '../settings/settings_screen.dart';

class LjodShell extends ConsumerStatefulWidget {
  const LjodShell({super.key});

  @override
  ConsumerState<LjodShell> createState() => _LjodShellState();
}

class _LjodShellState extends ConsumerState<LjodShell> {
  int _index = 0;

  late final List<Widget> _screens = [
    HomeScreen(onOpenLibrary: () => setState(() => _index = 2)),
    const SearchScreen(),
    const LibraryScreen(),
    const SettingsScreen(),
  ];

  void _openPlayer() {
    Navigator.of(context).push(PlayerScreen.route());
  }

  @override
  Widget build(BuildContext context) {
    final nowPlaying = ref.watch(nowPlayingProvider);
    final playing = ref.watch(playingProvider).value ?? false;
    final position = ref.watch(positionProvider).value ?? Duration.zero;
    final duration = ref.watch(effectiveDurationProvider);
    final controller = ref.read(playbackControllerProvider);

    // A track that cannot be opened used to fail silently; tell the listener.
    ref.listen<String?>(playbackErrorProvider, (previous, next) {
      if (next == null || next == previous) return;
      ScaffoldMessenger.maybeOf(context)
        ?..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(next)));
      ref.read(playbackErrorProvider.notifier).clear();
    });

    return Scaffold(
      extendBody: true,
      backgroundColor: Colors.transparent,
      body: LjodBackground(
        child: IndexedStack(index: _index, children: _screens),
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        minimum: const EdgeInsets.only(bottom: 10),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 300),
              switchInCurve: Curves.easeOutCubic,
              switchOutCurve: Curves.easeInCubic,
              transitionBuilder: (child, animation) {
                return SizeTransition(
                  sizeFactor: animation,
                  alignment: Alignment.topCenter,
                  child: FadeTransition(opacity: animation, child: child),
                );
              },
              child: nowPlaying == null
                  ? const SizedBox.shrink()
                  : _MiniPlayer(
                      key: const ValueKey('mini-player'),
                      song: nowPlaying,
                      playing: playing,
                      position: position,
                      duration: duration,
                      onTap: _openPlayer,
                      onPlayPause: controller.togglePlayPause,
                      onNext: controller.next,
                    ),
            ),
            _LjodNavBar(
              index: _index,
              onTap: (index) => setState(() => _index = index),
            ),
          ],
        ),
      ),
    );
  }
}

class _MiniPlayer extends StatelessWidget {
  const _MiniPlayer({
    super.key,
    required this.song,
    required this.playing,
    required this.position,
    required this.duration,
    required this.onTap,
    required this.onPlayPause,
    required this.onNext,
  });

  final SongModel song;
  final bool playing;
  final Duration position;
  final Duration duration;
  final VoidCallback onTap;
  final VoidCallback onPlayPause;
  final VoidCallback onNext;

  @override
  Widget build(BuildContext context) {
    final progress = duration.inMilliseconds <= 0
        ? 0.0
        : (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);

    final subtitle = song.album.isEmpty
        ? song.displayArtist
        : '${song.displayArtist} · ${song.album}';

    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 0, 12, 8),
      child: LjodBar(
        accent: true,
        onTap: onTap,
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Inset and rounded: at the very top edge of a capsule the curve
            // clips a full-bleed line down to a stub in the middle.
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(2),
                child: LinearProgressIndicator(
                  value: progress,
                  minHeight: 3,
                  backgroundColor: LjodTheme.borderLight,
                  color: LjodTheme.amber,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                SongCover(song: song, size: 42, radius: 13),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        song.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w700,
                          color: LjodTheme.textStrong,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Row(
                        children: [
                          if (playing)
                            const Padding(
                              padding: EdgeInsets.only(right: 6),
                              child: EqualizerBars(height: 9, bars: 3),
                            ),
                          Flexible(
                            child: Text(
                              subtitle,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 10.5,
                                color: LjodTheme.textSoft,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                PlayPauseButton(
                  playing: playing,
                  onTap: onPlayPause,
                  size: 42,
                  iconSize: 21,
                ),
                const SizedBox(width: 6),
                ShapeIconButton(
                  icon: Icons.skip_next_rounded,
                  onTap: onNext,
                  tooltip: 'Next',
                  shape: MaterialShapes.diamond,
                  size: 18,
                  padding: 7,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _LjodNavBar extends StatelessWidget {
  const _LjodNavBar({required this.index, required this.onTap});

  final int index;
  final ValueChanged<int> onTap;

  static const _items = [
    (Icons.home_rounded, 'Home'),
    (Icons.search_rounded, 'Search'),
    (Icons.library_music_rounded, 'Library'),
    (Icons.settings_rounded, 'Settings'),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      // Same surface as the mini player above it, so the two read as one stack.
      child: LjodBar(
        padding: const EdgeInsets.all(6),
        child: SizedBox(
          height: 52,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              for (var i = 0; i < _items.length; i++)
                _NavItem(
                  icon: _items[i].$1,
                  label: _items[i].$2,
                  selected: index == i,
                  onTap: () => onTap(i),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      selected: selected,
      button: true,
      label: label,
      child: Material(
        color: Colors.transparent,
        borderRadius: BorderRadius.circular(24),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 320),
            curve: Curves.easeOutCubic,
            height: double.infinity,
            padding: EdgeInsets.symmetric(horizontal: selected ? 18 : 16),
            decoration: BoxDecoration(
              color: selected ? LjodTheme.amber : Colors.transparent,
              borderRadius: BorderRadius.circular(24),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  size: 22,
                  color: selected
                      ? const Color(0xFF1A1200)
                      : LjodTheme.textMuted,
                ),
                AnimatedSize(
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOutCubic,
                  child: selected
                      ? Padding(
                          padding: const EdgeInsets.only(left: 8),
                          child: Text(
                            label,
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              color: Color(0xFF1A1200),
                              letterSpacing: 0.2,
                            ),
                          ),
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
