import 'dart:math' as math;

import 'package:game_core/src/battle/combat.dart';
import 'package:game_core/src/bignum/big_num.dart';
import 'package:game_core/src/engine/events.dart';

/// 배 흡수막 (선원 개성 v2 7.1 — turtle 보호막). 배 피해는 막이 먼저 받는다(Field.hurtShip).
class ShipShield {
  ShipShield({required this.crewId, required this.hp, required this.ticksLeft}) : full = hp;

  final String crewId;
  BigNum hp;
  final BigNum full;
  int ticksLeft;

  /// 남은 막 0~1 (BattleView.shipShield).
  double get ratio => full.isZero ? 0 : (hp / full).toDouble().clamp(0, 1).toDouble();
}

extension ShieldRound on Round {
  /// 매 틱: 보호막 선원의 주기(everySec)마다 막을 세우고(큰 쪽으로 갱신), 시간이 끝나거나 다 깎이면 거둔다.
  void tickShield() {
    final s = field.shield;
    if (s != null) {
      s.ticksLeft -= 1;
      if (s.hp.isZero || s.ticksLeft <= 0) {
        field.shield = null;
        ctx.emit(ShieldBroken(ctx.tick, crewId: s.crewId, reason: s.hp.isZero ? 'depleted' : 'expired'));
      }
    }
    for (final g in field.guns) {
      final def = g.legend?.shield;
      if (def == null) continue;
      g.shieldTimer -= dt;
      if (g.shieldTimer > 0) continue;
      g.shieldTimer += def.everySec;
      final hp = field.shipHpMax.times(def.hpRatio);
      final now = field.shield;
      if (now != null && now.hp > hp) continue; // 겹치지 않음 — 큰 쪽
      final ticks = math.max(1, (def.durationSec / dt).round());
      field.shield = ShipShield(crewId: g.crewId, hp: hp, ticksLeft: ticks);
      ctx.emit(ShieldUp(ctx.tick, crewId: g.crewId, hp: hp, ticks: ticks));
    }
  }
}
