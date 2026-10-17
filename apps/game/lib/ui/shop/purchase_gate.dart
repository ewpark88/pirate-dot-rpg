import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_core/game_core.dart';
import 'package:pirate_dot/adapters/purchase/purchase_providers.dart';
import 'package:pirate_dot/adapters/purchase/purchase_types.dart';
import 'package:pirate_dot/l10n/gen/app_localizations.dart';
import 'package:pirate_dot/ui/meta/trial_gate.dart';
import 'package:pirate_dot/ui/pixel/pixel_dialog.dart';
import 'package:pirate_dot/ui/shop/iap_text.dart';
import 'package:pirate_dot/ui/shop/shop_data.dart';
import 'package:pirate_dot/ui/shop/shop_offers.dart';
import 'package:pirate_dot/ui/skin/skin_toast.dart';
import 'package:pirate_dot/ui/state/clock_provider.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';

/// 스타터 팩 팝업을 띄울 최고 스테이지(초반 몇 판은 놀게 둔다).
const starterAtStage = 10;

/// 결제 소식(S5 PurchaseBridge.notices) → 토스트: 대기 '처리 중' · 실패(취소는 조용히) · 완료 '구매 완료! 상품'.
/// 스타터 팩 1회 팝업도 여기서 — 맛보기와 같은 '한 실행 한 팝업' 예산·조용한 45초를 쓴다(S1 실기기 ③).
class PurchaseGate extends ConsumerStatefulWidget {
  const PurchaseGate({required this.child, super.key});

  final Widget child;

  @override
  ConsumerState<PurchaseGate> createState() => _PurchaseGateState();
}

class _PurchaseGateState extends ConsumerState<PurchaseGate> {
  StreamSubscription<PurchaseUpdate>? _sub;
  Timer? _tick;
  int _quiet = 0;

  @override
  void initState() {
    super.initState();
    _sub = ref.read(purchaseBridgeProvider)?.notices.listen(_notice);
    if (ref.read(trialsEnabledProvider)) _tick = Timer.periodic(const Duration(seconds: 1), (_) => _poll());
  }

  void _notice(PurchaseUpdate u) {
    if (!mounted) return;
    final l10n = AppLocalizations.of(context);
    final text = switch (u) {
      PurchasePending() => l10n.uiPurchasePending,
      PurchaseFailed(reason: 'cancelled') => null,
      PurchaseFailed(reason: 'unavailable') => l10n.uiPurchaseUnavailable,
      PurchaseFailed(reason: 'alreadyOwned') => l10n.uiPurchaseOwned,
      PurchaseFailed() => l10n.uiPurchaseFailed,
      PurchaseDelivered(:final productId) => l10n.uiPurchaseDone(
        iapName(l10n, ref.read(tablesProvider).iap.products[productId]?.nameKey ?? productId),
      ),
      PurchaseRevoked() => null,
    };
    if (text != null) showSkinToast(context, text);
  }

  void _poll() {
    if (!mounted) return;
    if (!(ModalRoute.of(context)?.isCurrent ?? true)) {
      _quiet = 0;
      return;
    }
    _quiet++;
    final s = ref.read(gameStateProvider);
    final asked = ref.read(trialAskedProvider);
    if (_quiet < trialQuietSec || asked.isNotEmpty || starterShownOn(s) != null) return;
    if (s.progress.bestStage < starterAtStage) return;
    final offer = ref.read(shopOffersProvider)[ShopSection.starter]?.firstOrNull;
    if (offer == null || offer.owned) return;
    asked.add('starter');
    final day = localDate(ref.read(clockProvider).now());
    ref.read(commandSinkProvider).send(MarkHint('$starterHintPrefix$day'));
    unawaited(showSkinDialog<void>(context, builder: (_) => const StarterPackDialog()));
  }

  @override
  void dispose() {
    _tick?.cancel();
    unawaited(_sub?.cancel());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
