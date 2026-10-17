import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';
import 'package:game_data/game_data.dart';
import 'package:pirate_dot/adapters/purchase/purchase_providers.dart';
import 'package:pirate_dot/adapters/purchase/purchase_types.dart';
import 'package:pirate_dot/adapters/save_transfer.dart';
import 'package:pirate_dot/ui/home_screen.dart';
import 'package:pirate_dot/ui/meta/trial_gate.dart';
import 'package:pirate_dot/ui/pass/pass_sheet.dart';
import 'package:pirate_dot/ui/pixel/pixel_dialog.dart';
import 'package:pirate_dot/ui/settings/save_transfer_section.dart';
import 'package:pirate_dot/ui/shop/shop_sheet.dart';

import 'ui_harness.dart';

// 새 화면 접근성 자동 검사 (S1 2026-10-18): 누르는 칸 48dp(androidTapTargetGuideline) · 글자 대비(textContrastGuideline).
// 상점·패스·탑/던전 카드·세이브 옮기기·맛보기.

class _Shop implements PurchaseService {
  @override
  Future<bool> available() async => true;
  @override
  Future<List<ProductInfo>> products(Set<String> ids) async => [
    for (final id in ids) ProductInfo(id: id, kind: ProductKind.consumable, price: r'$4.99'),
  ];
  @override
  Future<void> buy(String productId) async {}
  @override
  Stream<PurchaseUpdate> get updates => const Stream.empty();
  @override
  Future<void> restore({required Set<String> active}) async {}
  @override
  Future<void> complete(String token) async {}
}

final _t = GameTables.load();

GameState _rich() {
  final s = loadFixture('stage37_midgame');
  final g = dungeonToday(s, _t, s.savedAt).str('id');
  return s.copyWith(
    progress: s.progress.copyWith(bestStage: 80),
    tower: const TowerState(tickets: 2, refilledOn: '2026-10-12', best: 12, firstCleared: 12),
    rush: const RushState(week: '2026-10-12', tickets: 7, bestTicks: 1500, claimed: [0]),
    dungeon: DungeonState(tickets: 2, refilledOn: '2026-10-12', cleared: {g: 3}),
    pass: PassState(season: _t.iap.pass.season, xp: _t.iap.pass.xpPerLevel * 4, best: 37, free: 2),
  );
}

Future<void> _pump(WidgetTester tester, {int? tab}) async {
  await pumpGame(
    tester,
    _rich(),
    tab: tab ?? 0,
    openTab: tab != null,
    overrides: [purchaseServiceProvider.overrideWithValue(_Shop()), saveImportProvider.overrideWithValue((s) async {})],
  );
  await tester.pumpAndSettle();
}

Future<void> _check(WidgetTester tester) async {
  final handle = tester.ensureSemantics();
  await expectLater(tester, meetsGuideline(androidTapTargetGuideline));
  await expectLater(tester, meetsGuideline(textContrastGuideline));
  handle.dispose();
}

void main() {
  testWidgets('상점', (tester) async {
    await _pump(tester);
    showShop(tester.element(find.byType(HomeScreen))).ignore();
    await tester.pumpAndSettle();
    await _check(tester);
  });

  testWidgets('패스', (tester) async {
    await _pump(tester);
    showPixelSheet<void>(
      tester.element(find.byType(HomeScreen)),
      maxHeight: 0.9,
      builder: (_) => const PassSheet(),
    ).ignore();
    await tester.pumpAndSettle();
    await _check(tester);
  });

  testWidgets('탑·던전 카드(항해 탭)', (tester) async {
    await _pump(tester, tab: 0);
    await showInSheet(tester, 'tower.card');
    await _check(tester);
    await showInSheet(tester, 'dungeon.card');
    await _check(tester);
  });

  testWidgets('세이브 옮기기 · 맛보기', (tester) async {
    await _pump(tester);
    final ctx = tester.element(find.byType(HomeScreen));
    showSkinDialog<void>(ctx, builder: (_) => const SaveImportDialog()).ignore();
    await tester.pumpAndSettle();
    await tester.enterText(find.byKey(const Key('save.text')), SaveTransfer.export(_rich()));
    await tester.tap(find.byKey(const Key('save.check')));
    await tester.pumpAndSettle();
    await _check(tester);
    Navigator.of(tester.element(find.byKey(const Key('save.import')))).pop();
    await tester.pumpAndSettle();
    showSkinDialog<void>(ctx, builder: (_) => const TrialOfferDialog(kind: 'speed')).ignore();
    await tester.pumpAndSettle();
    await _check(tester);
  });
}
