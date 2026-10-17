import 'package:game_data/src/models/common.dart';

/// 선원 계열 8종 (설계서 4.3).
const crewFamilies = [
  'lob',
  'direct',
  'pierce',
  'skip',
  'underwater',
  'air',
  'assault',
  'shock',
];

/// 선원 역할 5종(S2 BALANCE 역할표를 묶음, S1 2026-10-17): 지킴이(강습 근접) · 보스 딜 · 무리(범위·연쇄) · 제어(기절·감속·끌기·밀기) ·
/// 서포트(회복·보호막·피버). UI 역할 칩·추천이 읽는다.
const crewRoles = ['guard', 'boss', 'mob', 'control', 'support'];

/// 등급 5단계, 낮은 것부터.
const rarityOrder = ['common', 'rare', 'hero', 'legend', 'mythic'];

class CrewDef {
  CrewDef.fromJson(JsonReader j)
    : id = j.str('id'),
      num = j.integer('num'),
      baseRarity = j.str('baseRarity'),
      family = j.str('family'),
      role = j.str('role'),
      reachBonus = j.numberOr('reachBonus', 0),
      fx = j.str('fx'),
      skill = j.strOrNull('skill'),
      portrait = j.str('portrait'),
      nameKey = j.str('nameKey'),
      aim = j.has('aim') ? j.obj('aim') : null;

  final String id;
  final int num;

  /// Pirate Busters 원작 등급. 소환 풀 구성에만 쓰고, 이 게임의 등급은 레벨 구간이다.
  final String baseRarity;
  final String family;

  /// 역할 [crewRoles] 중 하나.
  final String role;

  /// 계열 사거리(skills.json attack.reach)에 더하는 선원별 보정(±, 필드 px).
  final double reachBonus;
  final String fx;

  /// 계열 스킬 대신 쓰는 스킬 id (skills.json crewSkills). 없으면 계열 스킬.
  final String? skill;
  final String portrait;
  final String nameKey;

  /// 선원 개성 v2(docs/specs/platform-crew-identity-v2.md, 선택): 계열 공격 위에 덮어쓸 키 —
  /// targets·intervalSec·power·모양 키·`projectile`{speed, lead, hitRadius}·`trait`. 없으면 계열 공격 그대로.
  final JsonReader? aim;
}

class CrewTable {
  CrewTable.fromJson(JsonReader j) : crews = j.objs('crews').map(CrewDef.fromJson).toList();

  final List<CrewDef> crews;

  CrewDef byId(String id) => crews.firstWhere((c) => c.id == id);

  List<String> validate() {
    final e = <String>[];
    final ids = crews.map((c) => c.id).toSet();
    expect(e, that: ids.length == crews.length, message: 'crews: id 중복');
    expect(e, that: crews.length == 40, message: 'crews: 40명이어야 함 (${crews.length})');
    // 계열 v3(사용자 승인 2026-10-16)부터 계열 인원은 5·4·2로 다르다 — 원래 8계열에 한 명 이상이면 된다(새 계열 ring·cluster·laser는 skills 표).
    for (final f in crewFamilies) {
      final n = crews.where((c) => c.family == f).length;
      expect(e, that: n >= 1, message: 'crews: 계열 $f에 선원이 없음');
    }
    for (final c in crews) {
      expect(e, that: crewRoles.contains(c.role), message: 'crews: ${c.id} role ${c.role}는 $crewRoles 중 하나여야 함');
    }
    const expected = {'common': 12, 'rare': 12, 'hero': 8, 'legend': 8};
    for (final r in expected.entries) {
      final n = crews.where((c) => c.baseRarity == r.key).length;
      expect(e, that: n == r.value, message: 'crews: ${r.key} ${r.value}명이어야 함 ($n)');
    }
    return e;
  }
}

class RarityDef {
  RarityDef.fromJson(JsonReader j)
    : id = j.str('id'),
      stars = j.integer('stars'),
      summonRate = j.number('summonRate'),
      levelMin = j.integer('levelMin'),
      levelMax = j.integer('levelMax'),
      color = j.str('color'),
      nameKey = j.str('nameKey');

  final String id;
  final int stars;
  final double summonRate;
  final int levelMin;
  final int levelMax;
  final String color;
  final String nameKey;
}

class RarityTable {
  RarityTable.fromJson(JsonReader j)
    : rarities = j.objs('rarities').map(RarityDef.fromJson).toList(),
      pityCount = j.obj('pity').integer('count'),
      pityMinRarity = j.obj('pity').str('minRarity'),
      bossDropRates = j.numberMap('bossDropRates');

  final List<RarityDef> rarities;
  final int pityCount;
  final String pityMinRarity;

  /// 보스 드롭 카드의 등급 확률 (설계서 4.3.3).
  final Map<String, double> bossDropRates;

  RarityDef byId(String id) => rarities.firstWhere((r) => r.id == id);

  List<String> validate() {
    final e = <String>[];
    final sum = rarities.fold<double>(0, (s, r) => s + r.summonRate);
    expect(e, that: (sum - 1).abs() < probabilityEpsilon, message: 'rarities: 확률 합 $sum ≠ 1.0');
    expect(
      e,
      that: rarities.map((r) => r.id).toList().join() == rarityOrder.join(),
      message: 'rarities: 순서는 ${rarityOrder.join(',')}',
    );
    for (var i = 1; i < rarities.length; i++) {
      expect(
        e,
        that: rarities[i].levelMin == rarities[i - 1].levelMax + 1,
        message: 'rarities: ${rarities[i].id} 레벨 구간이 이어지지 않음',
      );
    }
    expect(e, that: rarities.last.summonRate == 0, message: 'rarities: 신화는 소환에 없어야 함');
    expect(e, that: rarityOrder.contains(pityMinRarity), message: 'rarities: pity.minRarity 오류');
    final dropSum = bossDropRates.values.fold<double>(0, (s, v) => s + v);
    expect(e, that: (dropSum - 1).abs() < probabilityEpsilon, message: 'rarities: bossDropRates 합 $dropSum ≠ 1.0');
    expect(e, that: !bossDropRates.containsKey('mythic'), message: 'rarities: 신화는 보스 드롭에 없어야 함');
    return e;
  }
}

class PromotionDef {
  PromotionDef.fromJson(JsonReader j)
    : from = j.str('from'),
      to = j.str('to'),
      level = j.integer('level'),
      cards = j.integer('cards'),
      goldKills = j.number('goldKills'),
      tokens = j.integer('tokens');

  final String from;
  final String to;
  final int level;
  final int cards;

  /// 승급 골드 = 그때 스테이지 일반 몬스터 처치 골드 × [goldKills].
  final double goldKills;
  final int tokens;
}

class GrowthTable {
  GrowthTable.fromJson(JsonReader j)
    : maxLevel = j.integer('maxLevel'),
      cardExp = j.numberMap('cardExp').map((k, v) => MapEntry(k, v.toInt())),
      expToNext = j.numberMap('expToNext').map((k, v) => MapEntry(k, v.toInt())),
      powerPerLevel = j.number('powerPerLevel'),
      promotionMultiplier = j.number('promotionMultiplier'),
      ownedBonusPerLevel = j.number('ownedBonusPerLevel'),
      promotions = j.objs('promotions').map(PromotionDef.fromJson).toList(),
      bossCards = BossCardsDef.fromJson(j.obj('bossCards')),
      tokenPerSurplusCard = j.integer('tokenPerSurplusCard'),
      tokenExchangeCost = j.integer('tokenExchangeCost');

  final int maxLevel;
  final Map<String, int> cardExp;

  /// 등급 id → 레벨 1 올리는 경험치.
  final Map<String, int> expToNext;
  final double powerPerLevel;
  final double promotionMultiplier;
  final double ownedBonusPerLevel;
  final List<PromotionDef> promotions;
  final BossCardsDef bossCards;
  final int tokenPerSurplusCard;
  final int tokenExchangeCost;

  List<String> validate(RarityTable rarities) {
    final e = <String>[];
    for (final r in rarityOrder) {
      expect(e, that: (expToNext[r] ?? 0) > 0, message: 'growth: expToNext.$r 없음');
    }
    expect(e, that: promotionMultiplier > 1, message: 'growth: promotionMultiplier는 1보다 커야 함');
    expect(e, that: maxLevel == rarities.rarities.last.levelMax, message: 'growth: maxLevel ≠ 신화 levelMax');
    for (final p in promotions) {
      expect(e, that: rarities.byId(p.from).levelMax == p.level, message: 'growth: ${p.from} 승급 레벨 불일치');
      expect(e, that: p.goldKills > 0, message: 'growth: ${p.from} goldKills > 0');
    }
    return e;
  }
}

/// 보스 처치 카드 (설계서 4.3.3): 스테이지 [earlyStageMax]까지 [early]장, 이후 `base + floor(stage / stagesPerExtra)`장.
/// 첫 회차에는 스테이지 [starterFirstStage]부터 [starterEvery]번째 보스마다 [starterCount]번
/// [starterCrew]에게 그 보스의 카드 대신 일반 카드 1장을 준다(사용자 결정 2026-10-14, 첫 승급 30~40분).
class BossCardsDef {
  BossCardsDef.fromJson(JsonReader j)
    : earlyStageMax = j.integer('earlyStageMax'),
      early = j.integer('early'),
      base = j.integer('base'),
      stagesPerExtra = j.integer('stagesPerExtra'),
      starterCrew = j.str('starterCrew'),
      starterCount = j.integer('starterCount'),
      starterEvery = j.integer('starterEvery'),
      starterFirstStage = j.integer('starterFirstStage'),
      repeatEvery = j.integer('repeatEvery'),
      repeatCount = j.integer('repeatCount');

  final int earlyStageMax;
  final int early;
  final int base;
  final int stagesPerExtra;
  final String starterCrew;
  final int starterCount;
  final int starterEvery;

  /// 첫 시작 카드를 주는 보스 스테이지 (첫 승급 시점 미세 조정).
  final int starterFirstStage;

  /// 첫 회차에서 [stage] 보스가 시작 카드(옥토 일반 1장)를 주는가.
  bool isStarterStage(int stage) {
    final k = stage - starterFirstStage;
    return k >= 0 && k % starterEvery == 0 && k ~/ starterEvery < starterCount;
  }

  /// 환생 뒤 이미 깬 스테이지(bestStage 미만) 보스는 [repeatEvery]번째 스테이지마다 [repeatCount]장 (환생 3, 사용자 결정 2026-10-15).
  final int repeatEvery;
  final int repeatCount;

  /// 반복 보스 [stage]를 잡았을 때 받는 카드 수.
  int repeatCountAt(int stage) => stage % repeatEvery == 0 ? repeatCount : 0;

  /// [stage] 보스를 처음 잡았을 때 받는 카드 수.
  int countAt(int stage) => stage <= earlyStageMax ? early : base + stage ~/ stagesPerExtra;
}
