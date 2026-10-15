import 'package:game_core/game_core.dart';
import 'package:game_data/game_data.dart';

// 가상 플레이어의 ‘가장 싼 강화’ 계산.

/// 지금 레벨에서 가장 싼 강화 (최대 레벨 부위 제외).
({String part, BigNum cost})? cheapestUpgrade(GameTables t, Map<String, int> levels) {
  ({String part, BigNum cost})? best;
  for (final p in t.shipParts.parts) {
    final lv = levels[p.id] ?? 0;
    final max = p.maxLevel;
    if (max != null && lv >= max) continue;
    final cost = partCost(p, lv);
    if (best == null || cost < best.cost) best = (part: p.id, cost: cost);
  }
  return best;
}

/// [gold]로 가장 싼 강화를 몇 번 살 수 있나.
int upgradesAffordable(GameTables t, Map<String, int> levels, BigNum gold) {
  final lv = {...levels};
  var left = gold;
  var n = 0;
  while (true) {
    final next = cheapestUpgrade(t, lv);
    if (next == null || left < next.cost) return n;
    left = left - next.cost;
    lv[next.part] = (lv[next.part] ?? 0) + 1;
    n++;
  }
}

/// 가상 플레이어 강화 정책: 골드가 되는 만큼 가장 싼 부위부터 산다(상점 할인 반영, 승급 골드는 남기지 않음). 산 횟수.
int buyCheapest(CoreEngine engine, GameTables t, GameState s) {
  var gold = s.wallet.gold;
  final levels = {...s.ship.parts};
  final mult = upgradeCostMultiplier(s, t);
  var bought = 0;
  while (true) {
    final next = cheapestUpgrade(t, levels);
    if (next == null) return bought;
    final cost = next.cost.times(mult);
    if (gold < cost) return bought;
    gold = gold - cost;
    levels[next.part] = (levels[next.part] ?? 0) + 1;
    engine.enqueue(UpgradePart(next.part));
    bought++;
  }
}

/// 환생 v2 상점 정책: 살 수 있는 칸 중 가장 싼 것 하나 (1줄이 먼저 열리므로 1줄 우선).
void buyRebirthShop(CoreEngine engine, GameTables t, GameState s) {
  final items = shopView(s, t).items.where((i) => i.affordable).toList()..sort((a, b) => a.cost!.compareTo(b.cost!));
  if (items.isNotEmpty) engine.enqueue(BuyRebirthUpgrade(items.first.id));
}
