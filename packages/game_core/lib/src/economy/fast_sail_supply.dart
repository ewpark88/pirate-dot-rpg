import 'package:game_core/src/battle/spawner.dart' show stageCurve;
import 'package:game_core/src/economy/rebirth_shop.dart' show upgradeCostMultiplier;
import 'package:game_core/src/economy/ship_stats.dart';
import 'package:game_core/src/engine/game_state.dart';
import 'package:game_data/game_data.dart';

// 빠른 항해 보급 (사용자 긴급 2026-10-16: 환생 뒤 빠른 항해로 스테이지 83에 닿았는데 골드가 화물칸에 막혀 배를 못 올리고 침몰).
// 빠른 항해가 끝나면(엔진 S5가 부른다) 배 부위를 '도착 스테이지 적을 버티고 잡을 수 있는 레벨'로 무상으로 올린다.
// 번 골드로 계산하면(오프라인·상자·광고가 빠져) 모자라서, 적 곡선 대비 부위 효과로 정한다:
//   선체 효과 ÷ 적 공격(stage) ≥ hullVsAttack, 대포 효과 ÷ 적 HP(stage) ≥ cannonVsHp — 그 비율을 넘는 가장 낮은 레벨.
//   돛·망루 = 대포 레벨 × sideRatio(최대 레벨로 자름), 화물칸 = 다음 대포 강화가 들어가는 가장 낮은 레벨.

/// 보급 뒤 부위 레벨. waves.rebirthSkip.supply가 없으면 지금 레벨 그대로. 지금보다 낮추지 않는다.
Map<String, int> fastSailSupplyLevels(GameState s, GameTables t, int stage) {
  final skip = t.waves.raw.obj('rebirthSkip');
  final now = {for (final p in t.shipParts.parts) p.id: s.ship.level(p.id)};
  if (!skip.has('supply')) return now;
  final cfg = skip.obj('supply');
  final w = t.waves;
  final parts = t.shipParts;

  // 효과는 레벨마다 늘어나므로(성장 > 1) 반드시 멈춘다.
  int lowest(ShipPartDef p, bool Function(int lv) ok) {
    var lv = 0;
    while (!ok(lv) && (p.maxLevel == null || lv < p.maxLevel!)) {
      lv++;
    }
    return lv;
  }

  final attack = stageCurve(w.attackBase, w.attackGrowth, stage).times(cfg.number('hullVsAttack'));
  final hp = stageCurve(w.hpBase, w.hpGrowth, stage).times(cfg.number('cannonVsHp'));
  final cannonDef = parts.byId('cannon');
  final cannon = lowest(cannonDef, (lv) => partEffect(cannonDef, lv) >= hp);
  final hullDef = parts.byId('hull');
  final out = <String, int>{
    'hull': lowest(hullDef, (lv) => partEffect(hullDef, lv) >= attack),
    'cannon': cannon,
  };
  for (final p in parts.parts) {
    if (out.containsKey(p.id) || p.id == 'cargo') continue;
    final lv = (cannon * cfg.number('sideRatio')).round();
    out[p.id] = p.maxLevel != null && lv > p.maxLevel! ? p.maxLevel! : lv;
  }
  final next = partCost(cannonDef, cannon).times(upgradeCostMultiplier(s, t));
  final cargo = parts.byId('cargo');
  out['cargo'] = lowest(cargo, (lv) => partEffect(cargo, lv) >= next);
  return {
    for (final p in parts.parts) p.id: (out[p.id] ?? 0) > now[p.id]! ? out[p.id]! : now[p.id]!,
  };
}
