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
