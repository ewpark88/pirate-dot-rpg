import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:game_core/game_core.dart';

import 'ui_harness.dart';

// 시트 자동 접기 (사용자 2026-10-18 '버튼을 다 눌렀으면 자동으로 내려가서 전투를 볼 수 있게'): 열린 탭의 할 일(빨간 점)이
// 있다가 없어지면 잠깐 뒤 접는다. 다른 탭의 점이 바뀌는 건 상관없다.

void main() {
  testWidgets('배 탭: 살 게 있다가(골드 많음) 다 써서 없어지면 0.7초 뒤 시트가 접힌다', (tester) async {
    final s = loadFixture('stage37_midgame');
    final rich = s.copyWith(wallet: s.wallet.copyWith(gold: BigNum.parse('1e30')));
    await pumpGame(tester, rich, tab: 1);
    expect(find.byKey(const Key('sheet.panel')), findsOneWidget);
    replaceState(tester, rich.copyWith(wallet: rich.wallet.copyWith(gold: BigNum.zero)));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 800));
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('sheet.panel')), findsNothing);
  });

  testWidgets('할 일이 원래 없던 탭은 그대로 열려 있다', (tester) async {
    final s = loadFixture('stage37_midgame');
    final poor = s.copyWith(wallet: s.wallet.copyWith(gold: BigNum.zero));
    await pumpGame(tester, poor, tab: 1);
    replaceState(tester, poor.copyWith(wallet: poor.wallet.copyWith(gems: 1)));
    await tester.pump(const Duration(seconds: 1));
    expect(find.byKey(const Key('sheet.panel')), findsOneWidget);
  });
}
