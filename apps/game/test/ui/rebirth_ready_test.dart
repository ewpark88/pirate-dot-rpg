import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';
import 'package:game_data/game_data.dart';
import 'package:pirate_dot/ui/tabs/voyage_tab.dart';

import 'ui_harness.dart';

// 사용자 직접 지시 2026-10-16: 환생 가능 알림(알약·항해 점·맥박·첫 말풍선·손가락) + 환생하면 좋은 것 설명.

GameState _ready({int rebirths = 0, int stage = 45}) {
  final s = loadFixture('stage37_midgame');
  return s.copyWith(
    progress: s.progress.copyWith(stage: stage, bestStage: stage, rebirths: rebirths),
  );
}

const List<(String, Size, double)> _devices = [
  ('360', Size(360, 640), 3.0),
  ('s24', s24Size, s24Dpr),
  ('411', Size(411, 891), 2.625),
  ('tablet', Size(800, 1280), 2.0),
];

void main() {
  final t = GameTables.load();

  test('픽스처 기준: 스테이지 45는 환생 가능, 37은 아님', () {
    expect(rebirthPreview(_ready(), t).locked, isFalse);
    expect(rebirthPreview(_ready(), t).gain, greaterThan(0));
    expect(rebirthPreview(_ready(stage: 37), t).locked, isTrue);
  });

  testWidgets('환생 가능: 알약·항해 점·첫 말풍선·손가락 → 알약 누르면 항해 탭 → 손가락이 환생 버튼으로', (tester) async {
    await pumpGame(tester, _ready(), openTab: false);
    expect(find.byKey(const Key('rebirth.ready.pill')), findsOneWidget);
    expect(find.text('Rebirth ready!'), findsOneWidget);
    expect(find.byKey(const Key('rebirth.ready.bubble')), findsOneWidget);
    expect(find.byKey(const Key('tab.dot.0')), findsOneWidget);
    expect(find.byKey(const Key('tutorial.spot.tab.voyage')), findsOneWidget);

    await tester.tap(find.byKey(const Key('rebirth.ready.pill')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('rebirth.card')), findsOneWidget);
    expect(find.byKey(const Key('tutorial.spot.tab.voyage')), findsNothing);
    await tester.ensureVisible(find.byKey(const Key('rebirth.open')));
    await tester.pump();
    expect(find.byKey(const Key('tutorial.spot.rebirth.open')), findsOneWidget);

    await tester.tap(find.byKey(const Key('rebirth.open')));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('rebirth.why')), findsOneWidget);
    expect(find.byKey(const Key('rebirth.compare.now')), findsOneWidget);
    expect(find.text('At stage 55'), findsOneWidget);
    // 창을 열었으면 손가락 안내는 끝.
    expect(find.byKey(const Key('tutorial.spot.rebirth.open')), findsNothing);
    await tester.pump(const Duration(seconds: 7));
  });

  testWidgets('말풍선은 6초 뒤 닫힌다', (tester) async {
    await pumpGame(tester, _ready(), openTab: false);
    expect(find.byKey(const Key('rebirth.ready.bubble')), findsOneWidget);
    await tester.pump(const Duration(seconds: 7));
    expect(find.byKey(const Key('rebirth.ready.bubble')), findsNothing);
  });

  testWidgets('두 번째 회차부터는 알약·점만', (tester) async {
    await pumpGame(tester, _ready(rebirths: 1), openTab: false);
    expect(find.byKey(const Key('rebirth.ready.pill')), findsOneWidget);
    expect(find.byKey(const Key('rebirth.ready.bubble')), findsNothing);
    expect(find.byKey(const Key('tutorial.spot.tab.voyage')), findsNothing);
  });

  testWidgets('해금 전: 알약 없음, 카드에 환생이 뭔지 한 줄', (tester) async {
    await pumpGame(tester, _ready(stage: 37));
    expect(find.byKey(const Key('rebirth.ready.pill')), findsNothing);
    // 해금 전엔 카드가 맨 아래(아직 안 지어졌을 수 있음) — 스크롤해서 짓는다.
    await tester.scrollUntilVisible(
      find.byKey(const Key('rebirth.card')),
      200,
      scrollable: find.descendant(of: find.byType(VoyageTab), matching: find.byType(Scrollable)).first,
    );
    await tester.pump();
    expect(find.byKey(const Key('rebirth.lockedWhy')), findsOneWidget);
  });

  testWidgets('설명 판 수치는 경제 함수 그대로 (지금·+10 스테이지 조각)', (tester) async {
    final s = _ready();
    await pumpGame(tester, s);
    await tester.ensureVisible(find.byKey(const Key('rebirth.open')));
    await tester.pump();
    await tester.tap(find.byKey(const Key('rebirth.open')));
    await tester.pumpAndSettle();
    final now = rebirthPreview(s, t);
    final later = rebirthPreview(s.copyWith(progress: s.progress.copyWith(stage: 55)), t);
    expect(find.textContaining('+${now.gain} pieces'), findsWidgets);
    expect(find.textContaining('+${later.gain} pieces'), findsOneWidget);
    expect(later.gain, greaterThan(now.gain));
    await tester.pump(const Duration(seconds: 7));
  });

  group('골든 4기기', () {
    setUpAll(loadGoldenFonts);

    for (final (name, size, dpr) in _devices) {
      testWidgets('환생 가능 전장 $name', (tester) async {
        await pumpGame(tester, _ready(), size: size, dpr: dpr, locale: const Locale('ko'), openTab: false);
        await precacheImages(tester);
        await expectLater(find.byType(MaterialApp), matchesGoldenFile('../goldens/ko_rebirth_ready_$name.png'));
        await tester.pump(const Duration(seconds: 7));
      });

      testWidgets('환생 설명 창 $name', (tester) async {
        await pumpGame(tester, _ready(), size: size, dpr: dpr, locale: const Locale('ko'));
        await precacheImages(tester);
        await tester.ensureVisible(find.byKey(const Key('rebirth.open')));
        await tester.pump();
        await tester.tap(find.byKey(const Key('rebirth.open')));
        await tester.pumpAndSettle();
        await expectLater(find.byType(MaterialApp), matchesGoldenFile('../goldens/ko_rebirth_why_$name.png'));
        await tester.pump(const Duration(seconds: 7));
      });
    }
  });
}
