import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pirate_dot/l10n/gen/app_localizations.dart';
import 'package:pirate_dot/ui/home_screen.dart';
import 'package:pirate_dot/ui/pixel/palette.dart';
import 'package:pirate_dot/ui/pixel/pixel_theme.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';

/// 앱 루트. 언어는 설정의 lang 값(`system`이면 OS 언어, ko/en)을 따른다.
class PirateDotApp extends ConsumerWidget {
  const PirateDotApp({super.key, this.locale});

  /// 테스트용 고정 언어. null이면 설정 → OS 언어.
  final Locale? locale;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(gameStateProvider.select((s) => s.settings.lang));
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      onGenerateTitle: (context) => AppLocalizations.of(context).uiAppTitle,
      locale: locale ?? _localeOf(lang),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: pixelTheme(),
      // 글자 크기는 화면 픽셀 정수배(도트 한 칸)에 맞춘다 — MediaQuery가 있어야 해서 여기서.
      builder: (context, child) => Theme(
        data: pixelTheme(unit: pixelUnit(context)),
        child: child!,
      ),
      home: const HomeScreen(),
    );
  }
}

/// 설정의 lang → Locale. `system`(또는 모르는 값)이면 null = OS 언어.
Locale? _localeOf(String lang) => AppLocalizations.supportedLocales.where((l) => l.languageCode == lang).firstOrNull;
