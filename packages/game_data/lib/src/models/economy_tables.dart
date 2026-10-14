import 'package:game_data/src/models/common.dart';

const shipPartIds = ['cannon', 'hull', 'sail', 'crowsnest', 'cargo'];

class ShipPartDef {
  ShipPartDef.fromJson(JsonReader j)
    : id = j.str('id'),
      stat = j.str('stat'),
      formula = j.str('formula'),
      base = j.number('base'),
      growth = j.number('growth'),
      costBase = j.number('costBase'),
      costGrowth = j.number('costGrowth'),
      maxLevel = j.intOrNull('maxLevel'),
      milestoneEvery = j.intOrNull('milestoneEvery'),
      milestoneMultiplier = j.number('milestoneMultiplier'),
      nameKey = j.str('nameKey');

  final String id;
  final String stat;

  /// `exp`: base × growth^Lv, `linear`: base + growth × Lv.
  final String formula;
  final double base;
  final double growth;
  final double costBase;
  final double costGrowth;
  final int? maxLevel;
  final int? milestoneEvery;
  final double milestoneMultiplier;
  final String nameKey;
}

class ShipPartsTable {
  ShipPartsTable.fromJson(JsonReader j)
    : parts = j.objs('parts').map(ShipPartDef.fromJson).toList(),
      critChanceMax = j.obj('caps').number('critChanceMax'),
      critMultiplier = j.obj('caps').number('critMultiplier'),
      attackSpeedMax = j.obj('caps').number('attackSpeedMax'),
      skillCooldownMinSec = j.obj('caps').number('skillCooldownMinSec');

  final List<ShipPartDef> parts;
  final double critChanceMax;
  final double critMultiplier;
  final double attackSpeedMax;
  final double skillCooldownMinSec;

  ShipPartDef byId(String id) => parts.firstWhere((p) => p.id == id);

  List<String> validate() {
    final e = <String>[];
    expect(
      e,
      that: parts.map((p) => p.id).join(',') == shipPartIds.join(','),
      message: 'ship_parts: 부위는 ${shipPartIds.join(',')}',
    );
    for (final p in parts) {
      expect(e, that: p.costGrowth > 1, message: 'ship_parts: ${p.id} costGrowth는 1보다 커야 함');
      expect(e, that: p.formula == 'exp' || p.formula == 'linear', message: 'ship_parts: ${p.id} formula 오류');
      if (p.formula == 'exp') {
        expect(e, that: p.growth > 1, message: 'ship_parts: ${p.id} growth는 1보다 커야 함');
      }
    }
    return e;
  }
}

class ShipTierDef {
  ShipTierDef.fromJson(JsonReader j)
    : id = j.str('id'),
      stage = j.integer('stage'),
      slots = j.integer('slots'),
      damageBonus = j.number('damageBonus'),
      sprite = j.str('sprite'),
      nameKey = j.str('nameKey');

  final String id;
  final int stage;
  final int slots;
  final double damageBonus;
  final String sprite;
  final String nameKey;
}

class ShipTiersTable {
  ShipTiersTable.fromJson(JsonReader j) : tiers = j.objs('tiers').map(ShipTierDef.fromJson).toList();

  final List<ShipTierDef> tiers;

  /// [stage]에서의 배 등급.
  ShipTierDef tierAt(int stage) => tiers.lastWhere((t) => t.stage <= stage, orElse: () => tiers.first);

  List<String> validate() {
    final e = <String>[];
    expect(e, that: tiers.first.stage == 1, message: 'ship_tiers: 첫 등급은 스테이지 1');
    for (var i = 1; i < tiers.length; i++) {
      expect(e, that: tiers[i].stage > tiers[i - 1].stage, message: 'ship_tiers: 스테이지 오름차순');
      expect(e, that: tiers[i].slots >= tiers[i - 1].slots, message: 'ship_tiers: 슬롯 수 감소');
    }
    return e;
  }
}

class AdPlacementDef {
  AdPlacementDef.fromJson(JsonReader j)
    : id = j.str('id'),
      dailyLimit = j.intOrNull('dailyLimit'),
      reward = j.obj('reward');

  final String id;
  final int? dailyLimit;

  /// 보상 형태는 장치마다 달라 경제 레인이 해석한다.
  final JsonReader reward;
}

class AdsTable {
  AdsTable.fromJson(JsonReader j)
    : dailyCap = j.integer('dailyCap'),
      firstOfferAfterSec = j.integer('firstOfferAfterSec'),
      placements = j.objs('placements').map(AdPlacementDef.fromJson).toList(),
      chest = j.obj('chest');

  final int dailyCap;
  final int firstOfferAfterSec;
  final List<AdPlacementDef> placements;
  final JsonReader chest;

  List<String> validate() {
    final e = <String>[];
    const ids = ['chest', 'tailwind', 'offline', 'bossSupport', 'freeSummon'];
    expect(e, that: placements.map((p) => p.id).toSet().containsAll(ids), message: 'ads: 장치 누락 (${ids.join(',')})');
    expect(e, that: dailyCap > 0, message: 'ads: dailyCap > 0');
    return e;
  }
}

class MetaTable {
  MetaTable.fromJson(JsonReader j)
    : raw = j,
      rebirth = j.obj('rebirth'),
      startingCrews = j.strs('startingCrews'),
      summonCostGems = j.integer('summonCostGems'),
      offlineMaxSec = j.obj('offline').integer('maxSec'),
      offlineCardsPerMax = j.obj('offline').integer('cardsPerMax'),
      offlineEfficiency = j.obj('offline').number('efficiency'),
      offlineMinWaveSec = j.obj('offline').number('minWaveSec'),
      offlineMinSec = j.obj('offline').integer('minSec'),
      dailyQuests = j.objs('dailyQuests'),
      dailyQuestRewardGems = j.integer('dailyQuestRewardGems'),
      autoUpgradeUnlockStage = j.integer('autoUpgradeUnlockStage');

  final JsonReader raw;
  final JsonReader rebirth;

  /// 새 게임의 선원 (설계서 4.3.3: 옥토·톡).
  final List<String> startingCrews;
  final int summonCostGems;
  final int offlineMaxSec;
  final int offlineCardsPerMax;

  /// 오프라인 골드 = 온라인 추정 × 이 비율 (사용자 결정 2026-10-14, 8시간 = 강화 3~8회가 되게 sim으로 맞춘다).
  final double offlineEfficiency;

  /// 초당 골드 추정에서 한 파의 최소 시간(초). 화력이 압도적이면 적이 들어오는 시간이 한 파를 정한다.
  final double offlineMinWaveSec;

  /// 이보다 짧게 떠나 있었으면 복귀 보상(팝업) 없음.
  final int offlineMinSec;
  final List<JsonReader> dailyQuests;
  final int dailyQuestRewardGems;
  final int autoUpgradeUnlockStage;

  List<String> validate() {
    final e = <String>[];
    expect(e, that: dailyQuests.length <= 4, message: 'meta: 일일 퀘스트는 4개 이하 (피로 금지 규칙)');
    expect(e, that: rebirth.number('exponent') > 1, message: 'meta: rebirth.exponent > 1');
    expect(e, that: !raw.obj('attendance').boolean('resetOnMiss'), message: 'meta: 출석 초기화 금지 (피로 금지 규칙)');
    return e;
  }
}
