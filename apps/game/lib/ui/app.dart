import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pirate_dot/l10n/gen/app_localizations.dart';
import 'package:pirate_dot/ui/crew/new_mate.dart';
import 'package:pirate_dot/ui/guide/guide_layer.dart';
import 'package:pirate_dot/ui/home_screen.dart';
import 'package:pirate_dot/ui/idle/idle_gate.dart';
import 'package:pirate_dot/ui/meta/trial_gate.dart';
import 'package:pirate_dot/ui/pixel/pixel_theme.dart';
import 'package:pirate_dot/ui/rebirth/ship_skin_entries.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';
import 'package:pirate_dot/ui/story/story_layer.dart';

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
      // 태블릿은 UI 전체를 확대해 그린다(글자·버튼·패널·창 모두 같은 비율) — 사용자 원칙 '태블릿에서도 유동적으로'.
      // 절전 화면·잔상 방지(IdleGate)는 모든 화면 위 — 설정 창이 열려 있어도 동작한다.
      builder: (context, child) => IdleGate(
        child: UiScale(
          child: Theme(
            data: pixelTheme(devicePixelRatio: MediaQuery.devicePixelRatioOf(context)),
            child: child!,
          ),
        ),
      ),
      // 가이드 v2 층(카드·밝은 곳·손가락)은 홈 화면 위, 창(경로)들 아래.
      // 새 동료 카드(수집의 재미)는 홈 화면에서 연다.
      // 시나리오(오프닝·보스 대화)는 가이드 층 아래 — 대화 동안 가이드는 접힌다.
      home: const GuideLayer(
        child: StoryLayer(
          child: NewMateGate(
            child: SkinUnlockGate(child: TrialGate(child: HomeScreen())),
          ),
        ),
      ),
    );
  }
}

/// 설정의 lang → Locale. `system`(또는 모르는 값)이면 null = OS 언어.
Locale? _localeOf(String lang) => AppLocalizations.supportedLocales.where((l) => l.languageCode == lang).firstOrNull;

/// 화면 짧은 변 [_baseShortest]dp를 기준으로 UI 배율(1 ~ [_maxScale]). 폰은 1, 10인치 태블릿(800dp)은 1.4.
const _baseShortest = 480.0;
const _maxScale = 1.4;

double uiScaleFor(Size size) => (size.shortestSide / _baseShortest).clamp(1.0, _maxScale);

/// UI 배율: 화면을 (크기 ÷ 배율)로 줄인 논리 화면에 그린 뒤 배율만큼 키운다.
/// 누르기·스크롤은 Transform이 좌표를 되돌려 주므로 그대로 동작한다.
/// dpr은 바꾸지 않는다 — 렌더(BattleGame)가 창의 실제 dpr로 battleFrameFor를 계산하므로, UI 버튼 자리도 같은 값으로 맞아야 한다.
class UiScale extends StatelessWidget {
  const UiScale({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final mq = MediaQuery.of(context);
    final s = uiScaleFor(mq.size);
    if (s == 1) return child;
    final logical = mq.size / s;
    return MediaQuery(
      data: mq.copyWith(
        size: logical,
        padding: mq.padding / s,
        viewPadding: mq.viewPadding / s,
        viewInsets: mq.viewInsets / s,
      ),
      child: ClipRect(
        child: OverflowBox(
          alignment: Alignment.topLeft,
          minWidth: logical.width,
          maxWidth: logical.width,
          minHeight: logical.height,
          maxHeight: logical.height,
          child: Transform.scale(scale: s, alignment: Alignment.topLeft, child: child),
        ),
      ),
    );
  }
}
