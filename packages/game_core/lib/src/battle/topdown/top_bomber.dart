import 'package:game_core/src/battle/combat.dart';
import 'package:game_core/src/battle/targeting.dart';
import 'package:game_core/src/battle/topdown/top_geometry.dart';
import 'package:game_core/src/engine/events.dart';

/// 자폭 적(도감 v2, EnemyDef.bomber {capMul, blastRadius, blastRatio}): 배 몸통에 닿으면 터져 한 대 상한 × capMul 피해 후 사라진다
/// (처치 보상 없음). 선원이 먼저 잡으면 그 자리에서 터져 반경 안 다른 적에게 최대 HP × blastRatio.
extension Bombers on Round {
  void tickBombers() {
    final g = geo;
    if (g is! TopGeometry) return;
    for (final e in List.of(field.foes)) {
      final b = e.def?.bomber;
      if (b == null || e.exploded) continue;
      final radius = b.number('blastRadius');
      if (e.alive) {
        if (e.holdSec > 0 || g.hullGap(e.x, e.y) > g.top.radiusOf(e)) continue;
        e.exploded = true;
        field.foes.remove(e);
        ctx.emit(BomberBlast(ctx.tick, enemyId: e.id, x: e.x, y: e.y, radius: radius, onShip: true));
        if (invincible) continue;
        final amount = field.hurtShip(e.attack, w.raw.number('shipHitCap') * b.number('capMul'));
        ctx.emit(
          ShipDamaged(
            ctx.tick,
            amount: amount,
            hpRatio: (field.shipHp / field.shipHpMax).toDouble(),
            fromX: e.x,
            fromY: e.y,
          ),
        );
        continue;
      }
      e.exploded = true;
      ctx.emit(BomberBlast(ctx.tick, enemyId: e.id, x: e.x, y: e.y, radius: radius, onShip: false));
      final around = [
        for (final o in field.living)
          if ((o.x - e.x) * (o.x - e.x) + (o.y - e.y) * (o.y - e.y) <= radius * radius) o,
      ];
      if (around.isNotEmpty) strike((x: e.x, y: e.y, hits: spread(around, w)), e.maxHp.times(b.number('blastRatio')));
    }
  }
}
