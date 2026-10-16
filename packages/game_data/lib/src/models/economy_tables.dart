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
      accelLevels = (j.raw['accelLevels'] as num?)?.toDouble(),
      accelFrom = j.intOrNull('accelFrom') ?? 0,
      costRatio = (j.raw['costRatio'] as num?)?.toDouble(),
      visualStages = [for (final v in j.raw['visualStages'] as List) (v as num).toInt()],
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

  /// 가속(선택, 골드 재조정 2026-10-16 '강화가 갈수록 드물게'): 있으면 효과·비용의 레벨 자리에 Lv + d² ÷ (2 × accelLevels)를 쓴다(d = max(0, Lv − accelFrom)).
  /// 레벨이 오를수록 한 번이 더 크고 비싸다. 없으면 Lv 그대로.
  final double? accelLevels;

  /// 가속이 시작되는 레벨(그 아래는 Lv 그대로 — 초반 벽·튜토리얼 보스를 지키려고). 없으면 0.
  final int accelFrom;

  /// 있으면 비용 = 그 레벨 효과 × costRatio (화물칸: 용량의 60% — 꽉 찬 금고로 다음 화물칸을 산다). costBase·costGrowth 대신.
  final double? costRatio;

  /// 배 외형이 바뀌는 레벨 (오름차순, 1부터). 지금 단계 = 이 목록에서 레벨 이하인 것의 수 (사용자 지시 2026-10-15).
  final List<int> visualStages;
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
      expect(
        e,
        that: p.costRatio != null ? p.costRatio! > 0 && p.growth > 1 : p.costGrowth > 1,
        message: 'ship_parts: ${p.id} costGrowth(또는 costRatio가 있으면 growth)는 1보다 커야 함',
      );
      expect(e, that: p.formula == 'exp' || p.formula == 'linear', message: 'ship_parts: ${p.id} formula 오류');
      final v = p.visualStages;
      var ascending = v.isNotEmpty && v.first == 1;
      for (var i = 1; i < v.length; i++) {
        ascending = ascending && v[i] > v[i - 1];
      }
      expect(e, that: ascending, message: 'ship_parts: ${p.id} visualStages는 1부터 오름차순');
      if (p.maxLevel case final max?) {
        expect(e, that: v.isEmpty || v.last <= max, message: 'ship_parts: ${p.id} visualStages는 maxLevel 이하');
      }
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
      topRadius = j.number('topRadius'),
      topHalfWidth = j.number('topHalfWidth'),
      topHullBow = j.number('topHullBow'),
      topHullStern = j.number('topHullStern'),
      damageBonus = j.number('damageBonus'),
      sprite = j.str('sprite'),
      nameKey = j.str('nameKey');

  final String id;
  final int stage;
  final int slots;

  /// 탑다운 배 반경(충돌·사거리 기준 둘레, S3 배 크기 t1 34×80 ~ t3 40×100).
  final double topRadius;

  /// 탑다운 선체(위에서 본 배, 뱃머리 위): 반폭, 배 중심에서 뱃머리·배꼬리까지 — **배율 1·선체 1단계 기준**(그림 프레임 1px = 전장 1단위).
  /// 선체 그림은 프레임 가운데보다 배꼬리 쪽으로 치우쳐 있어 뱃머리·배꼬리를 따로 둔다. 바깥 외곽선·바우스프릿·충각은 뺀 값.
  /// 엔진은 × waves.top.shipScale × 선체 강화 단계 커짐(hullGrow)으로 쓴다 — 렌더와 같은 키(제안 platform-ship-hitbox, S1 채택).
  final double topHalfWidth;
  final double topHullBow;
  final double topHullStern;
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
      autoUpgradeUnlockStage = j.integer('autoUpgradeUnlockStage'),
      notificationsDailyMax = j.obj('notifications').integer('dailyMax');

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

  /// 일일 퀘스트 하나 끝낼 때마다 받는 젬 (사용자 결정 2026-10-14: 퀘스트마다 10).
  final int dailyQuestRewardGems;
  final int autoUpgradeUnlockStage;

  /// 오프라인 가득 로컬 알림의 하루 최대 횟수 (울릴 현지 날짜 기준, platform OfflineFullNotifier).
  final int notificationsDailyMax;

  List<String> validate() {
    final e = <String>[];
    expect(e, that: dailyQuests.length <= 4, message: 'meta: 일일 퀘스트는 4개 이하 (피로 금지 규칙)');
    expect(e, that: rebirth.number('exponent') > 1, message: 'meta: rebirth.exponent > 1');
    expect(e, that: !raw.obj('attendance').boolean('resetOnMiss'), message: 'meta: 출석 초기화 금지 (피로 금지 규칙)');
    expect(
      e,
      that: notificationsDailyMax >= 0 && notificationsDailyMax <= 1,
      message: 'meta: notifications.dailyMax는 0~1 (피로 금지 규칙: 알림 하루 1회)',
    );
    return e;
  }
}
