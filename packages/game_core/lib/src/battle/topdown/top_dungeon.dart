import 'dart:math' as math;

import 'package:game_core/src/battle/field.dart';
import 'package:game_core/src/battle/fleet.dart' show armField;
import 'package:game_core/src/battle/spawner.dart' show bossStandoffFor, spawnWave, startBoss;
import 'package:game_core/src/battle/topdown/top_geometry.dart';
import 'package:game_core/src/economy/dungeon.dart';
import 'package:game_core/src/economy/formation.dart' show activeFleet;
import 'package:game_core/src/engine/events.dart';
import 'package:game_core/src/engine/game_engine.dart';
import 'package:game_core/src/engine/game_state.dart';
import 'package:game_data/game_data.dart';

/// 요일 던전 전투 (docs/specs/platform-weekday-dungeon.md — S1 승인 2026-10-18).
///
/// 경제가 `StartDungeon`으로 도전을 쓰고 `dungeon.active`를 정하면, 다음 틱에 출전을 그 날 계열 선원으로 **전장에서만** 바꾸고
/// (세이브 fleet 그대로 — Field.sceneFleet) 단계 하나를 연다: 무리 wavesPerStep파(그 날 계열이 빛나는 자리 패턴·적 층) → 단계 보스
/// (그 날 계열이 약점인 보스). 깨면 계열 카드·젬, 침몰·그만두기·시간 초과·앱 종료면 실패(도전 돌려줌). 끝나면 원래 출전으로.
abstract final class TopDungeon {
  static GameState? prepare(GameState s, Field f, SystemContext ctx, {required bool fresh}) {
    final active = s.dungeon?.active;
    if (active == null) {
      if (f.dungeon != null) _reset(s, f, ctx);
      return null;
    }
    if (f.dungeon != null) return null;
    final t = ctx.tables;
    final g = dungeonGroupById(t, active.group);
    final crews = dungeonCrews(s, t, g);
    f
      ..foes.clear()
      ..zones.clear()
      ..bossActive = false
      ..dungeon = DungeonRun(group: active.group, step: active.step, waves: dungeonCfg(t).integer('wavesPerStep'))
      ..sceneFleet = crews
      ..scenePattern = g.str('pattern')
      ..sceneHpMul = g.numberOr('hpMul', 1); // 선원 2명 계열이 낀 날은 적을 가볍게(S2)
    if (fresh) return _fail(s, f, ctx, 'interrupted');
    armField(f, s, t, crews);
    ctx.emit(DungeonStarted(ctx.tick, group: active.group, step: active.step, crewIds: crews));
    _nextWave(s, f, ctx);
    return s;
  }

  static GameState resolve(GameState s, Field f, SystemContext ctx) {
    final run = f.dungeon;
    if (run == null || s.dungeon?.active == null) return s;
    if (f.shipHp.isZero) return _fail(s, f, ctx, 'sunk');
    run.ticks += 1;
    final limit = dungeonCfg(ctx.tables).number('stepTimeLimitSec') * Duration.millisecondsPerSecond;
    if (run.ticks * ctx.tables.waves.tickMs > limit) return _fail(s, f, ctx, 'timeout');
    if (f.living.isNotEmpty) return s;
    if (run.wave < run.waves) {
      _nextWave(s, f, ctx);
      return s;
    }
    if (!run.boss) {
      _boss(s, f, ctx);
      return s;
    }
    return _cleared(s, f, ctx);
  }

  static GameState retreat(GameState s, Field f, SystemContext ctx) =>
      f.dungeon == null || s.dungeon?.active == null ? s : _fail(s, f, ctx, 'retreat');

  /// 단계 기준 스테이지: max(1, floor(최고 × stageRatio)) + 단계 × stepStage.
  static int _stage(GameState s, GameTables t, int step) {
    final c = dungeonCfg(t);
    return math.max(1, (s.progress.bestStage * c.number('stageRatio')).floor()) + step * c.integer('stepStage');
  }

  static void _nextWave(GameState s, Field f, SystemContext ctx) {
    final t = ctx.tables;
    final run = f.dungeon!;
    final c = dungeonCfg(t);
    final g = dungeonGroupById(t, run.group);
    final stage = _stage(s, t, run.step);
    final n = math.min(
      c.integer('maxCount'),
      (c.number('baseCount') * math.pow(c.number('countGrowth'), run.step - 1)).round(),
    );
    // 적 층(물속·하늘 날): 그 해역 적 가운데 그 층만 — 없으면 해역 그대로.
    final layer = g.has('layer') ? g.str('layer') : null;
    final kinds = [
      for (final id in t.regions.regionAt(stage).enemies)
        if (layer == null || t.regions.enemies[id]?.layer == layer) id,
    ];
    final before = f.foes.length;
    spawnWave(
      f,
      stage,
      ctx,
      count: n,
      kind: kinds.isEmpty || layer == null ? null : kinds[ctx.rng.nextInt(kinds.length)],
    );
    final geo = f.geometry;
    if (geo is TopGeometry) {
      final mul = c.number('spawnDistanceMul'); // 화면 가장자리 바로 밖에서(탑과 같음)
      for (final e in f.foes.skip(before)) {
        e
          ..x = geo.top.shipX + (e.x - geo.top.shipX) * mul
          ..y = geo.top.shipY + (e.y - geo.top.shipY) * mul;
      }
    }
    run.wave += 1;
  }

  /// 단계 보스: 그 날 계열이 약점인 보스(id 순서로 첫째, 일요일·없으면 그 해역 보스) — standoff 바로 밖에서.
  static void _boss(GameState s, Field f, SystemContext ctx) {
    final t = ctx.tables;
    final run = f.dungeon!;
    final families = dungeonGroupById(t, run.group).strs('families');
    final stage = _stage(s, t, run.step);
    final ids = t.regions.bosses.keys.toList()..sort();
    final weak = ids.where((id) => t.regions.bosses[id]!.weakFamilies.any(families.contains)).firstOrNull;
    final id = weak ?? t.regions.regionAt(stage).boss;
    final geo = f.geometry;
    final top = geo is TopGeometry ? geo.top : null;
    startBoss(
      f,
      stage,
      ctx,
      emit: false,
      bossDef: t.regions.bosses[id],
      gold: false,
      x: top?.shipX,
      y: top == null ? null : top.shipY - bossStandoffFor(t, id) - top.bossRadius,
    );
    run.boss = true;
  }

  static GameState _cleared(GameState s, Field f, SystemContext ctx) {
    final run = f.dungeon!;
    final d = s.dungeon!;
    final paid = dungeonReward(s, ctx, dungeonGroupById(ctx.tables, run.group), run.step);
    final cleared = {...d.cleared, run.group: math.max(d.cleared[run.group] ?? 0, run.step)};
    _reset(paid, f, ctx);
    return paid.copyWith(dungeon: paid.dungeon!.copyWith(cleared: cleared, clearActive: true));
  }

  /// 실패: 도전을 돌려준다(현상금과 같음 — 던전은 깨야 보상이라 실패에 남는 것이 없다).
  static GameState _fail(GameState s, Field f, SystemContext ctx, String reason) {
    final run = f.dungeon!;
    final d = s.dungeon!;
    ctx.emit(DungeonFailed(ctx.tick, group: run.group, step: run.step, reason: reason));
    _reset(s, f, ctx);
    return s.copyWith(dungeon: d.copyWith(tickets: d.tickets + 1, clearActive: true));
  }

  /// 본 전투로: 같은 스테이지 빈 바다, 배 수리, 원래 출전으로 다시 무장.
  static void _reset(GameState s, Field f, SystemContext ctx) {
    f
      ..foes.clear()
      ..zones.clear()
      ..bossActive = false
      ..bossTicksLeft = 0
      ..dungeon = null
      ..sceneFleet = null
      ..scenePattern = null
      ..sceneHpMul = 1
      ..shipHp = f.shipHpMax
      ..travelLeft = ctx.tables.waves.travelSec;
    armField(f, s, ctx.tables, activeFleet(s, ctx.tables));
  }
}
