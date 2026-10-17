import 'package:game_core/src/bignum/big_num.dart';
import 'package:game_core/src/economy/auto_upgrade.dart' show autoUpgradePick;
import 'package:game_core/src/economy/rebirth_shop.dart' show upgradeCostMultiplier;
import 'package:game_core/src/economy/ship_stats.dart';
import 'package:game_core/src/engine/game_state.dart';
import 'package:game_data/game_data.dart';

/// '모두 강화' 한 번에 살 계획 (사용자 피드백 2026-10-17 '금화가 금방 상한에 차서 계속 레벨 올리기가 피곤하다', S4 버튼).
/// `levels` = 부위별 올릴 횟수(0인 부위는 없음), `cost` = 합계 골드, `after` = 산 뒤 부위 레벨.
typedef UpgradePlan = ({Map<String, int> levels, BigNum cost, Map<String, int> after});

/// 지금 골드로 자동 강화와 같은 규칙(살 수 있는 가장 싼 부위부터, 화물칸은 금고가 찼거나 다른 강화가 용량을 넘을 때)을
/// 골드가 바닥날 때까지 되풀이한 결과. 상태는 바꾸지 않는다 — UI는 부위마다 `UpgradePart(part, times: n)`을 보낸다
/// (부위 비용은 그 부위 레벨만 보므로 보내는 순서가 결과를 바꾸지 않는다).
UpgradePlan bestUpgradePlan(GameState state, GameTables t) {
  final mult = upgradeCostMultiplier(state, t);
  var s = state;
  var spent = BigNum.zero;
  final levels = <String, int>{};
  // 레벨마다 비용이 커지므로 금방 끝난다. 안전장치로 상한.
  for (var i = 0; i < _maxSteps; i++) {
    final pick = autoUpgradePick(s, t);
    if (pick == null) break;
    final lv = s.ship.level(pick);
    final cost = partCost(t.shipParts.byId(pick), lv).times(mult);
    spent = spent + cost;
    levels[pick] = (levels[pick] ?? 0) + 1;
    s = s.copyWith(
      wallet: s.wallet.copyWith(gold: s.wallet.gold - cost),
      ship: s.ship.withLevel(pick, lv + 1),
    );
  }
  return (
    levels: levels,
    cost: spent,
    after: {for (final p in t.shipParts.parts) p.id: s.ship.level(p.id)},
  );
}

const _maxSteps = 10000;
