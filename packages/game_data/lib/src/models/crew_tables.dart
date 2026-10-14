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

/// 등급 5단계, 낮은 것부터.
const rarityOrder = ['common', 'rare', 'hero', 'legend', 'mythic'];

class CrewDef {
  CrewDef.fromJson(JsonReader j)
    : id = j.str('id'),
      num = j.integer('num'),
      baseRarity = j.str('baseRarity'),
      family = j.str('family'),
      fx = j.str('fx'),
      skill = j.strOrNull('skill'),
      portrait = j.str('portrait'),
      nameKey = j.str('nameKey');

  final String id;
  final int num;

  /// Pirate Busters 원작 등급. 소환 풀 구성에만 쓰고, 이 게임의 등급은 레벨 구간이다.
  final String baseRarity;
  final String family;
  final String fx;

  /// 계열 스킬 대신 쓰는 스킬 id (skills.json crewSkills). 없으면 계열 스킬.
  final String? skill;
  final String portrait;
  final String nameKey;
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
    for (final f in crewFamilies) {
      final n = crews.where((c) => c.family == f).length;
      expect(e, that: n == 5, message: 'crews: 계열 $f가 5명이 아님 ($n)');
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
      pityMinRarity = j.obj('pity').str('minRarity');

  final List<RarityDef> rarities;
  final int pityCount;
  final String pityMinRarity;

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
    return e;
  }
}

class PromotionDef {
  PromotionDef.fromJson(JsonReader j)
    : from = j.str('from'),
      to = j.str('to'),
      level = j.integer('level'),
      cards = j.integer('cards'),
      gold = j.str('gold'),
      tokens = j.integer('tokens');

  final String from;
  final String to;
  final int level;
  final int cards;

  /// BigNum 문자열 (`"5e3"`).
  final String gold;
  final int tokens;
}

class GrowthTable {
  GrowthTable.fromJson(JsonReader j)
    : maxLevel = j.integer('maxLevel'),
      cardExp = j.numberMap('cardExp').map((k, v) => MapEntry(k, v.toInt())),
      expBase = j.obj('expToNext').number('base'),
      expGrowth = j.obj('expToNext').number('growth'),
      powerPerLevel = j.number('powerPerLevel'),
      promotionMultiplier = j.number('promotionMultiplier'),
      ownedBonusPerLevel = j.number('ownedBonusPerLevel'),
      promotions = j.objs('promotions').map(PromotionDef.fromJson).toList(),
      tokenPerSurplusCard = j.integer('tokenPerSurplusCard'),
      tokenExchangeCost = j.integer('tokenExchangeCost');

  final int maxLevel;
  final Map<String, int> cardExp;
  final double expBase;
  final double expGrowth;
  final double powerPerLevel;
  final double promotionMultiplier;
  final double ownedBonusPerLevel;
  final List<PromotionDef> promotions;
  final int tokenPerSurplusCard;
  final int tokenExchangeCost;

  List<String> validate(RarityTable rarities) {
    final e = <String>[];
    expect(e, that: expGrowth > 1, message: 'growth: expToNext.growth는 1보다 커야 함');
    expect(e, that: promotionMultiplier > 1, message: 'growth: promotionMultiplier는 1보다 커야 함');
    expect(e, that: maxLevel == rarities.rarities.last.levelMax, message: 'growth: maxLevel ≠ 신화 levelMax');
    for (final p in promotions) {
      expect(e, that: rarities.byId(p.from).levelMax == p.level, message: 'growth: ${p.from} 승급 레벨 불일치');
    }
    return e;
  }
}
