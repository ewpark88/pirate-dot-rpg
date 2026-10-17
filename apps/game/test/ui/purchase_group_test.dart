import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';
import 'package:pirate_dot/adapters/purchase/purchase_providers.dart';
import 'package:pirate_dot/adapters/purchase/sim_billing_sdk.dart';
import 'package:pirate_dot/l10n/gen/app_localizations.dart';
import 'package:pirate_dot/operator/purchase_group.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';

import 'ui_harness.dart';

// 운영자 '결제(흉내)' 묶음 (S5 SimBillingSdk): 다음 결과 · 환불 · 권리 켜기/끄기(OpSetEntitlement).

Future<CommandLog> _pump(WidgetTester tester, GameState s, SimBillingSdk? sim) async {
  tester.view
    ..physicalSize = const Size(400, 1000)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  final log = CommandLog();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        initialGameStateProvider.overrideWithValue(s),
        commandSinkProvider.overrideWithValue(log),
        simBillingProvider.overrideWithValue(sim),
      ],
      child: const MaterialApp(
        locale: Locale('en'),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(body: SingleChildScrollView(child: PurchaseGroup())),
      ),
    ),
  );
  await tester.pump();
  return log;
}

void main() {
  testWidgets('다음 결과 → 취소 · 산 영구 상품 환불 버튼 · 권리 noAds 켜기 → OpSetEntitlement', (tester) async {
    final base = loadFixture('stage37_midgame');
    final s = base.copyWith(entitlements: {'product:no_ads': Entitlement(since: base.savedAt.toUtc())});
    final sim = SimBillingSdk(prices: const {'no_ads': '₩6,900'});
    final log = await _pump(tester, s, sim);
    await tester.tap(find.text('Cancel'));
    await tester.pump();
    expect(sim.next, SimOutcome.cancel);
    expect(find.byKey(const Key('op.sim.refund.no_ads')), findsOneWidget);
    await tester.tap(find.byKey(const Key('op.right.noAds')));
    await tester.pump();
    expect(log.sent.map((c) => c.toJson()), [const OpSetEntitlement('noAds', on: true).toJson()]);
  });

  testWidgets('흉내가 없는 빌드면 안내만(권리 켜기는 된다)', (tester) async {
    await _pump(tester, loadFixture('stage37_midgame'), null);
    expect(find.text('No purchase simulator in this build'), findsOneWidget);
    expect(find.byKey(const Key('op.right.speed')), findsOneWidget);
  });
}
