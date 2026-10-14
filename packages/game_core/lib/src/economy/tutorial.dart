import 'package:game_core/src/engine/commands.dart';
import 'package:game_core/src/engine/game_state.dart';
import 'package:game_data/game_data.dart';

// 튜토리얼 단계 판정 (설계서 4.12, 스펙 economy-m3-meta 규칙 9). 단계는 `meta.tutorial.steps`, 끝·건너뜀 = null.
// UI가 `TutorialAck`으로 넘기는 단계(ack)와 코어가 상태로 넘기는 단계(upgrade·boss·merge)가 나뉜다.

JsonReader _steps(GameTables t) => t.meta.raw.obj('tutorial').obj('steps');

/// 매 틱: upgrade 단계 → 부위 레벨 달성, boss 단계 → 튜토리얼 보스 스테이지(`waves.boss.tutorialFailStage`)를 넘음.
GameState tutorialTick(GameState s, GameTables t) {
  final step = s.tutorialStep;
  if (step == null) return s;
  final st = _steps(t);
  final up = st.obj('upgrade');
  if (step == up.integer('step') && s.ship.level(up.str('part')) >= up.integer('level')) {
    return s.copyWith(tutorialStep: step + 1);
  }
  if (step == st.integer('boss') && s.progress.bestStage > t.waves.tutorialFailStage) {
    return s.copyWith(tutorialStep: step + 1);
  }
  return s;
}

/// UI 확인 단계만 넘긴다. 마지막 단계 다음은 끝(null). 지금 단계와 다르면 무시.
GameState tutorialAck(GameState s, GameTables t, TutorialAck c) {
  final st = _steps(t);
  final acks = [for (final v in st.raw['ack'] as List) (v as num).toInt()];
  if (s.tutorialStep != c.step || !acks.contains(c.step)) return s;
  return c.step == st.integer('last') ? s.copyWith(clearTutorial: true) : s.copyWith(tutorialStep: c.step + 1);
}

/// 일괄 합치기를 누르면 merge 단계 → 다음.
GameState tutorialAfterMerge(GameState s, GameTables t) {
  final merge = _steps(t).integer('merge');
  return s.tutorialStep == merge ? s.copyWith(tutorialStep: merge + 1) : s;
}

GameState opSetTutorial(GameState s, OpSetTutorial c) =>
    c.step == null ? s.copyWith(clearTutorial: true) : s.copyWith(tutorialStep: c.step);
