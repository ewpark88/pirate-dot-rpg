import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pirate_dot/adapters/purchase/purchase_bridge.dart';
import 'package:pirate_dot/adapters/purchase/purchase_types.dart';
import 'package:pirate_dot/adapters/purchase/sim_billing_sdk.dart';

/// 결제 포트(상점 UI가 상품·가격·구매를 쓴다). 앱(main.dart)이 덮는다 — 기본은 결제 없음(상점 숨김).
final purchaseServiceProvider = Provider<PurchaseService>((_) => const NoPurchases());

/// 결제 다리(대기·실패 소식 — UI 토스트). 결제가 없으면 null.
final purchaseBridgeProvider = Provider<PurchaseBridge?>((_) => null);

/// 운영자 빌드의 구매 흉내 SDK(운영자 패널 '구매 흉내' — 다음 결과·대기 마치기·환불). 배포 빌드는 null.
final simBillingProvider = Provider<SimBillingSdk?>((_) => null);
