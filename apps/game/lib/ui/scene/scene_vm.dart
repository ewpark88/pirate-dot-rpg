import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pirate_dot/l10n/gen/app_localizations.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';

// 장면 모드(심연의 탑 · 보스 러시, S5 계약 platform-tower.md · platform-boss-rush) 화면 공용.

/// 탑·러시·요일 던전 중인가 — 이때 보스 도전 버튼·피버·돌발 이벤트를 숨긴다(계약 4절).
final sceneActiveProvider = Provider<bool>(
  (ref) => ref.watch(
    gameStateProvider.select((s) => s.battle?.tower != null || s.battle?.rush != null || s.battle?.dungeon != null),
  ),
);

/// 틱 → 'm:ss' (러시 기록·HUD).
String sceneClock(AppLocalizations l, int ticks, int tickMs) {
  final sec = (ticks * tickMs / Duration.millisecondsPerSecond).floor();
  return l.uiClock(sec ~/ 60, (sec % 60).toString().padLeft(2, '0'));
}

/// 초 → 'm:ss' (러시 구간 표).
String secClock(AppLocalizations l, num sec) => l.uiClock(sec ~/ 60, (sec.round() % 60).toString().padLeft(2, '0'));

/// 보상 글: '젬 n · 카드 n장 · 지도 조각 n' (0인 것은 빼고).
String sceneReward(AppLocalizations l, {int gems = 0, int cards = 0, int pieces = 0}) => [
  if (gems > 0) l.uiSceneGems(gems),
  if (cards > 0) l.uiSceneCards(cards),
  if (pieces > 0) l.uiScenePieces(pieces),
].join(l.uiListSep);
