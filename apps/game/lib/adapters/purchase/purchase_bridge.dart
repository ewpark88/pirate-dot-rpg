import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:game_core/game_core.dart';
import 'package:game_data/game_data.dart';
import 'package:pirate_dot/adapters/purchase/purchase_types.dart';

/// 상품 표(iap.json kind) → 결제 흐름의 상품 종류.
Map<String, ProductKind> purchaseCatalog(GameTables t) => {
  for (final p in t.iap.products.values) p.id: ProductKind.values.byName(p.kind),
};

/// 결제 흐름 ↔ 엔진 다리(계약 요청서 platform-iap 4절 순서): `PurchaseDelivered` → `GrantPurchase` 명령 → 엔진이 토큰을 기록하면
/// **저장을 끝낸 뒤에만** `complete(token)`(Play acknowledge/consume). 그 전에 앱이 죽으면 Play가 다시 보내고, 토큰이 이미 있으면
/// 지급 없이 저장·완료만 한다. 엔진이 지급하지 않으면(계정당 한도 등) 완료하지 않는다 — Play가 3일 뒤 자동 환불.
/// 복원에서 사라진 상품(환불·구독 만료)은 그 상품의 권리를 `RevokeEntitlement`로 끈다. 대기·실패는 [notices]로 UI에.
class PurchaseBridge {
  PurchaseBridge({
    required this.shop,
    required this.tables,
    required this.send,
    required this.state,
    required this.ticks,
    required this.save,
    this.grantTimeout = const Duration(seconds: 3),
  });

  final PurchaseService shop;
  final GameTables tables;
  final void Function(Command) send;
  final GameState Function() state;
  final Stream<RecordedTick> ticks;
  final Future<void> Function() save;

  /// 엔진이 토큰을 기록하길 기다리는 시간(몇 틱이면 충분 — 넘으면 지급 안 됨으로 본다).
  final Duration grantTimeout;

  final _notices = StreamController<PurchaseUpdate>.broadcast();
  StreamSubscription<PurchaseUpdate>? _sub;

  /// UI가 볼 소식: 대기·실패·지급됨(복원 아님).
  Stream<PurchaseUpdate> get notices => _notices.stream;

  void start() => _sub ??= shop.updates.listen((u) => unawaited(_on(u)));

  /// 앱 시작·복귀: 엔진이 '샀다'고 기억하는 비소모·구독 상품을 스토어와 맞춘다.
  Future<void> restore() {
    final owned = {
      for (final p in tables.iap.products.values)
        if (p.kind != 'consumable' && state().entitlements.containsKey('product:${p.id}')) p.id,
    };
    return shop.restore(active: owned);
  }

  Future<void> _on(PurchaseUpdate u) async {
    switch (u) {
      case PurchaseDelivered():
        await _deliver(u);
      case PurchaseRevoked(:final productId):
        for (final r in tables.iap.products[productId]?.entitlements ?? const <({String id, int? days})>[]) {
          send(RevokeEntitlement(r.id));
        }
      case PurchasePending() || PurchaseFailed():
        _notices.add(u);
    }
  }

  Future<void> _deliver(PurchaseDelivered d) async {
    if (!state().purchaseTokens.contains(d.token)) {
      send(GrantPurchase(d.productId, d.token, d.at));
      try {
        await ticks.firstWhere((_) => state().purchaseTokens.contains(d.token)).timeout(grantTimeout);
      } on TimeoutException {
        debugPrint('purchase: ${d.productId} not granted — leaving it uncompleted (Play refunds)');
        return;
      }
      if (!d.restored) _notices.add(d);
    }
    await save(); // 지급이 디스크에 남은 뒤에만
    await shop.complete(d.token);
  }

  Future<void> dispose() async {
    await _sub?.cancel();
    await _notices.close();
  }
}

/// 광고 제거 권리(noAds)가 있으면 광고를 보여 주지 않고 바로 보상(하루 한도는 엔진 GrantAdReward 그대로 — S2 계약).
class EntitledAds implements AdsPort {
  EntitledAds(this.inner, {required this.noAds});

  final AdsPort inner;
  final bool Function() noAds;

  @override
  bool isReady(AdPlacement placement) => noAds() || inner.isReady(placement);

  @override
  Future<AdResult> show(AdPlacement placement) async => noAds() ? AdResult.rewarded : inner.show(placement);
}
