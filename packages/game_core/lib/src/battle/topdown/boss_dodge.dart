import 'dart:math' as math;

import 'package:game_core/src/battle/combat.dart';
import 'package:game_core/src/battle/field.dart';
import 'package:game_core/src/battle/topdown/boss_patterns.dart';
import 'package:game_core/src/battle/topdown/top_geometry.dart';
import 'package:game_core/src/engine/events.dart';
import 'package:game_data/game_data.dart';

/// 보스 공격 진짜 회피(docs/plans/active/platform-boss-dodge.md — waves.top.bossDodge {shellRadius, chargeOvershoot}):
/// 예고가 시작되는 틱에 배 자리를 조준으로 고정하고(BossPlan.aimX·aimY), 탄 일제 사격은 그 자리로 날아가 도착 때 배 몸통과
/// shellRadius 안이어야, 폭발 원은 그 자리를 중심으로 몸통이 원에 걸려야, 돌진은 그 방향으로 곧게 가다 몸통에 닿아야 맞는다.
/// 빗나가면 BossAttackMissed. 패턴에 homing: true면 지금처럼 늘 맞는다. 표 키가 없으면 아무것도 바뀌지 않는다.
/// 배는 예고 중 결투 비켜서기(bossDuel.dodge — 보스 방향의 옆으로 일직선)로 비킨다.
extension BossDodge on Round {
  JsonReader? get _dodge {
    final top = w.raw.obj('top');
    return top.has('bossDodge') ? top.obj('bossDodge') : null;
  }

  /// 이 패턴을 회피 규칙으로 판정하나.
  bool dodgeable(BossPatternDef p) => _dodge != null && !p.homing;

  /// 예고 시작: 조준을 지금 배 자리로 고정한다(회피 규칙일 때만 판정에 쓰인다).
  void aimAt(BossPlan plan, TopGeometry g) {
    plan
      ..aimX = g.top.shipX
      ..aimY = g.top.shipY;
  }

  /// 일제 사격 탄 하나: 회피 규칙이면 조준 자리를 싣는다.
  EnemyShot bossShell(Foe e, BossPlan plan, BossPatternDef p, int flight) => EnemyShot(
    ticksLeft: flight,
    amount: e.attack.times(p.damageRatio),
    fromX: e.x,
    fromY: e.y,
    aimX: dodgeable(p) ? plan.aimX : null,
    aimY: dodgeable(p) ? plan.aimY : null,
    enemyId: e.id,
  );

  /// 탄 도착: 조준이 없으면(지금 규칙) 맞음. 있으면 몸통이 조준 자리에서 shellRadius 안일 때만 — 아니면 빗나감 이벤트.
  bool shellHits(EnemyShot shot) {
    final g = geo;
    final x = shot.aimX;
    final y = shot.aimY;
    final d = _dodge;
    if (x == null || y == null || d == null || g is! TopGeometry) return true;
    if (g.hullGap(x, y) <= d.number('shellRadius')) return true;
    ctx.emit(BossAttackMissed(ctx.tick, enemyId: shot.enemyId ?? -1, kind: 'volley', x: x, y: y));
    return false;
  }

  /// 폭발 원: 회피 규칙이면 조준 자리 중심 원(shipRadius × radiusShipMul)에 몸통이 걸릴 때만.
  bool blastHits(Foe e, BossPlan plan, BossPatternDef p, TopGeometry g) {
    final x = plan.aimX;
    final y = plan.aimY;
    if (!dodgeable(p) || x == null || y == null) return true;
    if (g.hullGap(x, y) <= g.top.shipRadius * p.radiusShipMul) return true;
    ctx.emit(BossAttackMissed(ctx.tick, enemyId: e.id, kind: 'blast', x: x, y: y));
    return false;
  }

  /// 돌진 시작: 회피 규칙이면 조준 방향으로 곧게(조준까지 거리 + chargeOvershoot) — 따라오지 않는다.
  void lockCharge(Foe e, BossPlan plan, BossPatternDef p) {
    final x = plan.aimX;
    final y = plan.aimY;
    final d = _dodge;
    if (!dodgeable(p) || x == null || y == null || d == null) {
      plan.chargeLeft = null;
      return;
    }
    final dx = x - e.x;
    final dy = y - e.y;
    final len = math.sqrt(dx * dx + dy * dy);
    plan
      ..dirX = len == 0 ? 0 : dx / len
      ..dirY = len == 0 ? 0 : dy / len
      ..chargeLeft = len + d.number('chargeOvershoot');
  }

  /// 곧은 돌진 한 틱: [step]만큼. 몸통에 닿으면 true(맞음). 다 갔는데 못 닿으면 빗나감 이벤트 후 false(남은 거리 0).
  bool straightCharge(Foe e, BossPlan plan, double step, TopGeometry g) {
    final left = plan.chargeLeft ?? 0;
    final s = math.min(step, left);
    e
      ..x += plan.dirX * s
      ..y += plan.dirY * s;
    plan.chargeLeft = left - s;
    if (g.hullGap(e.x, e.y) <= g.top.radiusOf(e)) return true;
    if (left - s <= 0) ctx.emit(BossAttackMissed(ctx.tick, enemyId: e.id, kind: 'charge', x: e.x, y: e.y));
    return false;
  }
}
