import 'package:material_ui/material_ui.dart';

/// The visual language of Ljod: Veridian Zenith amber on a blueprint-black
/// substrate, fused with Material 3 Expressive's tactile, geometric shapes.
abstract final class LjodTheme {
  static const String monoFamily = 'JetBrainsMono';

  // Core palette — mirrors vzdev.indevs.in.
  static const Color amber = Color(0xFFFFB347);
  static const Color amberDeep = Color(0xFFD98A1F);
  static const Color crimson = Color(0xFFD72638);
  static const Color gold = Color(0xFFFFD700);

  // True black surfaces: OLED pixels stay off, and elevated panels use only a
  // whisper of lift so the hierarchy survives without washing the black out.
  static const Color bgBlack = Color(0xFF000000);
  static const Color bgPitch = Color(0xFF000000);
  static const Color panelBlack = Color(0xFF0B0B0D);
  static const Color panelHigh = Color(0xFF15151A);
  static const Color panelHighest = Color(0xFF1F1F26);

  static const Color textStrong = Color(0xFFF4F1E8);
  static const Color textSoft = Color(0xFFB9B4A8);
  static const Color textMuted = Color(0xFF7A756C);
  static const Color borderLight = Color(0xFF2B2A30);
  static const Color borderStrong = Color(0xFF4A4850);
  static const Color error = Color(0xFFFF6B57);
  static const Color stable = Color(0xFF5BD68A);

  static const List<Color> forgeGradient = [
    Color(0xFFFFB347),
    Color(0xFFFF8A3D),
    Color(0xFFD72638),
  ];

  static const double radiusXs = 8;
  static const double radiusSm = 14;
  static const double radiusMd = 22;
  static const double radiusLg = 30;
  static const double radiusXl = 40;

  static ThemeData build({bool expressiveMotion = true}) {
    final bg = bgPitch;
    final scheme = ColorScheme.dark(
      primary: amber,
      onPrimary: const Color(0xFF1A1200),
      primaryContainer: const Color(0xFF4B3300),
      onPrimaryContainer: const Color(0xFFFFE0AC),
      secondary: crimson,
      onSecondary: const Color(0xFFFFFFFF),
      secondaryContainer: const Color(0xFF5A1019),
      onSecondaryContainer: const Color(0xFFFFDAD8),
      tertiary: gold,
      onTertiary: const Color(0xFF1A1600),
      tertiaryContainer: const Color(0xFF4B4200),
      onTertiaryContainer: const Color(0xFFFFF0A6),
      error: error,
      onError: const Color(0xFF1A0500),
      surface: panelBlack,
      onSurface: textStrong,
      surfaceDim: bg,
      surfaceBright: panelHigh,
      surfaceContainerLowest: bg,
      surfaceContainerLow: panelBlack,
      surfaceContainer: const Color(0xFF15151A),
      surfaceContainerHigh: panelHigh,
      surfaceContainerHighest: panelHighest,
      onSurfaceVariant: textSoft,
      outline: borderStrong,
      outlineVariant: borderLight,
      inverseSurface: textStrong,
      onInverseSurface: bg,
      inversePrimary: amberDeep,
    );

    final base = _textTheme(scheme);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: bg,
      canvasColor: bg,
      fontFamily: monoFamily,
      textTheme: base,
      splashFactory: expressiveMotion
          ? InkSparkle.splashFactory
          : InkRipple.splashFactory,
      visualDensity: VisualDensity.standard,
      pageTransitionsTheme: expressiveMotion
          ? const PageTransitionsTheme(
              builders: {
                TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
                TargetPlatform.iOS: FadeForwardsPageTransitionsBuilder(),
                TargetPlatform.linux: FadeForwardsPageTransitionsBuilder(),
                TargetPlatform.macOS: FadeForwardsPageTransitionsBuilder(),
                TargetPlatform.windows: FadeForwardsPageTransitionsBuilder(),
              },
            )
          : null,
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        foregroundColor: textStrong,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: base.titleLarge,
      ),
      cardTheme: CardThemeData(
        color: panelBlack,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          side: const BorderSide(color: borderLight),
        ),
      ),
      iconButtonTheme: const IconButtonThemeData(
        variant: StyleVariant.material3Expressive,
        style: ButtonStyle(
          shapeVariant: ButtonShapeVariant.round,
          sizeVariant: ButtonSizeVariant.medium,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          minimumSize: const Size(64, 52),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: const StadiumBorder(),
          textStyle: base.labelLarge?.copyWith(
            fontWeight: FontWeight.w700,
            letterSpacing: 0.3,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(56, 48),
          foregroundColor: textStrong,
          side: const BorderSide(color: borderStrong),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          shape: const StadiumBorder(),
          textStyle: base.labelLarge,
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: amber,
          textStyle: base.labelLarge,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: panelBlack,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 18,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSm),
          borderSide: const BorderSide(color: borderLight),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSm),
          borderSide: const BorderSide(color: borderLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSm),
          borderSide: const BorderSide(color: amber, width: 1.5),
        ),
        hintStyle: base.bodyMedium?.copyWith(color: textMuted),
        labelStyle: base.bodySmall?.copyWith(color: textMuted),
      ),
      sliderTheme: SliderThemeData(
        // ignore: deprecated_member_use
        year2023: false,
        trackHeight: 16,
        trackGap: 6,
        activeTrackColor: amber,
        inactiveTrackColor: panelHighest,
        thumbColor: amber,
        overlayColor: amber.withValues(alpha: 0.16),
        activeTickMarkColor: bg,
        inactiveTickMarkColor: textMuted,
        thumbShape: const _BarSliderThumbShape(width: 4, height: 24),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: 22),
      ),
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) =>
                states.contains(WidgetState.selected) ? amber : panelBlack,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected)
                ? const Color(0xFF1A1200)
                : textSoft,
          ),
          side: const WidgetStatePropertyAll(BorderSide(color: borderLight)),
          textStyle: WidgetStatePropertyAll(base.labelMedium),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: panelBlack,
        selectedColor: amber,
        disabledColor: panelBlack,
        side: const BorderSide(color: borderLight),
        labelStyle: base.labelMedium?.copyWith(color: textSoft),
        secondaryLabelStyle: base.labelMedium?.copyWith(
          color: const Color(0xFF1A1200),
          fontWeight: FontWeight.w700,
        ),
        shape: const StadiumBorder(),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      ),
      dividerTheme: const DividerThemeData(
        color: borderLight,
        thickness: 1,
        space: 1,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: panelHighest,
        contentTextStyle: base.bodyMedium?.copyWith(color: textStrong),
        actionTextColor: amber,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusSm),
          side: const BorderSide(color: borderLight),
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: panelBlack,
        modalBackgroundColor: panelBlack,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        dragHandleColor: borderStrong,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(radiusLg)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: panelHigh,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLg),
          side: const BorderSide(color: borderLight),
        ),
        titleTextStyle: base.titleLarge,
        contentTextStyle: base.bodyMedium,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: amber,
        linearTrackColor: panelHighest,
        circularTrackColor: panelHighest,
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (states) => states.contains(WidgetState.selected)
              ? const Color(0xFF1A1200)
              : textMuted,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected) ? amber : panelHighest,
        ),
        trackOutlineColor: WidgetStateProperty.resolveWith(
          (states) =>
              states.contains(WidgetState.selected) ? amber : borderStrong,
        ),
      ),
      listTileTheme: ListTileThemeData(
        iconColor: textSoft,
        textColor: textStrong,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusSm),
        ),
      ),
    );
  }

  /// The geometric, oversized display face used for headers and hero numbers.
  static TextStyle display(TextTheme base, {double? size, Color? color}) {
    return TextStyle(
      fontFamily: monoFamily,
      fontSize: size ?? 34,
      height: 1.02,
      fontWeight: FontWeight.w800,
      letterSpacing: -1.4,
      color: color ?? textStrong,
    );
  }

  static TextTheme _textTheme(ColorScheme scheme) {
    final base = Typography.material2021(platform: TargetPlatform.android).white
        .apply(
          fontFamily: monoFamily,
          bodyColor: textStrong,
          displayColor: textStrong,
        );

    return base.copyWith(
      displayLarge: base.displayLarge?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -2,
        height: 1.0,
      ),
      displayMedium: base.displayMedium?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -1.6,
        height: 1.0,
      ),
      displaySmall: base.displaySmall?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -1.2,
        height: 1.05,
      ),
      headlineLarge: base.headlineLarge?.copyWith(
        fontWeight: FontWeight.w800,
        letterSpacing: -1.0,
      ),
      headlineMedium: base.headlineMedium?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.8,
      ),
      headlineSmall: base.headlineSmall?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.5,
      ),
      titleLarge: base.titleLarge?.copyWith(
        fontWeight: FontWeight.w700,
        letterSpacing: -0.4,
      ),
      titleMedium: base.titleMedium?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: -0.2,
      ),
      titleSmall: base.titleSmall?.copyWith(fontWeight: FontWeight.w600),
      bodyLarge: base.bodyLarge?.copyWith(color: textStrong, height: 1.5),
      bodyMedium: base.bodyMedium?.copyWith(color: textSoft, height: 1.45),
      bodySmall: base.bodySmall?.copyWith(color: textMuted, height: 1.4),
      labelLarge: base.labelLarge?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: 0.15,
      ),
      labelMedium: base.labelMedium?.copyWith(
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
      ),
      labelSmall: base.labelSmall?.copyWith(
        color: textMuted,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.6,
      ),
    );
  }
}

/// An expressive vertical-bar thumb for the 2024 slider appearance.
class _BarSliderThumbShape extends SliderComponentShape {
  const _BarSliderThumbShape({this.width = 4, this.height = 24});

  final double width;
  final double height;

  @override
  Size getPreferredSize(bool isEnabled, bool isDiscrete) => Size(width, height);

  @override
  void paint(
    PaintingContext context,
    Offset center, {
    required Animation<double> activationAnimation,
    required Animation<double> enableAnimation,
    required bool isDiscrete,
    required TextPainter labelPainter,
    required RenderBox parentBox,
    required SliderThemeData sliderTheme,
    required TextDirection textDirection,
    required double value,
    required double textScaleFactor,
    required Size sizeWithOverflow,
  }) {
    final expansion = Curves.easeOutCubic.transform(activationAnimation.value);
    final paint = Paint()
      ..color = sliderTheme.thumbColor ?? LjodTheme.amber
      ..isAntiAlias = true;
    final rect = Rect.fromCenter(
      center: center,
      width: width + expansion * 2,
      height: height + expansion * 4,
    );
    context.canvas.drawRRect(
      RRect.fromRectAndRadius(rect, const Radius.circular(2)),
      paint,
    );
  }
}
