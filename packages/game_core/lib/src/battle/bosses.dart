import 'package:game_core/src/battle/combat.dart';
import 'package:game_core/src/battle/field.dart';
import 'package:game_core/src/battle/spawner.dart';
import 'package:game_core/src/bignum/big_num.dart';
import 'package:game_core/src/engine/events.dart';

/// 보스 패턴 주기(초) → 틱.
int mechanicTicks(Round r, double sec) => (sec / r.dt).round();

/// 해역 보스 패턴 (docs/specs/battle-m3-bosses.md 2).
extension BossRound on Round {
  /// [e]가 [family] 계열 공격에서 받는 피해 비율. 보호막은 깨는 계열에 맞으면 깨진다.
  double guard(Foe e, String? family) {
    final m = e.bossDef?.mechanic;
    if (m == null) return 1;
    switch (m.type) {
      case 'frontArmor':
        return m.bypassFamilies.contains(family) ? 1 : m.factor;
      case 'shield':
        if (!e.shielded) return 1;
        // 깨는 계열이 없어도 넘을 수 있게, 다른 계열은 factor만큼 들어간다 (설계서 4.11: 편성을 바꿀 필요 없음).
        if (!m.breakerFamilies.contains(family)) return m.factor;
        e.shielded = false;
        field.bossTimerTicks = mechanicTicks(this, m.intervalSec);
        return 1;
      case 'tentacles':
        e.shielded = field.living.any((x) => x.ownerId == e.id);
        return e.shielded ? 0 : 1;
      default:
        return 1;
    }
  }

  /// 매 틱: 보호막 재생, 용암, 소환.
  void tickBoss() {
    final boss = field.living.where((e) => e.boss).firstOrNull;
    final m = boss?.bossDef?.mechanic;
    if (boss == null || m == null) return;
    if (m.type == 'tentacles') {
      boss.shielded = field.living.any((x) => x.ownerId == boss.id);
      return;
    }
    if (m.type == 'shield' && boss.shielded) return;
    if (m.intervalSec <= 0) return;
    field.bossTimerTicks -= 1;
    if (field.bossTimerTicks > 0) return;
    field.bossTimerTicks = mechanicTicks(this, m.intervalSec);
    switch (m.type) {
      case 'shield':
        boss.shielded = true;
      case 'lava':
        if (invincible) return;
        final amount = boss.attack.times(m.shipDamageMultiplier);
        final hp = field.shipHp - amount;
        field.shipHp = hp.isNegative ? BigNum.zero : hp;
        ctx.emit(ShipDamaged(ctx.tick, amount: amount, hpRatio: (field.shipHp / field.shipHpMax).toDouble()));
      case 'summoner':
        spawnWave(field, field.stage, ctx, count: m.count);
    }
  }
}
