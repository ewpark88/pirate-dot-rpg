import 'package:game_data/src/models/common.dart';

class WavesTable {
  WavesTable.fromJson(this.raw)
    : tickMs = raw.integer('tickMs'),
      wavesPerStage = raw.integer('wavesPerStage'),
      mobBase = raw.obj('mobCount').integer('base'),
      mobStagesPerExtra = raw.obj('mobCount').integer('stagesPerExtra'),
      mobMax = raw.obj('mobCount').integer('max'),
      waveHpPoolFactor = raw.number('waveHpPoolFactor'),
      bossTimeLimitSec = raw.obj('boss').number('timeLimitSec'),
      field = FieldDef.fromJson(raw.obj('field'));

  final JsonReader raw;
  final int tickMs;
  final int wavesPerStage;
  final int mobBase;
  final int mobStagesPerExtra;
  final int mobMax;
  final double waveHpPoolFactor;
  final double bossTimeLimitSec;
  final FieldDef field;

  JsonReader get _monster => raw.obj('monster');
  JsonReader get _boss => raw.obj('boss');
  double get hpBase => _monster.number('hpBase');
  double get hpGrowth => _monster.number('hpGrowth');
  double get attackBase => _monster.number('attackBase');
  double get attackGrowth => _monster.number('attackGrowth');
  double get goldBase => _monster.number('goldBase');
  double get goldGrowth => _monster.number('goldGrowth');
  double get bossHpMultiplier => _boss.number('hpMultiplier');
  double get bossAttackMultiplier => _boss.number('attackMultiplier');
  double get bossGoldMultiplier => _boss.number('goldMultiplier');
  int get bossGems => _boss.integer('gems');
  double get bossSpeed => _boss.number('speed');
  double get travelSec => raw.number('travelSec');
  double get multiKillWindowSec => raw.obj('multiKill').number('windowSec');
  double get multiKillGoldBonusPerKill => raw.obj('multiKill').number('goldBonusPerKill');

  /// 동시 처치로 인정하는 최소 마리 수 (tiers 첫 단계).
  int get multiKillMinKills => raw.obj('multiKill').objs('tiers').first.integer('kills');

  /// 이 수 이상 동시 처치하면 히트스톱 (juice.hitStopMs.multiKill4).
  int get multiKillHitStopMinKills => raw.obj('multiKill').integer('hitStopMinKills');
  int get aoeFullDamageTargets => raw.obj('aoe').integer('fullDamageTargets');
  double get aoeOverflowDamage => raw.obj('aoe').number('overflowDamage');
  double get chainFalloff => raw.number('chainFalloff');
  int get chainMax => raw.integer('chainMax');

  /// 한 파 마리 수 = min(max, base + floor(stage / stagesPerExtra)).
  int mobCountAt(int stage) {
    final n = mobBase + stage ~/ mobStagesPerExtra;
    return n < mobMax ? n : mobMax;
  }

  List<String> validate() {
    final e = <String>[];
    final m = raw.obj('monster');
    for (final k in ['hpGrowth', 'attackGrowth', 'goldGrowth']) {
      expect(e, that: m.number(k) > 1, message: 'waves: monster.$k는 1보다 커야 함');
    }
    expect(e, that: tickMs > 0 && 1000 % tickMs == 0, message: 'waves: tickMs는 1000의 약수');
    return e;
  }
}

/// 전장 배치 (논리 좌표, BattleView와 같다).
class FieldDef {
  FieldDef.fromJson(JsonReader j)
    : width = j.number('width'),
      shipX = j.number('shipX'),
      shipY = j.number('shipY'),
      spawnX = j.number('spawnX'),
      spawnSpacing = j.number('spawnSpacing'),
      laneY = j.numberMap('laneY'),
      laneJitter = j.number('laneJitter'),
      contactIntervalSec = j.number('contactIntervalSec');

  final double width;

  /// 배 앞머리. 적은 여기에 닿으면 멈추고 배를 공격한다.
  final double shipX;
  final double shipY;
  final double spawnX;

  /// 한 파 안에서 적 사이 가로 간격.
  final double spawnSpacing;

  /// 층(surface·underwater·air)별 기준 y.
  final Map<String, double> laneY;
  final double laneJitter;
  final double contactIntervalSec;
}

class RegionDef {
  RegionDef.fromJson(JsonReader j)
    : id = j.str('id'),
      fromStage = j.integer('fromStage'),
      background = j.str('background'),
      bgm = j.str('bgm'),
      enemies = j.strs('enemies'),
      boss = j.str('boss'),
      nameKey = j.str('nameKey');

  final String id;
  final int fromStage;
  final String background;
  final String bgm;
  final List<String> enemies;
  final String boss;
  final String nameKey;
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
      regions = j.objs('regions').map(RegionDef.fromJson).toList(),
      enemies = {for (final e in j.objs('enemies')) e.str('id'): EnemyDef.fromJson(e)};

  final int stagesPerRegion;
  final List<RegionDef> regions;
  final Map<String, EnemyDef> enemies;

  List<String> get enemyIds => enemies.keys.toList();

  RegionDef regionAt(int stage) => regions.lastWhere((r) => r.fromStage <= stage, orElse: () => regions.first);

  List<String> validate() {
    final e = <String>[];
    for (var i = 0; i < regions.length; i++) {
      final r = regions[i];
      expect(e, that: r.fromStage == i * stagesPerRegion + 1, message: 'regions: ${r.id} fromStage 오류');
      for (final en in r.enemies) {
        expect(e, that: enemyIds.contains(en), message: 'regions: ${r.id}의 적 $en이 enemies에 없음');
      }
    }
    return e;
  }
}
