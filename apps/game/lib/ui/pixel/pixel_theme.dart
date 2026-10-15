import 'package:flutter/material.dart';
import 'package:pirate_dot/ui/pixel/palette.dart';

/// 한글 도트 폰트 (OFL, assets/fonts — main 47d5eee).
const pixelFontFamily = 'Galmuri11';

/// Galmuri11의 설계 크기. 화면 픽셀로 이 값의 정수배일 때만 번지지 않는다.
const _fontPx = 11.0;

/// 본문·제목 최소 크기(dp) — 실기기에서 읽기 편하게 (layout-v2-brief D1: 본문 14sp, 제목 16~18).
const _bodyMinDp = 14.0;
const _titleMinDp = 16.0;

/// Galmuri11을 화면 픽셀로 11의 정수배(번지지 않음) 중 [minDp] 이상인 가장 작은 크기로.
double pixelFontSize(double devicePixelRatio, double minDp) =>
    (minDp * devicePixelRatio / _fontPx).ceil() * _fontPx / devicePixelRatio;

/// 도트 톤 테마 (스펙 ui-quality-v1 규칙 3·6): 남색 바탕, 네모 모서리 + 테두리, 그림자·잉크 물결 없음.
/// 글자는 Galmuri11 — 실제 화면 픽셀로 11의 정수배이면서 본문 14dp·제목 16dp 이상.
ThemeData pixelTheme({double devicePixelRatio = 1}) {
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

  final body = pixelFontSize(devicePixelRatio, _bodyMinDp);
  final title = pixelFontSize(devicePixelRatio, _titleMinDp);
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
    titleLarge: style(title, weight: FontWeight.bold),
    titleMedium: style(title, weight: FontWeight.bold),
    titleSmall: style(title, weight: FontWeight.bold),
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
