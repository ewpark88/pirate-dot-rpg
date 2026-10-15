import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';
import 'package:pirate_dot/ui/meta/rebirth.dart';
import 'package:pirate_dot/ui/rebirth/rebirth_chest.dart';
import 'package:pirate_dot/ui/rebirth/rebirth_v2.dart';
import 'package:pirate_dot/ui/skin/skin_button.dart';

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

GameState _state({int pieces = 40, int rebirths = 0, int stage = 37}) {
  final s = loadFixture('stage37_midgame');
  return s.copyWith(
    progress: s.progress.copyWith(rebirths: rebirths, stage: stage),
    wallet: s.wallet.copyWith(mapPieces: pieces),
  );
}

Future<void> _openShop(WidgetTester tester) async {
  await tester.ensureVisible(find.byKey(const Key('rebirth.shop.open')));
  await tester.pump();
  await tester.tap(find.byKey(const Key('rebirth.shop.open')));
  await tester.pumpAndSettle();
}

bool _enabled(WidgetTester tester, String key) => tester.widget<SkinButton>(find.byKey(Key(key))).onPressed != null;

void main() {
  testWidgets('상점: 2·3줄 잠김 안내, 칸을 누르면 레벨·효과, 사면 조각이 줄고 레벨이 오른다', (tester) async {
    await pumpGame(tester, _state(), size: _tall);
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
    expect(find.text('37 pieces to spend'), findsOneWidget);
    expect(find.text('Level 1 → 2'), findsOneWidget);
    await tester.pumpAndSettle(const Duration(seconds: 3));
  });

  testWidgets('상점: 쓴 조각 누계 30이면 2줄이 열린다 · 잠긴 줄 칸은 살 수 없다', (tester) async {
    await pumpGame(tester, _state(pieces: 200), size: _tall);
    await _openShop(tester);
    await tester.tap(find.byKey(const Key('rebirth.shop.item.offline')));
    await tester.pumpAndSettle();
    expect(_enabled(tester, 'rebirth.shop.buy'), isFalse);
    // startParts 3+5+6+8+10 = 32 ≥ 30.
    await tester.tap(find.byKey(const Key('rebirth.shop.item.startParts')));
    await tester.pumpAndSettle();
    for (var i = 0; i < 5; i++) {
      await tester.tap(find.byKey(const Key('rebirth.shop.buy')));
      await tester.pump();
    }
    expect(find.text('Spend 30 more pieces to unlock'), findsNothing);
    expect(find.text('Spend 118 more pieces to unlock'), findsOneWidget);
    await tester.tap(find.byKey(const Key('rebirth.shop.item.offline')));
    await tester.pumpAndSettle();
    expect(_enabled(tester, 'rebirth.shop.buy'), isTrue);
    await tester.pumpAndSettle(const Duration(seconds: 3));
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
    await pumpGame(
      tester,
      _state(rebirths: 3, stage: 50),
      size: _tall,
      overrides: [rebirthPreviewProvider.overrideWithValue((_) => _available)],
    );
    await tester.ensureVisible(find.byKey(const Key('rebirth.open')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('rebirth.open')));
    await tester.pumpAndSettle();
    expect(find.text('Kept: crew, collection, gems, ship look'), findsOneWidget);
    expect(find.text('Chest: 80 gems · 1 hero+ summon(s)'), findsOneWidget);
    expect(find.byKey(const Key('rebirth.sea.2')), findsNothing);
    await tester.tap(find.byKey(const Key('rebirth.sea.1')));
    await tester.pump();
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

  testWidgets('배 스킨: 환생 3회 = coral·storm 보유(처음은 coral 장착), gold는 환생 5회 잠김, 고르면 장착', (tester) async {
    await pumpGame(tester, _state(rebirths: 3), tab: shipTab);
    await tester.tap(find.byKey(const Key('ship.skin')));
    await tester.pumpAndSettle();
    expect(find.text('Rebirth ×5'), findsOneWidget);
    expect(find.text('Rebirth ×10'), findsOneWidget);
    expect(find.text('Equipped'), findsOneWidget);
    await tester.tap(find.byKey(const Key('ship.skin.storm')));
    await tester.pump();
    final container = ProviderScope.containerOf(tester.element(find.byKey(const Key('ship.skin.sheet'))));
    expect(container.read(shipSkinProvider).equipped, 'storm');
    await tester.ensureVisible(find.byKey(const Key('ship.skin.gold')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('ship.skin.gold')), warnIfMissed: false);
    await tester.pump();
    expect(container.read(shipSkinProvider).equipped, 'storm');
  });

  testWidgets('환생 전에는 스킨 버튼·칭호 띠가 없다', (tester) async {
    await pumpGame(tester, _state());
    expect(find.byKey(const Key('title.chip')), findsNothing);
    await tester.tap(find.byKey(const Key('tab.$shipTab')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('ship.skin')), findsNothing);
  });

  testWidgets('칭호: 띠를 누르면 목록, 고르면 띠 글자가 바뀐다', (tester) async {
    await pumpGame(tester, _state(rebirths: 3));
    expect(find.text('Title'), findsOneWidget);
    await tester.tap(find.byKey(const Key('title.chip')));
    await tester.pumpAndSettle();
    expect(find.text('Rebirth ×5'), findsOneWidget);
    await tester.tap(find.byKey(const Key('title.navigator')));
    await tester.pump();
    await tester.tapAt(const Offset(10, 60));
    await tester.pumpAndSettle();
    expect(find.text('Seasoned Navigator'), findsOneWidget);
  });

  group('골든', () {
    setUpAll(loadGoldenFonts);

    for (final lang in ['ko', 'en']) {
      testWidgets('상점 $lang', (tester) async {
        await pumpGame(tester, _state(pieces: 60), locale: Locale(lang), size: _tall);
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
      await pumpGame(tester, _state(rebirths: 5), locale: const Locale('ko'), tab: shipTab);
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
