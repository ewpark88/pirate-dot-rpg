import 'package:game_data/src/models/common.dart';

class RegionDef {
  RegionDef.fromJson(JsonReader j)
    : id = j.str('id'),
      fromStage = j.integer('fromStage'),
      background = j.str('background'),
      bgm = j.str('bgm'),
      enemies = j.strs('enemies'),
      boss = j.str('boss'),
      midBoss = j.str('midBoss'),
      regionBoss = j.str('regionBoss'),
      nameKey = j.str('nameKey');

  final String id;
  final int fromStage;
  final String background;
  final String bgm;
  final List<String> enemies;

  /// 일반 스테이지 보스.
  final String boss;

  /// `midBossEvery`(25)마다의 중간 보스, 해역 마지막(50) 스테이지의 해역 보스.
  final String midBoss;
  final String regionBoss;
  final String nameKey;
}

/// 보스 하나 (설계서 4.11). 체력은 일반 보스(waves.boss.hpMultiplier) 대비 [hpMultiplier]배.
class BossDef {
  BossDef.fromJson(JsonReader j)
    : id = j.str('id'),
      nameKey = j.str('nameKey'),
      hpMultiplier = j.number('hpMultiplier'),
      weakFamilies = j.strs('weakFamilies'),
      mechanic = j.has('mechanic') ? BossMechanic.fromJson(j.obj('mechanic')) : null;

  final String id;

  /// 보스 이름 ARB 키 (battle 레인).
  final String nameKey;
  final double hpMultiplier;

  /// 약점 표시용 계열 (UI·렌더가 아이콘으로).
  final List<String> weakFamilies;
  final BossMechanic? mechanic;
}

/// 해역 보스 패턴: frontArmor, shield, lava, tentacles, summoner (docs/specs/battle-m3-bosses.md).
class BossMechanic {
  BossMechanic.fromJson(JsonReader j)
    : type = j.str('type'),
      factor = j.numberOr('factor', 1),
      bypassFamilies = j.has('bypassFamilies') ? j.strs('bypassFamilies').toSet() : const {},
      breakerFamilies = j.has('breakerFamilies') ? j.strs('breakerFamilies').toSet() : const {},
      intervalSec = j.numberOr('intervalSec', 0),
      shipDamageMultiplier = j.numberOr('shipDamageMultiplier', 0),
      count = j.intOrNull('count') ?? 0,
      hpRatio = j.numberOr('hpRatio', 0);

  final String type;
  final double factor;
  final Set<String> bypassFamilies;
  final Set<String> breakerFamilies;
  final double intervalSec;
  final double shipDamageMultiplier;
  final int count;
  final double hpRatio;
}

/// 잡몹 한 종류. 보스(`RegionDef.boss`)는 여기에 없고 waves.json의 boss 배율을 쓴다.
class EnemyDef {
  EnemyDef.fromJson(JsonReader j)
    : id = j.str('id'),
      layer = j.str('layer'),
      hpScale = j.number('hpScale'),
      speed = j.number('speed'),
      role = j.str('role'),
      splitInto = j.strOrNull('splitInto'),
      splitCount = j.intOrNull('splitCount') ?? 0,
      splitHpRatio = j.numberOr('splitHpRatio', 0),
      reviveHpRatio = j.numberOr('reviveHpRatio', 0);

  final String id;

  /// surface | underwater | air.
  final String layer;
  final double hpScale;

  /// 초당 이동 거리(논리 px).
  final double speed;

  /// 역할 (설계서 4.11): basic, fast, tough, air, split, revive. 배율은 speed·hpScale에, 역할은 특수 동작만.
  final String role;

  /// 분열: 처치되면 [splitInto]를 [splitCount]마리, 체력 = 부모 최대 체력 × [splitHpRatio].
  final String? splitInto;
  final int splitCount;
  final double splitHpRatio;

  /// 부활: 처음 처치되면 체력 [reviveHpRatio]로 한 번 일어난다.
  final double reviveHpRatio;
}

class RegionsTable {
  RegionsTable.fromJson(JsonReader j)
    : stagesPerRegion = j.integer('stagesPerRegion'),
      midBossEvery = j.integer('midBossEvery'),
      loopStages = j.integer('loopStages'),
      maxLoopTier = j.integer('maxLoopTier'),
      regions = j.objs('regions').map(RegionDef.fromJson).toList(),
      bosses = {for (final b in j.objs('bosses')) b.str('id'): BossDef.fromJson(b)},
      enemies = {for (final e in j.objs('enemies')) e.str('id'): EnemyDef.fromJson(e)};

  final int stagesPerRegion;
  final int midBossEvery;

  /// 이 스테이지 수마다 해역을 처음부터 다시 돈다 (무한 항해).
  final int loopStages;
  final int maxLoopTier;
  final List<RegionDef> regions;
  final Map<String, BossDef> bosses;
  final Map<String, EnemyDef> enemies;

  List<String> get enemyIds => enemies.keys.toList();

  /// 무한 항해를 반영한 해역 (301 → 1의 해역).
  RegionDef regionAt(int stage) {
    final s = (stage - 1) % loopStages + 1;
    return regions.lastWhere((r) => r.fromStage <= s, orElse: () => regions.first);
  }

  /// 몇 바퀴째인지에 따른 적 등급 테두리 (0 = 없음).
  int tierAt(int stage) {
    final lap = (stage - 1) ~/ loopStages;
    return lap < maxLoopTier ? lap : maxLoopTier;
  }

  /// 스테이지 보스: 해역 마지막 = 해역 보스, midBossEvery마다 = 중간 보스, 그 밖 = 일반 보스.
  BossDef bossAt(int stage) {
    final r = regionAt(stage);
    final id = stage % stagesPerRegion == 0
        ? r.regionBoss
        : stage % midBossEvery == 0
        ? r.midBoss
        : r.boss;
    return bosses[id]!;
  }

  List<String> validate() {
    final e = <String>[];
    for (var i = 0; i < regions.length; i++) {
      final r = regions[i];
      expect(e, that: r.fromStage == i * stagesPerRegion + 1, message: 'regions: ${r.id} fromStage 오류');
      for (final en in r.enemies) {
        expect(e, that: enemyIds.contains(en), message: 'regions: ${r.id}의 적 $en이 enemies에 없음');
      }
      for (final b in [r.boss, r.midBoss, r.regionBoss]) {
        expect(e, that: bosses.containsKey(b), message: 'regions: ${r.id}의 보스 $b가 bosses에 없음');
      }
    }
    return e;
  }
}
