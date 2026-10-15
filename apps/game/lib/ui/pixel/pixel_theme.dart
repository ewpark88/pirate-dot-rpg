import 'package:flutter/material.dart';
import 'package:pirate_dot/ui/pixel/palette.dart';
import 'package:pirate_dot/ui/skin/skin.dart';

/// 한글 도트 폰트 (OFL, assets/fonts — main 47d5eee).
const pixelFontFamily = 'Galmuri11';

/// Galmuri11의 설계 크기. 화면 픽셀로 이 값의 정수배일 때만 번지지 않는다.
const _fontPx = 11.0;

/// Galmuri11을 화면 픽셀로 11의 정수배(번지지 않음) 중 [minDp] 이상인 가장 작은 크기로.
double pixelFontSize(double devicePixelRatio, double minDp) =>
    (minDp * devicePixelRatio / _fontPx).ceil() * _fontPx / devicePixelRatio;

/// 스킨 r1 테마 (docs/specs/ui-skin-r1.md, 사용자 승인): 하늘 파스텔 바탕, 둥근 모서리, 잉크 물결 없음,
/// 글꼴 Jua(+ 기호 보충), 본문 16 · 작은 글 14 · 제목 20 · 큰 글 24. ([devicePixelRatio]는 예전 도트 글꼴 정수배용 — 지금은 안 쓴다.)
ThemeData pixelTheme({double devicePixelRatio = 1}) {
  final scheme = ColorScheme.fromSeed(seedColor: Skin.primaryBottom).copyWith(
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
  const edge = BorderSide(color: PixelPalette.border, width: 1.5);
  final square = RoundedRectangleBorder(side: edge, borderRadius: BorderRadius.circular(Skin.radiusCard));
  final squareNoEdge = RoundedRectangleBorder(borderRadius: BorderRadius.circular(Skin.radiusButton));
  final buttonShape = WidgetStateProperty.all<OutlinedBorder>(squareNoEdge);

  const body = 16.0;
  const title = 20.0;
  const big = 24.0;
  TextStyle style(double size, {FontWeight weight = FontWeight.normal}) => Skin.text(size, weight: weight);
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
    fontFamily: Skin.font,
    textTheme: textTheme,
    scaffoldBackgroundColor: Skin.sky,
    canvasColor: Skin.sky,
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    hoverColor: Colors.transparent,
    cardTheme: CardThemeData(color: PixelPalette.navy, elevation: 0, shape: square, margin: EdgeInsets.zero),
    dialogTheme: DialogThemeData(backgroundColor: PixelPalette.navy, elevation: 0, shape: square),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: PixelPalette.navy,
      elevation: 0,
      shape: square,
      modalBackgroundColor: PixelPalette.navy,
    ),
    appBarTheme: const AppBarTheme(backgroundColor: Skin.sky, elevation: 0, scrolledUnderElevation: 0),
    navigationBarTheme: NavigationBarThemeData(
      backgroundColor: PixelPalette.navyPressed,
      indicatorColor: PixelPalette.border,
      indicatorShape: squareNoEdge,
      elevation: 0,
    ),
    chipTheme: ChipThemeData(shape: square, backgroundColor: PixelPalette.navyPressed),
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
