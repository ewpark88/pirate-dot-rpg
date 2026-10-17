import 'dart:math' as math;

import 'package:game_core/src/battle/field.dart';
import 'package:game_core/src/battle/spawner.dart' show startBoss;
import 'package:game_core/src/economy/bounty.dart' show bountyBossHp, bountyReward, grantBountyReward;
import 'package:game_core/src/economy/rebirth_shop.dart' show bossExtraSec;
import 'package:game_core/src/engine/events.dart';
import 'package:game_core/src/engine/game_engine.dart';
import 'package:game_core/src/engine/game_state.dart';
import 'package:game_core/src/engine/state_bounty.dart';

/// 현상금 전투 (탑다운, 계획 docs/plans/active/platform-bounty-topdown.md B1 — S1 결정: 피버 멈춤·standoff 100·침몰 = 실패+반환).
///
/// 경제가 `StartBounty`로 티켓을 쓰고 `bounty.active`를 정하면, 다음 틱에 전장을 현상금 보스 하나로 바꾼다
/// (본 보스 규칙 그대로: 위쪽 출발 → standoff 원 → 원거리 공격). 그동안 본 전투(스테이지·파·골드·피버·돌발 이벤트)는 멈춘다.
/// 끝(처치·시간 초과·후퇴·침몰)나면 이벤트를 내고 같은 스테이지 빈 바다로 돌아간다. 실패는 모두 티켓을 돌려준다.
abstract final class TopBounty {
  /// 전투 계산 전에 부른다. [fresh] = 이번 틱에 전장을 새로 만들었다(앱을 켜서 세이브를 불러옴).
  /// 세이브에 남은 active(앱이 꺼졌던 것)면 중단 실패 처리한 상태를, 새로 시작된 현상금이면 전장을 그 보스 하나로 바꾼
  /// 상태를 돌려준다(둘 다 이번 틱은 전투 계산 없이 화면 반영만). 그 밖에는 null(그대로 전투).
  static GameState? prepare(GameState s, Field f, SystemContext ctx, {required bool fresh}) {
    final active = s.bounty?.active;
    if (active == null) {
      if (f.bounty != null) _reset(f, ctx); // 운영자 등으로 active가 지워졌다
      return null;
    }
    if (f.bounty != null) return null;
    if (fresh) return _fail(s, f, ctx, active, 'interrupted', 0);
    _begin(s, f, ctx, active);
    return s; // 이번 틱은 보스를 띄우고 화면에 반영만 — 전장이 화면과 어긋나 새로 만들어지지 않게
  }

  /// 현상금 전투 한 틱이 끝난 뒤: 처치·시간 초과·침몰 판정. 이 틱은 본 판정·돌발 이벤트·피버를 건너뛴다(S1: 피버 멈춤).
  static GameState resolve(GameState s, Field f, SystemContext ctx) {
    final run = f.bounty;
    final active = s.bounty?.active;
    if (run == null || active == null) return s;
    final boss = f.foes.where((e) => e.boss).firstOrNull;
    if (boss == null || !boss.alive) return _clear(s, f, ctx, active);
    f.bossTicksLeft -= 1;
    if (f.shipHp.isZero) return _fail(s, f, ctx, active, 'sunk', _ratio(f));
    if (f.bossTicksLeft <= 0) return _fail(s, f, ctx, active, 'timeout', _ratio(f));
    return s;
  }

  /// 후퇴(RetreatBounty) — 현상금 중이 아니면 그대로.
  static GameState retreat(GameState s, Field f, SystemContext ctx) {
    final active = s.bounty?.active;
    if (f.bounty == null || active == null) return s;
    return _fail(s, f, ctx, active, 'retreat', _ratio(f));
  }

  static void _begin(GameState s, Field f, SystemContext ctx, BountyActive a) {
    final t = ctx.tables;
    f
      ..foes.clear()
      ..zones.clear()
      ..bossActive = false;
    startBoss(
      f,
      a.tier * t.meta.raw.obj('bounty').integer('stagePerTier'), // 공격력 곡선 = 같은 단계 스테이지
      ctx,
      emit: false, // 해역 보스 컷인 대신 BountyStarted(수배 포스터, 렌더 B3)
      bossDef: t.regions.bosses[a.bossId],
      maxHp: bountyBossHp(t, a.bossId, a.tier),
      gold: false,
      extraSec: bossExtraSec(s, t),
    );
    f.bounty = (bossId: a.bossId, tier: a.tier);
    ctx.emit(BountyStarted(ctx.tick, bossId: a.bossId, tier: a.tier, timeLimitTicks: f.bossTicksLeft));
  }

  static GameState _clear(GameState s, Field f, SystemContext ctx, BountyActive a) {
    final t = ctx.tables;
    final reward = bountyReward(s, t, a.bossId, a.tier, ctx.rng);
    final b = s.bounty!;
    final paid = grantBountyReward(s, ctx, reward);
    ctx.emit(BountyCleared(ctx.tick, bossId: a.bossId, tier: a.tier, reward: reward));
    _reset(f, ctx);
    return paid.copyWith(
      bounty: (paid.bounty ?? b).copyWith(
        cleared: {...b.cleared, a.bossId: math.max(b.cleared[a.bossId] ?? 0, a.tier)},
        progress: {...b.progress}..remove(a.bossId), // 다음 단계 막대는 처음부터
        clearActive: true,
      ),
    );
  }

  /// 실패: 티켓을 돌려주고, 시간 초과·후퇴·침몰이면 입힌 피해 비율을 다음 단계 막대에 남긴다(더 크면).
  static GameState _fail(GameState s, Field f, SystemContext ctx, BountyActive a, String reason, double ratio) {
    final b = s.bounty!;
    ctx.emit(BountyFailed(ctx.tick, bossId: a.bossId, tier: a.tier, damageRatio: ratio, reason: reason));
    _reset(f, ctx);
    return s.copyWith(
      bounty: b.copyWith(
        tickets: b.tickets + 1,
        progress: {...b.progress, a.bossId: math.max(b.progress[a.bossId] ?? 0, ratio)},
        clearActive: true,
      ),
    );
  }

  /// 입힌 피해 비율 0~1.
  static double _ratio(Field f) {
    final boss = f.foes.where((e) => e.boss).firstOrNull;
    return boss == null ? 1 : (1 - (boss.hp / boss.maxHp).toDouble()).clamp(0, 1).toDouble();
  }

  /// 본 전투로 돌아간다: 같은 스테이지 빈 바다, 배 수리, 이동 뒤 다음 파.
  static void _reset(Field f, SystemContext ctx) {
    f
      ..foes.clear()
      ..zones.clear()
      ..bossActive = false
      ..bossTicksLeft = 0
      ..bounty = null
      ..shipHp = f.shipHpMax
      ..travelLeft = ctx.tables.waves.travelSec;
  }
}
