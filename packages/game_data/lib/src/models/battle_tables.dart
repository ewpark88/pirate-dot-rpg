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

  /// 튜토리얼 3단계(설계서 4.12 '실패 → 강화' 학습): 이 스테이지의 첫 보스는 HP × [tutorialFailHpMultiplier].
  int get tutorialFailStage => _boss.integer('tutorialFailStage');
  double get tutorialFailHpMultiplier => _boss.number('tutorialFailHpMultiplier');
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
      coneNearPx = j.number('coneNearPx'),
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

  /// 부채꼴(강습) 근접 거리: 배 앞머리에서 이만큼 안의 적은 각도와 상관없이 맞는다.
  /// 배에 닿은 적은 x가 shipX로 멈춰 각도가 90°가 되므로 이게 없으면 강습이 붙은 적을 못 친다.
  final double coneNearPx;
  final double contactIntervalSec;
}
