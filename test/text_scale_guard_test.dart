import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:ljod/main.dart';
import 'package:material_ui/material_ui.dart';

/// A NaN scale cannot be built with [TextScaler.linear] in a debug build: its
/// constructor asserts `textScaleFactor >= 0`, and NaN fails that assert. On a
/// device the assert is compiled out (the diagnostics trail that reported this
/// came from a release build), so the NaN reaches `scale` unchanged.
class _NaNTextScaler extends TextScaler {
  const _NaNTextScaler();

  @override
  double scale(double fontSize) => double.nan;

  @override
  double get textScaleFactor => double.nan;
}

/// On a broken device the app holds a `SystemTextScaler`, which throws from
/// `scale` instead of returning NaN. Both shapes have to be caught.
class _ThrowingTextScaler extends TextScaler {
  const _ThrowingTextScaler();

  @override
  double scale(double fontSize) =>
      throw UnsupportedError('Infinity or NaN toInt');

  @override
  double get textScaleFactor => double.nan;
}

/// Mirrors where [LjodMediaQuery] sits in the real app: between the inherited
/// [MediaQuery] and the text that is painted.
Widget _host(TextScaler system) {
  return MediaQuery(
    data: MediaQueryData(textScaler: system),
    child: LjodMediaQuery(
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Center(child: Text('Amber')),
      ),
    ),
  );
}

double _effectiveScale(WidgetTester tester) {
  final scaler = MediaQuery.textScalerOf(tester.element(find.text('Amber')));
  return scaler.scale(16);
}

void main() {
  // Unscaled text: without the guard, every paragraph painted from this scale
  // fails with "Unsupported operation: Infinity or NaN toInt" from
  // scaleFontSize and the whole screen stays unlaid-out.
  testWidgets('a NaN system scale falls back to no scaling', (tester) async {
    await tester.pumpWidget(_host(const _NaNTextScaler()));

    expect(tester.takeException(), isNull);
    expect(_effectiveScale(tester), 16);
    expect(
      tester.renderObject<RenderParagraph>(find.text('Amber')).hasSize,
      isTrue,
    );
  });

  testWidgets('a scale that throws falls back to no scaling', (tester) async {
    await tester.pumpWidget(_host(const _ThrowingTextScaler()));

    expect(tester.takeException(), isNull);
    expect(_effectiveScale(tester), 16);
  });

  testWidgets('an infinite system scale falls back to no scaling', (
    tester,
  ) async {
    await tester.pumpWidget(_host(TextScaler.linear(double.infinity)));

    expect(tester.takeException(), isNull);
    expect(_effectiveScale(tester), 16);
  });

  // Finite, but every glyph would come out with no height.
  testWidgets('a zero system scale falls back to no scaling', (tester) async {
    await tester.pumpWidget(_host(TextScaler.linear(0)));

    expect(tester.takeException(), isNull);
    expect(_effectiveScale(tester), 16);
  });

  // The guard must not fight the accessibility setting it exists to protect.
  testWidgets('a usable system scale is passed through untouched', (
    tester,
  ) async {
    await tester.pumpWidget(_host(TextScaler.linear(1.5)));

    expect(tester.takeException(), isNull);
    expect(_effectiveScale(tester), closeTo(24, 1e-9));
  });
}
