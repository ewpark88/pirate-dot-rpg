import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:game_core/game_core.dart';
import 'package:pirate_dot/adapters/purchase/purchase_providers.dart';
import 'package:pirate_dot/adapters/purchase/sim_billing_sdk.dart';
import 'package:pirate_dot/l10n/gen/app_localizations.dart';
import 'package:pirate_dot/ui/shop/shop_sheet.dart';
import 'package:pirate_dot/ui/state/clock_provider.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';

/// 권리 id(iap.json entitlements) — 운영자 켜기/끄기.
const _rights = ['noAds', 'speed', 'offline12', 'gemSub', 'pass'];

/// 운영자 패널 '결제(흉내)' 묶음 (S5 SimBillingSdk · 운영자 빌드만): 다음 결과(성공·취소·대기·오류) · 대기 마치기 ·
/// 산 상품 환불(다음 복원에서 권리 회수) · 마지막 구매 다시 보내기(지급 두 번 안 되는지) · 권리 켜기/끄기(OpSetEntitlement) ·
/// 상점 열기.
class PurchaseGroup extends ConsumerStatefulWidget {
  const PurchaseGroup({super.key});

  @override
  ConsumerState<PurchaseGroup> createState() => _PurchaseGroupState();
}

class _PurchaseGroupState extends ConsumerState<PurchaseGroup> {
  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final sim = ref.watch(simBillingProvider);
    final t = ref.watch(tablesProvider);
    final s = ref.watch(gameStateProvider);
    final now = ref.watch(clockProvider).now();
    final sink = ref.read(commandSinkProvider);
    // 산 상품(경제 'product:<id>' 기록), 최근 것이 먼저.
    final bought = [
      for (final e in s.entitlements.entries)
        if (e.key.startsWith('product:')) (id: e.key.substring('product:'.length), since: e.value.since),
    ]..sort((a, b) => b.since.compareTo(a.since));
    Future<void> restore() => ref.read(purchaseServiceProvider).restore(active: {for (final b in bought) b.id});

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        OutlinedButton(
          key: const Key('op.shop'),
          onPressed: () => unawaited(showShop(context)),
          child: Text(l10n.opShopOpen),
        ),
        if (sim == null)
          Text(l10n.opSimNone)
        else ...[
          Text(l10n.opSimNext),
          SegmentedButton<SimOutcome>(
            key: const Key('op.sim.next'),
            segments: [
              ButtonSegment(value: SimOutcome.success, label: Text(l10n.opSimSuccess)),
              ButtonSegment(value: SimOutcome.cancel, label: Text(l10n.opSimCancel)),
              ButtonSegment(value: SimOutcome.pending, label: Text(l10n.opSimPending)),
              ButtonSegment(value: SimOutcome.error, label: Text(l10n.opSimError)),
            ],
            selected: {sim.next},
            onSelectionChanged: (v) => setState(() => sim.next = v.single),
          ),
          OutlinedButton(
            key: const Key('op.sim.settle'),
            onPressed: () => sim.settlePending(consumable: (id) => t.iap.products[id]?.kind == 'consumable'),
            child: Text(l10n.opSimSettle),
          ),
          for (final b in bought.where((b) => t.iap.products[b.id]?.kind != 'consumable'))
            OutlinedButton(
              key: Key('op.sim.refund.${b.id}'),
              onPressed: () {
                sim.refund(b.id);
                unawaited(restore());
              },
              child: Text(l10n.opSimRefund(b.id)),
            ),
          if (s.purchaseTokens.isNotEmpty && bought.isNotEmpty)
            OutlinedButton(
              key: const Key('op.sim.replay'),
              onPressed: () => sim.replay(s.purchaseTokens.last, bought.first.id),
              child: Text(l10n.opSimReplay),
            ),
        ],
        Text(l10n.opEntitlements),
        for (final id in _rights)
          FilterChip(
            key: Key('op.right.$id'),
            label: Text(id),
            selected: entitlementActive(s, id, now),
            onSelected: (on) => sink.send(OpSetEntitlement(id, on: on)),
          ),
      ],
    );
  }
}
