part of 'events.dart';

// 유료 상품 이벤트 (계약 platform-iap).

GameEvent _iapEventFromJson(int t, Json j) => switch (j['type'] as String) {
  'purchaseGranted' => PurchaseGranted(
    t,
    productId: j['productId'] as String,
    gems: j['gems'] as int? ?? 0,
    summons: j['summons'] as int? ?? 0,
    heroCards: j['heroCards'] as int? ?? 0,
    skins: (j['skins'] as List?)?.cast<String>() ?? const [],
    rights: (j['rights'] as List?)?.cast<String>() ?? const [],
  ),
  _ => EntitlementChanged(t, id: j['id'] as String, active: j['active'] as bool),
};

/// 구매 지급(UI 보상 연출): 실제로 준 젬(첫 구매 2배 포함)·소환·영웅 확정·스킨·켠 권리.
class PurchaseGranted extends GameEvent {
  const PurchaseGranted(
    super.tick, {
    required this.productId,
    this.gems = 0,
    this.summons = 0,
    this.heroCards = 0,
    this.skins = const [],
    this.rights = const [],
  });

  final String productId;
  final int gems;
  final int summons;
  final int heroCards;
  final List<String> skins;
  final List<String> rights;

  @override
  String get type => 'purchaseGranted';

  @override
  Json _fields() => {
    'productId': productId,
    if (gems != 0) 'gems': gems,
    if (summons != 0) 'summons': summons,
    if (heroCards != 0) 'heroCards': heroCards,
    if (skins.isNotEmpty) 'skins': skins,
    if (rights.isNotEmpty) 'rights': rights,
  };
}

/// 권리가 켜지거나 꺼졌다(광고 끄기·배속·오프라인 상한 등 화면 갱신).
class EntitlementChanged extends GameEvent {
  const EntitlementChanged(super.tick, {required this.id, required this.active});

  final String id;
  final bool active;

  @override
  String get type => 'entitlementChanged';

  @override
  Json _fields() => {'id': id, 'active': active};
}
