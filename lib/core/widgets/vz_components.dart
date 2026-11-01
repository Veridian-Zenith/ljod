import 'dart:io';
import 'dart:math' as math;

import 'package:material_ui/material_ui.dart';

import '../../core/models/song_model.dart';
import '../../core/theme/ljod_theme.dart';
import '../../core/utils/formatters.dart';

// ---------------------------------------------------------------------------
// Atmospheric substrate
// ---------------------------------------------------------------------------

/// A calm, layered backdrop: deep black with two soft amber/crimson light
/// pools. Geometry belongs to the cards and controls, not to a literal
/// blueprint grid painted behind everything.
class LjodBackground extends StatelessWidget {
  const LjodBackground({super.key, required this.child, this.showGlow = true});

  final Widget child;
  final bool showGlow;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        ColoredBox(color: Theme.of(context).scaffoldBackgroundColor),
        if (showGlow) ...[
          const Positioned(
            top: -220,
            left: -180,
            width: 520,
            height: 520,
            // Fade to transparent: a near-black stop would paint a visible
            // disc of grey over the true-black surface.
            child: _Glow(colors: [Color(0x33FFB347), Color(0x00000000)]),
          ),
          const Positioned(
            bottom: -260,
            right: -200,
            width: 560,
            height: 560,
            child: _Glow(colors: [Color(0x1FD72638), Color(0x00000000)]),
          ),
        ],
        child,
      ],
    );
  }
}

class _Glow extends StatelessWidget {
  const _Glow({required this.colors});

  final List<Color> colors;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(colors: colors, stops: const [0, 1]),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Artwork
// ---------------------------------------------------------------------------

class CoverArt extends StatelessWidget {
  const CoverArt({
    super.key,
    this.path,
    this.size = 56,
    this.radius = 16,
    this.label = '',
    this.icon = Icons.graphic_eq_rounded,
    this.showBorder = false,
  });

  /// Path to a cached image (never an audio file).
  final String? path;
  final double size;
  final double radius;
  final String label;
  final IconData icon;
  final bool showBorder;

  @override
  Widget build(BuildContext context) {
    final imagePath = path;
    final pixelRatio = MediaQuery.devicePixelRatioOf(context);
    final decodeSize = (size.isFinite ? size * pixelRatio : 512).round().clamp(
      64,
      1024,
    );
    final child = imagePath != null && imagePath.isNotEmpty
        ? SizedBox.expand(
            child: Image.file(
              File(imagePath),
              fit: BoxFit.cover,
              cacheWidth: decodeSize,
              cacheHeight: decodeSize,
              filterQuality: FilterQuality.medium,
              gaplessPlayback: true,
              errorBuilder: (_, _, _) => _fallback(context),
            ),
          )
        : _fallback(context);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        border: showBorder ? Border.all(color: LjodTheme.borderLight) : null,
      ),
      clipBehavior: Clip.antiAlias,
      child: child,
    );
  }

  Widget _fallback(BuildContext context) {
    final palette = [LjodTheme.amber, LjodTheme.crimson, LjodTheme.gold];
    final base = label.isEmpty ? icon.codePoint : label.codeUnitAt(0);
    final color = palette[base % palette.length];
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: 0.28),
            LjodTheme.panelHigh,
            LjodTheme.panelBlack,
          ],
        ),
      ),
      child: Stack(
        fit: StackFit.expand,
        children: [
          CustomPaint(
            painter: _CoverPatternPainter(color: color.withValues(alpha: 0.22)),
          ),
          Center(
            child: label.isEmpty
                ? Icon(icon, size: size * 0.34, color: LjodTheme.textMuted)
                : Text(
                    albumInitials(label),
                    style: TextStyle(
                      fontFamily: LjodTheme.monoFamily,
                      fontWeight: FontWeight.w800,
                      fontSize: size * 0.26,
                      color: color.withValues(alpha: 0.92),
                      letterSpacing: -1,
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}

class _CoverPatternPainter extends CustomPainter {
  _CoverPatternPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1;
    final center = Offset(size.width / 2, size.height / 2);
    canvas.drawCircle(center, size.width * 0.34, paint);
    canvas.drawCircle(center, size.width * 0.5, paint);
    canvas.drawLine(Offset.zero, Offset(size.width, size.height), paint);
  }

  @override
  bool shouldRepaint(covariant _CoverPatternPainter oldDelegate) {
    return oldDelegate.color != color;
  }
}

class SongCover extends StatelessWidget {
  const SongCover({
    super.key,
    required this.song,
    this.size = 56,
    this.radius = 16,
  });

  final SongModel song;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return CoverArt(
      path: song.artworkPath,
      size: size,
      radius: radius,
      label: song.album.isEmpty ? song.title : song.album,
    );
  }
}

// ---------------------------------------------------------------------------
// Pills, panels, headers
// ---------------------------------------------------------------------------

class LjodBadge extends StatelessWidget {
  const LjodBadge({
    super.key,
    required this.label,
    this.isActive = false,
    this.icon,
    this.color,
  });

  final String label;
  final bool isActive;
  final IconData? icon;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final accent = color ?? LjodTheme.amber;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: isActive
            ? accent.withValues(alpha: 0.14)
            : LjodTheme.panelHigh.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: isActive
              ? accent.withValues(alpha: 0.45)
              : LjodTheme.borderLight,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(
              icon,
              size: 11,
              color: isActive ? accent : LjodTheme.textMuted,
            ),
            const SizedBox(width: 5),
          ] else if (isActive) ...[
            Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(color: accent, shape: BoxShape.circle),
            ),
            const SizedBox(width: 6),
          ],
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: 9,
              fontFamily: LjodTheme.monoFamily,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.9,
              color: isActive ? accent : LjodTheme.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

class Panel extends StatelessWidget {
  const Panel({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.radius = LjodTheme.radiusMd,
    this.color = LjodTheme.panelBlack,
    this.borderColor = LjodTheme.borderLight,
    this.onTap,
    this.glow = false,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final double radius;
  final Color color;
  final Color borderColor;
  final VoidCallback? onTap;
  final bool glow;

  @override
  Widget build(BuildContext context) {
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(radius),
      side: BorderSide(color: borderColor),
    );
    final content = AnimatedContainer(
      duration: const Duration(milliseconds: 220),
      padding: padding,
      decoration: ShapeDecoration(
        color: color,
        shape: shape,
        shadows: glow
            ? [
                BoxShadow(
                  color: LjodTheme.amber.withValues(alpha: 0.12),
                  blurRadius: 30,
                  spreadRadius: 1,
                ),
              ]
            : null,
      ),
      child: child,
    );

    if (onTap == null) return content;
    return Material(
      color: Colors.transparent,
      shape: shape,
      clipBehavior: Clip.antiAlias,
      child: InkWell(onTap: onTap, child: content),
    );
  }
}

/// Numeric summary card shared by the Library stats row and Insights.
///
/// [dense] keeps the compact Library footprint; the default is the taller
/// Insights variant with an icon and a brighter number.
class StatCard extends StatelessWidget {
  const StatCard({
    super.key,
    required this.value,
    required this.label,
    this.icon,
    this.onTap,
    this.dense = false,
  });

  final String value;
  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final card = Container(
      padding: dense
          ? const EdgeInsets.symmetric(horizontal: 12, vertical: 10)
          : const EdgeInsets.fromLTRB(14, 14, 14, 12),
      decoration: BoxDecoration(
        color: LjodTheme.panelBlack.withValues(alpha: 0.86),
        borderRadius: BorderRadius.circular(dense ? 16 : LjodTheme.radiusMd),
        border: Border.all(color: LjodTheme.borderLight),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (icon != null && !dense) ...[
            Icon(icon, size: 15, color: LjodTheme.amber),
            const SizedBox(height: 12),
          ],
          Text(
            value,
            style: TextStyle(
              fontSize: dense ? 18 : 22,
              fontWeight: FontWeight.w800,
              color: dense ? LjodTheme.amber : LjodTheme.textStrong,
              letterSpacing: dense ? -0.6 : -0.8,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label.toUpperCase(),
            style: TextStyle(
              fontSize: dense ? 8 : 8.5,
              fontWeight: FontWeight.w700,
              letterSpacing: 1.2,
              color: LjodTheme.textMuted,
            ),
          ),
        ],
      ),
    );

    if (onTap == null) return card;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(dense ? 16 : LjodTheme.radiusMd),
        child: card,
      ),
    );
  }
}

class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.eyebrow,
    this.trailing,
    this.padding = const EdgeInsets.fromLTRB(20, 0, 20, 12),
  });

  final String title;
  final String? subtitle;
  final String? eyebrow;
  final Widget? trailing;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (eyebrow ?? title).toUpperCase(),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: LjodTheme.amber,
                    letterSpacing: 2.2,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (eyebrow != null) ...[
                  const SizedBox(height: 4),
                  Text(
                    title,
                    style: theme.textTheme.titleLarge?.copyWith(
                      color: LjodTheme.textStrong,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                if (subtitle != null) ...[
                  const SizedBox(height: 3),
                  Text(subtitle!, style: theme.textTheme.bodySmall),
                ],
              ],
            ),
          ),
          ?trailing,
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Controls
// ---------------------------------------------------------------------------

/// Expressive circular icon action with an amber "engaged" state.
class GlowIconButton extends StatelessWidget {
  const GlowIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.isActive = false,
    this.size = 20,
    this.tooltip,
    this.padding = 10,
    this.color,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final bool isActive;
  final double size;
  final String? tooltip;
  final double padding;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final accent = color ?? LjodTheme.amber;
    final button = Material(
      color: isActive
          ? accent.withValues(alpha: 0.16)
          : LjodTheme.panelHigh.withValues(alpha: 0.72),
      shape: CircleBorder(
        side: BorderSide(
          color: isActive
              ? accent.withValues(alpha: 0.5)
              : LjodTheme.borderLight,
        ),
      ),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(padding),
          child: Icon(
            icon,
            size: size,
            color: onTap == null
                ? LjodTheme.textMuted.withValues(alpha: 0.5)
                : isActive
                ? accent
                : LjodTheme.textStrong,
          ),
        ),
      ),
    );
    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}

/// Icon action built on a Material 3 Expressive geometric outline.
///
/// Use this where a circular button would read as generic: transport controls,
/// skip actions and other tactile one-tap affordances.
class ShapeIconButton extends StatelessWidget {
  const ShapeIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.shape,
    this.isActive = false,
    this.size = 20,
    this.padding = 10,
    this.tooltip,
    this.color,
  });

  final IconData icon;
  final VoidCallback? onTap;

  /// Defaults to a four-sided cookie; pass any [MaterialShapes] polygon.
  final RoundedPolygon? shape;
  final bool isActive;
  final double size;
  final double padding;
  final String? tooltip;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final accent = color ?? LjodTheme.amber;
    final outline = MaterialShapeBorder(
      shape: shape ?? MaterialShapes.cookie4Sided,
      side: BorderSide(
        color: isActive ? accent.withValues(alpha: 0.5) : LjodTheme.borderLight,
      ),
    );

    final button = Material(
      color: Colors.transparent,
      child: Ink(
        decoration: ShapeDecoration(
          color: isActive
              ? accent.withValues(alpha: 0.16)
              : LjodTheme.panelHigh.withValues(alpha: 0.72),
          shape: outline,
        ),
        child: InkWell(
          customBorder: outline,
          onTap: onTap,
          child: Padding(
            padding: EdgeInsets.all(padding),
            child: Icon(
              icon,
              size: size,
              color: onTap == null
                  ? LjodTheme.textMuted.withValues(alpha: 0.5)
                  : isActive
                  ? accent
                  : LjodTheme.textStrong,
            ),
          ),
        ),
      ),
    );

    return tooltip == null ? button : Tooltip(message: tooltip!, child: button);
  }
}

/// The signature play/pause control. The container morphs between a circle and
/// a soft Material 3 Expressive cookie shape while playback is active.
class PlayPauseButton extends StatelessWidget {
  const PlayPauseButton({
    super.key,
    required this.playing,
    required this.onTap,
    this.size = 64,
    this.iconSize = 32,
    this.enabled = true,
  });

  final bool playing;
  final VoidCallback onTap;
  final double size;
  final double iconSize;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final shape = MaterialShapeBorder(
      shape: playing ? MaterialShapes.cookie4Sided : MaterialShapes.circle,
      side: BorderSide(
        color: enabled
            ? LjodTheme.amber.withValues(alpha: 0.9)
            : LjodTheme.borderLight,
        width: 1.5,
      ),
    );

    return Semantics(
      button: true,
      label: playing ? 'Pause' : 'Play',
      child: GestureDetector(
        onTap: enabled ? onTap : null,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 420),
          curve: Curves.easeOutBack,
          width: size,
          height: size,
          decoration: ShapeDecoration(
            color: enabled ? LjodTheme.amber : LjodTheme.panelHigh,
            shape: shape,
            shadows: enabled
                ? [
                    BoxShadow(
                      color: LjodTheme.amber.withValues(alpha: 0.30),
                      blurRadius: 28,
                      spreadRadius: 1,
                    ),
                  ]
                : null,
          ),
          child: Icon(
            playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
            size: iconSize,
            color: enabled ? const Color(0xFF1A1200) : LjodTheme.textMuted,
          ),
        ),
      ),
    );
  }
}

class LjodSlider extends StatelessWidget {
  const LjodSlider({
    super.key,
    required this.value,
    required this.max,
    required this.onChanged,
    this.onChangeEnd,
    this.buffered,
    this.activeColor = LjodTheme.amber,
  });

  final double value;
  final double max;
  final ValueChanged<double> onChanged;
  final ValueChanged<double>? onChangeEnd;

  /// Position already buffered, drawn as a dimmer secondary track.
  final double? buffered;
  final Color activeColor;

  @override
  Widget build(BuildContext context) {
    final safeMax = max <= 0 ? 1.0 : max;
    return SliderTheme(
      data: SliderTheme.of(context).copyWith(
        activeTrackColor: activeColor,
        // Buffered audio needs to read as a track, not a stray dot.
        secondaryActiveTrackColor: activeColor.withValues(alpha: 0.45),
        thumbColor: activeColor,
        overlayColor: activeColor.withValues(alpha: 0.14),
      ),
      child: Slider(
        value: value.clamp(0, safeMax),
        max: safeMax,
        secondaryTrackValue: buffered?.clamp(0, safeMax),
        onChanged: onChanged,
        onChangeEnd: onChangeEnd,
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Song lists
// ---------------------------------------------------------------------------

class SongTile extends StatelessWidget {
  const SongTile({
    super.key,
    required this.song,
    required this.onTap,
    this.onFavorite,
    this.isCurrent = false,
    this.playing = false,
    this.showAlbum = true,
    this.trailing,
  });

  final SongModel song;
  final VoidCallback onTap;
  final VoidCallback? onFavorite;
  final bool isCurrent;
  final bool playing;
  final bool showAlbum;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Material(
      color: Colors.transparent,
      borderRadius: BorderRadius.circular(LjodTheme.radiusMd),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 220),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: isCurrent
                ? LjodTheme.amber.withValues(alpha: 0.08)
                : Colors.transparent,
            borderRadius: BorderRadius.circular(LjodTheme.radiusMd),
            border: Border.all(
              color: isCurrent
                  ? LjodTheme.amber.withValues(alpha: 0.34)
                  : Colors.transparent,
            ),
          ),
          child: Row(
            children: [
              Stack(
                alignment: Alignment.center,
                children: [
                  SongCover(song: song, size: 54, radius: 16),
                  if (isCurrent)
                    Container(
                      width: 54,
                      height: 54,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(16),
                        color: LjodTheme.bgPitch.withValues(alpha: 0.55),
                      ),
                      child: Icon(
                        playing
                            ? Icons.graphic_eq_rounded
                            : Icons.pause_rounded,
                        color: LjodTheme.amber,
                        size: 22,
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      song.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        color: isCurrent
                            ? LjodTheme.amber
                            : LjodTheme.textStrong,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.2,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      [
                        song.displayArtist,
                        if (showAlbum && song.album.isNotEmpty) song.album,
                      ].join(' · '),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: LjodTheme.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              if (trailing != null)
                trailing!
              else ...[
                Text(
                  formatDuration(song.duration),
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: LjodTheme.textMuted,
                    letterSpacing: 0.2,
                  ),
                ),
                if (onFavorite != null)
                  IconButton(
                    onPressed: onFavorite,
                    tooltip: song.isFavorite
                        ? 'Remove from favourites'
                        : 'Add to favourites',
                    visualDensity: VisualDensity.compact,
                    icon: Icon(
                      song.isFavorite
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      size: 18,
                      color: song.isFavorite
                          ? LjodTheme.crimson
                          : LjodTheme.textMuted,
                    ),
                  ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class AlbumTile extends StatelessWidget {
  const AlbumTile({
    super.key,
    required this.title,
    required this.subtitle,
    required this.artworkPath,
    required this.onTap,
    this.badge,
  });

  final String title;
  final String subtitle;
  final String? artworkPath;
  final VoidCallback onTap;
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(LjodTheme.radiusMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Stack(
              fit: StackFit.expand,
              children: [
                CoverArt(
                  path: artworkPath,
                  radius: LjodTheme.radiusMd,
                  label: title,
                  size: double.infinity,
                ),
                if (badge != null)
                  Positioned(
                    top: 10,
                    left: 10,
                    child: LjodBadge(label: badge!, isActive: true),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// States
// ---------------------------------------------------------------------------

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
    this.action,
    this.compact = false,
  });

  final IconData icon;
  final String title;
  final String message;
  final Widget? action;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final content = Padding(
      padding: EdgeInsets.all(compact ? 18 : 28),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: compact ? 64 : 92,
            height: compact ? 64 : 92,
            decoration: BoxDecoration(
              color: LjodTheme.panelBlack,
              borderRadius: BorderRadius.circular(LjodTheme.radiusLg),
              border: Border.all(
                color: LjodTheme.amber.withValues(alpha: 0.32),
              ),
              boxShadow: [
                BoxShadow(
                  color: LjodTheme.amber.withValues(alpha: 0.10),
                  blurRadius: 24,
                ),
              ],
            ),
            child: Icon(icon, size: compact ? 28 : 40, color: LjodTheme.amber),
          ),
          SizedBox(height: compact ? 14 : 20),
          Text(
            title.toUpperCase(),
            textAlign: TextAlign.center,
            style: theme.textTheme.labelMedium?.copyWith(
              color: LjodTheme.textStrong,
              letterSpacing: 1.8,
            ),
          ),
          const SizedBox(height: 8),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 300),
            child: Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: LjodTheme.textMuted,
                height: 1.55,
              ),
            ),
          ),
          if (action != null) ...[const SizedBox(height: 20), action!],
        ],
      ),
    );

    // Center keeps the state optically balanced on tall screens, while the
    // scroll view prevents overflows in landscape or small windows.
    return Center(child: SingleChildScrollView(child: content));
  }
}

class LoadingView extends StatelessWidget {
  const LoadingView({super.key, this.label = 'Reading the forge…'});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 34,
            height: 34,
            child: CircularProgressIndicator(strokeWidth: 2.5),
          ),
          const SizedBox(height: 16),
          Text(
            label,
            style: Theme.of(context).textTheme.bodySmall
                ?.copyWith(color: LjodTheme.textMuted, letterSpacing: 0.4),
          ),
        ],
      ),
    );
  }
}

class ErrorView extends StatelessWidget {
  const ErrorView({super.key, required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    return EmptyState(
      icon: Icons.warning_amber_rounded,
      title: 'Something jarred the needle',
      message: message,
      action: onRetry == null
          ? null
          : OutlinedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh_rounded, size: 18),
              label: const Text('Try again'),
            ),
    );
  }
}

// ---------------------------------------------------------------------------
// Search + filters
// ---------------------------------------------------------------------------

class LjodSearchBar extends StatelessWidget {
  const LjodSearchBar({
    super.key,
    required this.onChanged,
    this.controller,
    this.hint = 'Search the library…',
    this.autofocus = false,
  });

  final ValueChanged<String> onChanged;
  final TextEditingController? controller;
  final String hint;
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      onChanged: onChanged,
      autofocus: autofocus,
      textInputAction: TextInputAction.search,
      style: Theme.of(context).textTheme.bodyLarge,
      decoration: InputDecoration(
        hintText: hint,
        prefixIcon: const Icon(
          Icons.search_rounded,
          size: 20,
          color: LjodTheme.textMuted,
        ),
        suffixIcon: controller == null
            ? null
            : ValueListenableBuilder<TextEditingValue>(
                valueListenable: controller!,
                builder: (context, value, child) {
                  if (value.text.isEmpty) return const SizedBox.shrink();
                  return IconButton(
                    onPressed: () {
                      controller!.clear();
                      onChanged('');
                    },
                    icon: const Icon(Icons.close_rounded, size: 18),
                  );
                },
              ),
        isDense: true,
      ),
    );
  }
}

class FilterChipRow extends StatelessWidget {
  const FilterChipRow({
    super.key,
    required this.labels,
    required this.selectedIndex,
    required this.onSelected,
    this.padding = const EdgeInsets.symmetric(horizontal: 20),
  });

  final List<String> labels;
  final int selectedIndex;
  final ValueChanged<int> onSelected;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: padding,
        itemCount: labels.length,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) {
          final selected = index == selectedIndex;
          return ChoiceChip(
            label: Text(labels[index]),
            selected: selected,
            onSelected: (_) => onSelected(index),
            showCheckmark: false,
            labelStyle: TextStyle(
              fontSize: 12,
              fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              color: selected ? const Color(0xFF1A1200) : LjodTheme.textSoft,
            ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Equalizer ornament
// ---------------------------------------------------------------------------

class EqualizerBars extends StatefulWidget {
  const EqualizerBars({
    super.key,
    this.active = true,
    this.color = LjodTheme.amber,
    this.bars = 4,
    this.height = 14,
  });

  final bool active;
  final Color color;
  final int bars;
  final double height;

  @override
  State<EqualizerBars> createState() => _EqualizerBarsState();
}

class _EqualizerBarsState extends State<EqualizerBars>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    );
    if (widget.active) _controller.repeat();
  }

  @override
  void didUpdateWidget(covariant EqualizerBars oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.active && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: List.generate(widget.bars, (index) {
            final wave = math.sin(
              (_controller.value * math.pi * 2) + (index * 0.9),
            );
            final factor = widget.active
                ? 0.35 + ((wave + 1) / 2) * 0.65
                : 0.25;
            return Padding(
              padding: const EdgeInsets.symmetric(horizontal: 1.5),
              child: Container(
                width: 3,
                height: widget.height * factor,
                decoration: BoxDecoration(
                  color: widget.color,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            );
          }),
        );
      },
    );
  }
}
