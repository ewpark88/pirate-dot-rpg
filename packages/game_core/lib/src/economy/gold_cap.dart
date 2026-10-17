import 'package:game_core/src/bignum/big_num.dart';
import 'package:game_core/src/economy/ship_stats.dart';
import 'package:game_core/src/engine/events.dart';
import 'package:game_core/src/engine/game_engine.dart';
import 'package:game_core/src/engine/game_state.dart';
import 'package:game_data/game_data.dart';

// 화물칸 = 골드 금고 용량 (docs/specs/economy-cargo-capacity.md, 사용자 결정 2026-10-16).
// 보유 골드 상한 = 화물칸 용량. 가득 차면 넘친 몫은 버린다(이미 넘게 가진 골드는 깎지 않는다).

/// 지금 보유할 수 있는 최대 골드 = 화물칸 Lv의 용량.
BigNum goldCapacity(GameState s, GameTables t) => partEffect(t.shipParts.byId('cargo'), s.ship.level('cargo'));

/// 더 담을 수 있는 골드 (가득 차거나 넘었으면 0). [capScale]은 오프라인 보상처럼 용량의 몇 배까지 허용할 때.
BigNum goldRoom(GameState s, GameTables t, {double capScale = 1}) {
  final room = goldCapacity(s, t).times(capScale) - s.wallet.gold;
  return room.isNegative ? BigNum.zero : room;
}

/// 금고가 이 비율 이상이면 UI가 미리 경고한다(meta.cargo.warnRatio).
bool goldNearFull(GameState s, GameTables t) =>
    s.wallet.gold >= goldCapacity(s, t).times(t.meta.raw.obj('cargo').number('warnRatio'));

/// 오프라인 보상(복귀·광고 ×2)이 넘어도 되는 용량 배수(meta.offline.capMultiplier, 없으면 1).
/// [s]를 주면 바닥값: 다음 강화 meta.offline.floorUpgrades번(가장 싼 부위부터) 값까지는 담는다 — 환생 직후 화물칸이 작아
/// 8시간 복귀가 302골드·13.2K 잘림이던 것(실기기 2026-10-17). 지금 가진 골드는 빼지 않는다(용량 × 배수와 같은 기준).
double offlineCapScale(GameTables t, [GameState? s]) {
  final scale = t.meta.raw.obj('offline').numberOr('capMultiplier', 1);
  final n = t.meta.raw.obj('offline').intOrNull('floorUpgrades') ?? 0;
  if (s == null || n <= 0) return scale;
  final cap = goldCapacity(s, t);
  if (cap.isZero) return scale;
  final floor = nextUpgradesCost(s, t, n);
  final need = (floor / cap).toDouble();
  return need > scale ? need : scale;
}

/// 가장 싼 부위부터 [n]번 강화하는 골드 합(최대 레벨인 부위는 건너뜀).
BigNum nextUpgradesCost(GameState s, GameTables t, int n) {
  final lv = {for (final d in t.shipParts.parts) d.id: s.ship.level(d.id)};
  var sum = BigNum.zero;
  for (var i = 0; i < n; i++) {
    ShipPartDef? best;
    BigNum? cost;
    for (final d in t.shipParts.parts) {
      final max = d.maxLevel;
      if (max != null && lv[d.id]! >= max) continue;
      final c = partCost(d, lv[d.id]!);
      if (cost == null || c < cost) {
        best = d;
        cost = c;
      }
    }
    if (best == null) break;
    sum = sum + cost!;
    lv[best.id] = lv[best.id]! + 1;
  }
  return sum;
}

/// [amount]를 용량까지 더한다. 실제로 들어간 양과 넘친 양.
({GameState state, BigNum added, BigNum lost}) addGold(
  GameState s,
  GameTables t,
  BigNum amount, {
  double capScale = 1,
}) {
  if (amount.isZero || amount.isNegative) return (state: s, added: BigNum.zero, lost: BigNum.zero);
  final room = goldRoom(s, t, capScale: capScale);
  final added = amount > room ? room : amount;
  final lost = amount - added;
  final next = added.isZero ? s : s.copyWith(wallet: s.wallet.copyWith(gold: s.wallet.gold + added));
  return (state: next, added: added, lost: lost);
}

/// 경제 쪽(상자·광고·이벤트·도전·오프라인) 한 번에 들어오는 골드: 넘치면 바로 GoldOverflow.
GameState grantGold(GameState s, SystemContext ctx, BigNum amount, {double capScale = 1}) {
  final r = addGold(s, ctx.tables, amount, capScale: capScale);
  if (!r.lost.isZero) ctx.emit(GoldOverflow(ctx.tick, lost: r.lost));
  return r.state;
}
