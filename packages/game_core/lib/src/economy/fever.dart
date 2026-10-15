import 'package:game_core/src/engine/battle_view.dart';
import 'package:game_core/src/engine/events.dart';
import 'package:game_core/src/engine/game_engine.dart';
import 'package:game_core/src/engine/game_state.dart';
import 'package:game_core/src/engine/units.dart';
import 'package:game_data/game_data.dart';

// 피버 타임 (docs/specs/platform-fun-fever.md A). 수치는 meta.fever. 오프라인 계산에는 넣지 않는다.

/// 피버 중인가 (BattleView.feverTicksLeft > 0).
bool feverOn(GameState s) => (s.battle?.feverTicksLeft ?? 0) > 0;

/// 피버 중 피해 % 합에 더하는 값 (damageMultiplier − 1 — 설계서 4.8: 새 보너스는 마지막 % 합에만).
double feverDamageBonus(GameState s, GameTables t) =>
    feverOn(s) ? t.meta.raw.obj('fever').number('damageMultiplier') - 1 : 0;

/// 피버 중 처치 골드 배율.
double feverGoldMultiplier(GameState s, GameTables t) =>
    feverOn(s) ? t.meta.raw.obj('fever').number('goldMultiplier') : 1;

/// 한 틱 진행: 피버 중이면 남은 틱을 줄이고(끝나면 FeverEnded), 아니면 이번 틱 처치로 게이지를 채워 가득 차면 FeverStarted.
/// 동시 처치(이번 틱 2마리 이상)는 마리당 × multiKillBonus, 보스 처치는 + bossKill.
GameState feverStep(GameState s, SystemContext ctx, {required int kills, required bool bossKilled}) {
  final f = ctx.tables.meta.raw.obj('fever');
  final v = s.battle ?? BattleView.empty;
  if (v.feverTicksLeft > 0) {
    final left = v.feverTicksLeft - 1;
    if (left == 0) ctx.emit(FeverEnded(ctx.tick));
    return s.copyWith(battle: v.copyWith(feverTicksLeft: left, fever: 0));
  }
  final add =
      kills * f.number('perKill') * (kills > 1 ? f.number('multiKillBonus') : 1) +
      (bossKilled ? f.number('bossKill') : 0);
  if (add == 0 && v.fever == s.progress.fever) return s;
  var gauge = s.progress.fever + add;
  var ticks = 0;
  if (gauge >= 1) {
    ticks = (f.number('durationSec') / (ctx.tables.waves.tickMs * secondsPerMillisecond)).round();
    ctx.emit(FeverStarted(ctx.tick, untilTick: ctx.tick + ticks));
    gauge = 0;
  }
  return s.copyWith(
    progress: s.progress.copyWith(fever: gauge),
    battle: v.copyWith(fever: gauge, feverTicksLeft: ticks),
  );
}
