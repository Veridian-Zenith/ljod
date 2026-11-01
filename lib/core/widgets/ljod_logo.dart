import 'package:material_ui/material_ui.dart';

import '../theme/ljod_theme.dart';

/// The Ljod mark: an outlined "forge cookie" — a soft four-sided frame with
/// deliberately uneven corners and one squared-off corner where the metal was
/// struck — holding three waveform bars.
///
/// The mark is line art only: no filled tile, so it sits directly on the app's
/// black surface and on the launcher wallpaper. Geometry lives in a 108x108
/// design space, the same viewport the Android adaptive icon uses, so the
/// launcher art and the in-app mark share numbers.
const double ljodMarkDesignExtent = 108;

/// Frame stroke width in design units.
const double ljodMarkFrameStroke = 5;

/// Waveform stroke width in design units.
const double ljodMarkBarStroke = 7;

/// The frame outline. The bottom-right corner is nearly square: the "strike"
/// that keeps the silhouette from reading as a plain rounded square.
Path buildLjodFramePath() => Path()
  ..addRRect(
    RRect.fromRectAndCorners(
      const Rect.fromLTRB(26, 26, 82, 82),
      topLeft: const Radius.circular(26),
      topRight: const Radius.circular(14),
      bottomRight: const Radius.circular(3),
      bottomLeft: const Radius.circular(14),
    ),
  );

/// The three waveform bars, tallest in the middle. Heights stay distinct at
/// 48px, the mdpi launcher size.
Path buildLjodWavePath() {
  final path = Path();
  const bars = [(41.0, 46.0, 62.0), (54.0, 38.0, 70.0), (67.0, 44.0, 64.0)];
  for (final (x, top, bottom) in bars) {
    path
      ..moveTo(x, top)
      ..lineTo(x, bottom);
  }
  return path;
}

/// The Ljod glyph. Pass [color] for a single-colour mark (monochrome splash,
/// watermark, themed launcher art); otherwise it draws in the forge amber
/// gradient.
class LjodMark extends StatelessWidget {
  const LjodMark({super.key, this.size = 56, this.color, this.semanticLabel});

  final double size;
  final Color? color;
  final String? semanticLabel;

  static const List<Color> gradient = [
    Color(0xFFFFCE8A),
    Color(0xFFFFB347),
    Color(0xFFE08A1E),
  ];

  @override
  Widget build(BuildContext context) {
    final mark = CustomPaint(
      size: Size.square(size),
      painter: _LjodMarkPainter(color: color),
    );
    if (semanticLabel == null) return mark;
    return Semantics(label: semanticLabel, image: true, child: mark);
  }
}

class _LjodMarkPainter extends CustomPainter {
  const _LjodMarkPainter({this.color});

  final Color? color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..isAntiAlias = true;
    final resolved = color;
    if (resolved != null) {
      paint.color = resolved;
    } else {
      paint.shader = const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: LjodMark.gradient,
        stops: [0, 0.55, 1],
      ).createShader(Offset.zero & const Size.square(ljodMarkDesignExtent));
    }

    canvas
      ..save()
      ..scale(size.width / ljodMarkDesignExtent);
    canvas
      ..drawPath(buildLjodFramePath(), paint..strokeWidth = ljodMarkFrameStroke)
      ..drawPath(buildLjodWavePath(), paint..strokeWidth = ljodMarkBarStroke)
      ..restore();
  }

  @override
  bool shouldRepaint(_LjodMarkPainter oldDelegate) =>
      oldDelegate.color != color;
}

/// Mark + wordmark lockup used by the home header and first-run screen.
class LjodLockup extends StatelessWidget {
  const LjodLockup({super.key, this.markSize = 34, this.textSize = 38});

  final double markSize;
  final double textSize;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        LjodMark(size: markSize, semanticLabel: 'Ljod'),
        SizedBox(width: markSize * 0.34),
        Text(
          'LJOD',
          style: LjodTheme.display(
            theme.textTheme,
            size: textSize,
          ).copyWith(color: LjodTheme.textStrong),
        ),
      ],
    );
  }
}
