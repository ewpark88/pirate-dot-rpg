import 'package:game_core/src/economy/iap.dart' show purchasedSpeed;
import 'package:game_core/src/engine/game_engine.dart';
import 'package:game_core/src/engine/game_state.dart';

/// 순풍 배속 (battle_system에서 나눔 — 300줄).
class TailwindSpeed {
  bool _boost = false;

  /// 순풍 중에는 배속을 tailwind.speedMultiplier로(앱이 주기마다 그만큼 틱을 돈다). 운영자 배속(1 아님)은 그대로.
  GameState apply(GameState s, SystemContext ctx) {
    final b = s.battle;
    if (b == null) return s;
    final now = ctx.clock.now();
    final until = s.buffs.tailwindUntil;
    final tail = until != null && until.isAfter(now);
    final bought = purchasedSpeed(s, ctx.tables, now); // 유료 2배속(계약 platform-iap) — 순풍과 겹쳐도 곱하지 않는다
    final on = tail || bought != null;
    final tailBoost = ctx.tables.ads.placements.firstWhere((p) => p.id == 'tailwind').reward.integer('speedMultiplier');
    final boost = bought != null && bought > tailBoost ? bought : tailBoost;
    if (on && !_boost && b.speed == 1) {
      _boost = true;
      return s.copyWith(battle: b.copyWith(speed: boost));
    }
    if (!on && _boost) {
      _boost = false;
      return b.speed == boost ? s.copyWith(battle: b.copyWith(speed: 1)) : s;
    }
    return s;
  }
}
