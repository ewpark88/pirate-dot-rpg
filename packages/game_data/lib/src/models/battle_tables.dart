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

class FamilyDef {
  FamilyDef.fromJson(JsonReader j)
    : id = j.str('id'),
      projectile = j.strOrNull('projectile'),
      attack = j.obj('attack'),
      skill = SkillDef.fromJson(j.obj('skill')),
      ultimateId = j.obj('ultimate').str('id'),
      ultimateFx = j.obj('ultimate').str('fx'),
      nameKey = j.str('nameKey');

  final String id;
  final String? projectile;

  /// 기본 공격 모양. 해석은 전투 레인.
  final JsonReader attack;
  final SkillDef skill;
  final String ultimateId;
  final String ultimateFx;
  final String nameKey;
}

class SkillsTable {
  SkillsTable.fromJson(JsonReader j)
    : families = j.objs('families').map(FamilyDef.fromJson).toList(),
      maxSameFamilyInFleet = j.integer('maxSameFamilyInFleet'),
      ragePerKill = j.obj('rage').number('perKill'),
      rageAutoTrigger = j.obj('rage').boolean('autoTrigger');

  final List<FamilyDef> families;
  final int maxSameFamilyInFleet;
  final double ragePerKill;
  final bool rageAutoTrigger;

  FamilyDef byId(String id) => families.firstWhere((f) => f.id == id);

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
      bossTimeLimitSec = raw.obj('boss').number('timeLimitSec');

  final JsonReader raw;
  final int tickMs;
  final int wavesPerStage;
  final int mobBase;
  final int mobStagesPerExtra;
  final int mobMax;
  final double waveHpPoolFactor;
  final double bossTimeLimitSec;

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

class RegionsTable {
  RegionsTable.fromJson(JsonReader j)
    : stagesPerRegion = j.integer('stagesPerRegion'),
      regions = j.objs('regions').map(RegionDef.fromJson).toList(),
      enemyIds = j.objs('enemies').map((e) => e.str('id')).toList();

  final int stagesPerRegion;
  final List<RegionDef> regions;
  final List<String> enemyIds;

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
