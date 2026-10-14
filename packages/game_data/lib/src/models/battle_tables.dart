import 'package:game_data/src/models/common.dart';

/// 범위 모양: circle, single, line, chain, random, cone, ship.
class SkillDef {
  SkillDef.fromJson(this.raw)
    : id = raw.str('id'),
      shape = raw.str('shape'),
      count = raw.integer('count'),
      cooldownSec = raw.number('cooldownSec'),
      multiplier = raw.number('multiplier'),
      fx = raw.str('fx');

  final JsonReader raw;
  final String id;
  final String shape;
  final int count;
  final double cooldownSec;
  final double multiplier;
  final String fx;
}

/// 계열 기본 공격 (설계서 4.3.2·4.4). 모양별로 쓰는 필드만 채운다.
/// shape: circle, single, line, chain, random, cone, push.
class AttackDef {
  AttackDef.fromJson(this.raw)
    : shape = raw.str('shape'),
      intervalSec = raw.number('intervalSec'),
      power = raw.number('power'),
      excludeLayers = raw.strs('excludeLayers').toSet(),
      radius = raw.numberOr('radius', 0),
      width = raw.numberOr('width', 0),
      range = raw.numberOr('range', 0),
      angleDeg = raw.numberOr('angleDeg', 0),
      knockback = raw.numberOr('knockback', 0),
      shots = raw.intOrNull('shots') ?? 1,
      pierce = raw.intOrNull('pierce') ?? 1,
      chains = raw.intOrNull('chains') ?? 1,
      count = raw.intOrNull('count') ?? 1;

  final JsonReader raw;
  final String shape;

  /// 발사 간격(초). 돛 강화의 공격 속도 배율로 나눈다.
  final double intervalSec;

  /// 한 번 발사의 피해 배율 (계열 예산, 밸런스 시뮬로 조정).
  final double power;

  /// 이 공격이 맞히지 못하는 층.
  final Set<String> excludeLayers;
  final double radius;
  final double width;
  final double range;
  final double angleDeg;
  final double knockback;

  /// 연사 발수. 한 발 피해 = power / shots.
  final int shots;
  final int pierce;
  final int chains;
  final int count;
}

class FamilyDef {
  FamilyDef.fromJson(JsonReader j)
    : id = j.str('id'),
      projectile = j.strOrNull('projectile'),
      attack = AttackDef.fromJson(j.obj('attack')),
      skill = SkillDef.fromJson(j.obj('skill')),
      ultimateId = j.obj('ultimate').str('id'),
      ultimateFx = j.obj('ultimate').str('fx'),
      nameKey = j.str('nameKey');

  final String id;
  final String? projectile;

  final AttackDef attack;
  final SkillDef skill;
  final String ultimateId;
  final String ultimateFx;
  final String nameKey;
}

class SkillsTable {
  SkillsTable.fromJson(JsonReader j)
    : families = j.objs('families').map(FamilyDef.fromJson).toList(),
      crewSkills = j.objs('crewSkills').map(SkillDef.fromJson).toList(),
      maxSameFamilyInFleet = j.integer('maxSameFamilyInFleet'),
      ragePerKill = j.obj('rage').number('perKill'),
      rageMax = j.obj('rage').number('max'),
      rageAutoTrigger = j.obj('rage').boolean('autoTrigger'),
      ultimateMultiplier = j.obj('rage').number('ultimateMultiplier');

  final List<FamilyDef> families;

  /// 계열 스킬 대신 선원이 고를 수 있는 스킬 (crews.json의 `skill`).
  final List<SkillDef> crewSkills;
  final int maxSameFamilyInFleet;
  final double ragePerKill;
  final double rageMax;
  final bool rageAutoTrigger;

  /// 궁극기 피해 = 기본 공격 피해 × 이 값 (M1 공통 모양, 계열별 모양은 M3).
  final double ultimateMultiplier;

  FamilyDef byId(String id) => families.firstWhere((f) => f.id == id);

  /// 계열 스킬과 선원 스킬 전체의 id.
  Set<String> get skillIds => {for (final f in families) f.skill.id, for (final s in crewSkills) s.id};

  List<String> validate(double skillCooldownMinSec) {
    final e = <String>[];
    for (final f in families) {
      expect(
        e,
        that: f.skill.cooldownSec >= skillCooldownMinSec,
        message: 'skills: ${f.id} 쿨타임 ${f.skill.cooldownSec} < 최소 $skillCooldownMinSec',
      );
    }
    return e;
  }
}

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
      speed = j.number('speed');

  final String id;

  /// surface | underwater | air.
  final String layer;
  final double hpScale;

  /// 초당 이동 거리(논리 px).
  final double speed;
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
