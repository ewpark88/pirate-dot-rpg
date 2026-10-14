import 'package:flutter/material.dart';
import 'package:pirate_dot/l10n/gen/app_localizations.dart';
import 'package:pirate_dot/ui/home_screen.dart';

/// 앱 루트. 언어는 OS 설정을 따르고(ko/en), 설정의 lang 값으로 덮어쓴다.
class PirateDotApp extends StatelessWidget {
  const PirateDotApp({super.key, this.locale});

  /// null이면 OS 언어.
  final Locale? locale;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      onGenerateTitle: (context) => AppLocalizations.of(context).uiAppTitle,
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: ThemeData(colorSchemeSeed: const Color(0xFF1B4F72), useMaterial3: true),
      home: const HomeScreen(),
    );
  }
}
