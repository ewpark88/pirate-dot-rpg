import 'package:game_core/src/engine/game_state.dart';
import 'package:game_data/game_data.dart';

// ── 환생 횟수 보상·해금 (환생 v2 3·4절) ──

/// 선원 최대 레벨 = growth.maxLevel, 환생 해금(unlocks crewMaxLevel)으로 늘어난다. 76 이상은 신화 구간 규칙 그대로.
int crewMaxLevel(GameState s, GameTables t) {
  var max = t.growth.maxLevel;
  for (final u in t.meta.rebirth.objs('unlocks')) {
    if (u.str('kind') == 'crewMaxLevel' && s.progress.rebirths >= u.integer('rebirths') && u.integer('value') > max) {
      max = u.integer('value');
    }
  }
  return max;
}

JsonReader? _treasure(GameState s, GameTables t) {
  final sea = s.progress.treasureSea;
  if (sea == null) return null;
  for (final k in t.meta.rebirth.objs('treasureSeas')) {
    if (k.integer('sea') == sea) return k;
  }
  return null;
}

/// 이번 회차가 보물 바다면 적 체력·골드·환생 조각 배율, 아니면 1.
double treasureHpMultiplier(GameState s, GameTables t) => _treasure(s, t)?.number('hpMultiplier') ?? 1;
double treasureGoldMultiplier(GameState s, GameTables t) => _treasure(s, t)?.number('goldMultiplier') ?? 1;
double treasurePiecesMultiplier(GameState s, GameTables t) => _treasure(s, t)?.number('piecesMultiplier') ?? 1;

/// 환생 상자 (n = 이번 환생 뒤 횟수): 젬 min(max, base + per × (n − 1)), 영웅 이상 소환 수.
({int gems, int summons}) rebirthChest(GameTables t, int n) {
  final c = t.meta.rebirth.obj('chest');
  final gems = c.integer('gemsBase') + c.integer('gemsPerRebirth') * (n - 1);
  var summons = 0;
  for (final step in c.objs('summons')) {
    if (n >= step.integer('from')) summons = step.integer('count');
  }
  final max = c.integer('gemsMax');
  return (gems: gems > max ? max : gems, summons: summons);
}

/// 환생 [n]회째에 새로 얻는 스킨·칭호 id와 새로 열리는 해금.
({List<String> skins, List<String> titles, List<({String kind, int value})> unlocks}) rebirthRewardsAt(
  GameTables t,
  int n,
) {
  final r = t.meta.rebirth;
  return (
    skins: [
      for (final k in r.objs('skins'))
        if (k.integer('rebirths') == n) k.str('id'),
    ],
    titles: [
      for (final k in r.objs('titles'))
        if (k.integer('rebirths') == n) k.str('id'),
    ],
    unlocks: [
      for (final u in r.objs('unlocks'))
        if (u.integer('rebirths') == n) (kind: u.str('kind'), value: u.integer('value')),
    ],
  );
}

/// 배 등급 [tier]가 명예 등급을 넘는가 — ShipTierUp 연출은 이때만(환생 뒤 다시 오를 때 반복하지 않음). 능력치는 그대로 적용된다.
bool beyondHonor(GameState s, GameTables t, ShipTierDef tier) => t.shipTiers.tiers.indexOf(tier) > s.ship.honorTier;
