import 'dart:math' as math;

import 'package:game_core/src/battle/combat.dart';
import 'package:game_core/src/battle/topdown/top_fever.dart';
import 'package:game_core/src/battle/topdown/top_geometry.dart';
import 'package:game_core/src/bignum/big_num.dart';
import 'package:game_core/src/engine/events.dart';
import 'package:game_core/src/engine/game_state.dart';

/// 날아가는 적 탄 (배 위협 (a)) — [ticksLeft] 뒤 배에 [amount] 피해.
class EnemyShot {
  EnemyShot({required this.ticksLeft, required this.amount, required this.fromX, required this.fromY});

  int ticksLeft;
  final BigNum amount;
  final double fromX;
  final double fromY;
}

/// 탑다운 전투의 틱마다 추가 단계: 피버 오라 + 배 위협(docs/specs/platform-ship-threat.md).
extension TopdownStep on Round {
  void topdownStep(GameState s) {
    feverAura(s);
    _emerge();
    _enemyFire();
    _enemyShots();
  }

  /// (b) 가까이 등장: 대기가 예고 시간(warnSec) 안으로 들어오면 솟아오를 자리로 옮기고 예고를 낸다.
  void _emerge() {
    final g = geo;
    if (g is! TopGeometry) return;
    final ns = g.top.nearSpawn;
    if (ns == null) return;
    for (final e in field.living) {
      final nx = e.nearX;
      if (nx == null || e.warned || e.holdSec > ns.warnSec) continue;
      e
        ..x = nx
        ..y = e.nearY!
        ..warned = true;
      ctx.emit(
        EnemyEmerging(ctx.tick, enemyId: e.id, x: e.x, y: e.y, warnTicks: math.max(1, (e.holdSec / dt).round())),
      );
    }
  }

  /// (a) 원거리 적: 배 몸통에서 range 안이면 intervalSec마다 탄을 쏜다(다가오면서 — 멈추지 않음). 기절·대기 중엔 안 쏜다.
  void _enemyFire() {
    final g = geo;
    if (g is! TopGeometry) return;
    for (final e in field.living) {
      final r = e.def?.ranged;
      if (r == null || e.boss || e.stunned || e.holdSec > 0 || e.passX != null) continue;
      final gap = g.hullGap(e.x, e.y) - g.top.radiusOf(e);
      if (gap > r.number('range')) continue;
      e.fireTimer -= dt;
      if (e.fireTimer > 0) continue;
      e.fireTimer += r.number('intervalSec');
      final flight = math.max(1, (math.max(gap, 0) / r.number('projectileSpeed') / dt).round());
      field.enemyShots.add(
        EnemyShot(ticksLeft: flight, amount: e.attack.times(r.number('damageRatio')), fromX: e.x, fromY: e.y),
      );
      ctx.emit(
        EnemyFired(ctx.tick, enemyId: e.id, fromX: e.x, fromY: e.y, flightTicks: flight, kind: r.str('kind')),
      );
    }
  }

  /// 날아가는 적 탄: 도착하면 배 피해(무적이면 없음).
  void _enemyShots() {
    for (final shot in List.of(field.enemyShots)) {
      shot.ticksLeft -= 1;
      if (shot.ticksLeft > 0) continue;
      field.enemyShots.remove(shot);
      if (invincible) continue;
      final amount = field.hurtShip(shot.amount, w.raw.number('shipHitCap'));
      ctx.emit(
        ShipDamaged(
          ctx.tick,
          amount: amount,
          hpRatio: (field.shipHp / field.shipHpMax).toDouble(),
          fromX: shot.fromX,
          fromY: shot.fromY,
        ),
      );
    }
  }
}
