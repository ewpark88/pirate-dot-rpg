import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'ui_harness.dart';

// 선원 카드 Lv 배지 (사용자 2026-10-17 'Lv가 뭐냐 — 잘 보이게 크게'): 작은 'Lv' + 큰 숫자, 누르면 'Lv = 공격력' 팁.

void main() {
  testWidgets('Lv 배지를 누르면 한 줄 팁(상세 창 아님)', (tester) async {
    await pumpGame(tester, loadFixture('stage37_midgame'), tab: crewTab);
    final badge = find.byKey(const Key('crew.level.octo'));
    await tester.scrollUntilVisible(badge, 200, scrollable: find.byType(Scrollable).last);
    await tester.ensureVisible(badge);
    await tester.pumpAndSettle();
    await tester.tap(badge);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('Higher Lv = more attack'), findsOneWidget);
    expect(find.byKey(const Key('crew.detail.octo')), findsNothing);
    await tester.pump(const Duration(seconds: 3));
  });
}
