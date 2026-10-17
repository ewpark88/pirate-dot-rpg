import 'dart:math' as math;

import 'package:game_core/src/battle/field.dart';
import 'package:game_core/src/battle/spawner.dart' show bossMaxHp, bossStandoffFor, startBoss;
import 'package:game_core/src/battle/topdown/scene_hp.dart';
import 'package:game_core/src/battle/topdown/top_geometry.dart';
import 'package:game_core/src/economy/formation.dart' show activeFleet;
import 'package:game_core/src/economy/rush.dart';
import 'package:game_core/src/engine/events.dart';
import 'package:game_core/src/engine/game_engine.dart';
import 'package:game_core/src/engine/game_state.dart';
import 'package:game_core/src/engine/state_parts.dart';

/// 보스 러시 전투 (docs/specs/platform-boss-rush.md — S1 승인 2026-10-18).
///
/// 경제가 `StartRush`로 도전을 쓰고 `rush.active`를 정하면, 다음 틱에 전장을 이번 주 보스 차례(rushBosses)로 바꾼다.
/// 사이 무리 없음, 배 회복 없음 — 한 마리가 죽으면 다음 보스가 standoff 원 바로 밖에서 나온다(걸어오는 시간을 줄임).
/// 다 잡으면(cleared) 걸린 틱이 기록, 침몰·그만두기·앱 종료면 잡은 수만큼 보상. 그동안 본 전투는 멈춘다(scene_mode).
abstract final class TopRush {
  static GameState? prepare(GameState s, Field f, SystemContext ctx, {required bool fresh}) {
    final active = s.rush?.active;
    if (active == null) {
      if (f.rush != null) reset(f, ctx);
      return null;
    }
    if (f.rush != null) return null;
    final bosses = rushBosses(ctx.tables, s.rush!.week ?? rushWeek(ctx.clock.now()));
    f
      ..foes.clear()
      ..zones.clear()
      ..bossActive = false
      ..rush = RushRun(bosses: bosses, index: active.index, ticks: active.ticks);
    if (fresh) return _end(s, f, ctx, 'interrupted');
    ctx.emit(RushStarted(ctx.tick, bosses: bosses));
    _spawn(s, f, ctx);
    return s;
  }

  /// 러시 한 틱 뒤: 틱 +1, 침몰 → 끝, 보스가 죽었으면 RushBossDown → 다음 보스 또는 끝(cleared).
  static GameState resolve(GameState s, Field f, SystemContext ctx) {
    final run = f.rush;
    final r = s.rush;
    if (run == null || r?.active == null) return s;
    run.ticks += 1;
    if (f.shipHp.isZero) return _end(s, f, ctx, 'sunk');
    if (f.foes.any((e) => e.boss && e.alive)) return s.copyWith(rush: r!.copyWith(active: _active(run)));
    ctx.emit(RushBossDown(ctx.tick, index: run.index, bossId: run.bosses[run.index], ticks: run.ticks));
    run.index += 1;
    if (run.index >= run.bosses.length) return _end(s, f, ctx, 'cleared');
    f
      ..foes.removeWhere((e) => !e.alive)
      ..bossActive = false;
    _spawn(s, f, ctx);
    return s.copyWith(rush: r!.copyWith(active: _active(run)));
  }

  static GameState retreat(GameState s, Field f, SystemContext ctx) =>
      f.rush == null || s.rush?.active == null ? s : _end(s, f, ctx, 'retreat');

  static RushActive _active(RushRun run) => RushActive(index: run.index, ticks: run.ticks);

  /// 지금 차례 보스를 기준 스테이지(최고 스테이지 × stageRatio, 최소 1)로, standoff 원 바로 밖(배 위쪽)에 띄운다.
  static void _spawn(GameState s, Field f, SystemContext ctx) {
    final t = ctx.tables;
    final run = f.rush!;
    final id = run.bosses[run.index];
    final c = rushCfg(t);
    final stage = math.max(1, (s.progress.bestStage * c.number('stageRatio')).floor());
    final def = t.regions.bosses[id];
    final hp = sceneHp(
      s,
      t,
      c,
      activeFleet(s, t),
      bossMaxHp(t, stage, def: def, hpScale: c.number('hpMultiplier') * f.enemyHpScale),
      c.numberOr('rushBossSec', 0),
    );
    final g = f.geometry;
    final top = g is TopGeometry ? g.top : null;
    startBoss(
      f,
      stage,
      ctx,
      emit: false, // 해역 보스 컷인 대신 RushStarted·RushBossDown(렌더 짧은 컷인)
      bossDef: def,
      maxHp: hp, // max(스테이지 HP × hpMultiplier, 함대 DPS × rushBossSec × dpsHpRatio)
      gold: false,
      x: top?.shipX,
      y: top == null ? null : top.shipY - bossStandoffFor(t, id) - top.bossRadius,
    );
  }

  static GameState _end(GameState s, Field f, SystemContext ctx, String reason) {
    final run = f.rush!;
    final cleared = reason == 'cleared';
    final paid = rushReward(s, ctx.tables, run.index, run.ticks, cleared: cleared);
    ctx.emit(
      RushEnded(
        ctx.tick,
        killed: run.index,
        ticks: run.ticks,
        reason: reason,
        gems: paid.gems,
        pieces: paid.pieces,
        best: paid.best,
      ),
    );
    reset(f, ctx);
    return paid.state.copyWith(rush: paid.state.rush!.copyWith(clearActive: true));
  }

  /// 본 전투로 돌아간다: 같은 스테이지 빈 바다, 배 수리, 이동 뒤 다음 파.
  static void reset(Field f, SystemContext ctx) {
    f
      ..foes.clear()
      ..zones.clear()
      ..bossActive = false
      ..bossTicksLeft = 0
      ..rush = null
      ..shipHp = f.shipHpMax
      ..travelLeft = ctx.tables.waves.travelSec;
  }
}
