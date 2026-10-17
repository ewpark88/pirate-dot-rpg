import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pirate_dot/ui/home_screen.dart';
import 'package:pirate_dot/ui/rebirth/rebirth_cinematic.dart';
import 'package:pirate_dot/ui/rebirth/rebirth_v2.dart' show ChestVm;

import 'ui_harness.dart';

// 환생 연출 (S1 2026-10-18): 금빛 감김 → 지도 비 '보물지도 +n' → 새 돛 출항 '다시 출항!' → 보상 카드, 탭하면 넘김·닫힘.

const ChestVm _chest = (gems: 50, summons: 1, title: 'captain', skin: 'gold');

void main() {
  testWidgets('차례로: 지도 +n → 다시 출항! → 카드, 끝나면 저절로 닫힘', (tester) async {
    await pumpGame(tester, loadFixture('stage37_midgame'), openTab: false);
    var closed = false;
    showRebirthCinematic(
      tester.element(find.byType(HomeScreen)),
      pieces: 7,
      chest: _chest,
    ).then((_) => closed = true).ignore();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 900));
    expect(find.text('Treasure map +7'), findsOneWidget);
    expect(find.byKey(const Key('rebirth.cine.sail')), findsNothing);
    await tester.pump(const Duration(milliseconds: 1300));
    expect(find.byKey(const Key('rebirth.cine.sail')), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 800));
    expect(find.byKey(const Key('rebirth.cine.card.3')), findsOneWidget);
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('rebirth.cine')), findsNothing);
    expect(closed, isTrue);
  });

  testWidgets('탭: 처음엔 끝 장면으로 넘김, 다시 탭하면 닫힘', (tester) async {
    await pumpGame(tester, loadFixture('stage37_midgame'), openTab: false);
    showRebirthCinematic(tester.element(find.byType(HomeScreen)), pieces: 3, chest: _chest).ignore();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.byKey(const Key('rebirth.cine')));
    await tester.pump();
    expect(find.byKey(const Key('rebirth.cine.sail')), findsOneWidget);
    await tester.tap(find.byKey(const Key('rebirth.cine')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('rebirth.cine')), findsNothing);
  });

  group('골든', () {
    setUpAll(loadGoldenFonts);
    for (final (name, size, dpr) in const [('360', Size(360, 640), 3.0), ('tablet', Size(800, 1280), 2.0)]) {
      testWidgets('환생 연출 끝 장면 ko $name', (tester) async {
        await pumpGame(
          tester,
          loadFixture('stage37_midgame'),
          openTab: false,
          size: size,
          dpr: dpr,
          locale: const Locale('ko'),
        );
        showRebirthCinematic(tester.element(find.byType(HomeScreen)), pieces: 7, chest: _chest).ignore();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 1000));
        await tester.pump(const Duration(milliseconds: 1950));
        await precacheImages(tester);
        await tester.pump(const Duration(milliseconds: 1));
        await expectLater(find.byType(MaterialApp), matchesGoldenFile('../goldens/ko_rebirth_cine_$name.png'));
        await tester.pumpAndSettle();
      });
    }
  });
}
