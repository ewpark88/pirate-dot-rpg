import 'dart:math' as math;

import 'package:game_core/src/battle/field.dart';
import 'package:game_core/src/battle/spawner.dart' show bossStandoffFor, spawnWave, startBoss;
import 'package:game_core/src/battle/topdown/scene_spawn.dart';
import 'package:game_core/src/battle/topdown/top_geometry.dart';
import 'package:game_core/src/bignum/big_num.dart';
import 'package:game_core/src/economy/tower.dart';
import 'package:game_core/src/engine/events.dart';
import 'package:game_core/src/engine/game_engine.dart';
import 'package:game_core/src/engine/game_state.dart';
import 'package:game_core/src/engine/state_parts.dart';

/// 심연의 탑 전투 (docs/specs/platform-content-v2.md 4절, 요청 platform-tower.md 5절).
///
/// 경제가 `StartTower`로 도전권을 쓰고 `tower.active`를 정하면, 다음 틱에 전장을 탑으로 바꾼다. 층 = 무리 파 wavesPerFloor개
/// (마리 수 baseCount × countGrowth^(층−1), 상한 maxCount — 그 층 기준 스테이지의 보통 무리 한 마리 값, 골드 없음),
/// bossEvery층마다 마지막에 순환 보스. 층을 깨면 첫 클리어 보상·배 healRatio 회복, 침몰하면 끝(도달 층 상자).
/// 그동안 본 전투(스테이지·파·골드·피버·돌발 이벤트)는 멈추고, 끝나면 같은 스테이지 빈 바다로 돌아간다(현상금과 같음).
abstract final class TopTower {
  /// 전투 계산 전. 세이브에 남은 active(앱이 꺼졌던 것)면 중단 처리, 새로 시작이면 장면을 연다(이번 틱은 화면 반영만).
  static GameState? prepare(GameState s, Field f, SystemContext ctx, {required bool fresh}) {
    final active = s.tower?.active;
    if (active == null) {
      if (f.tower != null) _reset(f, ctx); // 운영자 등으로 active가 지워졌다
      return null;
    }
    if (f.tower != null) return null;
    final c = towerCfg(ctx.tables);
    f
      ..foes.clear()
      ..zones.clear()
      ..bossActive = false
      ..tower = TowerRun(floor: active.floor, waves: c.integer('wavesPerFloor'));
    if (fresh) return _end(s, f, ctx, 'interrupted');
    ctx.emit(TowerStarted(ctx.tick, floor: active.floor));
    _nextWave(s, f, ctx);
    return s;
  }

  /// 탑 한 틱이 끝난 뒤: 침몰 → 끝, 남은 적이 없으면 다음 파 → 보스 → 층 클리어.
  static GameState resolve(GameState s, Field f, SystemContext ctx) {
    final run = f.tower;
    if (run == null || s.tower?.active == null) return s;
    if (f.shipHp.isZero) return _end(s, f, ctx, 'sunk');
    run.floorTicks += 1; // 안전판: 한 층이 floorTimeLimitSec를 넘으면 그 층까지 기록하고 끝(timeout)
    if (run.floorTicks * ctx.tables.waves.tickMs >
        towerCfg(ctx.tables).number('floorTimeLimitSec') * Duration.millisecondsPerSecond) {
      return _end(s, f, ctx, 'timeout');
    }
    if (f.living.isNotEmpty) return s;
    if (run.wave < run.waves) {
      _nextWave(s, f, ctx);
      return s;
    }
    final c = towerCfg(ctx.tables);
    if (!run.boss && run.floor % c.integer('bossEvery') == 0) {
      _boss(s, f, ctx);
      return s;
    }
    return _floorCleared(s, f, ctx);
  }

  /// 그만두기(RetreatTower) — 탑 중이 아니면 그대로.
  static GameState retreat(GameState s, Field f, SystemContext ctx) =>
      f.tower == null || s.tower?.active == null ? s : _end(s, f, ctx, 'retreat');

  /// 이 층 기준 스테이지: max(1, floor(최고 × stageRatio)) + 층 + max(0, 층 − floorStageFrom) × (floorStageMul − 1)
  /// — floorStageFrom층까지는 층마다 +1, 그 뒤로는 +floorStageMul씩 올라 센 함대도 끝난다(S2 2026-10-18, 한 판 10~15분 목표).
  static int _stage(GameState s, SystemContext ctx, int floor) {
    final c = towerCfg(ctx.tables);
    final steep = math.max(0, floor - c.integer('floorStageFrom')) * (c.integer('floorStageMul') - 1);
    return math.max(1, (s.progress.bestStage * c.number('stageRatio')).floor()) + floor + steep;
  }

  static void _nextWave(GameState s, Field f, SystemContext ctx) {
    final run = f.tower!;
    final c = towerCfg(ctx.tables);
    final n = math.min(
      c.integer('maxCount'),
      (c.number('baseCount') * math.pow(c.number('countGrowth'), run.floor - 1)).round(),
    );
    final before = f.foes.length;
    spawnWave(f, _stage(s, ctx, run.floor), ctx, count: n); // 장면 모드라 골드 없음(spawnWaveFoes)
    sceneSpawnAtView(f, before); // 화면 가장자리 바로 밖에서 몰려오게(S3: 멀리서 걸어와 층당 25초로 느림)
    run
      ..wave += 1
      ..spawned += f.foes.length - before;
  }

  static void _boss(GameState s, Field f, SystemContext ctx) {
    final run = f.tower!;
    final stage = _stage(s, ctx, run.floor);
    final r = ctx.tables.regions.regionAt(stage);
    final id = r.bossRotation.isEmpty ? r.boss : r.bossRotation[run.floor % r.bossRotation.length];
    final g = f.geometry;
    final top = g is TopGeometry ? g.top : null; // 걸어오는 시간 없이 standoff 원 바로 밖에서(S1)
    startBoss(
      f,
      stage,
      ctx,
      emit: false,
      bossDef: ctx.tables.regions.bosses[id],
      hpScale: towerCfg(ctx.tables).number('bossHpMul'), // 층 보스는 가볍게 — 보스 층이 다른 층의 2배 걸리던 것(S2)
      gold: false,
      x: top?.shipX,
      y: top == null ? null : top.shipY - bossStandoffFor(ctx.tables, id) - top.bossRadius,
    );
    run
      ..boss = true
      ..spawned += 1;
  }

  /// 층 클리어: 첫 클리어면 보상, 배 회복, 다음 층 첫 파.
  static GameState _floorCleared(GameState s, Field f, SystemContext ctx) {
    final run = f.tower!;
    final w = s.tower!;
    final first = run.floor > w.firstCleared;
    final reward = first ? towerFirstClear(ctx.tables, run.floor) : (gems: 0, cards: 0);
    ctx.emit(TowerFloorCleared(ctx.tick, floor: run.floor, gems: reward.gems, cards: reward.cards));
    final paid = grantTowerReward(s, ctx, reward.gems, reward.cards);
    f
      ..bossActive = false
      ..shipHp = BigNum.min(f.shipHpMax, f.shipHp + f.shipHpMax.times(towerCfg(ctx.tables).number('healRatio')));
    final cleared = run.floor;
    run
      ..floor += 1
      ..wave = 0
      ..floorTicks = 0
      ..boss = false;
    _nextWave(paid, f, ctx);
    return paid.copyWith(
      tower: w.copyWith(
        best: math.max(w.best, cleared),
        firstCleared: math.max(w.firstCleared, cleared),
        active: TowerActive(floor: run.floor),
      ),
    );
  }

  /// 끝: 마지막으로 깬 층의 상자, 최고 층 기록, 본 전투로.
  static GameState _end(GameState s, Field f, SystemContext ctx, String reason) {
    final run = f.tower!;
    final w = s.tower!;
    final reached = run.floor - 1;
    final chest = towerChest(ctx.tables, reached);
    final kills = run.spawned - f.living.length;
    ctx.emit(
      TowerEnded(
        ctx.tick,
        floor: reached,
        reason: reason,
        kills: math.max(0, kills),
        chestGems: chest.gems,
        chestCards: chest.cards,
      ),
    );
    _reset(f, ctx);
    final paid = grantTowerReward(s, ctx, chest.gems, chest.cards);
    return paid.copyWith(tower: w.copyWith(best: math.max(w.best, reached), clearActive: true));
  }

  /// 본 전투로 돌아간다: 같은 스테이지 빈 바다, 배 수리, 이동 뒤 다음 파.
  static void _reset(Field f, SystemContext ctx) {
    f
      ..foes.clear()
      ..zones.clear()
      ..bossActive = false
      ..bossTicksLeft = 0
      ..tower = null
      ..shipHp = f.shipHpMax
      ..travelLeft = ctx.tables.waves.travelSec;
  }
}
