import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';
import 'package:game_data/game_data.dart';
import 'package:pirate_dot/render/battle_feed.dart';
import 'package:pirate_dot/ui/home_screen.dart';
import 'package:pirate_dot/ui/meta/rebirth.dart';
import 'package:pirate_dot/ui/rebirth/rebirth_chest.dart';
import 'package:pirate_dot/ui/rebirth/rebirth_v2.dart';
import 'package:pirate_dot/ui/skin/skin_button.dart';
import 'package:pirate_dot/ui/state/game_providers.dart';
import 'package:pirate_dot/ui/summon/summon_result.dart';

import 'ui_harness.dart';

// 환생 v2 화면 (스펙 platform-rebirth-v2 7장) — 경제 계약 전이라 가짜 컨트롤러(rebirthV2Provider)로 시험한다.

const _available = RebirthPreview(
  locked: false,
  minStage: 40,
  currentPieces: 0,
  gain: 7,
  nextPieceInStages: 3,
  bonusPerPiece: 0.05,
);

/// 항해 패널을 끝까지 펴야 환생 카드가 보인다 → 세로로 긴 화면.
const _tall = Size(400, 1300);

GameState _state({
  int pieces = 40,
  int rebirths = 0,
  int stage = 37,
  Map<String, int> shop = const {},
  Set<String> skins = const {},
  String? skin,
  List<String> titles = const [],
  String? title,
  int? route,
}) {
  final s = loadFixture('stage37_midgame');
  return s.copyWith(
    progress: s.progress.copyWith(rebirths: rebirths, stage: stage, titles: titles, treasureRoute: route),
    wallet: s.wallet.copyWith(mapPieces: pieces),
    rebirthShop: shop,
    ship: s.ship.copyWith(skinsOwned: skins, skin: skin),
    settings: s.settings.withTitle(title),
  );
}

Future<void> _openShop(WidgetTester tester) async {
  await showInSheet(tester, 'rebirth.shop.open');
  await tester.tap(find.byKey(const Key('rebirth.shop.open')));
  await tester.pumpAndSettle();
}

bool _enabled(WidgetTester tester, String key) => tester.widget<SkinButton>(find.byKey(Key(key))).onPressed != null;

void main() {
  testWidgets('상점: 2·3줄 잠김 안내, 칸을 누르면 레벨·효과, 사면 조각이 줄고 레벨이 오른다', (tester) async {
    final log = await pumpGame(tester, _state(), size: _tall);
    await _openShop(tester);
    expect(find.text('40 pieces to spend'), findsOneWidget);
    expect(find.text('Spend 30 more pieces to unlock'), findsOneWidget);
    expect(find.text('Spend 150 more pieces to unlock'), findsOneWidget);
    expect(find.text('Tap a slot to see its effect'), findsOneWidget);

    await tester.tap(find.byKey(const Key('rebirth.shop.item.startParts')));
    await tester.pumpAndSettle();
    expect(find.text('Level 0 → 1'), findsOneWidget);
    expect(find.text('Effect +0 lv → +5 lv'), findsOneWidget);
    await tester.tap(find.byKey(const Key('rebirth.shop.buy')));
    await tester.pump();
    expect(log.sent.whereType<BuyRebirthUpgrade>().map((c) => c.toJson()), [
      const BuyRebirthUpgrade('startParts').toJson(),
    ]);
    await tester.pumpAndSettle(const Duration(seconds: 3));
  });

  testWidgets('상점: 쓴 조각 누계 30이면 2줄이 열린다 · 잠긴 줄 칸은 살 수 없다', (tester) async {
    await pumpGame(tester, _state(pieces: 200), size: _tall);
    await _openShop(tester);
    await tester.tap(find.byKey(const Key('rebirth.shop.item.offline')));
    await tester.pumpAndSettle();
    expect(_enabled(tester, 'rebirth.shop.buy'), isFalse);
    // startParts 5레벨 = 3+5+6+8+10 = 32 ≥ 30.
    await pumpGame(tester, _state(pieces: 200, shop: {'startParts': 5}), size: _tall);
    await _openShop(tester);
    expect(find.text('Spend 30 more pieces to unlock'), findsNothing);
    expect(find.text('Spend 118 more pieces to unlock'), findsOneWidget);
    expect(find.text('Lv 5/10'), findsOneWidget);
    await tester.tap(find.byKey(const Key('rebirth.shop.item.offline')));
    await tester.pumpAndSettle();
    expect(_enabled(tester, 'rebirth.shop.buy'), isTrue);
    expect(find.text('Effect +0h → +1h'), findsOneWidget);
  });

  testWidgets('조각이 모자라면 구매 버튼이 꺼지고 항해 점이 없다', (tester) async {
    await pumpGame(tester, _state(pieces: 2), size: _tall);
    expect(find.byKey(const Key('tab.dot.0')), findsNothing);
    await _openShop(tester);
    await tester.tap(find.byKey(const Key('rebirth.shop.item.startParts')));
    await tester.pumpAndSettle();
    expect(_enabled(tester, 'rebirth.shop.buy'), isFalse);
  });

  testWidgets('살 수 있는 칸이 있으면 상점 버튼에 빨간 점', (tester) async {
    await pumpGame(tester, _state(), size: _tall);
    await showInSheet(tester, 'rebirth.shop.open');
    expect(find.byKey(const Key('rebirth.shop.cardDot')), findsOneWidget);
  });

  testWidgets('환생 카드: 미리보기 한 줄(전투력 × · 약 N분)', (tester) async {
    await pumpGame(
      tester,
      _state(stage: 50),
      size: _tall,
      overrides: [rebirthPreviewProvider.overrideWithValue((_) => _available)],
    );
    await tester.ensureVisible(find.byKey(const Key('rebirth.forecast')));
    await tester.pump();
    expect(find.textContaining('to pass stage 50'), findsOneWidget);
  });

  testWidgets('확인 창: 배 외형 그대로 · 상자 줄 · 환생 3회부터 보물 바다 항로', (tester) async {
    final log = await pumpGame(
      tester,
      _state(rebirths: 3, stage: 50),
      size: _tall,
      overrides: [rebirthPreviewProvider.overrideWithValue((_) => _available)],
    );
    await tester.ensureVisible(find.byKey(const Key('rebirth.open')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('rebirth.open')));
    await tester.pumpAndSettle();
    // 그대로인 것은 설명 판(rebirth.why)의 '그대로' 줄(사용자 지시 2026-10-16).
    expect(find.text('Crew · collection · gems · ship look'), findsOneWidget);
    expect(find.text('Chest: 80 gems · 1 hero+ summon(s)'), findsOneWidget);
    expect(find.byKey(const Key('rebirth.sea.2')), findsNothing);
    await tester.ensureVisible(find.byKey(const Key('rebirth.sea.1')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('rebirth.sea.1')));
    await tester.pump();
    expect(log.sent.whereType<SetTreasureRoute>().map((c) => c.toJson()), [const SetTreasureRoute(1).toJson()]);
  });

  testWidgets('확인 창: 항로가 정해져 있으면(progress.treasureRoute) 체력·조각 배수', (tester) async {
    await pumpGame(
      tester,
      _state(rebirths: 3, stage: 50, route: 1),
      size: _tall,
      overrides: [rebirthPreviewProvider.overrideWithValue((_) => _available)],
    );
    await tester.ensureVisible(find.byKey(const Key('rebirth.open')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('rebirth.open')));
    await tester.pumpAndSettle();
    expect(find.text('Enemy HP ×2.0 · Pieces ×1.5'), findsOneWidget);
  });

  testWidgets('확인 창: 환생 2회 이하는 항로가 없다', (tester) async {
    await pumpGame(
      tester,
      _state(rebirths: 2, stage: 50),
      size: _tall,
      overrides: [rebirthPreviewProvider.overrideWithValue((_) => _available)],
    );
    await tester.ensureVisible(find.byKey(const Key('rebirth.open')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('rebirth.open')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('rebirth.treasure')), findsNothing);
  });

  test('상자 내용 식 (스펙 3-1): 1회 젬 50·소환 1·coral·deckhand, 5회 젬 90·소환 2·gold, 20회 칭호만', () {
    expect(chestFor(1), (gems: 50, summons: 1, title: 'deckhand', skin: 'coral'));
    expect(chestFor(5), (gems: 90, summons: 2, title: 'captain', skin: 'gold'));
    expect(chestFor(12), (gems: 150, summons: 3, title: null, skin: null));
    expect(chestFor(20), (gems: 150, summons: 3, title: 'seaKing', skin: null));
  });

  testWidgets('첫 환생 상자: 열면 조각·젬·소환·스킨·칭호가 차례로, 스킨 배를 크게', (tester) async {
    await pumpGame(tester, _state());
    await _showChest(tester, chestFor(1));
    expect(find.text('Tap the chest to open'), findsOneWidget);
    expect(find.text('Gems +50'), findsNothing);
    await tester.tap(find.byKey(const Key('rebirth.chest.box')));
    await tester.pumpAndSettle();
    expect(find.text('Gems +50'), findsOneWidget);
    expect(find.text('Hero+ summon ×1'), findsOneWidget);
    expect(find.text('New ship skin: Coral Voyagers'), findsOneWidget);
    expect(find.text('New title: Map Reader'), findsOneWidget);
    expect(find.byKey(const Key('rebirth.chest.skin')), findsOneWidget);
  });

  testWidgets('배 스킨: 칸을 누르면 미리보기 — 가진 것은 [입기] → SelectShipSkin, 잠긴 것은 얻는 방법(환생 5회)', (tester) async {
    final log = await pumpGame(
      tester,
      _state(rebirths: 3, skins: {'coral', 'storm'}, skin: 'coral'),
      tab: shipTab,
    );
    await tester.tap(find.byKey(const Key('ship.skin')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('ship.skin.equipped')), findsOneWidget, reason: '처음엔 입은 coral 미리보기');
    await tester.tap(find.byKey(const Key('ship.skin.storm')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('ship.skin.wear')));
    await tester.pump();
    expect(log.sent.whereType<SelectShipSkin>().map((c) => c.toJson()), [const SelectShipSkin('storm').toJson()]);
    await tester.ensureVisible(find.byKey(const Key('ship.skin.gold')));
    await tester.tap(find.byKey(const Key('ship.skin.gold')));
    await tester.pump();
    expect(find.text('Rebirth ×5'), findsOneWidget);
    expect(find.byKey(const Key('ship.skin.wear')), findsNothing);
  });

  testWidgets('새 스킨 7종도 한 칸에: 도감 10명 king은 잠김 + 얻는 방법 · 조각 abyss는 조각이 모자라면 사기 버튼 꺼짐', (tester) async {
    final log = await pumpGame(
      tester,
      _state(rebirths: 3, skins: {'coral'}, skin: 'coral'),
      tab: shipTab,
    );
    await tester.tap(find.byKey(const Key('ship.skin')));
    await tester.pumpAndSettle();
    await tester.ensureVisible(find.byKey(const Key('ship.skin.king')));
    await tester.tap(find.byKey(const Key('ship.skin.king')));
    await tester.pump();
    expect(find.text('Collect 10 crew'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const Key('ship.skin.abyss')));
    await tester.tap(find.byKey(const Key('ship.skin.abyss')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('ship.skin.buy')), warnIfMissed: false);
    await tester.pump();
    expect(log.sent.whereType<BuySkin>(), isEmpty, reason: '조각 50개가 없으면 못 산다');
  });

  testWidgets('환생 전: 칭호 띠는 없고, 스킨 버튼은 있다(잠긴 스킨의 얻는 방법을 보여 주려고)', (tester) async {
    await pumpGame(tester, _state());
    expect(find.byKey(const Key('title.chip')), findsNothing);
    await tester.tap(find.byKey(const Key('tab.$shipTab')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('ship.skin')), findsOneWidget);
  });

  testWidgets('칭호: 띠를 누르면 목록, 고르면 SelectTitle · 고른 칭호가 띠에 보인다', (tester) async {
    final log = await pumpGame(tester, _state(rebirths: 3, titles: ['deckhand', 'navigator']));
    expect(find.text('Title'), findsOneWidget);
    await tester.tap(find.byKey(const Key('title.chip')));
    await tester.pumpAndSettle();
    // 잠긴 칭호는 진행(지금/필요) — 환생 3회면 '선장(5회)'은 3/5, 패스 칭호 줄도 있다.
    expect(find.text('Rebirths 3/5'), findsOneWidget);
    expect(find.byKey(const Key('title.passFlag')), findsOneWidget);
    await tester.tap(find.byKey(const Key('title.navigator')));
    await tester.pump();
    expect(log.sent.whereType<SelectTitle>().map((c) => c.toJson()), [const SelectTitle('navigator').toJson()]);
    await pumpGame(tester, _state(rebirths: 3, titles: ['deckhand', 'navigator'], title: 'navigator'));
    expect(find.text('Seasoned Navigator'), findsOneWidget);
  });

  testWidgets('골든: 칭호 목록(환생 3회 — 진행 막대·패스 칭호) ko', (tester) async {
    await loadGoldenFonts();
    await pumpGame(tester, _state(rebirths: 3, titles: ['deckhand', 'navigator']), locale: const Locale('ko'));
    await tester.tap(find.byKey(const Key('title.chip')));
    await tester.pumpAndSettle();
    await precacheImages(tester);
    await expectLater(find.byType(MaterialApp), matchesGoldenFile('../goldens/ko_title_sheet.png'));
  });

  test('화면 스킨·칭호 목록 = 경제 meta.rebirth (id·회차)', () {
    final meta = GameTables.load().meta.rebirth;
    expect(
      [for (final s in skinDefs) (s.id, s.rebirths)],
      [
        for (final o in meta.objs('skins')) (o.str('id'), o.integer('rebirths')),
      ],
    );
    expect(titleDefs, [for (final o in meta.objs('titles')) (o.str('id'), o.integer('rebirths'))]);
  });

  testWidgets('명예 외형: 환생 전 단계가 지금 레벨 단계보다 높으면 부위 칸에 표시', (tester) async {
    final s = _state();
    // 명예 단계 = 지금 레벨의 외형 단계 + 1 (표 visualStages에서 계산).
    final cannon = GameTables.load().shipParts.byId('cannon');
    final honored = s.copyWith(
      ship: s.ship.copyWith(honorParts: {'cannon': partLookStage(cannon, s.ship.level('cannon')) + 1}),
    );
    await pumpGame(tester, honored, tab: shipTab);
    expect(find.byKey(const Key('ship.honor.cannon')), findsOneWidget);
    expect(find.byKey(const Key('ship.honor.hull')), findsNothing);
  });

  testWidgets('해금 안내: ContentUnlocked(crewMaxLevel 80 · shopRow 2) → 토스트', (tester) async {
    final feed = StreamController<RecordedTick>.broadcast(sync: true);
    addTearDown(feed.close);
    final s = _state();
    await pumpGame(tester, s, openTab: false, overrides: [battleFeedProvider.overrideWithValue(feed.stream)]);
    feed.add(RecordedTick(s.battle!, const [ContentUnlocked(1, kind: 'crewMaxLevel', value: 80)]));
    await tester.pump();
    expect(find.text('Crew max level 80!'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
    feed.add(RecordedTick(s.battle!, const [ContentUnlocked(1, kind: 'shopRow', value: 2)]));
    await tester.pump();
    expect(find.text('Treasure Map Shop row 2 unlocked!'), findsOneWidget);
    await tester.pump(const Duration(seconds: 3));
  });

  testWidgets('상자 → 소환 순서: 환생과 영웅 소환이 함께 오면 상자를 닫은 뒤 소환 결과 창', (tester) async {
    final s = _state();
    await pumpGame(tester, s, openTab: false);
    final container = ProviderScope.containerOf(tester.element(find.byType(HomeScreen)));
    container
        .read(gameStateProvider.notifier)
        .replace(
          s.copyWith(
            progress: s.progress.copyWith(rebirths: 1),
            lastSummon: const [SummonResult(crewId: 'octo', rarity: 'hero')],
          ),
        );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('rebirth.chest')), findsOneWidget);
    expect(find.byType(SummonResultDialog), findsNothing);
    await tester.tap(find.byKey(const Key('rebirth.chest.open')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('rebirth.chest.sail')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('rebirth.chest')), findsNothing);
    expect(find.byType(SummonResultDialog), findsOneWidget);
  });

  group('골든', () {
    setUpAll(loadGoldenFonts);

    for (final lang in ['ko', 'en']) {
      testWidgets('상점 $lang', (tester) async {
        await pumpGame(
          tester,
          _state(pieces: 60, shop: {'startParts': 1}),
          locale: Locale(lang),
          size: _tall,
        );
        await precacheImages(tester);
        await _openShop(tester);
        await tester.tap(find.byKey(const Key('rebirth.shop.item.startParts')));
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('rebirth.shop.buy')));
        await tester.pumpAndSettle(const Duration(seconds: 3));
        await tester.tap(find.byKey(const Key('rebirth.shop.item.discount')));
        await tester.pumpAndSettle();
        await expectLater(find.byType(MaterialApp), matchesGoldenFile('../goldens/${lang}_rebirth_shop.png'));
      });
    }

    testWidgets('상자 팝업 ko (첫 환생, 열린 뒤)', (tester) async {
      await pumpGame(tester, _state(), locale: const Locale('ko'));
      await precacheImages(tester);
      await _showChest(tester, chestFor(1));
      await tester.tap(find.byKey(const Key('rebirth.chest.open')));
      await tester.pumpAndSettle();
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('../goldens/ko_rebirth_chest.png'));
    });

    testWidgets('확인 창 ko (보물 바다 2해역)', (tester) async {
      await pumpGame(
        tester,
        _state(rebirths: 5, stage: 60),
        locale: const Locale('ko'),
        size: _tall,
        overrides: [rebirthPreviewProvider.overrideWithValue((_) => _available)],
      );
      await precacheImages(tester);
      await tester.ensureVisible(find.byKey(const Key('rebirth.open')));
      await tester.pump();
      await tester.tap(find.byKey(const Key('rebirth.open')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const Key('rebirth.sea.2')));
      await tester.pumpAndSettle();
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('../goldens/ko_rebirth_dialog_v2.png'));
    });

    testWidgets('배 스킨 ko', (tester) async {
      await pumpGame(
        tester,
        _state(rebirths: 5, skins: {'coral', 'storm', 'gold'}, skin: 'coral'),
        locale: const Locale('ko'),
        tab: shipTab,
      );
      await precacheImages(tester);
      await tester.tap(find.byKey(const Key('ship.skin')));
      await tester.pumpAndSettle();
      await expectLater(find.byType(MaterialApp), matchesGoldenFile('../goldens/ko_ship_skin.png'));
    });
  });
}

Future<void> _showChest(WidgetTester tester, ChestVm chest) async {
  final context = tester.element(find.byKey(const Key('battle.area')));
  // 창은 테스트가 닫는다.
  unawaited(
    showDialog<void>(
      context: context,
      builder: (_) => RebirthChestDialog(chest: chest, pieces: 7, bonus: '35%'),
    ),
  );
  await tester.pumpAndSettle();
}
