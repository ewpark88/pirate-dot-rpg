import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';
import 'package:game_data/game_data.dart';
import 'package:pirate_dot/l10n/gen/app_localizations.dart';
import 'package:pirate_dot/ui/ads/ad_buttons.dart';
import 'package:pirate_dot/ui/ads/ad_providers.dart';
import 'package:pirate_dot/ui/dock/dock_request.dart';
import 'package:pirate_dot/ui/offline/offline_reward.dart';
import 'package:pirate_dot/ui/pixel/pixel_button.dart';
import 'package:pirate_dot/ui/pixel/pixel_theme.dart';
import 'package:pirate_dot/ui/skin/skin_button.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';

import 'ui_harness.dart';

// 화물칸 = 골드 금고 용량 (S2 3ba4dcd, 사용자 지시 2026-10-16) + 자동 강화는 광고 10분으로만.

final _t = GameTables.load();

/// 금고를 [ratio]만큼 채운 샘플 (1.0 이상 = 가득).
GameState _filled(double ratio) {
  final s = loadFixture('stage37_midgame');
  final cap = goldCapacity(s, _t);
  return s.copyWith(wallet: s.wallet.copyWith(gold: cap.times(ratio)));
}

const List<(String, Size, double)> _devices = [
  ('360', Size(360, 640), 3.0),
  ('s24', s24Size, s24Dpr),
  ('411', Size(411, 891), 2.625),
  ('tablet', Size(800, 1280), 2.0),
];

void main() {
  testWidgets('모두 강화(사용자 2026-10-17): 화물칸 가득 알약 옆 → 경제 bestUpgradePlan대로 부위마다 UpgradePart(times) + 토스트', (
    tester,
  ) async {
    final s = _filled(1);
    final plan = bestUpgradePlan(s, _t);
    expect(plan.levels, isNotEmpty);
    final log = await pumpGame(tester, s, openTab: false);
    await tester.tap(find.byKey(const Key('upgradeAll.pill')));
    await tester.pump();
    final sent = log.sent.whereType<UpgradePart>().toList();
    expect({for (final c in sent) c.part: c.times}, plan.levels);
    expect(find.byKey(const Key('skin.toast')), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('배 탭 위 큰 "모두 강화"(56dp) — 살 것이 없으면 흐림', (tester) async {
    final s = _filled(1);
    await pumpGame(tester, s, tab: shipTab);
    expect(tester.getSize(find.byKey(const Key('upgradeAll'))).height, greaterThanOrEqualTo(56));
    final broke = s.copyWith(wallet: s.wallet.copyWith(gold: BigNum.zero));
    await pumpGame(tester, broke, tab: shipTab);
    expect(tester.widget<SkinButton>(find.byKey(const Key('upgradeAll'))).onPressed, isNull);
  });

  testWidgets('골드 = 현재 / 최대(화물칸 상한, 피드백 #7)', (tester) async {
    final s = _filled(0.5);
    await pumpGame(tester, s, openTab: false);
    expect(find.text(' / ${goldCapacity(s, _t).format()}'), findsOneWidget);
  });

  testWidgets('가득: 상단 막대 + 알약 → 누르면 배 탭, 화물칸 강화 버튼에 손가락 · 줄 효과 "최대 a → b"', (tester) async {
    await pumpGame(tester, _filled(1), openTab: false);
    expect(find.byKey(const Key('cargo.bar')), findsOneWidget);
    expect(find.byKey(const Key('cargo.full')), findsOneWidget);
    await tester.tap(find.byKey(const Key('cargo.full')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('ship.upgrade.cargo')));
    await tester.pump();
    expect(find.byKey(const Key('tutorial.spot.ship.upgrade.cargo')), findsOneWidget);
    final cargo = _t.shipParts.byId('cargo');
    final lv = loadFixture('stage37_midgame').ship.level('cargo');
    expect(find.text('Max ${partEffect(cargo, lv).format()} → ${partEffect(cargo, lv + 1).format()}'), findsOneWidget);
  });

  testWidgets('상한을 넘게 가졌으면(복귀 ×3) "현재 / 최대" 대신 금빛 "+넘침" 배지(실기기 ④)', (tester) async {
    final s = _filled(3);
    final cap = goldCapacity(s, _t);
    await pumpGame(tester, s, openTab: false);
    expect(find.byKey(const Key('top.goldCap')), findsNothing);
    expect(find.text('+${(cap.times(3) - cap).format()} extra'), findsOneWidget);
  });

  testWidgets('여유 있으면(50%) 알약·손가락 없음', (tester) async {
    await pumpGame(tester, _filled(0.5), tab: shipTab);
    expect(find.byKey(const Key('cargo.full')), findsNothing);
    expect(find.byKey(const Key('tutorial.spot.ship.upgrade.cargo')), findsNothing);
  });

  testWidgets('설정에 자동 강화 토글이 없다(광고 10분으로만)', (tester) async {
    await pumpGame(tester, _filled(0.5), openTab: false);
    await tester.tap(find.byKey(const Key('hud.settings')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('settings.autoUpgrade')), findsNothing);
    expect(find.byKey(const Key('settings.autoBoss')), findsOneWidget);
  });

  testWidgets('자동 강화: 광고 준비면 상단 "자동" 광고 버튼, 버프 중이면 남은 시간 칩', (tester) async {
    final s = _filled(0.5);
    final sent = await pumpGame(tester, s, openTab: false, overrides: [adOfferProvider.overrideWith((ref, _) => true)]);
    expect(find.byKey(const Key('ad.autoUpgrade')), findsOneWidget);
    expect(find.byKey(const Key('autoUpgrade.on')), findsNothing);
    final c = ProviderScope.containerOf(tester.element(find.byKey(const Key('top.gold'))));
    c
        .read(gameStateProvider.notifier)
        .replace(s.copyWith(buffs: s.buffs.copyWith(autoUpgradeUntil: s.savedAt.add(const Duration(minutes: 9)))));
    await tester.pump();
    expect(find.byKey(const Key('autoUpgrade.on')), findsOneWidget);
    // 끄기 → CancelAutoUpgrade (남은 시간을 버린다).
    await tester.tap(find.byKey(const Key('autoUpgrade.off')));
    expect(sent.sent.whereType<CancelAutoUpgrade>(), hasLength(1));
    await tester.pump(const Duration(seconds: 2));
  });

  testWidgets('복귀 창: 화물칸이 작아 잘린 골드 + 화물칸 강화 바로가기(받고 배 탭으로)', (tester) async {
    tester.view
      ..physicalSize = const Size(400, 800)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final s = _filled(0.5);
    final room = goldRoom(s, _t, capScale: offlineCapScale(_t, s)); // 복귀는 화물칸 × capMultiplier(또는 다음 강화 바닥값)까지
    final container = ProviderContainer(overrides: [initialGameStateProvider.overrideWithValue(s)]);
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: pixelTheme(),
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: ElevatedButton(
                  onPressed: () => showDialog<void>(
                    context: context,
                    builder: (_) => OfflineRewardDialog(
                      preview: OfflinePreview(seconds: 3600, gold: room.times(3), cards: 0),
                    ),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Lost to a full cargo hold: ${(room.times(3) - room).format()}'), findsOneWidget);
    await tester.tap(find.byKey(const Key('offline.cargo')));
    await tester.pumpAndSettle();
    expect(find.byType(OfflineRewardDialog), findsNothing);
    expect(container.read(dockTabRequestProvider), shipTabIndex);
  });

  testWidgets('복귀 창: 화물칸이 가득이라 받을 골드가 0이면 광고 ×2(+0)를 숨기고 [화물칸 강화]가 주 버튼(실기기 ②)', (
    tester,
  ) async {
    final s = _filled(offlineCapScale(_t, _filled(0)));
    expect(goldRoom(s, _t, capScale: offlineCapScale(_t, s)).isZero, isTrue, reason: '시험 전제: 복귀 상한까지 가득');
    final container = ProviderContainer(
      overrides: [
        initialGameStateProvider.overrideWithValue(s),
        adOfferProvider.overrideWith((ref, _) => true),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          theme: pixelTheme(),
          locale: const Locale('en'),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: OfflineRewardDialog(preview: OfflinePreview(seconds: 3600, gold: BigNum.from(581), cards: 0)),
          ),
        ),
      ),
    );
    await tester.pump();
    expect(tester.widget<PixelButton>(find.byKey(const Key('offline.claim'))).primary, isFalse);
    await tester.tap(find.byKey(const Key('offline.claim')));
    await tester.pump();
    expect(find.byType(OfflineAdButton), findsNothing);
    expect(find.byKey(const Key('offline.cargo')), findsOneWidget);
  });

  group('골든 4기기', () {
    setUpAll(loadGoldenFonts);

    for (final (name, size, dpr) in _devices) {
      testWidgets('화물칸 가득 $name', (tester) async {
        await pumpGame(
          tester,
          _filled(1),
          size: size,
          dpr: dpr,
          locale: const Locale('ko'),
          openTab: false,
          overrides: [adOfferProvider.overrideWith((ref, _) => true)],
        );
        await precacheImages(tester);
        await expectLater(find.byType(MaterialApp), matchesGoldenFile('../goldens/ko_cargo_full_$name.png'));
      });
    }

    testWidgets('화물칸 가득 배 탭 360', (tester) async {
      await pumpGame(
        tester,
        _filled(1),
        size: const Size(360, 640),
        dpr: 3,
        locale: const Locale('ko'),
        tab: shipTab,
        fullSheet: true,
      );
      await precacheImages(tester);
      await tester.ensureVisible(find.byKey(const Key('ship.upgrade.cargo')));
      await tester.pumpAndSettle();
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('../goldens/ko_cargo_ship_360.png'));
    });
  });
}
