import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';
import 'package:game_data/game_data.dart';
import 'package:pirate_dot/adapters/purchase/purchase_providers.dart';
import 'package:pirate_dot/adapters/purchase/purchase_types.dart';
import 'package:pirate_dot/adapters/save_transfer.dart';
import 'package:pirate_dot/render/battle_feed.dart';
import 'package:pirate_dot/ui/home_screen.dart';
import 'package:pirate_dot/ui/meta/trial_gate.dart';
import 'package:pirate_dot/ui/pass/pass_sheet.dart';
import 'package:pirate_dot/ui/pixel/pixel_dialog.dart';
import 'package:pirate_dot/ui/settings/save_transfer_section.dart';
import 'package:pirate_dot/ui/shop/shop_sheet.dart';

import 'ui_harness.dart';

// 오늘 새 화면 영어 점검 (S1 2026-10-18): 상점·패스·탑/러시/던전 카드·세이브 옮기기·맛보기·탑 결과 — 360·tablet en 골든.
// 새 화면은 넘침(RenderFlex overflow)이 나면 이 시험이 실패한다.

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

const _sizes = [('360', Size(360, 640), 3.0), ('tablet', Size(800, 1280), 2.0)];

Future<void> _pump(WidgetTester tester, Size size, double dpr, {int? tab}) async {
  await pumpGame(
    tester,
    _rich(),
    tab: tab ?? 0,
    openTab: tab != null,
    size: size,
    dpr: dpr,
    overrides: [purchaseServiceProvider.overrideWithValue(_Shop()), saveImportProvider.overrideWithValue((s) async {})],
  );
  await tester.pumpAndSettle();
}

Future<void> _shot(WidgetTester tester, String name) async {
  await precacheImages(tester);
  await expectLater(find.byType(MaterialApp), matchesGoldenFile('../goldens/en_new_$name.png'));
}

void main() {
  setUpAll(loadGoldenFonts);
  for (final (dev, size, dpr) in _sizes) {
    testWidgets('상점 $dev', (tester) async {
      await _pump(tester, size, dpr);
      showShop(tester.element(find.byType(HomeScreen))).ignore();
      await tester.pumpAndSettle();
      await _shot(tester, 'shop_$dev');
    });
    testWidgets('패스 $dev', (tester) async {
      await _pump(tester, size, dpr);
      showPixelSheet<void>(
        tester.element(find.byType(HomeScreen)),
        maxHeight: 0.9,
        builder: (_) => const PassSheet(),
      ).ignore();
      await tester.pumpAndSettle();
      await _shot(tester, 'pass_$dev');
    });
    testWidgets('탑·러시·던전 카드 $dev', (tester) async {
      await _pump(tester, size, dpr, tab: 0);
      await showInSheet(tester, 'tower.card');
      await _shot(tester, 'tower_$dev');
      await showInSheet(tester, 'dungeon.card');
      await _shot(tester, 'dungeon_$dev');
    });
    testWidgets('세이브 옮기기·맛보기 $dev', (tester) async {
      await _pump(tester, size, dpr);
      final ctx = tester.element(find.byType(HomeScreen));
      showSkinDialog<void>(ctx, builder: (_) => const SaveImportDialog()).ignore();
      await tester.pumpAndSettle();
      final now = _rich();
      await tester.enterText(find.byKey(const Key('save.text')), SaveTransfer.export(now));
      await tester.tap(find.byKey(const Key('save.check')));
      await tester.pumpAndSettle();
      await _shot(tester, 'save_$dev');
      Navigator.of(tester.element(find.byKey(const Key('save.import')))).pop();
      await tester.pumpAndSettle();
      showSkinDialog<void>(ctx, builder: (_) => const TrialOfferDialog(kind: 'autoUpgrade')).ignore();
      await tester.pumpAndSettle();
      await _shot(tester, 'trial_$dev');
    });
    testWidgets('탑 결과(시간 초과) $dev', (tester) async {
      final feed = StreamController<RecordedTick>.broadcast(sync: true);
      addTearDown(feed.close);
      final s = _rich();
      await pumpGame(
        tester,
        s,
        openTab: false,
        size: size,
        dpr: dpr,
        overrides: [battleFeedProvider.overrideWithValue(feed.stream)],
      );
      feed.add(
        RecordedTick(s.battle!, const [
          TowerEnded(1, floor: 12, reason: 'timeout', kills: 340, chestGems: 25, chestCards: 1),
        ]),
      );
      await tester.pumpAndSettle();
      await _shot(tester, 'tower_result_$dev');
    });
  }
}
