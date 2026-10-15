import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';
import 'package:pirate_dot/l10n/gen/app_localizations.dart';
import 'package:pirate_dot/ui/state/badge_providers.dart';
import 'package:pirate_dot/ui/text/big_num_text.dart';

import 'ui_harness.dart';

/// ‘지금 할 수 있는 일’ 빨간 점 (계획 E5) · 큰 수 전체 값 (계획 E11).
GameState _money(String gold, int gems) {
  final s = loadFixture('stage37_midgame');
  return s.copyWith(
    wallet: s.wallet.copyWith(gold: BigNum.parse(gold), gems: gems),
  );
}

Finder _dot(int tab) => find.byKey(Key('tab.dot.$tab'));

void main() {
  testWidgets('배 탭: 살 수 있는 강화가 있으면 점, 골드 0이면 없음', (tester) async {
    await pumpGame(tester, _money('1e30', 0));
    expect(_dot(shipTab), findsOneWidget);
    await pumpGame(tester, _money('0', 0));
    expect(_dot(shipTab), findsNothing);
  });

  testWidgets('보고 있는 탭에는 점이 없다', (tester) async {
    await pumpGame(tester, _money('1e30', 0), tab: shipTab);
    expect(_dot(shipTab), findsNothing);
  });

  testWidgets('소환 탭: 젬이 1회 비용 이상이면 점, 0이면 없음', (tester) async {
    await pumpGame(tester, _money('0', 1000));
    expect(_dot(summonTab), findsOneWidget);
    await pumpGame(tester, _money('0', 0));
    expect(_dot(summonTab), findsNothing);
  });

  testWidgets('선원 탭: 승급할 수 있는 선원이 있으면 점', (tester) async {
    final s = _money('1e30', 0);
    await pumpGame(tester, s.copyWith(crews: {...s.crews, 'octo': s.crews['octo']!.copyWith(cards: 99)}));
    expect(_dot(crewTab), findsOneWidget);
    await pumpGame(tester, _money('0', 0));
    expect(_dot(crewTab), findsNothing);
  });

  testWidgets('선원 탭: 합치기로 오를 선원이 있으면 탭 점 + 일괄 합치기 점', (tester) async {
    await pumpGame(
      tester,
      _money('0', 0),
      overrides: [mergeAvailableProvider.overrideWithValue((_) => true)],
    );
    expect(_dot(crewTab), findsOneWidget);
    await tester.tap(find.byKey(const Key('tab.$crewTab')));
    await tester.pump();
    expect(find.byKey(const Key('crew.mergeAll.dot')), findsOneWidget);
  });

  test('큰 수 전체 값: 10^20 이하는 쉼표, 그 위는 m × 10^e', () async {
    final l10n = await AppLocalizations.delegate.load(const Locale('en'));
    expect(fullBigNumText(l10n, BigNum.parse('1.25e6')), '1,250,000');
    expect(fullBigNumText(l10n, BigNum.parse('999')), '999');
    expect(fullBigNumText(l10n, BigNum.parse('1.25e24')), '1.25 × 10^24');
  });

  testWidgets('상단 바 골드를 길게 누르면 전체 자릿수', (tester) async {
    await pumpGame(tester, loadFixture('stage37_midgame'));
    await tester.longPress(find.byKey(const Key('top.gold')));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.text('1,250,000'), findsOneWidget);
  });

  testWidgets('설정: 도움말에 큰 수 단위 설명', (tester) async {
    await pumpGame(tester, loadFixture('stage37_midgame'));
    await tester.tap(find.byKey(const Key('hud.settings')));
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.byKey(const Key('settings.help')), 200);
    expect(find.textContaining('K = thousand'), findsOneWidget);
  });
}
