import 'package:game_core/src/economy/cards.dart' show receiveCard;
import 'package:game_core/src/economy/formation.dart' show fleetSlots;
import 'package:game_core/src/engine/commands.dart';
import 'package:game_core/src/engine/events.dart';
import 'package:game_core/src/engine/game_engine.dart';
import 'package:game_core/src/engine/game_state.dart';
import 'package:game_data/game_data.dart';

// 튜토리얼 단계 판정 (설계서 4.12, 스펙 economy-m3-meta 규칙 9). 단계는 `meta.tutorial.steps`, 끝·건너뜀 = null.
// UI가 `TutorialAck`으로 넘기는 단계(ack)와 코어가 상태로 넘기는 단계(upgrade·boss·merge)가 나뉜다.

JsonReader _steps(GameTables t) => t.meta.raw.obj('tutorial').obj('steps');

/// 매 틱: upgrade 단계 → 부위 레벨 달성, boss 단계 → 튜토리얼 보스 스테이지(`waves.boss.tutorialFailStage`)를 넘음.
GameState tutorialTick(GameState s, SystemContext ctx) {
  final t = ctx.tables;
  final step = s.tutorialStep;
  if (step == null) return s;
  final st = _steps(t);
  final up = st.obj('upgrade');
  if (step == up.integer('step') && s.ship.level(up.str('part')) >= up.integer('level')) {
    return _welcome(s.copyWith(tutorialStep: step + 1), ctx);
  }
  if (step == st.integer('boss') && s.progress.bestStage > t.waves.tutorialFailStage) {
    return s.copyWith(tutorialStep: step + 1);
  }
  return s;
}

/// 환영 선원(사용자 피드백 #21 '1분 안에 연사 특성 희귀 선원 확정'): 첫 강화 단계를 넘는 순간 `meta.tutorial.welcomeCrew` 한 명을
/// 그 등급으로 보유 + 첫 빈 출전 칸에 앉힌다. 받는 화면·카드 연출은 소환과 같은 CrewSummoned(한 장). 이미 있으면 주지 않는다.
GameState _welcome(GameState s, SystemContext ctx) {
  final tut = ctx.tables.meta.raw.obj('tutorial');
  if (!tut.has('welcomeCrew')) return s;
  final w = tut.obj('welcomeCrew');
  final id = w.str('crewId');
  if (s.crews.containsKey(id)) return s;
  final got = receiveCard(s, ctx.tables, id, w.str('rarity'));
  final fleet = [...got.fleet];
  final slots = fleetSlots(got, ctx.tables);
  final at = fleet.indexOf(null);
  if (at >= 0 && at < slots) {
    fleet[at] = id;
  } else if (fleet.length < slots) {
    fleet.add(id);
  }
  ctx.emit(CrewSummoned(ctx.tick, results: [(crewId: id, rarity: w.str('rarity'))]));
  return got.copyWith(fleet: fleet);
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

/// 건너뛰기(S1 결정 2026-10-17): 튜토리얼은 끝나도 환영 선원은 그 틱에 받는다(아직 첫 강화 전이었으면).
GameState skipTutorial(GameState s, SystemContext ctx) {
  final up = _steps(ctx.tables).obj('upgrade').integer('step');
  final step = s.tutorialStep;
  final before = step != null && step <= up;
  final done = s.copyWith(clearTutorial: true);
  return before ? _welcome(done, ctx) : done;
}

GameState opSetTutorial(GameState s, OpSetTutorial c) =>
    c.step == null ? s.copyWith(clearTutorial: true) : s.copyWith(tutorialStep: c.step);
