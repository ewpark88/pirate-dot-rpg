import 'package:game_data/src/models/common.dart';

/// 유료 상품(docs/specs/economy-iap.md, 사용자 가격 확정 2026-10-17 · 계약 platform-iap). 가격은 스토어가 정한다 — 표엔 효과만.
/// [kind]: consumable(젬 팩) · nonConsumable(영구·스킨·스타터) · subscription(30일 — 권리 `days`).
class IapProduct {
  IapProduct.fromJson(JsonReader j)
    : id = j.str('id'),
      nameKey = j.str('nameKey'),
      kind = j.str('kind'),
      gems = j.intOrNull('gems') ?? 0,
      summons = j.intOrNull('summons') ?? 0,
      heroCards = j.intOrNull('heroCards') ?? 0,
      skins = j.has('skins') ? j.strs('skins') : const [],
      entitlements = [
        if (j.has('entitlements'))
          for (final e in j.objs('entitlements')) (id: e.str('id'), days: e.intOrNull('days')),
      ],
      firstBuyDouble = j.raw['firstBuyDouble'] == true,
      limit = j.intOrNull('limit');

  final String id;
  final String nameKey;
  final String kind;
  final int gems;
  final int summons;
  final int heroCards;
  final List<String> skins;

  /// 켜지는 권리(noAds·speed·gemSub·offline12·pass). `days`가 있으면 그만큼(구독 30일), 없으면 영구.
  final List<({String id, int? days})> entitlements;

  /// 첫 구매 젬 2배(상품마다 한 번).
  final bool firstBuyDouble;

  /// 계정당 살 수 있는 횟수(스타터 팩 1). null = 제한 없음.
  final int? limit;
}

/// 항해 패스 한 단계 보상(무료·유료 줄). 비어 있는 값은 0.
typedef PassReward = ({
  int gems,
  int summons,
  int pieces,
  int heroCards,
  int legendSummon,
  List<String> skins,
  String? title,
});

PassReward _reward(JsonReader j) => (
  gems: j.intOrNull('gems') ?? 0,
  summons: j.intOrNull('summons') ?? 0,
  pieces: j.intOrNull('pieces') ?? 0,
  heroCards: j.intOrNull('heroCards') ?? 0,
  legendSummon: j.intOrNull('legendSummon') ?? 0,
  skins: j.has('skins') ? j.strs('skins') : const <String>[],
  title: j.raw['title'] as String?,
);

/// 항해 패스(시즌 30일, economy-iap.md 3절): 경험치 [xp](출처별) → [xpPerLevel]마다 한 단계, 무료 줄은 누구나·유료 줄은 pass 권리.
class PassTable {
  PassTable.fromJson(JsonReader j)
    : season = j.str('season'),
      xpPerLevel = j.integer('xpPerLevel'),
      xp = {for (final k in j.obj('xp').raw.keys) k: j.obj('xp').integer(k)},
      free = j.objs('free').map(_reward).toList(),
      paid = j.objs('paid').map(_reward).toList();

  /// 시즌 id — 바뀌면 진행이 처음부터.
  final String season;
  final int xpPerLevel;
  final Map<String, int> xp;
  final List<PassReward> free;
  final List<PassReward> paid;
}

class IapTable {
  IapTable.fromJson(JsonReader j)
    : gemSubDaily = j.integer('gemSubDaily'),
      firstBuyMultiplier = j.integer('firstBuyMultiplier'),
      offlineHours = j.integer('offlineHours'),
      speedMultiplier = j.integer('speedMultiplier'),
      products = {for (final p in j.objs('products').map(IapProduct.fromJson)) p.id: p},
      pass = PassTable.fromJson(j.obj('pass'));

  /// 월간 젬: 구독 중 하루 한 번 받는 젬.
  final int gemSubDaily;

  /// 첫 구매 젬 배수(firstBuyDouble 상품, 상품마다 한 번).
  final int firstBuyMultiplier;

  /// offline12 권리가 있으면 오프라인 상한(시간).
  final int offlineHours;

  /// speed 권리가 있으면 전투 배속(순풍과 겹치면 이 값 그대로 — 곱하지 않음).
  final int speedMultiplier;
  final Map<String, IapProduct> products;
  final PassTable pass;

  static const kinds = {'consumable', 'nonConsumable', 'subscription'};
  static const rights = {'noAds', 'speed', 'gemSub', 'offline12', 'pass'};

  List<String> validate() {
    final e = <String>[];
    expect(
      e,
      that: gemSubDaily > 0 && offlineHours > 0 && speedMultiplier > 1,
      message: 'iap: gemSubDaily·offlineHours > 0, speedMultiplier > 1',
    );
    expect(
      e,
      that: pass.free.length == pass.paid.length && pass.xpPerLevel > 0,
      message: 'iap: pass 무료·유료 줄 길이가 같고 xpPerLevel > 0',
    );
    for (final p in products.values) {
      expect(e, that: kinds.contains(p.kind), message: 'iap: ${p.id} kind ${p.kind}');
      expect(e, that: p.entitlements.every((r) => rights.contains(r.id)), message: 'iap: ${p.id}의 권리 id가 목록에 없음');
      expect(e, that: p.kind != 'consumable' || p.entitlements.isEmpty, message: 'iap: ${p.id} 소모 상품은 권리를 켜지 않는다');
      expect(
        e,
        that: p.kind != 'subscription' || p.entitlements.every((r) => (r.days ?? 0) > 0),
        message: 'iap: ${p.id} 구독은 days가 있어야 함',
      );
    }
    return e;
  }
}
