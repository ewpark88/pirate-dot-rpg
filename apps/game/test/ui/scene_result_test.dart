import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';
import 'package:pirate_dot/ui/home_screen.dart';
import 'package:pirate_dot/ui/pixel/pixel_dialog.dart';
import 'package:pirate_dot/ui/scene/scene_battle.dart';

import 'ui_harness.dart';

// 결과 창 HD 결 (S1 2026-10-18): 숫자 굴림 · 신기록 도장·이전 기록 줄 긋기 · 실패면 약점 편성 바로가기.

Future<void> _open(WidgetTester tester, Widget dialog) async {
  await pumpGame(tester, loadFixture('stage37_midgame'), openTab: false);
  showSkinDialog<void>(tester.element(find.byType(HomeScreen)), builder: (_) => dialog).ignore();
  await tester.pump();
}

void main() {
  testWidgets('탑 신기록: 층 숫자 굴러 오름 → NEW RECORD! 도장 · 이전 기록 줄 긋기', (tester) async {
    const end = TowerEnded(1, floor: 14, reason: 'retreat', kills: 300, chestGems: 20, chestCards: 1);
    await _open(tester, const TowerResultDialog(end: end, previousBest: 9));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('Floor 14'), findsNothing); // 굴러 오르는 중
    await tester.pump(const Duration(milliseconds: 1500));
    expect(find.text('Floor 14'), findsWidgets);
    expect(find.byKey(const Key('scene.result.record')), findsOneWidget);
    expect(find.text('Previous Floor 9'), findsOneWidget);
    expect(find.byKey(const Key('scene.result.weak')), findsNothing); // 후퇴는 실패 아님
  });

  testWidgets('탑 침몰(기록 못 넘김): 도장 없음 · 약점 편성 바로가기', (tester) async {
    const end = TowerEnded(1, floor: 5, reason: 'sunk', kills: 80);
    await _open(tester, const TowerResultDialog(end: end, previousBest: 9));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('scene.result.record')), findsNothing);
    expect(find.byKey(const Key('scene.result.weak')), findsOneWidget);
  });

  group('골든', () {
    setUpAll(loadGoldenFonts);
    for (final (name, size, dpr) in const [('360', Size(360, 640), 3.0), ('tablet', Size(800, 1280), 2.0)]) {
      testWidgets('탑 신기록 ko $name', (tester) async {
        await pumpGame(
          tester,
          loadFixture('stage37_midgame'),
          openTab: false,
          size: size,
          dpr: dpr,
          locale: const Locale('ko'),
        );
        const end = TowerEnded(1, floor: 14, reason: 'retreat', kills: 300, chestGems: 20, chestCards: 1);
        showSkinDialog<void>(
          tester.element(find.byType(HomeScreen)),
          builder: (_) => const TowerResultDialog(end: end, previousBest: 9),
        ).ignore();
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 1300)); // 도장 찍히고 폭죽 퍼지는 중
        await precacheImages(tester);
        await tester.pump(const Duration(milliseconds: 1));
        await expectLater(find.byType(MaterialApp), matchesGoldenFile('../goldens/ko_scene_record_$name.png'));
        await tester.pumpAndSettle();
      });
    }
  });
}
