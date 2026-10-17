import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';

import 'ui_harness.dart';

/// 레이아웃 점검: 작은 화면(360×640)·한국어·가로. 넘침(overflow)은 위젯 테스트에서 예외로 실패한다.
void main() {
  const small = Size(360, 640);
  final fixtures = ['new_player', 'stage37_midgame', 'boss_fight', 'all_crews_mythic'];

  for (final locale in const [Locale('en'), Locale('ko')]) {
    for (final name in fixtures) {
      testWidgets('${locale.languageCode} 360×640 $name: 탭 4개가 넘치지 않는다', (tester) async {
        for (final tab in [voyageTab, shipTab, crewTab, summonTab]) {
          await pumpGame(tester, _farming(loadFixture(name)), locale: locale, tab: tab, size: small);
        }
      });
    }

    testWidgets('${locale.languageCode} 360×640: 설정 화면이 넘치지 않는다', (tester) async {
      await pumpGame(tester, loadFixture('stage37_midgame'), locale: locale, size: small);
      await tester.tap(find.byKey(const Key('hud.settings')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('settings.lang')), findsOneWidget);
    });
  }

  group('한국어 화면 문구', () {
    testWidgets('HUD·배 탭', (tester) async {
      await pumpGame(tester, loadFixture('boss_fight'), locale: const Locale('ko'), tab: shipTab);
      expect(find.text('브레이크'), findsOneWidget); // 보스전 브레이크 막대 꼬리표(궁극기 버튼은 2026-10-17 제거)
      // 배 탭 맨 위에 '모두 강화'(56dp)가 생겨 부위 줄은 조금 아래 — 굴려서 찾는다.
      await tester.scrollUntilVisible(find.text('대포'), 100, scrollable: find.byType(Scrollable).last);
      expect(find.text('대포'), findsOneWidget);
    });

    testWidgets('소환 탭: 천장 문구', (tester) async {
      await pumpGame(tester, loadFixture('stage37_midgame'), locale: const Locale('ko'), tab: summonTab);
      expect(find.text('1회 소환'), findsOneWidget);
      expect(find.text('50회 안에 영웅 이상 확정'), findsOneWidget);
    });

    testWidgets('선원 탭: 도감·일괄 합치기·출전', (tester) async {
      await pumpGame(tester, loadFixture('stage37_midgame'), locale: const Locale('ko'), tab: crewTab);
      expect(find.text('도감 4/40'), findsOneWidget);
      expect(find.text('일괄 합치기'), findsOneWidget);
      expect(find.text('출전', skipOffstage: false), findsWidgets);
    });

    testWidgets('파밍: 보스 도전', (tester) async {
      await pumpGame(tester, _farming(loadFixture('stage37_midgame')), locale: const Locale('ko'));
      expect(find.byTooltip('보스 도전'), findsOneWidget);
    });
  });

  // 가로 화면 안전망은 뺐다 — 앱이 세로 고정이다(main 53b8831, 태블릿도 세로).

  testWidgets('접근성: 아이콘 버튼에는 설명(tooltip)이 있다', (tester) async {
    await pumpGame(tester, loadFixture('stage37_midgame'));
    expect(
      find.descendant(of: find.byKey(const Key('hud.settings')), matching: find.byTooltip('Settings')),
      findsOneWidget,
    );
    // 퀘스트는 도크 첫 칸(#9 A) — 툴팁 대신 아이콘 아래 글자가 늘 보인다.
    expect(find.descendant(of: find.byKey(const Key('daily.icon')), matching: find.text('Quests')), findsOneWidget);
    await expectLater(tester, meetsGuideline(textContrastGuideline));
  });
}

/// 보스 도전 버튼까지 보이게 파밍 상태로 (보스전 중이면 버튼은 숨는다).
GameState _farming(GameState s) => s.copyWith(progress: s.progress.copyWith(farming: true));
