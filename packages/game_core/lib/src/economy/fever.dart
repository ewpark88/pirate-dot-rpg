import 'package:game_core/src/economy/crew_stats.dart' show rarityOfLevel;
import 'package:game_core/src/economy/formation.dart' show activeFleet;
import 'package:game_core/src/engine/battle_view.dart';
import 'package:game_core/src/engine/events.dart';
import 'package:game_core/src/engine/game_engine.dart';
import 'package:game_core/src/engine/game_state.dart';
import 'package:game_core/src/engine/units.dart';
import 'package:game_data/game_data.dart';

// 피버 타임 (docs/specs/platform-fun-fever.md A). 수치는 meta.fever. 오프라인 계산에는 넣지 않는다.

/// 피버 중인가 (BattleView.feverTicksLeft > 0).
bool feverOn(GameState s) => (s.battle?.feverTicksLeft ?? 0) > 0;

/// 피버가 켜진 첫 틱(남은 틱이 아직 꽉 찬 틱)인가 — 전투가 피버를 처음 보는 틱. 첫 일격·피버 무리 즉시 소환이 쓴다.
bool feverJustStarted(GameState s, GameTables t) {
  if (!feverOn(s)) return false;
  final f = t.meta.raw.obj('fever');
  final full = ((f.number('durationSec') + feverSupport(s, t).extraSec) / (t.waves.tickMs * secondsPerMillisecond))
      .round();
  return s.battle!.feverTicksLeft == full;
}

/// 피버 중 피해 % 합에 더하는 값 (damageMultiplier − 1 — 설계서 4.8: 새 보너스는 마지막 % 합에만).
double feverDamageBonus(GameState s, GameTables t) =>
    feverOn(s) ? t.meta.raw.obj('fever').number('damageMultiplier') - 1 : 0;

/// 피버 중 처치 골드 배율.
double feverGoldMultiplier(GameState s, GameTables t) =>
    feverOn(s) ? t.meta.raw.obj('fever').number('goldMultiplier') : 1;

/// 피버까지 필요한 처치 수 (사용자 결정 2026-10-16 처치 수 기준, 피드백 #2 2026-10-17 '초반 200 → 점점 늘려 최대 1000').
/// 스테이지 1에서 killsStart, killsRampStage까지 곧게 늘어 killsMax. 환생하면 스테이지를 따라 다시 짧아진다.
int feverKillsAt(GameTables t, int stage) {
  final f = t.meta.raw.obj('fever');
  final start = f.integer('killsStart');
  final max = f.integer('killsMax');
  final ramp = f.integer('killsRampStage');
  final k = stage >= ramp ? 1.0 : (stage - 1) / (ramp - 1);
  return (start + (max - start) * k).round();
}

/// 피버 서포트 선원(개성 v2 7.3, legends `fever`)의 합: 출전 중인 선원의 그 등급 능력(특징 배율 포함).
({double charge, double extraSec}) feverSupport(GameState s, GameTables t) {
  final legend = t.rarities.rarities.indexWhere((r) => r.id == 'legend');
  var charge = 0.0;
  var extra = 0.0;
  for (final id in activeFleet(s, t)) {
    final c = s.crews[id];
    if (c == null) continue;
    final rarity = t.rarities.rarities.indexOf(rarityOfLevel(t.rarities, c.level));
    final f = t.skills.legendFor(id, rarity, legend)?.fever;
    if (f == null) continue;
    charge += f.chargeBonus;
    extra += f.extraSec;
  }
  return (charge: charge, extraSec: extra);
}

/// 게이지에 [amount]를 더한다 (특정 조건 — 즉석 도전 성공·돌발 이벤트 성공). 가득 차면 다음 틱 feverStep이 켠다. 피버 중이면 무시.
GameState addFever(GameState s, double amount) =>
    feverOn(s) ? s : s.copyWith(progress: s.progress.copyWith(fever: s.progress.fever + amount));

/// 한 틱 진행: 피버 중이면 남은 틱을 줄이고(끝나면 FeverEnded), 아니면 이번 틱 처치로 게이지를 채워 가득 차면 FeverStarted.
/// 처치 1마리 = 1 ÷ feverKillsAt, 보스 처치는 + bossKill.
GameState feverStep(GameState s, SystemContext ctx, {required int kills, required bool bossKilled}) {
  final f = ctx.tables.meta.raw.obj('fever');
  final v = s.battle ?? BattleView.empty;
  if (v.feverTicksLeft > 0) {
    final left = v.feverTicksLeft - 1;
    if (left == 0) ctx.emit(FeverEnded(ctx.tick));
    return s.copyWith(battle: v.copyWith(feverTicksLeft: left, fever: 0));
  }
  final support = feverSupport(s, ctx.tables);
  final add =
      (kills / feverKillsAt(ctx.tables, s.progress.stage) + (bossKilled ? f.number('bossKill') : 0)) *
      (1 + support.charge);
  if (add == 0 && v.fever == s.progress.fever) return s;
  var gauge = s.progress.fever + add;
  var ticks = 0;
  if (gauge >= 1) {
    ticks = ((f.number('durationSec') + support.extraSec) / (ctx.tables.waves.tickMs * secondsPerMillisecond)).round();
    ctx.emit(FeverStarted(ctx.tick, untilTick: ctx.tick + ticks));
    gauge = 0;
  }
  return s.copyWith(
    progress: s.progress.copyWith(fever: gauge),
    battle: v.copyWith(fever: gauge, feverTicksLeft: ticks),
  );
}
