import 'dart:math' as math;

import 'package:game_core/src/battle/bosses.dart';
import 'package:game_core/src/battle/combat.dart';
import 'package:game_core/src/battle/combat_stats.dart';
import 'package:game_core/src/battle/field.dart';
import 'package:game_core/src/battle/spawner.dart' show stageCurve;
import 'package:game_core/src/battle/topdown/top_geometry.dart';
import 'package:game_core/src/bignum/big_num.dart';
import 'package:game_core/src/economy/rebirth_shop.dart' show fastSailFraction;
import 'package:game_core/src/engine/battle_view.dart';
import 'package:game_core/src/engine/events.dart';
import 'package:game_core/src/engine/game_engine.dart';
import 'package:game_core/src/engine/game_state.dart';
import 'package:game_data/game_data.dart';

/// 빠른 항해 돌파 구간 (docs/specs/platform-fast-sail-breakthrough.md, 사용자 결정 2026-10-16).
class FastSailRun {
  FastSailRun({required this.from, required this.to, required this.startGold, required this.startGems});

  final int from;
  final int to;
  final BigNum startGold;
  final int startGems;

  /// 이번 구간 연속 격파 수.
  int combo = 0;

  /// 지금 보스가 나온 뒤 지난 틱(돌파 사격 시각).
  int bossTicks = 0;

  /// 지금 보스(스테이지마다 전장을 새로 만들어 id가 겹치므로 객체로 본다).
  Foe? boss;

  /// 격파 이벤트를 이미 낸 보스(같은 보스로 두 번 내지 않게).
  Foe? struck;

  /// 지금 리듬(다음 보스): build | rush | finale.
  String phase = 'build';
  double speed = 1;

  FastSailView view() => FastSailView(from: from, to: to, combo: combo, phase: phase, speed: speed);
}

/// 빠른 항해 범위의 끝 스테이지(환생 뒤 bestStage × fastSailFraction 올림). 환생 전이면 null.
int? fastSailEnd(GameState s, GameTables t) {
  final p = s.progress;
  return p.rebirths > 0 ? (p.bestStage * fastSailFraction(s, t)).ceil() : null;
}

extension FastSailRound on Round {
  /// 매 틱 끝: 구간을 열고, 보스를 standoff 원에 바로 세우고, breakSec 안에 못 잡으면 돌파 사격(남은 HP 전부 — 보통 처치 길이라
  /// 골드·카드 그대로), 격파 순간 BreakthroughStrike. 표에 breakSec가 없거나 현상금 중이면 아무것도 하지 않는다.
  void breakthrough(GameState s) {
    final rs = w.rebirthSkip;
    final end = fastSailEnd(s, t);
    if (rs.breakSec <= 0 || field.bounty != null || end == null) return;
    final p = s.progress;
    var run = field.fastSail;
    if (run == null) {
      if (p.stage > end) return;
      run = field.fastSail = FastSailRun(from: p.stage, to: end, startGold: s.wallet.gold, startGems: s.wallet.gems);
      ctx.emit(FastSailStarted(ctx.tick, from: p.stage, to: end));
    }
    // 리듬: 첫 breakSec에서 격파마다 × breakAccel, 최소 breakMinSec(rush), 마지막 스테이지는 finaleSec(finale). 이동도 같은 비율.
    final floor = rs.breakMinSec > 0 ? rs.breakMinSec : rs.breakSec;
    var sec = rs.breakSec * math.pow(rs.breakAccel, run.combo);
    if (sec < floor) sec = floor;
    final finale = p.stage >= run.to && rs.finaleSec > 0;
    run
      ..phase = finale ? 'finale' : (sec <= floor && floor < rs.breakSec ? 'rush' : 'build')
      ..speed = rs.breakSec / sec;
    final travel = rs.travelSec * sec / rs.breakSec;
    if (field.travelLeft > travel) field.travelLeft = travel;
    if (finale) sec = rs.finaleSec;
    final boss = field.foes.where((e) => e.boss).firstOrNull;
    if (boss == null || !field.bossActive) return;
    final g = geo;
    if (!identical(boss, run.boss)) {
      run
        ..boss = boss
        ..bossTicks = 0;
      if (g is TopGeometry) {
        boss
          ..x = g.top.shipX
          ..y = g.top.shipY - g.top.bossStandoff; // 걸어오지 않고 standoff 원에 바로
      }
    }
    if (boss.alive) {
      run.bossTicks += 1;
      if (run.bossTicks * dt >= sec) {
        // 돌파 사격: 보호막·장갑을 걷고 남은 HP만큼(받는 비율로 나눠) — 보통 strike라 처치 보상이 같다.
        boss.shielded = false;
        final k = guard(boss, null);
        if (k > 0) strike((x: boss.x, y: boss.y, hits: [(foe: boss, factor: 1.0)]), boss.hp.times(1 / k));
      }
    }
    if (!boss.alive && !identical(run.struck, boss)) {
      run
        ..struck = boss
        ..combo += 1;
      ctx.emit(
        BreakthroughStrike(
          ctx.tick,
          stage: p.stage,
          bossId: boss.kind,
          x: boss.x,
          y: boss.y,
          combo: run.combo,
          phase: run.phase,
          speed: run.speed,
        ),
      );
    }
  }
}

/// 건너뛸 때 [stage] 보스 한 마리 처치 골드(보스 골드 곡선 × 선박 골드 배율 — 보통 처치와 같은 식).
BigNum fastSailBossGold(GameState s, GameTables t, int stage) {
  final w = t.waves;
  return stageCurve(w.goldBase, w.goldGrowth, stage).times(w.bossGoldMultiplier * CombatStats.of(s, t).goldMultiplier);
}

/// 보스 처치로 스테이지가 [after]가 된 뒤: 구간 끝(to를 넘음)이면 FastSailEnded(얻은 골드·젬)를 내고 닫는다.
void closeFastSail(GameState after, Field f, SystemContext ctx, {bool skipped = false}) {
  final run = f.fastSail;
  if (run == null || (after.progress.stage <= run.to && !skipped)) return;
  final gold = after.wallet.gold - run.startGold;
  ctx.emit(
    FastSailEnded(
      ctx.tick,
      from: run.from,
      to: run.to,
      stages: after.progress.stage - run.from,
      gold: gold.isNegative ? BigNum.zero : gold,
      gems: after.wallet.gems - run.startGems,
      skipped: skipped,
    ),
  );
  f.fastSail = null;
}
