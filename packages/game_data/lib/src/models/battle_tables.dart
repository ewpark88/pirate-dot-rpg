import 'package:game_data/src/models/common.dart';

class WavesTable {
  WavesTable.fromJson(this.raw)
    : tickMs = raw.integer('tickMs'),
      wavesPerStage = raw.integer('wavesPerStage'),
      mobBase = raw.obj('mobCount').integer('base'),
      mobStagesPerExtra = raw.obj('mobCount').integer('stagesPerExtra'),
      mobMax = raw.obj('mobCount').integer('max'),
      mobPoolBase = raw.obj('mobCount').obj('pool').integer('base'),
      mobPoolStagesPerExtra = raw.obj('mobCount').obj('pool').integer('stagesPerExtra'),
      mobPoolMax = raw.obj('mobCount').obj('pool').integer('max'),
      waveHpPoolFactor = raw.number('waveHpPoolFactor'),
      bossTimeLimitSec = raw.obj('boss').number('timeLimitSec'),
      field = FieldDef.fromJson(raw.obj('field')),
      top = TopFieldDef.fromJson(raw.obj('top'));

  final JsonReader raw;
  final int tickMs;
  final int wavesPerStage;
  final int mobBase;
  final int mobStagesPerExtra;
  final int mobMax;

  /// 한 파 총량(HP·공격·골드) 기준 마리 수. 보이는 마리([mobCountAt])가 이만큼의 몫을 나눠 갖는다.
  final int mobPoolBase;
  final int mobPoolStagesPerExtra;
  final int mobPoolMax;
  final double waveHpPoolFactor;
  final double bossTimeLimitSec;
  final FieldDef field;

  /// 탑다운 전장 (T0). 옆모습은 [field].
  final TopFieldDef top;

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

  /// 첫 회차 스테이지 1~[earlyStageMax] 보스는 HP × [earlyHpMultiplier] — 입력 없이도 시작 편성으로 잡히게 (설계서 4.12 1~2단계).
  int get earlyStageMax => _boss.integer('earlyStageMax');
  double get earlyHpMultiplier => _boss.number('earlyHpMultiplier');

  /// 스테이지 1~[earlyStageMax] 보스 공격 배율(없으면 1) — 보스 공격을 크게 올린 뒤(C8 ×100)에도 강화 전 배가 첫 보스에 가라앉지 않게.
  double get earlyAttackMultiplier => _boss.numberOr('earlyAttackMultiplier', 1);
  double get travelSec => raw.number('travelSec');

  /// 빠른 항해: 환생 뒤 bestStage × fraction(올림) 이하 스테이지는 파 [RebirthSkip.waves]개만 잡고 보스.
  RebirthSkip get rebirthSkip => RebirthSkip(raw.obj('rebirthSkip'));
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

  /// 한 파 보이는 마리 수 = min(max, base + floor(stage / stagesPerExtra)) (사용자 지시 2026-10-15: ‘무리’로 보이게).
  int mobCountAt(int stage) {
    final n = mobBase + stage ~/ mobStagesPerExtra;
    return n < mobMax ? n : mobMax;
  }

  /// 탑다운 한 파 마리 수 = min(top.mobCount.max, base + floor(stage / stagesPerExtra)) — 무리 습격(핵&슬래시, 2026-10-15).
  /// 탑다운 한 파 마릿수. 초반 핵앤슬래시(피드백 #4): earlyExtra를 스테이지 1에 더하고 earlyStages까지 곧게 0으로(없으면 0).
  /// 파 총량(pool)은 그대로라 마리가 많을수록 한 마리는 약하다.
  int topMobCountAt(int stage) {
    final m = raw.obj('top').obj('mobCount');
    final early = m.numberOr('earlyExtra', 0);
    final fade = m.numberOr('earlyStages', 1);
    final extra = stage >= fade ? 0 : (early * (fade - stage) / (fade - 1)).round();
    final n = m.integer('base') + stage ~/ m.integer('stagesPerExtra') + extra;
    return n < m.integer('max') ? n : m.integer('max');
  }

  /// 한 파 총량 기준 = min(pool.max, pool.base + floor(stage / pool.stagesPerExtra)). 총 HP·공격·골드 = 단일 곡선 × 이 값.
  int mobPoolAt(int stage) {
    final n = mobPoolBase + stage ~/ mobPoolStagesPerExtra;
    return n < mobPoolMax ? n : mobPoolMax;
  }

  List<String> validate() {
    final e = <String>[];
    final m = raw.obj('monster');
    for (final k in ['hpGrowth', 'attackGrowth', 'goldGrowth']) {
      expect(e, that: m.number(k) > 1, message: 'waves: monster.$k는 1보다 커야 함');
    }
    expect(e, that: tickMs > 0 && 1000 % tickMs == 0, message: 'waves: tickMs는 1000의 약수');
    final skip = rebirthSkip;
    expect(e, that: skip.fraction >= 0 && skip.fraction < 1, message: 'waves: rebirthSkip.fraction은 0 이상 1 미만');
    expect(
      e,
      that: skip.waves >= 0 && skip.waves <= wavesPerStage,
      message: 'waves: rebirthSkip.waves는 0~wavesPerStage',
    );
    e.addAll(top.validate());
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

  /// 부채꼴(강습) 근접 거리: 배 앞머리에서 이만큼 안의 적은 각도와 상관없이 맞는다.
  /// 배에 닿은 적은 x가 shipX로 멈춰 각도가 90°가 되므로 이게 없으면 강습이 붙은 적을 못 친다.
  final double coneNearPx;
  final double contactIntervalSec;
}

class RebirthSkip {
  RebirthSkip(JsonReader j)
    : fraction = j.number('fraction'),
      waves = j.integer('waves'),
      breakSec = j.numberOr('breakSec', 0),
      travelSec = j.numberOr('travelSec', 0),
      breakAccel = j.numberOr('breakAccel', 1),
      breakMinSec = j.numberOr('breakMinSec', 0),
      finaleSec = j.numberOr('finaleSec', 0);

  final double fraction;
  final int waves;

  /// 빠른 항해 돌파(docs/specs/platform-fast-sail-breakthrough.md): 보스 등장 뒤 이 초 안에 못 잡으면 돌파 사격. 0이면 돌파 없음(지금처럼).
  final double breakSec;

  /// 돌파 구간의 스테이지 사이 이동(초). 리듬이 빨라지면 같은 비율로 짧아진다.
  final double travelSec;

  /// 리듬 가속(사용자 지시 '점점 빨라지다 순식간에'): 격파마다 breakSec × breakAccel, 최소 breakMinSec(= 순식간 rush).
  final double breakAccel;
  final double breakMinSec;

  /// 마지막 스테이지 보스: 이 초 뒤 피날레 돌파(렌더가 슬로모션). 0이면 보통 리듬.
  final double finaleSec;
}

/// 탑다운 전장 (탑다운 전환 T0, Settings.battleView == 'top'). 좌표는 왼쪽 위 원점, 배 중심 고정.
/// 거리 판정은 ‘배 둘레 → 적 가장자리’: dist − shipRadius − 적 반경 ≤ 사거리 × reachScale (S5 검토 반영).
class TopFieldDef {
  TopFieldDef.fromJson(JsonReader j)
    : width = j.number('width'),
      height = j.number('height'),
      shipX = j.number('shipX'),
      shipY = j.number('shipY'),
      shipRadius = j.number('shipRadius'),
      mobRadius = j.number('mobRadius'),
      bossRadius = j.number('bossRadius'),
      bossStandoff = j.number('bossStandoff'),
      spawnMargin = j.number('spawnMargin'),
      approachRadius = j.number('approachRadius'),
      approachBoost = j.number('approachBoost'),
      swarmGroupsMin = j.integer('swarmGroupsMin'),
      swarmGroupsMax = j.integer('swarmGroupsMax'),
      swarmSpreadDeg = j.number('swarmSpreadDeg'),
      reachScale = j.number('reachScale');

  final double width;
  final double height;

  /// 배 중심 (화면 가운데 고정).
  final double shipX;
  final double shipY;
  final double shipRadius;
  final double mobRadius;
  final double bossRadius;

  /// 보스가 멈추는 배 중심 거리 (배 둘레 + 보스 반경 + 여유 — 모든 계열 사거리 안).
  final double bossStandoff;

  /// 스폰: 테두리 바로 바깥 여유.
  final double spawnMargin;

  /// 이 반경 밖에서는 해류로 ×approachBoost 다가온다 — 어느 방향이든 도착 시간이 옆모습과 비슷하게.
  final double approachRadius;
  final double approachBoost;

  /// 한 파를 나누는 방향 묶음 수 [min, max]와 묶음 안 흩어짐(±도).
  final int swarmGroupsMin;
  final int swarmGroupsMax;
  final double swarmSpreadDeg;

  /// 사거리 배율 (skills reach × 이 값).
  final double reachScale;

  List<String> validate() {
    final e = <String>[];
    expect(e, that: shipX > 0 && shipX < width && shipY > 0 && shipY < height, message: 'waves.top: 배 중심은 전장 안');
    expect(
      e,
      that: bossStandoff >= shipRadius + bossRadius,
      message: 'waves.top: 보스가 배와 겹치지 않게 standoff ≥ 배 반경 + 보스 반경',
    );
    expect(e, that: swarmGroupsMin >= 1 && swarmGroupsMax >= swarmGroupsMin, message: 'waves.top: swarmGroups 범위');
    expect(e, that: approachBoost >= 1, message: 'waves.top: approachBoost ≥ 1');
    return e;
  }
}
