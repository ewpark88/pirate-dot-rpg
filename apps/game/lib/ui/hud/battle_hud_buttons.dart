import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_core/game_core.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';

export 'package:pirate_dot/ui/hud/hud_bubble.dart';

// 선원 줄 오른쪽 버튼이 무엇인지 한눈에 (사용자 질문 2026-10-16 "동그라미로 떠 있는 슬롯은 뭐냐", "새로고침 버튼 같은 건 뭐냐").
// 궁극기 버튼·함성 게이지는 없앴다(사용자 결정 2026-10-17 — 피버 첫 일격으로 흡수, specs/platform-fever-break.md).
// 보스 도전: 새로고침 화살표 대신 해역 보스 초상 + '보스 도전!' 빨강·금 버튼, 칼 교차, 맥박, 처음 말풍선.

/// 이번 실행에서 안내를 보인 횟수 (탭! 손가락 3회 · 말풍선 1회). 세이브에는 남기지 않는다.
final hudHintsProvider = NotifierProvider<HudHints, Map<String, int>>(HudHints.new);

class HudHints extends Notifier<Map<String, int>> {
  @override
  Map<String, int> build() => const {};

  /// 세이브에 남기는 '처음 1회' 안내 (Settings.hints · MarkHint — 앱을 다시 켜도 다시 안 뜬다).
  static const persistent = {'boss.bubble', 'rebirth.bubble', 'rebirth.seen'};

  /// 본 횟수: 이번 실행 수, 세이브에 본 기록이 있으면 최소 1.
  int count(String id) {
    final n = state[id] ?? 0;
    final saved = persistent.contains(id) && ref.read(gameStateProvider).settings.hints.contains(id);
    return saved && n == 0 ? 1 : n;
  }

  void shown(String id) {
    state = {...state, id: (state[id] ?? 0) + 1};
    if (persistent.contains(id)) ref.read(commandSinkProvider).send(MarkHint(id));
  }

  /// 켜짐/꺼짐 표시 (말풍선이 지금 떠 있는지 — 한 번에 하나만).
  void set(String id, {required bool on}) => state = {...state, id: on ? 1 : 0};
}
