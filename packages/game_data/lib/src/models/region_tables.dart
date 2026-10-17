import 'package:game_data/src/models/common.dart';
import 'package:game_data/src/models/enemy_def.dart';

export 'package:game_data/src/models/enemy_def.dart';

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
      nameKey = j.str('nameKey'),
      bossRotation = j.has('bossRotation') ? j.strs('bossRotation') : const [],
      wallBoss = j.strOrNull('wallBoss');

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

  /// 도감 v2(docs/specs/platform-bestiary-v2.md): 보통 스테이지 보스 순환(스테이지 번호로 고정 순서). 비면 [boss] 하나.
  final List<String> bossRotation;

  /// 10단위 벽(wallEvery)의 대보스. null이면 보통 순환.
  final String? wallBoss;
}

/// 보스 하나 (설계서 4.11). 체력은 일반 보스(waves.boss.hpMultiplier) 대비 [hpMultiplier]배.
class BossDef {
  BossDef.fromJson(JsonReader j, {Map<String, dynamic> traitDefaults = const {}})
    : traits = [
        for (final t in (j.raw['traits'] as List?) ?? const [])
          BossTraitDef.of(t is String ? {'type': t} : t as Map<String, dynamic>, traitDefaults, j.path),
      ],
      id = j.str('id'),
      nameKey = j.str('nameKey'),
      hpMultiplier = j.number('hpMultiplier'),
      weakFamilies = j.strs('weakFamilies'),
      mechanic = j.has('mechanic') ? BossMechanic.fromJson(j.obj('mechanic')) : null,
      patterns = j.has('patterns') ? j.objs('patterns').map(BossPatternDef.fromJson).toList() : const [],
      restSec = j.numberOr('restSec', 0),
      splitAt = j.has('splitAt') ? [for (final v in j.raw['splitAt'] as List) (v as num).toDouble()] : const [],
      firstRestSec = j.has('firstRestSec') ? j.number('firstRestSec') : null;

  final String id;

  /// 보스 이름 ARB 키 (battle 레인).
  final String nameKey;
  final double hpMultiplier;

  /// 약점 표시용 계열 (UI·렌더가 아이콘으로).
  final List<String> weakFamilies;
  final BossMechanic? mechanic;

  /// 보스 행동 v2(docs/specs/platform-boss-patterns.md): 순서대로 돌아가는 패턴. 비면 지금처럼 원거리 기본 공격만.
  final List<BossPatternDef> patterns;

  /// 패턴 사이 쉼(초) — 이때는 기본 원거리 공격(BossFired).
  final double restSec;

  /// 등장 뒤 첫 패턴까지 쉼(초, 없으면 restSec) — 보스가 금방 죽어도 첫 패턴을 보게(S2).
  final double? firstRestSec;

  /// 분열(도감 v2 — 아메바·슬라임): HP 비율이 이 값들 아래로 내려갈 때마다 둘로 갈라진다(둘 다 잡아야 격파).
  final List<double> splitAt;

  /// 보스 특성(docs/specs/economy-boss-traits.md, 사용자 요청 #25): 회피·장갑·재생·반사막·분노·호위·가속. 비면 지금 그대로.
  final List<BossTraitDef> traits;

  BossTraitDef? trait(String type) => traits.where((t) => t.type == type).firstOrNull;

  /// 약점 표시(UI): 특성들의 카운터 계열.
  List<String> get counterFamilies => {for (final t in traits) ...t.cfg.strs('counters')}.toList();
}

/// 보스 특성 하나 = regions.json bossTraits[type](기본 수치·카운터) 위에 보스별 덮어쓰기.
class BossTraitDef {
  BossTraitDef(this.type, this.cfg);

  factory BossTraitDef.of(Map<String, dynamic> raw, Map<String, dynamic> defaults, String path) {
    final type = raw['type'] as String;
    final base = (defaults[type] as Map<String, dynamic>?) ?? const {};
    return BossTraitDef(type, JsonReader({...base, ...raw}, '$path.traits.$type'));
  }

  static const types = {'evade', 'armor', 'regen', 'reflect', 'enrage', 'escort', 'dash'};

  final String type;
  final JsonReader cfg;
}

/// 보스 패턴 하나: volley(조준 탄막) · charge(돌진) · summon(졸개) · blast(배 둘레 장판).
class BossPatternDef {
  BossPatternDef.fromJson(JsonReader j)
    : type = j.str('type'),
      warnSec = j.number('warnSec'),
      count = j.intOrNull('count') ?? 1,
      damageRatio = j.numberOr('damageRatio', 0),
      speed = j.numberOr('speed', 0),
      speedMul = j.numberOr('speedMul', 1),
      spreadDeg = j.numberOr('spreadDeg', 0),
      radiusShipMul = j.numberOr('radiusShipMul', 0),
      capMul = j.numberOr('capMul', 1),
      durationSec = j.numberOr('durationSec', 0),
      healRatio = j.numberOr('healRatio', 0);

  final String type;
  final double warnSec;

  /// 탄막 발 수 · 소환 마리 수.
  final int count;

  /// 배 피해 = 보스 공격 × damageRatio (한 대 상한 waves.shipHitCap × [capMul]).
  final double damageRatio;

  /// 탄막 탄속(단위/초).
  final double speed;

  /// 돌진 속도 = 보스 속도 × speedMul.
  final double speedMul;

  /// 탄막 부채꼴 전체 각(도, 연출·이벤트).
  final double spreadDeg;

  /// 장판 반지름 = 배 반경 × radiusShipMul.
  final double radiusShipMul;
  final double capMul;

  /// 먹물(ink): 먹물 구름이 남는 초(그 안 적은 조준되지 않는다).
  final double durationSec;

  /// 삼키기(swallow): 삼킨 잡몹 한 마리당 보스 HP 회복(최대 HP 비율).
  final double healRatio;
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

class RegionsTable {
  RegionsTable.fromJson(JsonReader j)
    : stagesPerRegion = j.integer('stagesPerRegion'),
      midBossEvery = j.integer('midBossEvery'),
      wallEvery = j.intOrNull('wallEvery') ?? 0,
      rotationFromStage = j.intOrNull('rotationFromStage') ?? 0,
      _unlockSteps = [
        if (j.has('speciesUnlock'))
          for (final s in j.obj('speciesUnlock').objs('steps')) (at: s.integer('at'), count: s.integer('count')),
      ],
      _unlockPerRebirth = j.has('speciesUnlock') ? j.obj('speciesUnlock').integer('perRebirth') : 0,
      loopStages = j.integer('loopStages'),
      maxLoopTier = j.integer('maxLoopTier'),
      regions = j.objs('regions').map(RegionDef.fromJson).toList(),
      bosses = {
        for (final b in j.objs('bosses'))
          b.str('id'): BossDef.fromJson(b, traitDefaults: (j.raw['bossTraits'] as Map<String, dynamic>?) ?? const {}),
      },
      enemies = {for (final e in j.objs('enemies')) e.str('id'): EnemyDef.fromJson(e)};

  final int stagesPerRegion;
  final int midBossEvery;

  /// 대보스 벽 간격(도감 v2, 10). 0이면 대보스 없음.
  final int wallEvery;

  /// 보스 순환을 시작하는 스테이지(도감 v2 — 그 앞은 해역 일반 보스, 튜토리얼 3단계 보스 유지). 0이면 처음부터.
  final int rotationFromStage;

  /// 이 스테이지 수마다 해역을 처음부터 다시 돈다 (무한 항해).
  final int loopStages;
  final int maxLoopTier;
  final List<RegionDef> regions;
  final Map<String, BossDef> bosses;
  final Map<String, EnemyDef> enemies;

  List<String> get enemyIds => enemies.keys.toList();

  // 종 해금(사용자 2026-10-18 '초반에는 1~2종만, 환생·스테이지가 높아질수록 다양하게'): 해역 안 스테이지(1~stagesPerRegion)가
  // steps의 at 이상이면 count종, 환생마다 perRebirth종 더. 해역 적 목록 앞에서부터 연다(쉬운 종이 앞). 표에 없으면 전부.
  final List<({int at, int count})> _unlockSteps;
  final int _unlockPerRebirth;

  /// [stage]에서 나오는 무리 종(해역 목록 앞에서부터 해금된 만큼, 최소 1).
  List<String> enemiesAt(int stage, {int rebirths = 0}) {
    final all = regionAt(stage).enemies;
    if (_unlockSteps.isEmpty) return all;
    final inRegion = ((stage - 1) % loopStages) % stagesPerRegion + 1;
    var n = 1;
    for (final s in _unlockSteps) {
      if (inRegion >= s.at) n = s.count;
    }
    n += rebirths * _unlockPerRebirth;
    return all.sublist(0, n.clamp(1, all.length));
  }

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
  /// 도감 v2: 그 밖은 10단위(wallEvery) 벽이면 해역 대보스, 아니면 해역 보스 순환(같은 스테이지는 늘 같은 보스).
  BossDef bossAt(int stage) {
    final r = regionAt(stage);
    final String id;
    if (stage % stagesPerRegion == 0) {
      id = r.regionBoss;
    } else if (stage % midBossEvery == 0) {
      id = r.midBoss;
    } else if (r.wallBoss != null && wallEvery > 0 && stage % wallEvery == 0) {
      id = r.wallBoss!;
    } else if (r.bossRotation.isNotEmpty && stage >= rotationFromStage) {
      id = r.bossRotation[stage % r.bossRotation.length];
    } else {
      id = r.boss;
    }
    return bosses[id]!;
  }

  List<String> validate() {
    final e = <String>[];
    for (final t in [for (final b in bosses.values) ...b.traits]) {
      expect(e, that: BossTraitDef.types.contains(t.type), message: 'regions: 모르는 보스 특성 ${t.type}');
    }
    for (var i = 0; i < regions.length; i++) {
      final r = regions[i];
      expect(e, that: r.fromStage == i * stagesPerRegion + 1, message: 'regions: ${r.id} fromStage 오류');
      for (final en in r.enemies) {
        expect(e, that: enemyIds.contains(en), message: 'regions: ${r.id}의 적 $en이 enemies에 없음');
      }
      for (final b in [r.boss, r.midBoss, r.regionBoss, ...r.bossRotation, ?r.wallBoss]) {
        expect(e, that: bosses.containsKey(b), message: 'regions: ${r.id}의 보스 $b가 bosses에 없음');
      }
    }
    return e;
  }
}
