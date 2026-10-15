import 'package:flutter/material.dart';
import 'package:pirate_dot/ui/pixel/palette.dart';

/// 한글 도트 폰트 (OFL, assets/fonts — main 47d5eee).
const pixelFontFamily = 'Galmuri11';

/// Galmuri11의 설계 크기. 화면 픽셀로 이 값의 정수배일 때만 번지지 않는다.
const _fontPx = 11.0;

/// 도트 톤 테마 (스펙 ui-quality-v1 규칙 3·6): 남색 바탕, 네모 모서리 + 테두리, 그림자·잉크 물결 없음,
/// 글자는 Galmuri11을 [unit](도트 한 칸 dp)의 11배(제목은 22배)로 — 실제 화면 픽셀로 11의 정수배.
/// 도트 프레임으로 아직 바꾸지 않은 Material 위젯도 이 테마로 기준 화면의 톤을 따른다.
ThemeData pixelTheme({double unit = 1}) {
  final scheme = ColorScheme.fromSeed(seedColor: PixelPalette.border, brightness: Brightness.dark).copyWith(
    surface: PixelPalette.navy,
    onSurface: PixelPalette.text,
    surfaceContainerHighest: PixelPalette.navyPressed,
    primary: PixelPalette.action,
    onPrimary: PixelPalette.text,
    primaryContainer: PixelPalette.border,
    onPrimaryContainer: PixelPalette.text,
    secondaryContainer: PixelPalette.border,
    onSecondaryContainer: PixelPalette.text,
    tertiaryContainer: PixelPalette.navyPressed,
    error: PixelPalette.danger,
    outline: PixelPalette.border,
    outlineVariant: PixelPalette.border,
  );
  const edge = BorderSide(color: PixelPalette.border, width: 2);
  const square = RoundedRectangleBorder(side: edge);
  const squareNoEdge = RoundedRectangleBorder();
  final buttonShape = WidgetStateProperty.all<OutlinedBorder>(squareNoEdge);

  final body = _fontPx * unit;
  final big = body * 2;
  TextStyle style(double size, {FontWeight weight = FontWeight.normal}) => TextStyle(
    fontFamily: pixelFontFamily,
    fontSize: size,
    fontWeight: weight,
    height: 1.25,
    color: PixelPalette.text,
  );
  final textTheme = TextTheme(
    displayLarge: style(big, weight: FontWeight.bold),
    displayMedium: style(big, weight: FontWeight.bold),
    displaySmall: style(big, weight: FontWeight.bold),
    headlineLarge: style(big, weight: FontWeight.bold),
    headlineMedium: style(big, weight: FontWeight.bold),
    headlineSmall: style(big, weight: FontWeight.bold),
    titleLarge: style(body, weight: FontWeight.bold),
    titleMedium: style(body, weight: FontWeight.bold),
    titleSmall: style(body, weight: FontWeight.bold),
    bodyLarge: style(body),
    bodyMedium: style(body),
    bodySmall: style(body),
    labelLarge: style(body, weight: FontWeight.bold),
    labelMedium: style(body),
    labelSmall: style(body),
  );

  return ThemeData(
    colorScheme: scheme,
    useMaterial3: true,
    fontFamily: pixelFontFamily,
    textTheme: textTheme,
    scaffoldBackgroundColor: PixelPalette.navy,
    canvasColor: PixelPalette.navy,
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    hoverColor: Colors.transparent,
    cardTheme: const CardThemeData(color: PixelPalette.navy, elevation: 0, shape: square, margin: EdgeInsets.zero),
    dialogTheme: const DialogThemeData(backgroundColor: PixelPalette.navy, elevation: 0, shape: square),
    bottomSheetTheme: const BottomSheetThemeData(
      backgroundColor: PixelPalette.navy,
      elevation: 0,
      shape: square,
      modalBackgroundColor: PixelPalette.navy,
    ),
    appBarTheme: const AppBarTheme(backgroundColor: PixelPalette.navy, elevation: 0, scrolledUnderElevation: 0),
    navigationBarTheme: const NavigationBarThemeData(
      backgroundColor: PixelPalette.navyPressed,
      indicatorColor: PixelPalette.border,
      indicatorShape: squareNoEdge,
      elevation: 0,
    ),
    chipTheme: const ChipThemeData(shape: square, backgroundColor: PixelPalette.navyPressed),
    filledButtonTheme: FilledButtonThemeData(
      style: ButtonStyle(shape: buttonShape, elevation: WidgetStateProperty.all(0)),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(style: ButtonStyle(shape: buttonShape)),
    textButtonTheme: TextButtonThemeData(style: ButtonStyle(shape: buttonShape)),
    segmentedButtonTheme: SegmentedButtonThemeData(style: ButtonStyle(shape: buttonShape)),
    progressIndicatorTheme: const ProgressIndicatorThemeData(
      color: PixelPalette.danger,
      linearTrackColor: PixelPalette.outline,
      borderRadius: BorderRadius.zero,
    ),
    dividerTheme: const DividerThemeData(color: PixelPalette.border, thickness: 2),
  );
}
